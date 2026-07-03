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
- `backend/src/modules/auth/*` — JWT issue/verify, login, role guards
- `backend/src/modules/outlets/*` — full CRUD, the one fully-wired Phase 1 module

## What is a route skeleton (not a stub, but not implemented)

`visits`, `stock`, `visibility`, `pricing`, `competitive`, `capability`,
`risks`, `tasks`, `scorecards`, and `dashboard` modules currently return
`501 Not Implemented` for every route. These are Phase 1 features (not
deferred to Phase 2+) — they're scoped to the follow-up S1–S10
implementation plan, not this scaffold. No GitHub issues are needed for
these; they're just not built yet within Phase 1's own scope.

## Known Phase 1 gaps

Not a stub — this is in-scope Phase 1 work that isn't done yet, tracked as a
regular issue rather than deferred:

| Gap | Where | Tracking issue |
|---|---|---|
| Login form UI + router auth-redirect | `app/lib/features/auth/presentation/login_screen.dart` has no form; `app/lib/core/router/app_router.dart` has no redirect based on session state | https://github.com/Wandashabba/TradeIQ/issues/5 |

## Deferred infrastructure (Phase 2+, no code yet)

Kafka event streaming, PostGIS (currently plain lat/lng + haversine), Redis
soft-reserve cache, territory heatmaps, campaign ROI measurement, retailer
incentive engine, and ERP/POS/API marketplace integrations have no stub
because Phase 1 has no caller for them. Track these as issues once a
Phase 2 plan identifies the first real caller.
