# Data Model

Managed via Prisma — `backend/prisma/schema.prisma` is the single source of
truth. Summary of entities (see the schema file for exact fields/types):

| Entity | Purpose |
|---|---|
| `Client` | A brand/tenant. Holds `scorecardWeights` and `kpiThresholds` (jsonb), configurable per client. |
| `User` | `field_agent`, `manager`, or `admin`, scoped to one `Client`. |
| `Outlet` | A store/branch. Has lat/lng for geofencing, a `territoryId`, and a `teamProfile` jsonb blob. |
| `Sku` | A product, scoped to a `Client`, with `minFacingsStandard` and `rrp`. |
| `PlanogramTemplate` | Stub-era zone map for planogram compliance scoring (Phase 2+ CV target). |
| `PromoCalendar` | Active promotions per client, with required POSM and outlet scope. |
| `Visit` | One agent's audit visit to one outlet — the root of S1–S10 data. |
| `VisitStock` / `VisitVisibility` / `VisitPricing` / `VisitCompetitive` / `VisitCapability` / `VisitRisk` | One row (or set of rows) per `Visit`, one per audit section (S2, S3-4, S5, S6, S7, S8). |
| `Task` | Auto-created from a flagged finding; has `priority`, `slaDueAt` (via `slaClock.ts`), `ownerId`, and closure-verification fields. |
| `Photo` | A stored image (base64, ADR 0007). Either GPS+timestamp-tagged visit evidence (`visitId` set), or a message attachment (`visitId` null, owned by `clientId` + `uploadedById`). |
| `MessageAttachment` | Links an image `Photo` to a `Message` (#125), at most 4 per message, each photo attached once. Images only — no general file attachments. |
| `Scorecard` | The S10 weighted-total output for a `Visit`. |

`VisitStock` and `VisitPricing` each carry a proper `skuId` foreign key with
a `sku: Sku @relation(...)` relation (not just a loose string reference) —
both link stock levels and shelf pricing back to a specific `Sku` row, so
per-SKU rollups (e.g. coverage-days-by-SKU, price-deviation-by-SKU) can be
queried directly through Prisma without joining on a denormalized name.

## Migrations

Run `npx prisma migrate dev --name <description>` from `backend/` after any
schema change. Never hand-edit files under `backend/prisma/migrations/`.
