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

## What is a route skeleton (not a stub, but not implemented)

`pricing` (S5), `competitive` (S6), `capability` (S7), `risks` (S8),
`tasks` (S9), `scorecards` (S10), and `dashboard` modules currently return
`501 Not Implemented` for every route. These are Phase 1 features (not
deferred to Phase 2+) — they're scoped to the follow-up S5–S10
implementation plans, not this scaffold. No GitHub issues are needed for
these; they're just not built yet within Phase 1's own scope.

`GET` listing routes on the built modules (`GET /visits`, `GET /stock`,
`GET /visibility`) also still return `501` — only the agent-facing capture
(`POST`) paths are wired so far; manager-facing listings land with the
dashboard slice.

## Known Phase 1 gaps

Not a stub — in-scope Phase 1 work still to do:

| Gap | Where |
|---|---|
| Audit sections S5–S10 (pricing, competitive, capability, risks, action-plan, scorecard) | backend `modules/{pricing,competitive,capability,risks,tasks,scorecards}` return 501; app section screens are placeholders |
| Manager dashboard (real KPI data) | `app/lib/features/dashboard/...` renders placeholder tiles; `GET` listing routes are 501 |

Resolved since the original scaffold: login form UI + router auth-redirect
(issue #5), session persistence, configurable API base URL, RBAC enforcement,
and auth hardening (helmet, CORS allowlist, login rate-limiting) — see
`docs/phase1-audit-and-remediation.md`.

## Deferred infrastructure (Phase 2+, no code yet)

Kafka event streaming, PostGIS (currently plain lat/lng + haversine), Redis
soft-reserve cache, territory heatmaps, campaign ROI measurement, retailer
incentive engine, and ERP/POS/API marketplace integrations have no stub
because Phase 1 has no caller for them. Track these as issues once a
Phase 2 plan identifies the first real caller.
