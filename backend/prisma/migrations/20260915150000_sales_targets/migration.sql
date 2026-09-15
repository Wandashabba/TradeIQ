-- #119: monthly sell-in targets per SKU, set by managers.
--
-- The actual a target is measured against is sell-in — units ordered through
-- TradeIQ (order_lines on non-cancelled orders) — not consumer sell-out, which
-- no feed exists for. visit_stock.sales_actual / sales_target are untouched and
-- stay nullable and unused (#112).

-- CreateTable
CREATE TABLE "sales_targets" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "sku_id" TEXT NOT NULL,
    "month" DATE NOT NULL,
    "territory_id" TEXT,
    "outlet_id" TEXT,
    "target_units" INTEGER NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sales_targets_pkey" PRIMARY KEY ("id"),
    -- A target is client-wide, for one territory, or for one outlet. Both at
    -- once would be an outlet target that also claims a territory it may not
    -- belong to (Outlet.territoryId is a free-text code), so it is refused.
    CONSTRAINT "sales_targets_single_scope" CHECK ("territory_id" IS NULL OR "outlet_id" IS NULL),
    CONSTRAINT "sales_targets_target_units_non_negative" CHECK ("target_units" >= 0),
    -- The month is stored as its first day; any other day would make two rows
    -- for the same month look distinct to the unique index below.
    CONSTRAINT "sales_targets_month_first_day" CHECK (EXTRACT(DAY FROM "month") = 1)
);

-- CreateIndex
CREATE INDEX "sales_targets_client_id_month_idx" ON "sales_targets"("client_id", "month");

-- CreateIndex
CREATE INDEX "sales_targets_sku_id_idx" ON "sales_targets"("sku_id");

-- One target per scope. A plain unique over the nullable columns would not do
-- it: Postgres treats NULLs as distinct, so two client-wide rows (both scope
-- columns NULL) would both be accepted. COALESCE folds NULL to '' — never a
-- real id, since ids are uuids — so every scope has exactly one key. The upsert
-- in salesTargets.service.ts names this same expression list in ON CONFLICT.
--
-- Prisma cannot express an expression index, so schema.prisma does not show
-- this and `prisma migrate diff` does not compare it.
CREATE UNIQUE INDEX "sales_targets_scope_key" ON "sales_targets"(
    "client_id",
    "sku_id",
    "month",
    (COALESCE("territory_id", '')),
    (COALESCE("outlet_id", ''))
);

-- AddForeignKey
ALTER TABLE "sales_targets" ADD CONSTRAINT "sales_targets_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_targets" ADD CONSTRAINT "sales_targets_sku_id_fkey" FOREIGN KEY ("sku_id") REFERENCES "skus"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_targets" ADD CONSTRAINT "sales_targets_territory_id_fkey" FOREIGN KEY ("territory_id") REFERENCES "territories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_targets" ADD CONSTRAINT "sales_targets_outlet_id_fkey" FOREIGN KEY ("outlet_id") REFERENCES "outlets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_targets" ADD CONSTRAINT "sales_targets_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
