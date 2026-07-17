-- CreateIndex
CREATE INDEX "alert_rules_client_id_idx" ON "alert_rules"("client_id");

-- CreateIndex
CREATE INDEX "alerts_client_id_acknowledged_idx" ON "alerts"("client_id", "acknowledged");

-- CreateIndex
CREATE INDEX "announcements_client_id_idx" ON "announcements"("client_id");

-- CreateIndex
CREATE INDEX "beat_plans_client_id_idx" ON "beat_plans"("client_id");

-- CreateIndex
CREATE INDEX "beat_plans_agent_id_idx" ON "beat_plans"("agent_id");

-- CreateIndex
CREATE INDEX "campaigns_client_id_idx" ON "campaigns"("client_id");

-- CreateIndex
CREATE INDEX "check_in_attempts_client_id_passed_idx" ON "check_in_attempts"("client_id", "passed");

-- CreateIndex
CREATE INDEX "check_in_attempts_agent_id_outlet_id_idx" ON "check_in_attempts"("agent_id", "outlet_id");

-- CreateIndex
CREATE INDEX "incentive_schemes_client_id_active_idx" ON "incentive_schemes"("client_id", "active");

-- CreateIndex
CREATE INDEX "messages_client_id_idx" ON "messages"("client_id");

-- CreateIndex
CREATE INDEX "messages_recipient_id_idx" ON "messages"("recipient_id");

-- CreateIndex
CREATE INDEX "orders_client_id_idx" ON "orders"("client_id");

-- CreateIndex
CREATE INDEX "outlets_client_id_idx" ON "outlets"("client_id");

-- CreateIndex
CREATE INDEX "outlets_territory_id_idx" ON "outlets"("territory_id");

-- CreateIndex
CREATE INDEX "photos_visit_id_idx" ON "photos"("visit_id");

-- CreateIndex
CREATE INDEX "promo_calendar_client_id_idx" ON "promo_calendar"("client_id");

-- CreateIndex
CREATE INDEX "report_definitions_client_id_idx" ON "report_definitions"("client_id");

-- CreateIndex
CREATE INDEX "report_schedules_client_id_idx" ON "report_schedules"("client_id");

-- CreateIndex
CREATE INDEX "scorecards_created_at_idx" ON "scorecards"("created_at");

-- CreateIndex
CREATE INDEX "skus_client_id_idx" ON "skus"("client_id");

-- CreateIndex
CREATE INDEX "tasks_owner_id_status_idx" ON "tasks"("owner_id", "status");

-- CreateIndex
CREATE INDEX "tasks_outlet_id_idx" ON "tasks"("outlet_id");

-- CreateIndex
CREATE INDEX "tasks_visit_id_idx" ON "tasks"("visit_id");

-- CreateIndex
CREATE INDEX "users_client_id_role_idx" ON "users"("client_id", "role");

-- CreateIndex
CREATE INDEX "visit_competitive_visit_id_idx" ON "visit_competitive"("visit_id");

-- CreateIndex
CREATE INDEX "visit_pricing_visit_id_idx" ON "visit_pricing"("visit_id");

-- CreateIndex
CREATE INDEX "visit_risks_visit_id_idx" ON "visit_risks"("visit_id");

-- CreateIndex
CREATE INDEX "visit_stock_visit_id_idx" ON "visit_stock"("visit_id");

-- CreateIndex
CREATE INDEX "visit_stock_sku_id_idx" ON "visit_stock"("sku_id");

-- CreateIndex
CREATE INDEX "visits_client_id_status_idx" ON "visits"("client_id", "status");

-- CreateIndex
CREATE INDEX "visits_client_id_checkin_ts_idx" ON "visits"("client_id", "checkin_ts");

-- CreateIndex
CREATE INDEX "visits_outlet_id_idx" ON "visits"("outlet_id");

-- CreateIndex
CREATE INDEX "visits_agent_id_idx" ON "visits"("agent_id");

-- CreateIndex
CREATE INDEX "webhooks_client_id_event_active_idx" ON "webhooks"("client_id", "event", "active");
