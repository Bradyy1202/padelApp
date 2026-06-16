import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { MatchStatus, Role } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { MatchesService } from '../matches/matches.service';
import { NotificationsService } from '../notifications/notifications.service';
import { DisputeResolution } from './dto/resolve-dispute.dto';

/** Moderación: disputas y asignación de rol (PRD §7.10, §11.6). Todo audita en audit_log. */
@Injectable()
export class ModerationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly matches: MatchesService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Cola de disputas: partidos en estado DISPUTED. */
  async listDisputes() {
    const rows = await this.prisma.match.findMany({
      where: { status: MatchStatus.DISPUTED },
      include: {
        teams: { include: { players: { include: { player: true } } }, orderBy: { side: 'asc' } },
        result: true,
        sets: { orderBy: { setNo: 'asc' } },
      },
      orderBy: { confirmDeadline: 'asc' },
    });
    return rows.map((m) => ({
      id: m.id,
      type: m.type,
      result: m.result ? { winnerSide: m.result.winnerSide, gamesDiff: m.result.gamesDiff } : null,
      teams: m.teams.map((t) => ({
        side: t.side,
        players: t.players.map((mp) => mp.player.fullName),
      })),
      sets: m.sets.map((s) => ({ setNo: s.setNo, games1: s.games1, games2: s.games2 })),
    }));
  }

  /** Resuelve una disputa: UPHELD→CONFIRMED (aplica rating), OVERTURNED→DISCARDED. */
  async resolveDispute(adminUserId: string, matchId: string, resolution: DisputeResolution) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Partido no encontrado');
    if (match.status !== MatchStatus.DISPUTED) {
      throw new BadRequestException('El partido no está en disputa');
    }

    if (resolution === DisputeResolution.UPHELD) {
      await this.matches.approve(matchId); // → CONFIRMED + rating + notifica
    } else {
      await this.prisma.match.update({
        where: { id: matchId },
        data: { status: MatchStatus.DISCARDED },
      });
      const players = await this.prisma.matchPlayer.findMany({ where: { matchId } });
      await this.notifications.notifyPlayers(
        players.map((p) => p.playerId),
        'MATCH_DISCARDED',
        { matchId, reason: 'dispute_overturned' },
        `match-${matchId}-discarded`,
      );
    }

    await this.audit(adminUserId, 'RESOLVE_DISPUTE', 'matches', matchId, { resolution });
    return { ok: true, resolution };
  }

  /** Asigna rol a un usuario (típicamente administrador a clubes). */
  async setRole(adminUserId: string, targetUserId: string, role: Role) {
    const before = await this.prisma.profile.findUnique({ where: { id: targetUserId } });
    await this.prisma.profile.upsert({
      where: { id: targetUserId },
      create: { id: targetUserId, role },
      update: { role },
    });
    await this.audit(adminUserId, 'SET_ROLE', 'profiles', targetUserId, {
      before: before?.role ?? null,
      after: role,
    });
    return { ok: true, role };
  }

  private audit(actorId: string, action: string, entity: string, entityId: string, after: object) {
    return this.prisma.auditLog.create({
      data: { actorId, action, entity, entityId, after: after as object },
    });
  }
}
