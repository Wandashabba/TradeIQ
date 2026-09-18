-- A manager's ruling on a flagged visit, and the lock that makes it one
-- ruling (#392, #395).
--
-- Flagged visits had no outcome at all: the queue showed the same cases every
-- morning, because nothing a manager did could take one out of it. Two
-- managers working the queue together would each "handle" the same case, and
-- neither could see that the other had.
--
-- The UNIQUE constraint on `visit_id` is the lock. A verdict is INSERTed, never
-- upserted, so the second manager to press the button is rejected by the
-- database rather than silently overwriting the first manager's decision — and
-- can be told whose verdict already stands. Doing this in application code
-- instead would leave the race open between the SELECT and the INSERT.
--
-- It is a ledger, so it outlives what it refers to. `reviewer_id` is a bare
-- TEXT column and not a foreign key: deactivating a manager must not erase the
-- record of who ruled. `reviewer_label` freezes their name as it read at the
-- time, and `risk_score_at_review` freezes the number they were looking at —
-- `visits.risk_score` is a snapshot that `npm run rescore-fraud` can move
-- afterwards, and without this a dismissal read a month later looks like it was
-- made against a score nobody ever saw. Same shape and same reasoning as
-- `competitor_price_collection_audit`.

-- CreateTable
CREATE TABLE "fraud_verdicts" (
    "id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "verdict" TEXT NOT NULL,
    "reviewer_id" TEXT NOT NULL,
    "reviewer_label" TEXT NOT NULL,
    "note" TEXT,
    "risk_score_at_review" INTEGER,
    "decided_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fraud_verdicts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "fraud_verdicts_visit_id_key" ON "fraud_verdicts"("visit_id");

-- CreateIndex
-- GET /fraud/verdicts: the tenant's ledger, newest first, keyset-paged on
-- exactly this sort.
CREATE INDEX "fraud_verdicts_client_id_decided_at_id_idx" ON "fraud_verdicts"("client_id", "decided_at" DESC, "id" DESC);

-- AddForeignKey
ALTER TABLE "fraud_verdicts" ADD CONSTRAINT "fraud_verdicts_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fraud_verdicts" ADD CONSTRAINT "fraud_verdicts_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
