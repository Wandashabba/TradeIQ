-- Ask TradeIQ: per-client switch for live web search.
--
-- Defaults true: web results only ever appear cited and labelled as outside
-- information, and an operator can switch a tenant off. When false, the search
-- tool is not declared on the provider request at all.

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "assistant_web_search_enabled" BOOLEAN NOT NULL DEFAULT true;
