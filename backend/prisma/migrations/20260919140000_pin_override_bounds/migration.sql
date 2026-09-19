-- Bounding the pin-dispute override (#386 follow-up).
--
-- The override shipped scored but unbounded. One agent sitting at home could
-- claim a wrong pin at every outlet within the 25 km limit, one claim each,
-- and every one of them scored 30 — below the 50 review threshold — so none of
-- them reached a manager. The visit still counted for points and incentives,
-- and a manager who rejected the claim changed nothing about the visit.
--
-- Four columns, each closing one hole:
--
--   check_in_attempts.accuracy_m / is_mocked
--                            what the device said about the QUALITY of the fix.
--                            "Use their position" copies an attempt's
--                            coordinates onto an outlet — that is an access
--                            boundary moved on one phone's word — and a mocked
--                            fix must not be adoptable. Nullable: an older
--                            build sends neither and still works, and unknown
--                            is warned about, never silently trusted.
--
--   pin_disputes.accuracy_m / is_mocked
--                            the same two, frozen onto the claim, so the
--                            manager reading it months later sees the quality
--                            of the coordinate and not only the coordinate.
--
--   outlet_change_audit.from_attempt_id / from_agent_id
--                            WHICH attempt a pin was copied from and WHOSE.
--                            `pin_source = 'agent_position'` alone recorded
--                            that a pin had moved to a position some phone
--                            claimed, with no way to ask whose.
--
--   photos.source            camera or gallery. A pin-dispute storefront photo
--                            is stamped with the time the picker handed the
--                            file back, so a Street View screenshot picked at
--                            home carries a fresh timestamp and a home gpsTag
--                            that agrees with the claimed position. The server
--                            now requires `camera` for that one section.
--
-- Additive throughout, every column nullable: existing rows keep their meaning
-- (unknown), and a build that predates this sends none of them.

-- AlterTable
ALTER TABLE "check_in_attempts" ADD COLUMN "accuracy_m" DOUBLE PRECISION,
ADD COLUMN "is_mocked" BOOLEAN;

-- AlterTable
ALTER TABLE "pin_disputes" ADD COLUMN "accuracy_m" DOUBLE PRECISION,
ADD COLUMN "is_mocked" BOOLEAN;

-- AlterTable
ALTER TABLE "outlet_change_audit" ADD COLUMN "from_attempt_id" TEXT,
ADD COLUMN "from_agent_id" TEXT;

-- AlterTable
ALTER TABLE "photos" ADD COLUMN "source" TEXT;

-- CreateIndex
-- One agent's claims, newest first. Every rate rule reads exactly this range:
-- "is one already open at this outlet", "how many has this agent opened today",
-- and the 7-day override-rate and override-cluster fraud signals.
CREATE INDEX "pin_disputes_client_id_agent_id_created_at_idx" ON "pin_disputes"("client_id", "agent_id", "created_at" DESC);
