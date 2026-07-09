# Stubs and Interfaces

Everything in this table is Phase 2+ scope. Each stub lives behind a
narrow interface so a real implementation can swap in later without
touching callers.

| Capability | Stub file | Interface | Real implementation needed | Tracking issue |
|---|---|---|---|---|
| Computer vision (branding/planogram/facings/cleanliness) | `backend/src/services/vision.stub.ts` | `detectBranding`, `scorePlanogramCompliance`, `countFacings`, `scoreCleanliness` | On-device or server CV model for S3/S4 | https://github.com/Wandashabba/TradeIQ/issues/1 |
| OCR price extraction | `backend/src/services/ocr.stub.ts` | `extractPriceFromPhoto` | Real OCR from a shelf-price photo for S5 | https://github.com/Wandashabba/TradeIQ/issues/2 |
| Behavioural fraud / ghost-visit detection | `backend/src/services/fraud.stub.ts` | `detectGhostVisit` (currently throws, no Phase 1 caller) | Fraud/ghost-visit detection | https://github.com/Wandashabba/TradeIQ/issues/3 |
| Predictive field dispatch | `backend/src/services/dispatch.stub.ts` | `dispatchNearestAgent` (currently throws, no Phase 1 caller) | Auto-assign nearest agent on share-of-shelf drop | https://github.com/Wandashabba/TradeIQ/issues/4 |

## What is real (not stubbed)

- `backend/src/lib/geofence.ts` — haversine distance check, ≤50m threshold
- `backend/src/lib/slaClock.ts` — SLA due-date computation (critical=+24h, high=+3d, normal=+7d)
- `backend/src/services/forecast.service.ts` — stock coverage-days prediction from velocity (simple formula, not ML — per-SKU ML demand forecasting is Phase 2+ and has no stub yet because no Phase 1 caller needs it)
- `backend/src/modules/auth/*` — JWT issue/verify, login (rate-limited), role guards (`requireRole`, enforced on write routes)
- `backend/src/modules/outlets/*` — list (all roles) + create (manager/admin)
- `backend/src/modules/skus/*` — client-scoped SKU listing (`GET /skus`)
- `backend/src/modules/visits/*` — geofenced check-in (`POST /visits`) + submit (`POST /visits/:id/submit`), field_agent
- `backend/src/modules/stock/*` — S2 per-SKU stock capture (`POST /stock`) with server-side coverage-days
- `backend/src/modules/visibility/*` — S3–S4 visibility/display capture (`POST /visibility`, upsert)
- `backend/src/modules/pricing/*` — S5 per-SKU shelf-price capture (`POST /pricing`), priceMaster from `Sku.rrp`, deviation computed server-side (shelf price is manual entry through the OCR-stub interface)
- `backend/src/modules/competitive/*` — S6 competitor observations (`POST /competitive`)
- `backend/src/modules/capability/*` — S7 sales-team capability (`POST /capability`, upsert)
- `backend/src/modules/risks/*` — S8 risk flags (`POST /risks`); each risk auto-creates a `Task` with an SLA due date via `slaClock`
- `backend/src/modules/tasks/*` — S9 task lifecycle: `POST /tasks` (manual create), `GET /tasks` (client-scoped list + filters), `PATCH /tasks/:id` (open → in_progress → closed with closure-photo rule; `closureVerified` manager-only)
- `backend/src/modules/scorecards/*` — S10 weighted scorecard (`POST /scorecards`, upsert; `GET /scorecards/:visitId`) from S2–S8 rows using `Client.scorecardWeights` / `kpiThresholds`
- `backend/src/modules/dashboard/*` — manager KPI rollup (`GET /dashboard`, manager/admin, territory/outlet/date filters)

## What is a route skeleton (not a stub, but not implemented)

`GET` listing routes on the capture modules (`GET /visits`, `GET /stock`,
`GET /visibility`, `GET /pricing`, `GET /competitive`, `GET /capability`,
`GET /risks`, bare `GET /scorecards`) still return `501` — only the
agent-facing capture (`POST`) paths plus the manager-facing `GET /tasks`,
`GET /scorecards/:visitId`, and `GET /dashboard` are wired.

## Known Phase 1 gaps

Not a stub — in-scope Phase 1 work still to do:

| Gap | Where |
|---|---|
| Photo capture/upload (`Photo` model, closure photos as real uploads) | no `/photos` endpoint; `closurePhotoUrl` is a plain string |
| Capture-module `GET` listings | see route-skeleton section above |

Resolved since the original scaffold: S5–S10 audit sections + manager
dashboard (issues #10–#16), login form UI + router auth-redirect
(issue #5), session persistence, configurable API base URL, RBAC enforcement,
and auth hardening (helmet, CORS allowlist, login rate-limiting) — see
`docs/phase1-audit-and-remediation.md`.

## Deferred infrastructure (Phase 2+, no code yet)

Kafka event streaming, PostGIS (currently plain lat/lng + haversine), Redis
soft-reserve cache, territory heatmaps, campaign ROI measurement, retailer
incentive engine, and ERP/POS/API marketplace integrations have no stub
because Phase 1 has no caller for them. Track these as issues once a
Phase 2 plan identifies the first real caller.
