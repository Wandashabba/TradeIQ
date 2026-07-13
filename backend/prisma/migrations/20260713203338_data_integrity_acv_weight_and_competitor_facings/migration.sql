-- AlterTable
ALTER TABLE "outlets" ADD COLUMN     "acv_weight" DOUBLE PRECISION NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "visit_competitive" ADD COLUMN     "facings_count" INTEGER NOT NULL DEFAULT 1;
