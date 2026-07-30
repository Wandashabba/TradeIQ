-- AlterTable
ALTER TABLE "beat_plans" ADD COLUMN     "recurrence" JSONB,
ADD COLUMN     "series_id" TEXT;

-- CreateIndex
CREATE INDEX "beat_plans_series_id_idx" ON "beat_plans"("series_id");
