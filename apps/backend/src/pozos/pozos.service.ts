import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { MatchStatus, MatchType, PlayerStatus, PozoMode, PozoStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RatingQueue } from '../rating/rating.queue';
import { ScoreValidatorService } from '../matches/score-validator.service';
import { PozoPairingService, PozoParticipant } from './pozo-pairing.service';
import { CreatePozoDto } from './dto/create-pozo.dto';
import { AddParticipantsDto } from './dto/add-participants.dto';
import { RoundResultsDto } from './dto/round-results.dto';

const DEFAULT_RATING = 4.0;
const POZO_BEST_OF = 1;

@Injectable()
export class PozosService {
  private readonly logger = new Logger(PozosService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly pairing: PozoPairingService,
    private readonly scores: ScoreValidatorService,
    private readonly ratingQueue: RatingQueue,
  ) {}

  async create(ownerId: string, dto: CreatePozoDto) {
    const pozo = await this.prisma.pozo.create({
      data: {
        name: dto.name,
        clubId: dto.clubId,
        ownerId,
        mode: dto.mode,
        courts: dto.courts,
        status: PozoStatus.DRAFT,
        scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : null,
      },
    });
    return this.getPozo(pozo.id);
  }

  async addParticipants(ownerId: string, pozoId: string, dto: AddParticipantsDto) {
    const pozo = await this.requireOwner(ownerId, pozoId);
    if (pozo.status !== PozoStatus.DRAFT && pozo.status !== PozoStatus.OPEN) {
      throw new BadRequestException('El pozo ya no admite participantes');
    }

    const ids = [...(dto.playerIds ?? [])];
    for (const name of dto.guestNames ?? []) {
      const guest = await this.prisma.player.create({
        data: { status: PlayerStatus.GUEST, fullName: name },
      });
      ids.push(guest.id);
    }

    await this.prisma.$transaction(
      ids.map((playerId) =>
        this.prisma.pozoParticipant.upsert({
          where: { pozoId_playerId: { pozoId, playerId } },
          create: { pozoId, playerId },
          update: {},
        }),
      ),
    );
    await this.prisma.pozo.update({ where: { id: pozoId }, data: { status: PozoStatus.OPEN } });
    return this.getPozo(pozoId);
  }

  /** Genera la primera ronda (balanceada por rating) y pasa a IN_PROGRESS. */
  async start(ownerId: string, pozoId: string) {
    const pozo = await this.requireOwner(ownerId, pozoId);
    if (pozo.status !== PozoStatus.OPEN) {
      throw new BadRequestException('El pozo debe estar OPEN para iniciar');
    }
    const participants = await this.loadParticipants(pozoId);
    if (participants.length < 4) {
      throw new BadRequestException('Se necesitan al menos 4 participantes');
    }
    await this.generateAndPersistRound(pozo.id, pozo.mode, pozo.courts, 1, participants);
    await this.prisma.pozo.update({
      where: { id: pozoId },
      data: { status: PozoStatus.IN_PROGRESS },
    });
    return this.getPozo(pozoId);
  }

  /** Genera la siguiente ronda. */
  async nextRound(ownerId: string, pozoId: string) {
    const pozo = await this.requireOwner(ownerId, pozoId);
    if (pozo.status !== PozoStatus.IN_PROGRESS) {
      throw new BadRequestException('El pozo no está en progreso');
    }
    const last = await this.prisma.pozoRound.findFirst({
      where: { pozoId },
      orderBy: { roundNo: 'desc' },
    });
    const nextNo = (last?.roundNo ?? 0) + 1;
    const participants = await this.loadParticipants(pozoId);
    await this.generateAndPersistRound(pozo.id, pozo.mode, pozo.courts, nextNo, participants);
    return this.getPozo(pozoId);
  }

  /** Registra los resultados de una ronda y recalcula la tabla. */
  async submitRoundResults(ownerId: string, pozoId: string, roundNo: number, dto: RoundResultsDto) {
    await this.requireOwner(ownerId, pozoId);
    const round = await this.prisma.pozoRound.findUnique({
      where: { pozoId_roundNo: { pozoId, roundNo } },
      include: { matches: true },
    });
    if (!round) throw new NotFoundException('Ronda no encontrada');

    for (const r of dto.results) {
      const pm = round.matches.find((m) => m.id === r.pozoMatchId);
      if (!pm || !pm.matchId) throw new BadRequestException('Partido de pozo inválido');
      const result = this.scores.validate(r.sets, POZO_BEST_OF);
      await this.prisma.$transaction(async (tx) => {
        await tx.matchSet.deleteMany({ where: { matchId: pm.matchId! } });
        await tx.matchSet.createMany({
          data: r.sets.map((s, i) => ({
            matchId: pm.matchId!,
            setNo: i + 1,
            games1: s.games1,
            games2: s.games2,
          })),
        });
        await tx.matchResult.upsert({
          where: { matchId: pm.matchId! },
          create: {
            matchId: pm.matchId!,
            winnerSide: result.winnerSide,
            gamesDiff: result.gamesDiff,
            reportedBy: await this.anyPlayerOf(tx, pm.matchId!),
          },
          update: { winnerSide: result.winnerSide, gamesDiff: result.gamesDiff },
        });
        await tx.match.update({ where: { id: pm.matchId! }, data: { playedAt: new Date() } });
      });
    }

    await this.recomputeStandings(pozoId);
    return this.getPozo(pozoId);
  }

  /** Pozos donde el usuario es organizador o participa. */
  async listMine(userId: string) {
    const rows = await this.prisma.pozo.findMany({
      where: {
        OR: [{ ownerId: userId }, { participants: { some: { player: { userId } } } }],
      },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { participants: true } } },
    });
    return rows.map((p) => ({
      id: p.id,
      name: p.name,
      mode: p.mode,
      status: p.status,
      participants: p._count.participants,
      isOwner: p.ownerId === userId,
    }));
  }

  async getStandings(pozoId: string) {
    const rows = await this.prisma.pozoStanding.findMany({
      where: { pozoId },
      include: { player: { select: { fullName: true } } },
    });
    return rows
      .map((s) => ({
        playerId: s.playerId,
        fullName: s.player.fullName,
        wins: s.wins,
        draws: s.draws,
        losses: s.losses,
        gamesFor: s.gamesFor,
        gamesAgainst: s.gamesAgainst,
        gamesDiff: s.gamesFor - s.gamesAgainst,
      }))
      .sort((a, b) => b.wins - a.wins || b.gamesDiff - a.gamesDiff)
      .map((s, i) => ({ rank: i + 1, ...s }));
  }

  /** Cierra el pozo: cada partido pasa a CONFIRMED (origen POZO) y alimenta el rating. */
  async close(ownerId: string, pozoId: string) {
    const pozo = await this.requireOwner(ownerId, pozoId);
    if (pozo.status !== PozoStatus.IN_PROGRESS) {
      throw new BadRequestException('El pozo no está en progreso');
    }
    const rounds = await this.prisma.pozoRound.findMany({
      where: { pozoId },
      include: { matches: { include: { match: { include: { result: true } } } } },
    });

    const toRate: string[] = [];
    for (const round of rounds) {
      for (const pm of round.matches) {
        if (pm.match && pm.match.result && pm.match.status !== MatchStatus.CONFIRMED) {
          await this.prisma.match.update({
            where: { id: pm.match.id },
            data: { status: MatchStatus.CONFIRMED },
          });
          toRate.push(pm.match.id);
        }
      }
    }
    await this.prisma.pozo.update({ where: { id: pozoId }, data: { status: PozoStatus.CLOSED } });
    await this.recomputeStandings(pozoId);
    for (const matchId of toRate) await this.ratingQueue.enqueueMatch(matchId);

    this.logger.log(`Pozo ${pozoId} cerrado; ${toRate.length} partidos enviados a rating`);
    return this.getPozo(pozoId);
  }

  async getPozo(pozoId: string) {
    const pozo = await this.prisma.pozo.findUnique({
      where: { id: pozoId },
      include: {
        rounds: {
          orderBy: { roundNo: 'asc' },
          include: {
            matches: {
              include: {
                match: {
                  include: {
                    teams: { include: { players: { include: { player: true } } }, orderBy: { side: 'asc' } },
                    result: true,
                    sets: { orderBy: { setNo: 'asc' } },
                  },
                },
              },
            },
          },
        },
      },
    });
    if (!pozo) throw new NotFoundException('Pozo no encontrado');
    const standings = await this.getStandings(pozoId);
    return {
      id: pozo.id,
      name: pozo.name,
      mode: pozo.mode,
      courts: pozo.courts,
      status: pozo.status,
      rounds: pozo.rounds.map((r) => ({
        roundNo: r.roundNo,
        matches: r.matches.map((pm) => ({
          pozoMatchId: pm.id,
          court: pm.court,
          status: pm.match?.status,
          teams: (pm.match?.teams ?? []).map((t) => ({
            side: t.side,
            players: t.players.map((mp) => mp.player.fullName),
          })),
          sets: (pm.match?.sets ?? []).map((s) => ({ games1: s.games1, games2: s.games2 })),
          result: pm.match?.result
            ? { winnerSide: pm.match.result.winnerSide }
            : null,
        })),
      })),
      standings,
    };
  }

  // ─────────────────────────── helpers ───────────────────────────

  private async requireOwner(ownerId: string, pozoId: string) {
    const pozo = await this.prisma.pozo.findUnique({ where: { id: pozoId } });
    if (!pozo) throw new NotFoundException('Pozo no encontrado');
    if (pozo.ownerId !== ownerId) throw new ForbiddenException('No eres el organizador del pozo');
    return pozo;
  }

  private async loadParticipants(pozoId: string): Promise<PozoParticipant[]> {
    const rows = await this.prisma.pozoParticipant.findMany({
      where: { pozoId },
      include: { player: { include: { ratingCurrent: true } } },
    });
    return rows.map((r) => ({
      playerId: r.playerId,
      rating: r.player.ratingCurrent ? Number(r.player.ratingCurrent.ratingDisplay) : DEFAULT_RATING,
    }));
  }

  private async generateAndPersistRound(
    pozoId: string,
    mode: PozoMode,
    courts: number,
    roundNo: number,
    participants: PozoParticipant[],
  ) {
    const generated = this.pairing.generateRound(participants, mode, courts, roundNo);
    await this.prisma.$transaction(async (tx) => {
      const round = await tx.pozoRound.create({ data: { pozoId, roundNo } });
      for (const mu of generated.matchups) {
        const match = await tx.match.create({
          data: {
            type: MatchType.POZO,
            sourceId: pozoId,
            bestOf: POZO_BEST_OF,
            status: MatchStatus.READY,
            createdBy: mu.side1[0],
            teams: { create: [{ side: 1 }, { side: 2 }] },
          },
          include: { teams: true },
        });
        const t1 = match.teams.find((t) => t.side === 1)!;
        const t2 = match.teams.find((t) => t.side === 2)!;
        await tx.matchPlayer.createMany({
          data: [
            ...mu.side1.map((pid) => ({ matchId: match.id, teamId: t1.id, playerId: pid })),
            ...mu.side2.map((pid) => ({ matchId: match.id, teamId: t2.id, playerId: pid })),
          ],
        });
        await tx.pozoMatch.create({ data: { roundId: round.id, court: mu.court, matchId: match.id } });
      }
    });
  }

  private async anyPlayerOf(tx: Prisma.TransactionClient, matchId: string): Promise<string> {
    const mp = await tx.matchPlayer.findFirst({ where: { matchId } });
    return mp!.playerId;
  }

  private async recomputeStandings(pozoId: string) {
    const rounds = await this.prisma.pozoRound.findMany({
      where: { pozoId },
      include: {
        matches: {
          include: {
            match: { include: { teams: { include: { players: true } }, result: true, sets: true } },
          },
        },
      },
    });

    const acc = new Map<string, { wins: number; losses: number; gf: number; ga: number }>();
    const ensure = (id: string) =>
      acc.get(id) ?? acc.set(id, { wins: 0, losses: 0, gf: 0, ga: 0 }).get(id)!;

    for (const round of rounds) {
      for (const pm of round.matches) {
        const m = pm.match;
        if (!m || !m.result) continue;
        const g1 = m.sets.reduce((s, x) => s + x.games1, 0);
        const g2 = m.sets.reduce((s, x) => s + x.games2, 0);
        for (const team of m.teams) {
          const mine = team.side === 1 ? g1 : g2;
          const theirs = team.side === 1 ? g2 : g1;
          const won = m.result.winnerSide === team.side;
          for (const mp of team.players) {
            const e = ensure(mp.playerId);
            e.gf += mine;
            e.ga += theirs;
            if (won) e.wins++;
            else e.losses++;
          }
        }
      }
    }

    await this.prisma.$transaction([
      this.prisma.pozoStanding.deleteMany({ where: { pozoId } }),
      ...[...acc.entries()].map(([playerId, s]) =>
        this.prisma.pozoStanding.create({
          data: {
            pozoId,
            playerId,
            wins: s.wins,
            losses: s.losses,
            gamesFor: s.gf,
            gamesAgainst: s.ga,
          },
        }),
      ),
    ]);
  }
}
