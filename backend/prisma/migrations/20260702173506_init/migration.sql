-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('field_agent', 'manager', 'admin');

-- CreateEnum
CREATE TYPE "VisitStatus" AS ENUM ('in_progress', 'submitted');

-- CreateEnum
CREATE TYPE "TaskPriority" AS ENUM ('critical', 'high', 'normal');

-- CreateEnum
CREATE TYPE "TaskStatus" AS ENUM ('open', 'in_progress', 'closed');

-- CreateTable
CREATE TABLE "clients" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "industry" TEXT NOT NULL,
    "scorecard_weights" JSONB NOT NULL,
    "kpi_thresholds" JSONB NOT NULL,

    CONSTRAINT "clients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "client_id" TEXT NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outlets" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "channel_type" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "territory_id" TEXT NOT NULL,
    "team_profile" JSONB NOT NULL,
    "client_id" TEXT NOT NULL,

    CONSTRAINT "outlets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "skus" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "min_facings_standard" INTEGER NOT NULL,
    "rrp" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "skus_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "planogram_templates" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "zone_map" JSONB NOT NULL,

    CONSTRAINT "planogram_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "promo_calendar" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "promo_name" TEXT NOT NULL,
    "active_from" TIMESTAMP(3) NOT NULL,
    "active_to" TIMESTAMP(3) NOT NULL,
    "required_posm" JSONB NOT NULL,
    "outlet_scope" JSONB NOT NULL,

    CONSTRAINT "promo_calendar_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visits" (
    "id" TEXT NOT NULL,
    "outlet_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "checkin_ts" TIMESTAMP(3) NOT NULL,
    "checkin_lat" DOUBLE PRECISION NOT NULL,
    "checkin_lng" DOUBLE PRECISION NOT NULL,
    "geofence_pass" BOOLEAN NOT NULL,
    "status" "VisitStatus" NOT NULL DEFAULT 'in_progress',

    CONSTRAINT "visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_stock" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "sku_id" TEXT NOT NULL,
    "units_available" INTEGER NOT NULL,
    "last_stockin_date" TIMESTAMP(3) NOT NULL,
    "days_out_of_stock" INTEGER NOT NULL,
    "velocity_avg" DOUBLE PRECISION NOT NULL,
    "coverage_days_predicted" DOUBLE PRECISION NOT NULL,
    "sales_actual" DOUBLE PRECISION NOT NULL,
    "sales_target" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "visit_stock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_visibility" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "branding_elements" JSONB NOT NULL,
    "planogram_compliance_pct" DOUBLE PRECISION NOT NULL,
    "facings_count" JSONB NOT NULL,
    "high_traffic_pass" BOOLEAN NOT NULL,
    "cleanliness_score" INTEGER NOT NULL,

    CONSTRAINT "visit_visibility_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_pricing" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "sku_id" TEXT NOT NULL,
    "price_actual" DOUBLE PRECISION NOT NULL,
    "price_master" DOUBLE PRECISION NOT NULL,
    "deviation_pct" DOUBLE PRECISION NOT NULL,
    "promo_active" BOOLEAN NOT NULL,
    "promo_materials_detected" JSONB NOT NULL,
    "comms_rating" INTEGER NOT NULL,

    CONSTRAINT "visit_pricing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_competitive" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "competitor_sku" TEXT NOT NULL,
    "competitor_price" DOUBLE PRECISION NOT NULL,
    "competitor_posm_type" TEXT NOT NULL,
    "competitor_promoter_present" BOOLEAN NOT NULL,
    "geotag" JSONB NOT NULL,

    CONSTRAINT "visit_competitive_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_capability" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "staff_headcount_confirmed" INTEGER NOT NULL,
    "rep_training_status" JSONB NOT NULL,
    "quiz_score" INTEGER NOT NULL,

    CONSTRAINT "visit_capability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_risks" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "flag_type" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "note" TEXT NOT NULL,

    CONSTRAINT "visit_risks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tasks" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT,
    "finding_type" TEXT NOT NULL,
    "outlet_id" TEXT NOT NULL,
    "required_fix" TEXT NOT NULL,
    "priority" "TaskPriority" NOT NULL,
    "sla_due_at" TIMESTAMP(3) NOT NULL,
    "owner_id" TEXT NOT NULL,
    "status" "TaskStatus" NOT NULL DEFAULT 'open',
    "closure_photo_url" TEXT,
    "closure_verified" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "photos" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "section" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "gps_tag" JSONB NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "photos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "scorecards" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "dimension_scores" JSONB NOT NULL,
    "weighted_total" DOUBLE PRECISION NOT NULL,
    "rating_band" TEXT NOT NULL,

    CONSTRAINT "scorecards_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "outlets_code_key" ON "outlets"("code");

-- CreateIndex
CREATE UNIQUE INDEX "visit_visibility_visit_id_key" ON "visit_visibility"("visit_id");

-- CreateIndex
CREATE UNIQUE INDEX "visit_capability_visit_id_key" ON "visit_capability"("visit_id");

-- CreateIndex
CREATE UNIQUE INDEX "scorecards_visit_id_key" ON "scorecards"("visit_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "outlets" ADD CONSTRAINT "outlets_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "skus" ADD CONSTRAINT "skus_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "planogram_templates" ADD CONSTRAINT "planogram_templates_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promo_calendar" ADD CONSTRAINT "promo_calendar_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visits" ADD CONSTRAINT "visits_outlet_id_fkey" FOREIGN KEY ("outlet_id") REFERENCES "outlets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visits" ADD CONSTRAINT "visits_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visits" ADD CONSTRAINT "visits_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_stock" ADD CONSTRAINT "visit_stock_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_visibility" ADD CONSTRAINT "visit_visibility_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_pricing" ADD CONSTRAINT "visit_pricing_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_competitive" ADD CONSTRAINT "visit_competitive_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_capability" ADD CONSTRAINT "visit_capability_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_risks" ADD CONSTRAINT "visit_risks_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_outlet_id_fkey" FOREIGN KEY ("outlet_id") REFERENCES "outlets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "photos" ADD CONSTRAINT "photos_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "scorecards" ADD CONSTRAINT "scorecards_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
