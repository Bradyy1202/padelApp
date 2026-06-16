-- Índices especiales y vista materializada de ranking (PRD §10.7, §10.8).
-- Portable: corre tanto en Postgres local (docker) como en Supabase.

-- Extensión para búsqueda difusa por nombre (sugerencia de merge de invitados, §11.1).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Índice trigram GIN sobre players.full_name.
CREATE INDEX IF NOT EXISTS "players_full_name_trgm_idx"
  ON "players" USING gin ("full_name" gin_trgm_ops);

-- Vista materializada de ranking (PRD §10.8).
-- Solo jugadores activos con rating establecido; se refresca por job cada 5–15 min.
CREATE MATERIALIZED VIEW IF NOT EXISTS "mv_rankings" AS
SELECT
  p."id"             AS player_id,
  p."full_name"      AS full_name,
  p."city"           AS city,
  p."club_id"        AS club_id,
  p."gender"         AS gender,
  rc."rating_display" AS rating_display,
  rc."confidence"    AS confidence,
  rc."state"         AS state,
  rc."matches_count" AS matches_count
FROM "players" p
JOIN "rating_current" rc ON rc."player_id" = p."id"
WHERE p."status" = 'ACTIVE' AND rc."state" = 'ESTABLISHED';

-- Índice único requerido para REFRESH MATERIALIZED VIEW CONCURRENTLY.
CREATE UNIQUE INDEX IF NOT EXISTS "mv_rankings_player_id_idx"
  ON "mv_rankings" (player_id);

-- Índices de apoyo para ordenar/filtrar el ranking.
CREATE INDEX IF NOT EXISTS "mv_rankings_rating_idx"
  ON "mv_rankings" (rating_display DESC);
CREATE INDEX IF NOT EXISTS "mv_rankings_club_idx"
  ON "mv_rankings" (club_id);
