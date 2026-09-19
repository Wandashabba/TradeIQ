-- The repair path for a wrongly pinned outlet (#386).
--
-- An outlet's coordinates came from one place only — the phone's position when
-- the create form was submitted — and nothing in the product could change them
-- afterwards. Forty stores onboarded during a Monday planning session at the
-- depot are forty stores pinned to the depot car park, and every agent who
-- stands in one of them on Tuesday is told they are kilometres away, forever.
--
-- Three things arrive together, because none of them is safe alone:
--
--   outlets.status          so an outlet can be retired instead of edited into
--                           something else. Defaulted, never NULL: every
--                           existing outlet is exactly as active as it was.
--
--   pin_disputes            the agent's claim that the pin is wrong, with the
--                           evidence for it. The override this unlocks is the
--                           one thing check-in fraud detection exists to
--                           prevent, so it is never silent — see the model doc.
--
--   outlet_change_audit     who moved a pin, and where it was before. Making
--                           coordinates editable without this would let the
--                           boundary of who can check in where move with no
--                           record of who moved it.
--
-- Additive throughout. An app build that predates all of this sends none of
-- these fields and reads none of them, and behaves exactly as it did.

-- AlterTable
-- NOT NULL with a default, so the backfill is the default and no existing row
-- needs rewriting to a meaning nobody chose for it.
ALTER TABLE "outlets" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'active';

-- CreateTable
CREATE TABLE "pin_disputes" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "outlet_id" TEXT NOT NULL,
    "agent_id" TEXT NOT NULL,
    "visit_id" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "distance_m" DOUBLE PRECISION NOT NULL,
    -- The pin as it read when the claim was made. Frozen for the same reason
    -- fraud_verdicts.risk_score_at_review is: a dispute read after the pin was
    -- corrected must still show what the agent was arguing with, or it looks
    -- like a complaint about coordinates nobody ever had.
    "outlet_lat" DOUBLE PRECISION NOT NULL,
    "outlet_lng" DOUBLE PRECISION NOT NULL,
    "note" TEXT,
    "status" TEXT NOT NULL DEFAULT 'open',
    "resolved_by_id" TEXT,
    "resolved_by_label" TEXT,
    "resolved_note" TEXT,
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pin_disputes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
-- One dispute per visit. The override and the evidence for it are one record:
-- a second dispute against the same visit would be a second story about one
-- check-in, and a reviewer could not tell which one the agent meant.
CREATE UNIQUE INDEX "pin_disputes_visit_id_key" ON "pin_disputes"("visit_id");

-- CreateIndex
-- The manager's open queue: client_id = ? AND status = 'open' ordered
-- created_at DESC, id DESC — the equality columns, then exactly the keyset's
-- sort, so a page is an index range read with no sort step.
CREATE INDEX "pin_disputes_client_id_status_created_at_id_idx" ON "pin_disputes"("client_id", "status", "created_at" DESC, "id" DESC);

-- CreateIndex
-- The evidence list on one outlet's detail screen.
CREATE INDEX "pin_disputes_outlet_id_created_at_idx" ON "pin_disputes"("outlet_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "pin_disputes" ADD CONSTRAINT "pin_disputes_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pin_disputes" ADD CONSTRAINT "pin_disputes_outlet_id_fkey" FOREIGN KEY ("outlet_id") REFERENCES "outlets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pin_disputes" ADD CONSTRAINT "pin_disputes_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pin_disputes" ADD CONSTRAINT "pin_disputes_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "visits"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "outlet_change_audit" (
    "id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "outlet_id" TEXT NOT NULL,
    -- A bare column, not a foreign key: deactivating a manager must not erase
    -- the record of what they changed. Same shape as
    -- competitor_price_collection_audit and fraud_verdicts.reviewer_id.
    "user_id" TEXT NOT NULL,
    "user_label" TEXT NOT NULL,
    "before" JSONB NOT NULL,
    "after" JSONB NOT NULL,
    "pin_source" TEXT,
    "dispute_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outlet_change_audit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "outlet_change_audit_client_id_created_at_id_idx" ON "outlet_change_audit"("client_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "outlet_change_audit_outlet_id_created_at_idx" ON "outlet_change_audit"("outlet_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "outlet_change_audit" ADD CONSTRAINT "outlet_change_audit_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "outlet_change_audit" ADD CONSTRAINT "outlet_change_audit_outlet_id_fkey" FOREIGN KEY ("outlet_id") REFERENCES "outlets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
