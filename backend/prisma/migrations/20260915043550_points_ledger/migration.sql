-- CreateTable
CREATE TABLE "points_ledger_entries" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "points" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "source_type" TEXT NOT NULL,
    "source_id" TEXT NOT NULL,
    "score" DOUBLE PRECISION,
    "occurred_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "points_ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "points_ledger_entries_client_id_agent_id_occurred_at_idx" ON "points_ledger_entries"("client_id", "agent_id", "occurred_at");

-- CreateIndex
CREATE INDEX "points_ledger_entries_client_id_occurred_at_idx" ON "points_ledger_entries"("client_id", "occurred_at");

-- CreateIndex
CREATE UNIQUE INDEX "points_ledger_entries_source_type_source_id_reason_key" ON "points_ledger_entries"("source_type", "source_id", "reason");

-- AddForeignKey
ALTER TABLE "points_ledger_entries" ADD CONSTRAINT "points_ledger_entries_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "points_ledger_entries" ADD CONSTRAINT "points_ledger_entries_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
