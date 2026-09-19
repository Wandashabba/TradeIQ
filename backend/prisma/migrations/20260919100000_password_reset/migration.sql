-- Password change and in-field reset (#400).
--
-- Until now a password was set once at POST /users and could never be changed
-- by anyone, including an admin. A forgotten password was therefore a dead
-- identity: the only move was a new user row with a new id, orphaning that
-- agent's points, leaderboard standing, scorecard history and every visit they
-- had ever submitted — and stranding the unsent outbox rows on their phone,
-- which are owned by the old id and would never flush.
--
-- `password_reset_codes` stores a bcrypt hash, never the code. The plaintext
-- lives in exactly two places: the response to the manager who generated it,
-- and the agent's ear. `attempts` is the control that actually bounds guessing —
-- rate limits are per-IP and per-email and an attacker can move between both,
-- but this counter travels with the code and burns it wherever the guesses came
-- from.
--
-- `password_change_events` is a ledger, so it outlives what it refers to:
-- `user_id` and `actor_id` are bare TEXT columns and not foreign keys, because
-- deactivating or deleting someone must not erase the record of who reset whose
-- password. Same shape and same reasoning as `fraud_verdicts` and
-- `competitor_price_collection_audit`. It never stores a password, a hash or a
-- code.

-- CreateTable
CREATE TABLE "password_reset_codes" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "issued_by" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "password_change_events" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "actor_id" TEXT NOT NULL,
    "actor_role" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_change_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
-- Redemption asks for "the newest live code for this user".
CREATE INDEX "password_reset_codes_user_id_created_at_idx" ON "password_reset_codes"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "password_reset_codes_client_id_created_at_idx" ON "password_reset_codes"("client_id", "created_at");

-- CreateIndex
CREATE INDEX "password_change_events_client_id_created_at_idx" ON "password_change_events"("client_id", "created_at");

-- CreateIndex
-- "everything that happened to this account" — the first question asked when
-- someone reports they cannot sign in.
CREATE INDEX "password_change_events_client_id_user_id_created_at_idx" ON "password_change_events"("client_id", "user_id", "created_at");

-- AddForeignKey
ALTER TABLE "password_reset_codes" ADD CONSTRAINT "password_reset_codes_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "password_change_events" ADD CONSTRAINT "password_change_events_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
