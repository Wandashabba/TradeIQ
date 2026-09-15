-- CreateTable
CREATE TABLE "report_email_deliveries" (
    "id" TEXT NOT NULL,
    "run_id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "recipient" TEXT NOT NULL,
    "status" "WebhookDeliveryStatus" NOT NULL DEFAULT 'pending',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "last_error" TEXT,
    "next_attempt_at" TIMESTAMP(3),
    "last_attempt_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "csv_attached" BOOLEAN,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "report_email_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "report_email_deliveries_status_next_attempt_at_idx" ON "report_email_deliveries"("status", "next_attempt_at");

-- CreateIndex
CREATE INDEX "report_email_deliveries_run_id_created_at_idx" ON "report_email_deliveries"("run_id", "created_at");

-- AddForeignKey
ALTER TABLE "report_email_deliveries" ADD CONSTRAINT "report_email_deliveries_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "report_schedule_runs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
