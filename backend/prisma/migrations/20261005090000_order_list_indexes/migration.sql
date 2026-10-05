-- Two indexes the orders list has always needed, and neither of which exists.
--
-- `GET /orders` pages with `ORDER BY created_at DESC, id DESC` and returns each
-- order's line count. `orders` carried only `(client_id)`, so the page order was
-- a parallel sequential scan and a full sort of every order the client has
-- (38ms at the database over 45,734 rows on the demo tenant, and it grows with
-- the table, not with the page). `order_lines` carried no index at all beyond
-- its primary key, so `_count.lines` scanned the whole child table: measured at
-- 20ms for a 51-row page without the count and 243ms with it.
--
-- Nothing about the results changes. `_count.lines` is part of the response the
-- Flutter app reads ("N lines" on each order), so the count stays and gets an
-- index instead of being dropped.
--
-- `migrate deploy`-safe: two CREATE INDEX statements and no data change, so the
-- migration is re-runnable against a database that already has them only in the
-- sense that Prisma records it once — there is nothing to back-fill and nothing
-- to undo. CREATE INDEX (not CONCURRENTLY, which cannot run inside the
-- transaction `migrate deploy` wraps each migration in) takes a SHARE lock:
-- readers are unaffected, and writers to these two tables wait for the build.
-- On the largest table here, 91,468 orders and their lines, that is seconds.

-- CreateIndex
CREATE INDEX "orders_client_id_created_at_id_idx" ON "orders"("client_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "order_lines_order_id_idx" ON "order_lines"("order_id");
