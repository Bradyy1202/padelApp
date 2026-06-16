import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

/**
 * Notificaciones push (FCM) + in-app (PRD §14).
 * Dedupe por `event_id`. El envío FCM real es un punto de integración: si no hay
 * credenciales configuradas, solo se registra in-app (igual que Supabase en modo dev).
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    await this.prisma.device.upsert({
      where: { fcmToken: dto.fcmToken },
      create: { userId, fcmToken: dto.fcmToken, platform: dto.platform },
      update: { userId, platform: dto.platform },
    });
    return { ok: true };
  }

  async listMine(userId: string, page = 1, limit = 20) {
    const where = { userId };
    const [rows, total, unread] = await this.prisma.$transaction([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({ where: { userId, readAt: null } }),
    ]);
    return { data: rows, page, total, unread };
  }

  async markRead(userId: string, id: string) {
    const notif = await this.prisma.notification.findUnique({ where: { id } });
    if (!notif || notif.userId !== userId) throw new NotFoundException('Notificación no encontrada');
    await this.prisma.notification.update({ where: { id }, data: { readAt: new Date() } });
    return { ok: true };
  }

  /** Inserta una notificación in-app por usuario (dedupe por event_id) y envía push. */
  async notifyUsers(
    userIds: string[],
    type: string,
    payload: Prisma.InputJsonValue,
    eventIdBase?: string,
  ) {
    const unique = [...new Set(userIds.filter(Boolean))];
    for (const userId of unique) {
      const eventId = eventIdBase ? `${eventIdBase}:${userId}` : undefined;
      try {
        await this.prisma.notification.create({
          data: { userId, type, payload, eventId },
        });
      } catch (err) {
        // Violación de unique(event_id) => ya notificado; se ignora (idempotencia §14).
        if ((err as { code?: string }).code !== 'P2002') throw err;
        continue;
      }
      await this.sendPush(userId, type, payload);
    }
  }

  /** Notifica a una lista de players (mapea a su user real; los invitados se omiten). */
  async notifyPlayers(
    playerIds: string[],
    type: string,
    payload: Prisma.InputJsonValue,
    eventIdBase?: string,
  ) {
    const players = await this.prisma.player.findMany({
      where: { id: { in: playerIds }, userId: { not: null } },
      select: { userId: true },
    });
    await this.notifyUsers(
      players.map((p) => p.userId as string),
      type,
      payload,
      eventIdBase,
    );
  }

  /** Envío push (FCM). Punto de integración: requiere firebase-admin + credenciales. */
  private async sendPush(userId: string, type: string, _payload: Prisma.InputJsonValue) {
    // TODO(integración FCM): cargar firebase-admin con FCM_SERVICE_ACCOUNT_JSON,
    // buscar devices del usuario y enviar multicast; purgar tokens inválidos.
    this.logger.debug(`push pendiente (sin FCM) user=${userId} type=${type}`);
  }
}
