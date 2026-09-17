-- #153 T2: background location tracking.
--
-- Two additions, both with defaults chosen so that an existing row keeps the
-- behaviour it already had and no backfill is needed.
--
-- 1. `clients.work_hours_*` / `work_days` — the window background tracking is
--    allowed to run in, on the wall clock of `clients.timezone` (#309).
--    Monday-to-Friday 07:00-17:00 is the field day this product was built for,
--    and it is the conservative default: a weekend or a night collects nothing
--    until somebody deliberately widens it.
--
-- 2. `location_consents.kind` — which notice an answer is an answer TO.
--    Background tracking is a bigger ask than foreground sharing, so it has its
--    own notice, its own acceptance and its own record. Every row written
--    before this migration is an answer to the foreground notice, which is
--    exactly what the default says, so the append-only history stays true.

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "work_days" INTEGER[] DEFAULT ARRAY[1, 2, 3, 4, 5],
ADD COLUMN     "work_hours_end" TEXT NOT NULL DEFAULT '17:00',
ADD COLUMN     "work_hours_start" TEXT NOT NULL DEFAULT '07:00';

-- AlterTable
ALTER TABLE "location_consents" ADD COLUMN     "kind" TEXT NOT NULL DEFAULT 'foreground';
