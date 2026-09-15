-- CreateTable
CREATE TABLE "agent_location_pings" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "accuracy_m" DOUBLE PRECISION,
    "recorded_at" TIMESTAMP(3) NOT NULL,
    "source" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "agent_location_pings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "agent_day_summaries" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "first_ping_at" TIMESTAMP(3) NOT NULL,
    "last_ping_at" TIMESTAMP(3) NOT NULL,
    "ping_count" INTEGER NOT NULL,
    "stops" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agent_day_summaries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "location_consents" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "notice_version" TEXT NOT NULL,
    "decision" TEXT NOT NULL,
    "decided_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "location_consents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "agent_location_pings_client_id_agent_id_recorded_at_idx" ON "agent_location_pings"("client_id", "agent_id", "recorded_at");

-- CreateIndex
CREATE INDEX "agent_location_pings_recorded_at_idx" ON "agent_location_pings"("recorded_at");

-- CreateIndex
CREATE UNIQUE INDEX "agent_location_pings_agent_id_recorded_at_key" ON "agent_location_pings"("agent_id", "recorded_at");

-- CreateIndex
CREATE INDEX "agent_day_summaries_client_id_day_idx" ON "agent_day_summaries"("client_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "agent_day_summaries_agent_id_day_key" ON "agent_day_summaries"("agent_id", "day");

-- CreateIndex
CREATE INDEX "location_consents_client_id_agent_id_created_at_idx" ON "location_consents"("client_id", "agent_id", "created_at");

-- AddForeignKey
ALTER TABLE "agent_location_pings" ADD CONSTRAINT "agent_location_pings_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agent_location_pings" ADD CONSTRAINT "agent_location_pings_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agent_day_summaries" ADD CONSTRAINT "agent_day_summaries_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agent_day_summaries" ADD CONSTRAINT "agent_day_summaries_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "location_consents" ADD CONSTRAINT "location_consents_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "location_consents" ADD CONSTRAINT "location_consents_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
