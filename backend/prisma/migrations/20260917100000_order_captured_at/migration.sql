-- #338: the device's capture time for an order.
--
-- Orders were dated by `created_at` — when the SERVER received them. An order
-- taken offline on the 30th and synced on the 1st therefore counted toward the
-- next month, skewing sell-in attainment (#119), the demand forecast and
-- campaign attribution (#324).
--
-- NOT NULL, so nothing downstream has to decide what a null capture time
-- means. Existing rows are backfilled from `created_at`: for an order that was
-- placed online they are the same instant anyway, and for one that was not, the
-- received time is the only evidence we ever kept of when it happened. The
-- column is added WITH the default first so the NOT NULL holds while the rows
-- are still being backfilled.

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "captured_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Backfill: every pre-existing order keeps the only timestamp it ever had.
UPDATE "orders" SET "captured_at" = "created_at";
