import { Injectable, Logger } from '@nestjs/common';
import { MatchStatus, Prisma, RatingState } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { Glicko2Service, GlickoState } from './glicko2.service';

const matchForRating = {
  teams: { include: { players: true } },
  result: true,
  sets: true,
} satisfies Prisma.MatchInclude;

type MatchForRating = Prisma.MatchGetPayload<{ include: typeof matchForRating }>;

@Injectable()
export class RatingService {
  private readonly logger = new Logger(RatingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly glicko: Glicko2Service,
  ) {}

  /**
   * Aplica el rating de un partido CONFIRMED a sus 4 jugadores (PRD §12).
   * Idempotente por (player_id, match_id) y por match.ratingApplied.
   */
  async applyMatch(matchId: string): Promise<void> {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: matchForRating,
    });
    if (!match) return;
    if (match.status !== MatchStatus.CONFIRMED || match.ratingApplied) {
      this.logger.log(`Partido ${matchId} no aplicable (status=${match.status}, applied=${match.ratingApplied})`);
      return;
    }
    if (!match.result) return;

    const { mov, sides } = await this.prepare(match);
    const playedAt = match.playedAt ?? new Date();

    await this.prisma.$transaction(async (tx) => {
      for (const side of [1, 2] as const) {
        const team = sides[side];
        const opponent = this.glicko.teamOpponent(sides[side === 1 ? 2 : 1].map((p) => p.state));
        const isWinner = match.result!.winnerSide === side;
        const score = this.glicko.movScore(match.result!.gamesDiff, this.totalGames(match), isWinner);

        for (const p of team) {
          const exists = await tx.ratingHistory.findUnique({
            where: { playerId_matchId: { playerId: p.playerId, matchId } },
          });
          if (exists) continue;
          const next = this.glicko.update(p.state, opponent, score);
          await this.persist(tx, p.playerId, matchId, p.state, next, playedAt);
        }
      }
      await tx.match.update({ where: { id: matchId }, data: { ratingApplied: true } });
    });
    this.logger.log(`Rating aplicado al partido ${matchId}`);
  }

  /**
   * Recalcula el rating de un jugador desde cero replayando sus partidos CONFIRMED
   * en orden cronológico (PRD §7.5/§12.6). Usado tras un merge de invitado.
   * MVP: usa el rating actual de los oponentes como aproximación.
   */
  async recomputePlayer(playerId: string): Promise<void> {
    const matches = await this.prisma.match.findMany({
      where: { status: MatchStatus.CONFIRMED, players: { some: { playerId } } },
      include: matchForRating,
      orderBy: [{ playedAt: 'asc' }, { createdAt: 'asc' }],
    });

    await this.prisma.$transaction(async (tx) => {
      await tx.ratingHistory.deleteMany({ where: { playerId } });
      let state = this.glicko.defaultState();
      let count = 0;
      let last: Date | null = null;

      for (const match of matches) {
        if (!match.result) continue;
        const side = this.sideOf(match, playerId);
        if (!side) continue;
        const opponentStates = await this.opponentStates(tx, match, side, playerId);
        const opponent = this.glicko.teamOpponent(opponentStates);
        const isWinner = match.result.winnerSide === side;
        const score = this.glicko.movScore(match.result.gamesDiff, this.totalGames(match), isWinner);
        const next = this.glicko.update(state, opponent, score);
        await this.writeHistory(tx, playerId, match.id, state, next);
        state = next;
        count++;
        last = match.playedAt ?? last;
      }

      await this.writeCurrent(tx, playerId, state, count, last);
    });
    this.logger.log(`Rating recalculado para player ${playerId}`);
  }

  // ─────────────────────────── helpers ───────────────────────────

  private async prepare(match: MatchForRating) {
    const sides: Record<1 | 2, Array<{ playerId: string; state: GlickoState }>> = { 1: [], 2: [] };
    for (const team of match.teams) {
      for (const mp of team.players) {
        sides[team.side as 1 | 2].push({
          playerId: mp.playerId,
          state: await this.stateOf(mp.playerId),
        });
      }
    }
    return { mov: true, sides };
  }

  private totalGames(match: MatchForRating): number {
    return match.sets.reduce((s, set) => s + set.games1 + set.games2, 0);
  }

  private sideOf(match: MatchForRating, playerId: string): 1 | 2 | null {
    for (const team of match.teams) {
      if (team.players.some((p) => p.playerId === playerId)) return team.side as 1 | 2;
    }
    return null;
  }

  private async opponentStates(
    tx: Prisma.TransactionClient,
    match: MatchForRating,
    side: 1 | 2,
    _playerId: string,
  ): Promise<GlickoState[]> {
    const oppTeam = match.teams.find((t) => t.side !== side);
    if (!oppTeam) return [this.glicko.defaultState()];
    const states: GlickoState[] = [];
    for (const mp of oppTeam.players) {
      states.push(await this.stateOf(mp.playerId, tx));
    }
    return states;
  }

  private async stateOf(playerId: string, tx?: Prisma.TransactionClient): Promise<GlickoState> {
    const client = tx ?? this.prisma;
    const rc = await client.ratingCurrent.findUnique({ where: { playerId } });
    if (!rc) return this.glicko.defaultState();
    return { rating: Number(rc.mu), rd: Number(rc.rd), sigma: Number(rc.sigma) };
  }

  private async persist(
    tx: Prisma.TransactionClient,
    playerId: string,
    matchId: string,
    before: GlickoState,
    after: GlickoState,
    playedAt: Date,
  ) {
    await this.writeHistory(tx, playerId, matchId, before, after);
    const rc = await tx.ratingCurrent.findUnique({ where: { playerId } });
    await this.writeCurrent(tx, playerId, after, (rc?.matchesCount ?? 0) + 1, playedAt);
  }

  private async writeCurrent(
    tx: Prisma.TransactionClient,
    playerId: string,
    state: GlickoState,
    matchesCount: number,
    lastMatchAt: Date | null,
  ) {
    const display = this.glicko.toDisplay(state.rating);
    const confidence = this.glicko.toConfidence(state.rd);
    const ratingState = this.glicko.isEstablished(state.rd)
      ? RatingState.ESTABLISHED
      : RatingState.PROVISIONAL;
    const data = {
      mu: state.rating,
      rd: state.rd,
      sigma: state.sigma,
      ratingDisplay: display,
      confidence,
      state: ratingState,
      matchesCount,
      lastMatchAt,
    };
    await tx.ratingCurrent.upsert({
      where: { playerId },
      create: { playerId, ...data },
      update: data,
    });
  }

  private async writeHistory(
    tx: Prisma.TransactionClient,
    playerId: string,
    matchId: string,
    before: GlickoState,
    after: GlickoState,
  ) {
    const dBefore = this.glicko.toDisplay(before.rating);
    const dAfter = this.glicko.toDisplay(after.rating);
    await tx.ratingHistory.create({
      data: {
        playerId,
        matchId,
        muBefore: before.rating,
        muAfter: after.rating,
        rdBefore: before.rd,
        rdAfter: after.rd,
        ratingBefore: dBefore,
        ratingAfter: dAfter,
        delta: Math.round((dAfter - dBefore) * 10) / 10,
      },
    });
  }
}
