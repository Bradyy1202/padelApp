-- CreateEnum
CREATE TYPE "Role" AS ENUM ('jugador', 'administrador');

-- CreateEnum
CREATE TYPE "PlayerStatus" AS ENUM ('GUEST', 'ACTIVE', 'MERGED', 'DELETED');

-- CreateEnum
CREATE TYPE "DominantHand" AS ENUM ('R', 'L');

-- CreateEnum
CREATE TYPE "FavSide" AS ENUM ('DRIVE', 'REVES', 'BOTH');

-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('M', 'F', 'OTHER', 'NA');

-- CreateEnum
CREATE TYPE "MatchType" AS ENUM ('FRIENDLY', 'COMPETITIVE', 'POZO', 'TOURNAMENT');

-- CreateEnum
CREATE TYPE "MatchStatus" AS ENUM ('DRAFT', 'READY', 'PENDING_CONFIRMATION', 'CONFIRMED', 'DISPUTED', 'DISCARDED');

-- CreateEnum
CREATE TYPE "ConfirmDecision" AS ENUM ('CONFIRM', 'DISPUTE');

-- CreateEnum
CREATE TYPE "QrStatus" AS ENUM ('ACTIVE', 'EXPIRED', 'CONSUMED');

-- CreateEnum
CREATE TYPE "RatingState" AS ENUM ('PROVISIONAL', 'ESTABLISHED');

-- CreateEnum
CREATE TYPE "PozoMode" AS ENUM ('FIXED_PAIRS', 'ROTATION');

-- CreateEnum
CREATE TYPE "PozoStatus" AS ENUM ('DRAFT', 'OPEN', 'IN_PROGRESS', 'CLOSED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "TournamentFormat" AS ENUM ('SINGLE_ELIM', 'ROUND_ROBIN');

-- CreateEnum
CREATE TYPE "TournamentStatus" AS ENUM ('DRAFT', 'REGISTRATION_OPEN', 'REGISTRATION_CLOSED', 'IN_PROGRESS', 'FINISHED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "CategoryGender" AS ENUM ('M', 'F', 'MIXED', 'OPEN');

-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('ios', 'android');

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('OPEN', 'RESOLVED');

-- CreateTable
CREATE TABLE "profiles" (
    "id" UUID NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'jugador',
    "player_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "players" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "status" "PlayerStatus" NOT NULL DEFAULT 'ACTIVE',
    "merged_into" UUID,
    "full_name" TEXT NOT NULL,
    "photo_url" TEXT,
    "city" TEXT,
    "club_id" UUID,
    "dominant_hand" "DominantHand",
    "fav_side" "FavSide",
    "gender" "Gender",
    "birthdate" DATE,
    "est_level" DECIMAL(3,1),
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "players_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "clubs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "city" TEXT,
    "claimed_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "clubs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "matches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "type" "MatchType" NOT NULL,
    "source_id" UUID,
    "status" "MatchStatus" NOT NULL DEFAULT 'DRAFT',
    "best_of" INTEGER NOT NULL DEFAULT 3,
    "created_by" UUID NOT NULL,
    "played_at" TIMESTAMPTZ(6),
    "confirm_deadline" TIMESTAMPTZ(6),
    "rating_applied" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "match_teams" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "side" INTEGER NOT NULL,

    CONSTRAINT "match_teams_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "match_players" (
    "match_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "player_id" UUID NOT NULL,

    CONSTRAINT "match_players_pkey" PRIMARY KEY ("match_id","player_id")
);

-- CreateTable
CREATE TABLE "match_sets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "set_no" INTEGER NOT NULL,
    "games_1" INTEGER NOT NULL,
    "games_2" INTEGER NOT NULL,
    "tiebreak_1" INTEGER,
    "tiebreak_2" INTEGER,

    CONSTRAINT "match_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "match_results" (
    "match_id" UUID NOT NULL,
    "winner_side" INTEGER NOT NULL,
    "games_diff" INTEGER NOT NULL,
    "reported_by" UUID NOT NULL,
    "reported_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "match_results_pkey" PRIMARY KEY ("match_id")
);

-- CreateTable
CREATE TABLE "match_confirmations" (
    "match_id" UUID NOT NULL,
    "player_id" UUID NOT NULL,
    "decision" "ConfirmDecision" NOT NULL,
    "decided_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "match_confirmations_pkey" PRIMARY KEY ("match_id","player_id")
);

-- CreateTable
CREATE TABLE "qr_tokens" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "short_code" TEXT,
    "status" "QrStatus" NOT NULL DEFAULT 'ACTIVE',
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "qr_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rating_current" (
    "player_id" UUID NOT NULL,
    "mu" DECIMAL(8,4) NOT NULL,
    "rd" DECIMAL(8,4) NOT NULL,
    "sigma" DECIMAL(8,4) NOT NULL,
    "rating_display" DECIMAL(3,1) NOT NULL,
    "confidence" INTEGER NOT NULL,
    "state" "RatingState" NOT NULL DEFAULT 'PROVISIONAL',
    "matches_count" INTEGER NOT NULL DEFAULT 0,
    "last_match_at" TIMESTAMPTZ(6),
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rating_current_pkey" PRIMARY KEY ("player_id")
);

-- CreateTable
CREATE TABLE "rating_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "player_id" UUID NOT NULL,
    "match_id" UUID NOT NULL,
    "mu_before" DECIMAL(8,4),
    "mu_after" DECIMAL(8,4),
    "rd_before" DECIMAL(8,4),
    "rd_after" DECIMAL(8,4),
    "rating_before" DECIMAL(3,1),
    "rating_after" DECIMAL(3,1),
    "delta" DECIMAL(3,1),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rating_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pozos" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "club_id" UUID,
    "owner_id" UUID NOT NULL,
    "mode" "PozoMode" NOT NULL,
    "courts" INTEGER NOT NULL,
    "status" "PozoStatus" NOT NULL DEFAULT 'DRAFT',
    "scheduled_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pozos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pozo_participants" (
    "pozo_id" UUID NOT NULL,
    "player_id" UUID NOT NULL,

    CONSTRAINT "pozo_participants_pkey" PRIMARY KEY ("pozo_id","player_id")
);

-- CreateTable
CREATE TABLE "pozo_rounds" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pozo_id" UUID NOT NULL,
    "round_no" INTEGER NOT NULL,

    CONSTRAINT "pozo_rounds_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pozo_matches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "round_id" UUID NOT NULL,
    "court" INTEGER,
    "match_id" UUID,

    CONSTRAINT "pozo_matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pozo_standings" (
    "pozo_id" UUID NOT NULL,
    "player_id" UUID NOT NULL,
    "wins" INTEGER NOT NULL DEFAULT 0,
    "draws" INTEGER NOT NULL DEFAULT 0,
    "losses" INTEGER NOT NULL DEFAULT 0,
    "games_for" INTEGER NOT NULL DEFAULT 0,
    "games_against" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "pozo_standings_pkey" PRIMARY KEY ("pozo_id","player_id")
);

-- CreateTable
CREATE TABLE "tournaments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "owner_id" UUID,
    "format" "TournamentFormat" NOT NULL,
    "status" "TournamentStatus" NOT NULL DEFAULT 'DRAFT',
    "start_date" DATE,
    "end_date" DATE,

    CONSTRAINT "tournaments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tournament_categories" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tournament_id" UUID NOT NULL,
    "name" TEXT,
    "gender" "CategoryGender" NOT NULL,
    "min_rating" DECIMAL(3,1),
    "max_rating" DECIMAL(3,1),

    CONSTRAINT "tournament_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tournament_registrations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "category_id" UUID NOT NULL,
    "player1_id" UUID NOT NULL,
    "player2_id" UUID NOT NULL,
    "seed" INTEGER,

    CONSTRAINT "tournament_registrations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tournament_matches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "category_id" UUID NOT NULL,
    "round" INTEGER,
    "bracket_pos" INTEGER,
    "reg_a" UUID,
    "reg_b" UUID,
    "match_id" UUID,
    "next_match_id" UUID,

    CONSTRAINT "tournament_matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "type" TEXT,
    "payload" JSONB,
    "read_at" TIMESTAMPTZ(6),
    "event_id" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "devices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "fcm_token" TEXT NOT NULL,
    "platform" "DevicePlatform" NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reports" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "reporter_id" UUID,
    "target_type" TEXT,
    "target_id" UUID,
    "reason" TEXT,
    "status" "ReportStatus" NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_log" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "actor_id" UUID,
    "action" TEXT,
    "entity" TEXT,
    "entity_id" UUID,
    "before" JSONB,
    "after" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "profiles_player_id_key" ON "profiles"("player_id");

-- CreateIndex
CREATE UNIQUE INDEX "players_user_id_key" ON "players"("user_id");

-- CreateIndex
CREATE INDEX "players_user_id_idx" ON "players"("user_id");

-- CreateIndex
CREATE INDEX "players_status_idx" ON "players"("status");

-- CreateIndex
CREATE INDEX "players_club_id_idx" ON "players"("club_id");

-- CreateIndex
CREATE INDEX "matches_status_confirm_deadline_idx" ON "matches"("status", "confirm_deadline");

-- CreateIndex
CREATE INDEX "matches_type_source_id_idx" ON "matches"("type", "source_id");

-- CreateIndex
CREATE UNIQUE INDEX "match_teams_match_id_side_key" ON "match_teams"("match_id", "side");

-- CreateIndex
CREATE INDEX "match_players_player_id_idx" ON "match_players"("player_id");

-- CreateIndex
CREATE UNIQUE INDEX "match_sets_match_id_set_no_key" ON "match_sets"("match_id", "set_no");

-- CreateIndex
CREATE UNIQUE INDEX "qr_tokens_short_code_key" ON "qr_tokens"("short_code");

-- CreateIndex
CREATE INDEX "qr_tokens_status_expires_at_idx" ON "qr_tokens"("status", "expires_at");

-- CreateIndex
CREATE INDEX "rating_current_rating_display_idx" ON "rating_current"("rating_display" DESC);

-- CreateIndex
CREATE INDEX "rating_current_state_idx" ON "rating_current"("state");

-- CreateIndex
CREATE INDEX "rating_history_player_id_created_at_idx" ON "rating_history"("player_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "rating_history_player_id_match_id_key" ON "rating_history"("player_id", "match_id");

-- CreateIndex
CREATE UNIQUE INDEX "pozo_rounds_pozo_id_round_no_key" ON "pozo_rounds"("pozo_id", "round_no");

-- CreateIndex
CREATE UNIQUE INDEX "tournament_registrations_category_id_player1_id_player2_id_key" ON "tournament_registrations"("category_id", "player1_id", "player2_id");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_event_id_key" ON "notifications"("event_id");

-- CreateIndex
CREATE UNIQUE INDEX "devices_fcm_token_key" ON "devices"("fcm_token");

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "players" ADD CONSTRAINT "players_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "players" ADD CONSTRAINT "players_merged_into_fkey" FOREIGN KEY ("merged_into") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "players" ADD CONSTRAINT "players_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_teams" ADD CONSTRAINT "match_teams_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_players" ADD CONSTRAINT "match_players_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_players" ADD CONSTRAINT "match_players_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "match_teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_players" ADD CONSTRAINT "match_players_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_sets" ADD CONSTRAINT "match_sets_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_results" ADD CONSTRAINT "match_results_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_results" ADD CONSTRAINT "match_results_reported_by_fkey" FOREIGN KEY ("reported_by") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_confirmations" ADD CONSTRAINT "match_confirmations_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_confirmations" ADD CONSTRAINT "match_confirmations_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "qr_tokens" ADD CONSTRAINT "qr_tokens_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_current" ADD CONSTRAINT "rating_current_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_history" ADD CONSTRAINT "rating_history_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_history" ADD CONSTRAINT "rating_history_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozos" ADD CONSTRAINT "pozos_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_participants" ADD CONSTRAINT "pozo_participants_pozo_id_fkey" FOREIGN KEY ("pozo_id") REFERENCES "pozos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_participants" ADD CONSTRAINT "pozo_participants_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_rounds" ADD CONSTRAINT "pozo_rounds_pozo_id_fkey" FOREIGN KEY ("pozo_id") REFERENCES "pozos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_matches" ADD CONSTRAINT "pozo_matches_round_id_fkey" FOREIGN KEY ("round_id") REFERENCES "pozo_rounds"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_matches" ADD CONSTRAINT "pozo_matches_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_standings" ADD CONSTRAINT "pozo_standings_pozo_id_fkey" FOREIGN KEY ("pozo_id") REFERENCES "pozos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pozo_standings" ADD CONSTRAINT "pozo_standings_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_categories" ADD CONSTRAINT "tournament_categories_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "tournaments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_registrations" ADD CONSTRAINT "tournament_registrations_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "tournament_categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_registrations" ADD CONSTRAINT "tournament_registrations_player1_id_fkey" FOREIGN KEY ("player1_id") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_registrations" ADD CONSTRAINT "tournament_registrations_player2_id_fkey" FOREIGN KEY ("player2_id") REFERENCES "players"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_matches" ADD CONSTRAINT "tournament_matches_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "tournament_categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_matches" ADD CONSTRAINT "tournament_matches_reg_a_fkey" FOREIGN KEY ("reg_a") REFERENCES "tournament_registrations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_matches" ADD CONSTRAINT "tournament_matches_reg_b_fkey" FOREIGN KEY ("reg_b") REFERENCES "tournament_registrations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_matches" ADD CONSTRAINT "tournament_matches_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tournament_matches" ADD CONSTRAINT "tournament_matches_next_match_id_fkey" FOREIGN KEY ("next_match_id") REFERENCES "tournament_matches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "players"("id") ON DELETE SET NULL ON UPDATE CASCADE;

