-- Outlet.code becomes unique per tenant rather than globally.
--
-- A global unique meant one tenant creating 'SAN-001' made that code
-- permanently unavailable to every other tenant, and the resulting 409 told
-- them somebody else already held it — a cross-tenant existence oracle.
-- Territory already models this correctly with @@unique([clientId, code]).
--
-- This fails loudly if two tenants already share a code. That is the right
-- behaviour: silently merging or renaming somebody's outlet codes would be
-- worse than stopping. Check before deploying:
--   SELECT code, COUNT(*) FROM outlets GROUP BY code HAVING COUNT(*) > 1;

-- DropIndex
DROP INDEX "outlets_code_key";

-- CreateIndex
CREATE UNIQUE INDEX "outlets_client_id_code_key" ON "outlets"("client_id", "code");
