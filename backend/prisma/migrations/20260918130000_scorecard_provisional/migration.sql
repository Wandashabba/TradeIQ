-- "Scored 71, you saw 84" (#390, #399).
--
-- The app scores a visit locally as the agent works, reading its own outbox,
-- with a deliberately simplified formula: `pricing` is a proxy for whether any
-- prices were captured, `competitive` may be unmeasurable, and the weights are
-- a hardcoded mirror of the client's. The server then recomputes from what
-- actually persisted. The two legitimately disagree, and that is fine — what
-- was not fine is that the device's number was discarded on sync, so an agent
-- who watched 84 on the walk out and opened 71 the next morning had no way to
-- learn that both numbers were honest. It read as the score being changed.
--
-- `provisional_total` / `provisional_band` / `provisional_at` record what the
-- agent SAW, and nothing else ever reads them: no KPI, no aggregate, no
-- scorecard input. They are nullable because they are unknowable for every
-- scorecard written before now and for every older app build, which sends no
-- provisional score at all — and a missing provisional must read as "we do not
-- know what they saw", never as 0.
--
-- `scored_at` is when the SERVER last computed `weighted_total`. `created_at`
-- is preserved across the scorecard upsert, so after a regenerate it names when
-- the FIRST score was written; a client saying "scored 71" needs to date 71.
-- Backfilled to `created_at`, which is exactly right for any scorecard that has
-- not been regenerated and the closest honest value for one that has.

-- AlterTable
ALTER TABLE "scorecards" ADD COLUMN     "provisional_total" DOUBLE PRECISION;
ALTER TABLE "scorecards" ADD COLUMN     "provisional_band" TEXT;
ALTER TABLE "scorecards" ADD COLUMN     "provisional_at" TIMESTAMP(3);
ALTER TABLE "scorecards" ADD COLUMN     "scored_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Backfill: the only timestamp these rows ever had for when they were scored.
UPDATE "scorecards" SET "scored_at" = "created_at";
