-- Drops PlanogramTemplate: seeded since day one, read by nothing.
--
-- Verified by grep across backend/src, backend/scripts and app/lib before
-- removal — the only writer was the seed itself. A seeded model with no
-- readers is worse than no model: it reads as working infrastructure, and
-- planogram compliance is exactly the thing a future CV feature (#1) would
-- assume already exists.
--
-- This deletes data. It is demo/seed data only (two rows, both created by
-- scripts/seed.ts), and nothing has ever read it, so there is nothing to
-- migrate out. If a planogram feature is built later it should design its own
-- schema rather than inherit an empty guess.
--
-- Note: VisitVisibility.planogram_compliance_pct is unrelated and stays — that
-- is the real S3 audit measurement.

-- DropTable
DROP TABLE "planogram_templates";
