-- #66: report schedules now fire. `next_run_at` is when the worker next fires a
-- schedule (null while paused); `claimed_until` is the worker's claim lease.
-- `report_schedule_runs` records each run and what was delivered.
--
-- All columns are new or nullable, so this cannot fail on existing data.
-- AlterTable
ALTER TABLE "report_schedules" ADD COLUMN     "claimed_until" TIMESTAMP(3),
ADD COLUMN     "next_run_at" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "report_schedule_runs" (
    "id" TEXT NOT NULL,
    "schedule_id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "trigger" TEXT NOT NULL,
    "due_at" TIMESTAMP(3),
    "generated_at" TIMESTAMP(3) NOT NULL,
    "row_count" INTEGER NOT NULL,
    "deliveries" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "report_schedule_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "report_schedule_runs_client_id_schedule_id_created_at_idx" ON "report_schedule_runs"("client_id", "schedule_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "report_schedule_runs_schedule_id_due_at_key" ON "report_schedule_runs"("schedule_id", "due_at");

-- CreateIndex
CREATE INDEX "report_schedules_active_next_run_at_idx" ON "report_schedules"("active", "next_run_at");

-- AddForeignKey
ALTER TABLE "report_schedule_runs" ADD CONSTRAINT "report_schedule_runs_schedule_id_fkey" FOREIGN KEY ("schedule_id") REFERENCES "report_schedules"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: every active schedule gets its next due time, one cadence period
-- after its last run (or its creation if it never ran). A schedule whose due
-- time has already passed fires ONCE when the worker first polls — a missed
-- run catches up once, never once per missed period (reportschedules.cadence.ts).
-- Days are UTC durations until per-client timezones land (#309).
UPDATE "report_schedules"
SET "next_run_at" = COALESCE("last_run_at", "created_at")
  + CASE WHEN "cadence" = 'weekly' THEN INTERVAL '7 days' ELSE INTERVAL '1 day' END
WHERE "active" = true;
