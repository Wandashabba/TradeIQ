-- Outside context for Ask TradeIQ: calendar, weather and the economy.
--
-- 1. `clients.assistant_external_context_enabled` — per-client switch for the
--    outside-context tools. Defaults true: the data is public and the tools
--    send nothing about the tenant out except an outlet-centroid coordinate
--    to the weather API. Off removes the tools from the declared roster.
--
-- 2. `economic_observations` — global (no client_id) public series: Stats SA
--    retail trade and CPI, and fuel price adjustments, each row with its source,
--    release date and retrieval time. Written by the refresh job only.
--
-- 3. `economic_source_refreshes` — last attempt/success per source, so a stale
--    feed shows up in the answer rather than being silently old.

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "assistant_external_context_enabled" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "economic_observations" (
    "id" TEXT NOT NULL,
    "series" TEXT NOT NULL,
    "period" TEXT NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "source_name" TEXT NOT NULL,
    "source_url" TEXT NOT NULL,
    "released_at" DATE,
    "retrieved_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "economic_observations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "economic_source_refreshes" (
    "source" TEXT NOT NULL,
    "last_attempt_at" TIMESTAMP(3) NOT NULL,
    "last_success_at" TIMESTAMP(3),
    "last_error" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "economic_source_refreshes_pkey" PRIMARY KEY ("source")
);

-- CreateIndex
CREATE UNIQUE INDEX "economic_observations_series_period_key" ON "economic_observations"("series", "period");

