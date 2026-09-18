-- A stock line that was never counted (#389).
--
-- `units_available` was NOT NULL, so an agent who had walked half the shelf
-- had no way to say "I have not reached this SKU yet" — the app sent 0, and 0
-- is a finding: it raises a stock-out task, drops on-shelf-availability, and
-- tells a manager the store is empty of something nobody looked at.
--
-- NULL now means "not counted". 0 keeps meaning what it always meant: an
-- agent stood at the shelf and saw nothing there. Every reader that used to
-- divide by "stock rows" now divides by "stock rows that were counted", and
-- the stock-out task is raised on a counted 0 only.
--
-- `coverage_days_predicted` is units / velocity, so it is unknowable for an
-- uncounted line and goes NULL with it. `days_out_of_stock` and `velocity_avg`
-- are derived from the outlet's EARLIER history rather than from this count,
-- so they stay NOT NULL and stay true.
--
-- Backfill-free by construction: every existing row has a count, so no
-- existing row becomes NULL. Widening a NOT NULL column to nullable rewrites
-- no rows and takes only a brief catalog lock.

-- AlterTable
ALTER TABLE "visit_stock" ALTER COLUMN "units_available" DROP NOT NULL;
ALTER TABLE "visit_stock" ALTER COLUMN "coverage_days_predicted" DROP NOT NULL;
