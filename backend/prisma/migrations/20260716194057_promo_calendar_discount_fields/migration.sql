-- AlterTable
ALTER TABLE "promo_calendar" ADD COLUMN     "discount_type" TEXT,
ADD COLUMN     "discount_value" DOUBLE PRECISION,
ADD COLUMN     "sku_scope" JSONB;
