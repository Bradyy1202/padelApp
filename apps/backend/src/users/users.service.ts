import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Player, PlayerStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { SupabaseService } from '../supabase/supabase.service';
import { RatingQueue } from '../rating/rating.queue';
import { OnboardingDto } from './dto/onboarding.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { CreateGuestDto } from './dto/create-guest.dto';

const ALLOWED_PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_PHOTO_BYTES = 5 * 1024 * 1024; // 5 MB (§7.1)
const MIN_AGE = 12; // §7.1
const SUGGESTION_SIMILARITY = 0.3;

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly supabase: SupabaseService,
    private readonly ratingQueue: RatingQueue,
  ) {}

  /** Perfil completo del usuario autenticado + rating. Crea el profile si falta. */
  async getMe(userId: string) {
    await this.ensureProfile(userId);
    const player = await this.findMyPlayer(userId);
    return {
      userId,
      onboarded: !!player,
      player: player ? this.toPlayerDto(player) : null,
    };
  }

  /** Onboarding: crea el player vinculado al usuario (§6.1). */
  async completeOnboarding(userId: string, dto: OnboardingDto) {
    this.assertAge(dto.birthdate);
    const existing = await this.findMyPlayer(userId);
    if (existing) {
      throw new ConflictException('El usuario ya completó el onboarding');
    }

    const player = await this.prisma.$transaction(async (tx) => {
      const created = await tx.player.create({
        data: {
          userId,
          status: PlayerStatus.ACTIVE,
          fullName: dto.fullName,
          city: dto.city,
          clubId: dto.clubId,
          dominantHand: dto.dominantHand,
          favSide: dto.favSide,
          gender: dto.gender,
          birthdate: dto.birthdate ? new Date(dto.birthdate) : null,
          estLevel: dto.estLevel,
        },
      });
      await tx.profile.update({ where: { id: userId }, data: { playerId: created.id } });
      return created;
    });

    return this.toPlayerDto(player);
  }

  /** Edita el perfil propio (§11.1 PATCH /me). */
  async updateMe(userId: string, dto: UpdateMeDto) {
    if (dto.birthdate) this.assertAge(dto.birthdate);
    const player = await this.findMyPlayer(userId);
    if (!player) throw new NotFoundException('Primero completa el onboarding');

    const updated = await this.prisma.player.update({
      where: { id: player.id },
      data: {
        fullName: dto.fullName,
        city: dto.city,
        clubId: dto.clubId,
        dominantHand: dto.dominantHand,
        favSide: dto.favSide,
        gender: dto.gender,
        birthdate: dto.birthdate ? new Date(dto.birthdate) : undefined,
        estLevel: dto.estLevel,
      },
    });
    return this.toPlayerDto(updated);
  }

  /** Perfil público de un jugador (§11.1 GET /players/:id). */
  async getPlayer(id: string) {
    const player = await this.prisma.player.findUnique({
      where: { id },
      include: { ratingCurrent: true, club: true },
    });
    if (!player || player.status === PlayerStatus.DELETED) {
      throw new NotFoundException('Jugador no encontrado');
    }
    return this.toPlayerDto(player);
  }

  /** Crea un jugador invitado (placeholder reclamable). */
  async createGuest(creatorUserId: string, dto: CreateGuestDto) {
    const creator = await this.findMyPlayer(creatorUserId);
    const guest = await this.prisma.player.create({
      data: {
        status: PlayerStatus.GUEST,
        fullName: dto.fullName,
        city: dto.city,
        gender: dto.gender,
        dominantHand: dto.dominantHand,
        favSide: dto.favSide,
        estLevel: dto.estLevel,
        createdBy: creator?.id,
      },
    });
    return this.toPlayerDto(guest);
  }

  /**
   * Invitados que podrían ser "yo" por similitud de nombre (trigram, §11.1).
   * Usa pg_trgm: ordena por similarity descendente sobre players.full_name.
   */
  async guestSuggestions(userId: string, name?: string) {
    const me = await this.findMyPlayer(userId);
    const target = name ?? me?.fullName;
    if (!target) return [];

    const rows = await this.prisma.$queryRaw<
      Array<{ id: string; full_name: string; city: string | null; similarity: number }>
    >`
      SELECT id, full_name, city, similarity(full_name, ${target}) AS similarity
      FROM players
      WHERE status = 'GUEST'
        AND similarity(full_name, ${target}) > ${SUGGESTION_SIMILARITY}
      ORDER BY similarity DESC
      LIMIT 10
    `;
    return rows.map((r) => ({
      id: r.id,
      fullName: r.full_name,
      city: r.city,
      similarity: Number(r.similarity),
    }));
  }

  /**
   * Reclama/mergea un invitado en el player del usuario (US-03, §7.1):
   * reasigna el historial de partidos, marca el invitado como MERGED y audita.
   * El recálculo de rating se encola en Sprint 3.
   */
  async claimGuest(userId: string, guestId: string) {
    const myPlayer = await this.findMyPlayer(userId);
    if (!myPlayer) throw new NotFoundException('Primero completa el onboarding');

    const guest = await this.prisma.player.findUnique({ where: { id: guestId } });
    if (!guest) throw new NotFoundException('Invitado no encontrado');
    if (guest.status !== PlayerStatus.GUEST || guest.userId) {
      throw new BadRequestException('Este jugador no es un invitado reclamable');
    }
    if (guest.id === myPlayer.id) {
      throw new BadRequestException('No puedes reclamarte a ti mismo');
    }

    await this.prisma.$transaction(async (tx) => {
      // Reasignar match_players del invitado al player destino (evitando colisión de PK).
      const guestMatchPlayers = await tx.matchPlayer.findMany({ where: { playerId: guestId } });
      for (const mp of guestMatchPlayers) {
        const collision = await tx.matchPlayer.findUnique({
          where: { matchId_playerId: { matchId: mp.matchId, playerId: myPlayer.id } },
        });
        if (collision) {
          await tx.matchPlayer.delete({
            where: { matchId_playerId: { matchId: mp.matchId, playerId: guestId } },
          });
        } else {
          await tx.matchPlayer.update({
            where: { matchId_playerId: { matchId: mp.matchId, playerId: guestId } },
            data: { playerId: myPlayer.id },
          });
        }
      }

      await tx.player.update({
        where: { id: guestId },
        data: { status: PlayerStatus.MERGED, mergedInto: myPlayer.id },
      });

      await tx.auditLog.create({
        data: {
          actorId: userId,
          action: 'CLAIM_GUEST',
          entity: 'players',
          entityId: guestId,
          before: { status: guest.status, mergedInto: null } as Prisma.InputJsonValue,
          after: { status: 'MERGED', mergedInto: myPlayer.id } as Prisma.InputJsonValue,
        },
      });
    });

    // Recalcular el rating del player resultante tras heredar el historial (§7.5).
    await this.ratingQueue.enqueueRecompute(myPlayer.id);
    this.logger.log(`Invitado ${guestId} reclamado por player ${myPlayer.id}; recálculo encolado`);

    return this.getMe(userId);
  }

  /** Sube la foto de perfil a Storage y guarda la URL (§11.1 POST /me/photo). */
  async uploadPhoto(userId: string, file: Buffer, contentType: string) {
    if (!ALLOWED_PHOTO_TYPES.includes(contentType)) {
      throw new BadRequestException('Formato no permitido (usa jpg, png o webp)');
    }
    if (file.length > MAX_PHOTO_BYTES) {
      throw new BadRequestException('La foto supera los 5 MB');
    }
    const player = await this.findMyPlayer(userId);
    if (!player) throw new NotFoundException('Primero completa el onboarding');

    const url = await this.supabase.uploadAvatar(userId, file, contentType);
    const updated = await this.prisma.player.update({
      where: { id: player.id },
      data: { photoUrl: url },
    });
    return this.toPlayerDto(updated);
  }

  /** Borrado de cuenta (Ley 8968, §11.1 DELETE /me): anonimiza y borra el usuario en Auth. */
  async deleteAccount(userId: string) {
    const player = await this.findMyPlayer(userId);

    await this.prisma.$transaction(async (tx) => {
      if (player) {
        await tx.player.update({
          where: { id: player.id },
          data: {
            status: PlayerStatus.DELETED,
            userId: null,
            fullName: 'Usuario eliminado',
            photoUrl: null,
            city: null,
            birthdate: null,
          },
        });
      }
      await tx.profile.deleteMany({ where: { id: userId } });
    });

    if (this.supabase.isConfigured) {
      try {
        await this.supabase.deleteAuthUser(userId);
      } catch (err) {
        this.logger.error(`No se pudo borrar el usuario en Supabase Auth: ${(err as Error).message}`);
      }
    }
    return { deleted: true };
  }

  // ─────────────────────────── helpers ───────────────────────────

  private async ensureProfile(userId: string) {
    await this.prisma.profile.upsert({
      where: { id: userId },
      update: {},
      create: { id: userId },
    });
  }

  private async findMyPlayer(userId: string): Promise<PlayerWithRating | null> {
    const profile = await this.prisma.profile.findUnique({
      where: { id: userId },
      include: { player: { include: { ratingCurrent: true, club: true } } },
    });
    if (profile?.player) return profile.player as PlayerWithRating;
    return this.prisma.player.findFirst({
      where: { userId },
      include: { ratingCurrent: true, club: true },
    });
  }

  private assertAge(birthdate?: string) {
    if (!birthdate) return;
    const d = new Date(birthdate);
    const now = new Date();
    let age = now.getFullYear() - d.getFullYear();
    const m = now.getMonth() - d.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age--;
    if (age < MIN_AGE) {
      throw new BadRequestException(`Edad mínima ${MIN_AGE} años`);
    }
  }

  private toPlayerDto(player: PlayerWithRating | Player) {
    const rating = 'ratingCurrent' in player ? player.ratingCurrent : null;
    return {
      id: player.id,
      fullName: player.fullName,
      photoUrl: player.photoUrl,
      city: player.city,
      clubId: player.clubId,
      dominantHand: player.dominantHand,
      favSide: player.favSide,
      gender: player.gender,
      status: player.status,
      estLevel: player.estLevel ? Number(player.estLevel) : null,
      rating: rating
        ? {
            rating: Number(rating.ratingDisplay),
            confidence: rating.confidence,
            state: rating.state,
          }
        : null,
    };
  }
}

type PlayerWithRating = Prisma.PlayerGetPayload<{
  include: { ratingCurrent: true; club: true };
}>;
