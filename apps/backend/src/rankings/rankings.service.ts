import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { RankingScope, RankingsQueryDto } from './dto/rankings-query.dto';

interface RankingRow {
  player_id: string;
  full_name: string;
  city: string | null;
  club_id: string | null;
  gender: string | null;
  rating_display: number;
  confidence: number;
  state: string;
  matches_count: number;
}

@Injectable()
export class RankingsService {
  private readonly logger = new Logger(RankingsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Ranking paginado por ámbito (PRD §7.6/§11.3). Por defecto lee de la vista
   * materializada `mv_rankings` (solo ESTABLISHED). Con includeProvisional
   * consulta las tablas base para incluir jugadores provisionales.
   */
  async getRankings(q: RankingsQueryDto) {
    const page = q.page ?? 1;
    const limit = q.limit ?? 20;
    const offset = (page - 1) * limit;

    const rows = q.includeProvisional
      ? await this.queryBase(q, limit, offset)
      : await this.queryMaterialized(q, limit, offset);

    const total = q.includeProvisional ? await this.countBase(q) : await this.countMaterialized(q);

    return {
      data: rows.map((r, i) => ({
        rank: offset + i + 1,
        playerId: r.player_id,
        fullName: r.full_name,
        city: r.city,
        clubId: r.club_id,
        gender: r.gender,
        rating: Number(r.rating_display),
        confidence: r.confidence,
        state: r.state,
        matchesCount: r.matches_count,
      })),
      page,
      total: Number(total),
    };
  }

  /** Rating actual de un jugador (PRD §11.3 GET /players/:id/rating). */
  async getPlayerRating(playerId: string) {
    const rc = await this.prisma.ratingCurrent.findUnique({ where: { playerId } });
    if (!rc) {
      return { playerId, rating: null, confidence: 0, state: 'PROVISIONAL', matchesCount: 0 };
    }
    return {
      playerId,
      rating: Number(rc.ratingDisplay),
      confidence: rc.confidence,
      state: rc.state,
      matchesCount: rc.matchesCount,
      lastMatchAt: rc.lastMatchAt,
    };
  }

  /** Evolución del rating (PRD §11.3 GET /players/:id/rating/history). */
  async getPlayerRatingHistory(playerId: string) {
    const rows = await this.prisma.ratingHistory.findMany({
      where: { playerId },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map((h) => ({
      matchId: h.matchId,
      ratingBefore: h.ratingBefore ? Number(h.ratingBefore) : null,
      ratingAfter: h.ratingAfter ? Number(h.ratingAfter) : null,
      delta: h.delta ? Number(h.delta) : null,
      createdAt: h.createdAt,
    }));
  }

  /** Refresca la vista materializada (job programado, PRD §7.6). */
  async refresh(): Promise<void> {
    try {
      await this.prisma.$executeRawUnsafe('REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rankings');
    } catch {
      // CONCURRENTLY falla si nunca se ha poblado; fallback a refresh normal.
      await this.prisma.$executeRawUnsafe('REFRESH MATERIALIZED VIEW mv_rankings');
    }
  }

  // ─────────────────────────── helpers ───────────────────────────

  /** Filtro de ámbito sobre tablas base (alias p). */
  private baseScope(q: RankingsQueryDto): Prisma.Sql {
    switch (q.scope) {
      case RankingScope.CITY:
        return q.value ? Prisma.sql`AND p.city = ${q.value}` : Prisma.empty;
      case RankingScope.CLUB:
        return q.value ? Prisma.sql`AND p.club_id = ${q.value}::uuid` : Prisma.empty;
      case RankingScope.GENDER:
        return q.value ? Prisma.sql`AND p.gender = ${q.value}::"Gender"` : Prisma.empty;
      default:
        return Prisma.empty; // global / country (CR implícito)
    }
  }

  /** Filtro de ámbito sobre la vista materializada (columnas sin alias). */
  private mvScope(q: RankingsQueryDto): Prisma.Sql {
    switch (q.scope) {
      case RankingScope.CITY:
        return q.value ? Prisma.sql`AND city = ${q.value}` : Prisma.empty;
      case RankingScope.CLUB:
        return q.value ? Prisma.sql`AND club_id = ${q.value}::uuid` : Prisma.empty;
      case RankingScope.GENDER:
        return q.value ? Prisma.sql`AND gender = ${q.value}::"Gender"` : Prisma.empty;
      default:
        return Prisma.empty;
    }
  }

  private queryBase(q: RankingsQueryDto, limit: number, offset: number) {
    return this.prisma.$queryRaw<RankingRow[]>`
      SELECT p.id AS player_id, p.full_name, p.city, p.club_id, p.gender::text AS gender,
             rc.rating_display::float AS rating_display, rc.confidence, rc.state::text AS state,
             rc.matches_count
      FROM players p
      JOIN rating_current rc ON rc.player_id = p.id
      WHERE p.status = 'ACTIVE' ${this.baseScope(q)}
      ORDER BY rc.rating_display DESC, rc.confidence DESC
      LIMIT ${limit} OFFSET ${offset}`;
  }

  private async countBase(q: RankingsQueryDto): Promise<number> {
    const r = await this.prisma.$queryRaw<Array<{ count: number }>>`
      SELECT count(*)::int AS count
      FROM players p JOIN rating_current rc ON rc.player_id = p.id
      WHERE p.status = 'ACTIVE' ${this.baseScope(q)}`;
    return r[0]?.count ?? 0;
  }

  private queryMaterialized(q: RankingsQueryDto, limit: number, offset: number) {
    return this.prisma.$queryRaw<RankingRow[]>`
      SELECT player_id, full_name, city, club_id, gender::text AS gender,
             rating_display::float AS rating_display, confidence, state::text AS state, matches_count
      FROM mv_rankings
      WHERE TRUE ${this.mvScope(q)}
      ORDER BY rating_display DESC, confidence DESC
      LIMIT ${limit} OFFSET ${offset}`;
  }

  private async countMaterialized(q: RankingsQueryDto): Promise<number> {
    const r = await this.prisma.$queryRaw<Array<{ count: number }>>`
      SELECT count(*)::int AS count FROM mv_rankings WHERE TRUE ${this.mvScope(q)}`;
    return r[0]?.count ?? 0;
  }
}
