-- #236: persist the fraud score, so GET /fraud/flagged filters, sorts and
-- paginates on columns instead of scoring every visit on every request.
--
-- Schema only. Existing visits are NOT scored here: scoring reads each visit's
-- history (earlier stock and photos, check-in attempts), which inside a migration
-- would hold the deploy for as long as that takes. New submissions are scored by
-- submitVisit; older visits by the batched, resumable `npm run rescore-fraud`.
-- Until then they have no score, and the flagged list excludes them and reports
-- how many (`unscored`). All three columns are nullable with no default, so
-- adding them is metadata-only on a large table.
--
-- The index is the flagged query's shape: equality on (client_id, status), then
-- the keyset sort (risk_score DESC, id DESC), so a page is an in-order index read.

-- AlterTable
ALTER TABLE "visits" ADD COLUMN     "fraud_scored_at" TIMESTAMP(3),
ADD COLUMN     "fraud_signals" JSONB,
ADD COLUMN     "risk_score" INTEGER;

-- CreateIndex
CREATE INDEX "visits_client_id_status_risk_score_id_idx" ON "visits"("client_id", "status", "risk_score" DESC, "id" DESC);
