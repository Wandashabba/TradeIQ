-- #309: the IANA zone a client's calendar days are counted in — which beat
-- plan a check-in belongs to, trend day/week buckets, the assistant's "today".
-- Before this every such rule used the UTC day, so a 00:00-02:00 SAST check-in
-- counted toward yesterday's plan. NOT NULL with a default, so every existing
-- client gets Africa/Johannesburg (where every current field team works) in
-- the same statement and no row is ever without a zone.

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "timezone" TEXT NOT NULL DEFAULT 'Africa/Johannesburg';
