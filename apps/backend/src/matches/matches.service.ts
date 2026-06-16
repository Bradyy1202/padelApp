import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ConfirmDecision,
  MatchStatus,
  MatchType,
  PlayerStatus,
  Prisma,
  QrStatus,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RatingQueue } from '../rating/rating.queue';
import { NotificationsService } from '../notifications/notifications.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { QrService } from './qr.service';
import { ScoreValidatorService } from './score-validator.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { JoinMatchDto } from './dto/join-match.dto';
import { AddPlayerDto } from './dto/add-player.dto';
import { RegisterResultDto } from './dto/register-result.dto';

const TEAM_MAX = 2; // 2v2 (PRD §6.3)
const REQUIRED_PLAYERS = 4;
const CONFIRM_WINDOW_HOURS = 24; // §7.4

const matchInclude = {
  teams: { include: { players: { include: { player: true } } }, orderBy: { side: 'asc' } },
  sets: { orderBy: { setNo: 'asc' } },
  result: true,
} satisfies Prisma.MatchInclude;

@Injectable()
export class MatchesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly qr: QrService,
    private readonly scores: ScoreValidatorService,
    private readonly ratingQueue: RatingQueue,
    private readonly notifications: NotificationsService,
    private readonly analytics: AnalyticsService,
  ) {}

  /** Crea un partido en DRAFT y añade al creador al lado 1 (PRD §6.3). */
  async createMatch(userId: string, dto: CreateMatchDto) {
    const creatorId = await this.requirePlayerId(userId);
    const match = await this.prisma.$transaction(async (tx) => {
      const created = await tx.match.create({
        data: {
          type: dto.type as unknown as MatchType,
          bestOf: dto.bestOf ?? 3,
          status: MatchStatus.DRAFT,
          createdBy: creatorId,
          teams: { create: [{ side: 1 }, { side: 2 }] },
        },
        include: { teams: true },
      });
      const team1 = created.teams.find((t) => t.side === 1)!;
      await tx.matchPlayer.create({
        data: { matchId: created.id, teamId: team1.id, playerId: creatorId },
      });
      return created;
    });
    return this.getMatch(match.id);
  }

  /** Genera un token QR firmado para el partido (solo el creador, §7.3). */
  async generateQr(userId: string, matchId: string) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Partido no encontrado');
    const creatorId = await this.requirePlayerId(userId);
    if (match.createdBy !== creatorId) {
      throw new ForbiddenException('Solo el creador genera el QR');
    }
    if (match.status !== MatchStatus.DRAFT && match.status !== MatchStatus.READY) {
      throw new BadRequestException('El partido ya no admite uniones');
    }

    const { token, expiresAt } = await this.qr.sign(matchId);
    const shortCode = this.qr.generateShortCode();
    await this.prisma.qrToken.create({
      data: { matchId, shortCode, status: QrStatus.ACTIVE, expiresAt },
    });
    return { token, shortCode, expiresAt };
  }

  /** Unirse a un partido por token o código corto (PRD §6.4). */
  async join(userId: string, dto: JoinMatchDto) {
    const matchId = await this.resolveMatchId(dto);
    const playerId = await this.requirePlayerId(userId);
    await this.addPlayerToMatch(matchId, playerId, dto.side);
    return this.getMatch(matchId);
  }

  /** Añade un jugador real o invitado manualmente (participante del partido, §6.3). */
  async addPlayer(userId: string, matchId: string, dto: AddPlayerDto) {
    const requesterId = await this.requirePlayerId(userId);
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { players: true },
    });
    if (!match) throw new NotFoundException('Partido no encontrado');
    const isParticipant = match.players.some((p) => p.playerId === requesterId);
    if (match.createdBy !== requesterId && !isParticipant) {
      throw new ForbiddenException('Solo un participante puede añadir jugadores');
    }

    let playerId = dto.playerId;
    if (!playerId && dto.guestName) {
      const guest = await this.prisma.player.create({
        data: { status: PlayerStatus.GUEST, fullName: dto.guestName, createdBy: requesterId },
      });
      playerId = guest.id;
    }
    if (!playerId) throw new BadRequestException('Indica playerId o guestName');

    await this.addPlayerToMatch(matchId, playerId, dto.side);
    return this.getMatch(matchId);
  }

  /** Registra el marcador: valida (§7.2) y pasa a PENDING_CONFIRMATION (§6.5). */
  async registerResult(userId: string, matchId: string, dto: RegisterResultDto) {
    const requesterId = await this.requirePlayerId(userId);
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { players: true },
    });
    if (!match) throw new NotFoundException('Partido no encontrado');
    if (match.status !== MatchStatus.READY) {
      throw new BadRequestException('El partido no está listo para registrar resultado');
    }
    const isParticipant = match.players.some((p) => p.playerId === requesterId);
    if (match.createdBy !== requesterId && !isParticipant) {
      throw new ForbiddenException('Solo un participante registra el resultado');
    }

    const result = this.scores.validate(dto.sets, match.bestOf);
    const deadline = new Date(Date.now() + CONFIRM_WINDOW_HOURS * 3600 * 1000);

    await this.prisma.$transaction(async (tx) => {
      await tx.matchSet.deleteMany({ where: { matchId } });
      await tx.matchSet.createMany({
        data: dto.sets.map((s, i) => ({
          matchId,
          setNo: i + 1,
          games1: s.games1,
          games2: s.games2,
          tiebreak1: s.tiebreak1 ?? null,
          tiebreak2: s.tiebreak2 ?? null,
        })),
      });
      await tx.matchResult.upsert({
        where: { matchId },
        create: {
          matchId,
          winnerSide: result.winnerSide,
          gamesDiff: result.gamesDiff,
          reportedBy: requesterId,
        },
        update: {
          winnerSide: result.winnerSide,
          gamesDiff: result.gamesDiff,
          reportedBy: requesterId,
        },
      });
      await tx.match.update({
        where: { id: matchId },
        data: {
          status: MatchStatus.PENDING_CONFIRMATION,
          playedAt: new Date(),
          confirmDeadline: deadline,
        },
      });
    });

    this.analytics.capture(userId, 'match_result_reported', { bestOf: match.bestOf });

    // Notifica a los demás jugadores que hay un resultado por confirmar (§14).
    const toNotify = match.players.map((p) => p.playerId).filter((id) => id !== requesterId);
    await this.notifications.notifyPlayers(
      toNotify,
      'MATCH_RESULT_PENDING',
      { matchId, winnerSide: result.winnerSide },
      `match-${matchId}-pending`,
    );

    return this.getMatch(matchId);
  }

  /** Detalle del partido (PRD §11.2 GET /matches/:id). */
  async getMatch(id: string) {
    const match = await this.prisma.match.findUnique({ where: { id }, include: matchInclude });
    if (!match) throw new NotFoundException('Partido no encontrado');
    return this.toMatchDto(match);
  }

  /** Historial paginado de partidos del usuario (PRD §11.2 GET /me/matches). */
  async listMine(userId: string, page = 1, limit = 20) {
    const playerId = await this.requirePlayerId(userId);
    const where: Prisma.MatchWhereInput = { players: { some: { playerId } } };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.match.findMany({
        where,
        include: matchInclude,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.match.count({ where }),
    ]);
    return { data: rows.map((m) => this.toMatchDto(m)), page, total };
  }

  /** Confirma el resultado (jugador real del partido). Mayoría → CONFIRMED + rating (§7.4). */
  async confirm(userId: string, matchId: string) {
    const match = await this.loadPendingWithRealPlayers(matchId);
    const myPlayerId = this.requireRealPlayer(match, userId);

    await this.prisma.matchConfirmation.upsert({
      where: { matchId_playerId: { matchId, playerId: myPlayerId } },
      create: { matchId, playerId: myPlayerId, decision: ConfirmDecision.CONFIRM },
      update: { decision: ConfirmDecision.CONFIRM },
    });

    const realPlayerIds = this.realPlayerIds(match);
    const confirmations = await this.prisma.matchConfirmation.findMany({
      where: { matchId, decision: ConfirmDecision.CONFIRM, playerId: { in: realPlayerIds } },
    });

    const majority = realPlayerIds.length <= 1 ? Infinity : Math.floor(realPlayerIds.length / 2) + 1;
    if (confirmations.length >= majority) {
      await this.markConfirmed(matchId);
    }
    return this.getMatch(matchId);
  }

  /** Disputa el resultado → DISPUTED (bloquea hasta resolución admin, §7.4/§7.10). */
  async dispute(userId: string, matchId: string) {
    const match = await this.loadPendingWithRealPlayers(matchId);
    const myPlayerId = this.requireRealPlayer(match, userId);
    await this.prisma.$transaction([
      this.prisma.matchConfirmation.upsert({
        where: { matchId_playerId: { matchId, playerId: myPlayerId } },
        create: { matchId, playerId: myPlayerId, decision: ConfirmDecision.DISPUTE },
        update: { decision: ConfirmDecision.DISPUTE },
      }),
      this.prisma.match.update({ where: { id: matchId }, data: { status: MatchStatus.DISPUTED } }),
    ]);
    await this.notifications.notifyPlayers(
      match.players.map((p) => p.playerId),
      'MATCH_DISPUTED',
      { matchId },
      `match-${matchId}-disputed`,
    );
    return this.getMatch(matchId);
  }

  /** Aprobación forzada por administrador → CONFIRMED + rating (§7.4 override). */
  async approve(matchId: string) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Partido no encontrado');
    if (
      match.status !== MatchStatus.PENDING_CONFIRMATION &&
      match.status !== MatchStatus.DISPUTED
    ) {
      throw new BadRequestException('El partido no está pendiente ni disputado');
    }
    await this.markConfirmed(matchId);
    return this.getMatch(matchId);
  }

  /** Job: descarta partidos pendientes vencidos (>24h sin mayoría ni admin, §7.4). */
  async discardExpired(): Promise<number> {
    const res = await this.prisma.match.updateMany({
      where: { status: MatchStatus.PENDING_CONFIRMATION, confirmDeadline: { lt: new Date() } },
      data: { status: MatchStatus.DISCARDED },
    });
    return res.count;
  }

  private async markConfirmed(matchId: string) {
    await this.prisma.match.update({
      where: { id: matchId },
      data: { status: MatchStatus.CONFIRMED },
    });
    await this.ratingQueue.enqueueMatch(matchId);
    this.analytics.capture('system', 'match_confirmed', { matchId });
    const players = await this.prisma.matchPlayer.findMany({ where: { matchId } });
    await this.notifications.notifyPlayers(
      players.map((p) => p.playerId),
      'MATCH_CONFIRMED',
      { matchId },
      `match-${matchId}-confirmed`,
    );
  }

  private async loadPendingWithRealPlayers(matchId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { players: { include: { player: true } } },
    });
    if (!match) throw new NotFoundException('Partido no encontrado');
    if (match.status !== MatchStatus.PENDING_CONFIRMATION) {
      throw new BadRequestException('El partido no está en confirmación');
    }
    return match;
  }

  private realPlayerIds(match: { players: Array<{ playerId: string; player: { userId: string | null } }> }) {
    return match.players.filter((p) => p.player.userId).map((p) => p.playerId);
  }

  private requireRealPlayer(
    match: { players: Array<{ playerId: string; player: { userId: string | null } }> },
    userId: string,
  ): string {
    const mp = match.players.find((p) => p.player.userId === userId);
    if (!mp) throw new ForbiddenException('Solo un jugador real del partido puede confirmar');
    return mp.playerId;
  }

  // ─────────────────────────── helpers ───────────────────────────

  private async resolveMatchId(dto: JoinMatchDto): Promise<string> {
    if (dto.token) {
      try {
        const payload = await this.qr.verify(dto.token);
        return payload.matchId;
      } catch {
        throw new BadRequestException('Token QR inválido o expirado');
      }
    }
    if (dto.shortCode) {
      const tok = await this.prisma.qrToken.findUnique({ where: { shortCode: dto.shortCode } });
      if (!tok || tok.status !== QrStatus.ACTIVE || tok.expiresAt < new Date()) {
        throw new BadRequestException('Código inválido o expirado');
      }
      return tok.matchId;
    }
    throw new BadRequestException('Indica token o shortCode');
  }

  private async addPlayerToMatch(matchId: string, playerId: string, side: number) {
    await this.prisma.$transaction(async (tx) => {
      const match = await tx.match.findUnique({
        where: { id: matchId },
        include: { teams: true, players: true },
      });
      if (!match) throw new NotFoundException('Partido no encontrado');
      if (match.status !== MatchStatus.DRAFT && match.status !== MatchStatus.READY) {
        throw new BadRequestException('El partido ya no admite jugadores');
      }
      if (match.players.some((p) => p.playerId === playerId)) {
        throw new BadRequestException('El jugador ya está en el partido');
      }
      const team = match.teams.find((t) => t.side === side);
      if (!team) throw new BadRequestException('Lado inválido');
      const sideCount = match.players.filter((p) => p.teamId === team.id).length;
      if (sideCount >= TEAM_MAX) throw new BadRequestException('Ese lado está completo');

      await tx.matchPlayer.create({ data: { matchId, teamId: team.id, playerId } });

      if (match.players.length + 1 >= REQUIRED_PLAYERS) {
        await tx.match.update({ where: { id: matchId }, data: { status: MatchStatus.READY } });
      }
    });
  }

  private async requirePlayerId(userId: string): Promise<string> {
    const profile = await this.prisma.profile.findUnique({
      where: { id: userId },
      include: { player: true },
    });
    if (profile?.player) return profile.player.id;
    const player = await this.prisma.player.findFirst({ where: { userId } });
    if (!player) throw new BadRequestException('Primero completa el onboarding');
    return player.id;
  }

  private toMatchDto(match: Prisma.MatchGetPayload<{ include: typeof matchInclude }>) {
    return {
      id: match.id,
      type: match.type,
      status: match.status,
      bestOf: match.bestOf,
      createdBy: match.createdBy,
      playedAt: match.playedAt,
      confirmDeadline: match.confirmDeadline,
      teams: match.teams.map((t) => ({
        side: t.side,
        players: t.players.map((mp) => ({
          id: mp.player.id,
          fullName: mp.player.fullName,
          status: mp.player.status,
        })),
      })),
      sets: match.sets.map((s) => ({
        setNo: s.setNo,
        games1: s.games1,
        games2: s.games2,
        tiebreak1: s.tiebreak1,
        tiebreak2: s.tiebreak2,
      })),
      result: match.result
        ? { winnerSide: match.result.winnerSide, gamesDiff: match.result.gamesDiff }
        : null,
    };
  }
}
