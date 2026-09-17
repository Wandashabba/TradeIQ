-- Competitor shelf prices from retailer websites — built, and OFF.
--
-- Nothing here collects anything. Collection needs ALL of:
--   * COMPETITOR_PRICE_COLLECTION=on in the environment (the global kill switch),
--   * clients.competitor_price_collection_enabled = true,
--   * both approval columns set (who signed off the legal review, and when),
-- and every client row defaults to false with no approval. See
-- docs/operations/competitor-price-collection.md.

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "competitor_price_collection_approved_at" TIMESTAMP(3),
ADD COLUMN     "competitor_price_collection_approved_by" TEXT,
ADD COLUMN     "competitor_price_collection_enabled" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "competitor_sku_mappings" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "competitor_sku" TEXT NOT NULL,
    "competitor_brand" TEXT,
    "retailer" TEXT NOT NULL,
    "product_url" TEXT NOT NULL,
    "pack_size" TEXT,
    "our_sku_id" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "competitor_sku_mappings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "competitor_shelf_price_observations" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "mapping_id" TEXT NOT NULL,
    "retailer" TEXT NOT NULL,
    "product_name" TEXT NOT NULL,
    "pack_size" TEXT,
    "shelf_price" DOUBLE PRECISION NOT NULL,
    "promo_price" DOUBLE PRECISION,
    "promo_ends_at" TIMESTAMP(3),
    "currency" TEXT NOT NULL DEFAULT 'ZAR',
    "source_url" TEXT NOT NULL,
    "retrieved_at" TIMESTAMP(3) NOT NULL,
    "method" TEXT NOT NULL DEFAULT 'page',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "competitor_shelf_price_observations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "competitor_price_collection_events" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "retailer" TEXT NOT NULL,
    "mapping_id" TEXT,
    "kind" TEXT NOT NULL,
    "url" TEXT,
    "detail" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "competitor_price_collection_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "competitor_price_collection_audit" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "approved_by" TEXT,
    "approved_at" TIMESTAMP(3),
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "competitor_price_collection_audit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "competitor_sku_mappings_client_id_active_idx" ON "competitor_sku_mappings"("client_id", "active");

-- CreateIndex
CREATE UNIQUE INDEX "competitor_sku_mappings_client_id_retailer_product_url_key" ON "competitor_sku_mappings"("client_id", "retailer", "product_url");

-- CreateIndex
CREATE INDEX "competitor_shelf_price_observations_client_id_mapping_id_re_idx" ON "competitor_shelf_price_observations"("client_id", "mapping_id", "retrieved_at");

-- CreateIndex
CREATE INDEX "competitor_price_collection_events_client_id_retailer_kind__idx" ON "competitor_price_collection_events"("client_id", "retailer", "kind", "created_at");

-- CreateIndex
CREATE INDEX "competitor_price_collection_audit_client_id_created_at_idx" ON "competitor_price_collection_audit"("client_id", "created_at");

-- AddForeignKey
ALTER TABLE "competitor_sku_mappings" ADD CONSTRAINT "competitor_sku_mappings_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "competitor_sku_mappings" ADD CONSTRAINT "competitor_sku_mappings_our_sku_id_fkey" FOREIGN KEY ("our_sku_id") REFERENCES "skus"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "competitor_shelf_price_observations" ADD CONSTRAINT "competitor_shelf_price_observations_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "competitor_shelf_price_observations" ADD CONSTRAINT "competitor_shelf_price_observations_mapping_id_fkey" FOREIGN KEY ("mapping_id") REFERENCES "competitor_sku_mappings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "competitor_price_collection_events" ADD CONSTRAINT "competitor_price_collection_events_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "competitor_price_collection_audit" ADD CONSTRAINT "competitor_price_collection_audit_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- Append-only: a changed price is a new observation, and an approval is never
-- rewritten after the fact. DELETE stays possible for tenant offboarding.
CREATE OR REPLACE FUNCTION competitor_prices_refuse_update() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "competitor_shelf_price_observations_append_only"
  BEFORE UPDATE ON "competitor_shelf_price_observations"
  FOR EACH ROW EXECUTE FUNCTION competitor_prices_refuse_update();

CREATE TRIGGER "competitor_price_collection_audit_append_only"
  BEFORE UPDATE ON "competitor_price_collection_audit"
  FOR EACH ROW EXECUTE FUNCTION competitor_prices_refuse_update();
