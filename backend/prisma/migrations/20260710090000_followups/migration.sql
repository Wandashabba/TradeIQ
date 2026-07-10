-- AlterTable: deactivatable users (admin provisioning)
ALTER TABLE "users" ADD COLUMN "active" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "incentive_schemes" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "metric" TEXT NOT NULL,
    "threshold" DOUBLE PRECISION NOT NULL,
    "reward_points" INTEGER NOT NULL,
    "reward_detail" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "incentive_schemes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "report_schedules" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "report_definition_id" TEXT NOT NULL,
    "cadence" TEXT NOT NULL,
    "recipients" JSONB NOT NULL,
    "last_run_at" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "report_schedules_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "incentive_schemes" ADD CONSTRAINT "incentive_schemes_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_schedules" ADD CONSTRAINT "report_schedules_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "report_schedules" ADD CONSTRAINT "report_schedules_report_definition_id_fkey" FOREIGN KEY ("report_definition_id") REFERENCES "report_definitions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
