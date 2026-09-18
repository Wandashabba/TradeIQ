-- A resumed visit, and a visit that cannot become two rows (#379, #385).
--
-- 1. `visits.client_visit_id` — the DEVICE's own uuid for the visit, its
--    idempotency key. The app mints it at check-in and flushes the outbox
--    later; when that POST succeeded but its response was lost, the retry
--    created a second Visit. One store walk, two rows, and no way to tell
--    which one a manager should read. The unique index below makes the retry
--    find the first row instead of writing another.
--
--    Unique per AGENT, not globally: two agents' local uuids never collide,
--    and Postgres treats NULLs as distinct — so visits from app builds that
--    send no key are unconstrained and keep working exactly as before. This is
--    the same shape as `messages(sender_id, client_message_id)` from #308.
--
-- 2. `visits.resumed_from_draft` — whether the agent resumed a saved draft
--    rather than checking in fresh. DEFAULT false, so every existing row and
--    every older client reads as what it is: a fresh check-in. It exists
--    because a resumed visit's timeline legitimately contains a long gap, and
--    a manager (and the fraud engine's dwell signals) should be able to tell
--    that gap from an idle agent.
--
-- No backfill: NULL is the correct value for every visit created before a
-- device id was ever sent, and false is the correct value for every visit
-- created before resuming existed.

-- AlterTable
ALTER TABLE "visits" ADD COLUMN     "client_visit_id" TEXT;
ALTER TABLE "visits" ADD COLUMN     "resumed_from_draft" BOOLEAN NOT NULL DEFAULT false;

-- CreateIndex
CREATE UNIQUE INDEX "visits_agent_id_client_visit_id_key" ON "visits"("agent_id", "client_visit_id");
