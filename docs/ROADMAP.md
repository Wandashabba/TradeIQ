# TradeIQ Roadmap

TradeIQ is a multi-industry trade-marketing / retail-execution platform. The
product roadmap follows the pitch deck's four phases; this document maps each
phase to its implementation status and the GitHub issues that track it.

Scope authority: `docs/superpowers/specs/2026-07-02-tradeiq-scaffold-design.md`
(§2 reconciles the detailed build prompt with the pitch deck). Real-vs-stubbed
detail: `docs/architecture/stubs-and-interfaces.md`.

## Phase 1 — Foundation (months 1-3) — ✅ implemented

The field-agent offline-first audit app + manager dashboard, on lean infra
(plain Postgres + haversine, no Kafka/PostGIS/Redis).

| Capability | Status |
|---|---|
| Auth (JWT, bcrypt, rate-limited login, RBAC route guards) | ✅ |
| Outlet registry + create + haversine geofence check-in | ✅ |
| S1-S10 audit capture (offline-first Drift + sync queue) | ✅ |
| S2 stock (coverage-days), S3-4 visibility (vision-stub wired), S5 pricing (OCR-stub wired) | ✅ |
| S6 competitive, S7 capability, S8 risks (auto-creates SLA tasks) | ✅ |
| S9 task lifecycle (create / list / PATCH close / verify) | ✅ |
| S10 scorecard (local on-device + server-authoritative, per-client weights/thresholds) | ✅ |
| Manager dashboard — 8 KPIs (`GET /dashboard`, filterable server-side) | ✅ |
| Photo pipeline (`POST /photos`) + photo-verified task closure | ✅ (base64/Postgres, ADR 0007) |
| Manager-facing GET listings for every section + `GET /visits` | ✅ |
| Per-row `createdAt` timestamps + measured check-in distance | ✅ |
| Seed: client/users/outlets/SKUs/planograms/promos/demo visits+scorecards+tasks | ✅ |
| Migrations, docker-compose (Postgres), CI (app + backend) | ✅ |

**Phase-1 follow-ups (tracked, not blocking):** real in-app camera capture
(#41), admin clients-config (#46), admin user provisioning (#42), auto-tasks
from stockouts/price-deviations (#47), dashboard filter UI (#48), app
per-route role guards (#43). Closed audit-section issues: #8-#16; login #5.

## Phase 2 — Intelligence (months 4-6) — 🔵 deferred, seams ready

Real ML/CV/OCR behind the interfaces the stubs already define. The Phase-1
gap-closure work deliberately started **capturing the raw data** these need
(photos, GPS/timestamps, measured distances) so Phase 2 does not cold-start.

| Capability | Stub / seam | Issue |
|---|---|---|
| Computer vision (branding/planogram/facings/cleanliness/POSM) | `vision.stub.ts`, wired into S3-4 | #1 |
| OCR price extraction | `ocr.stub.ts`, wired into S5 | #2 |
| Behavioural fraud / ghost-visit detection | `fraud.stub.ts` | #3 |
| Predictive field dispatch | `dispatch.stub.ts` | #4 |
| ML demand forecasting | replaces `forecast.service.ts` velocity formula | (no issue yet) |

**Phase-2 data-readiness follow-ups:** persist failed/borderline geofence
attempts for fraud (#44); agent location/territory model for dispatch (#45);
migrate photo storage to an object store (folded into #1/#2, ADR 0007).
Infra deferred here: Kafka, PostGIS, Redis (ADR 0002).

## Phase 3 — Activation (months 7-9) — 🟣 planned, issues filed

Turning captured audit data into field action and business outcomes. Grounded
in a competitive scan (Repsly, GoSpotCheck/FORM, Salesforce Consumer Goods
Cloud, Wiser, Movista, FieldAssist, Bizom, BeatRoute, StayinFront).

**Tier 1 (build first):**
1. Trade Promotion & Campaign Management — planning → compliance → ROI (#29)
2. Journey / Beat planning & visit scheduling (#30)
3. Rules-based alerting & exception notifications (#31)
4. Configurable audit/survey template builder (#32)
5. Campaign-ROI / perfect-store / share-of-shelf trend analytics (#33)

**Tier 2:**
6. Field-agent gamification & retailer incentives (#34)
7. Territory management & coverage heatmaps (#35)
8. In-store order-taking / sell-in capture (#36)
9. In-app messaging & announcements (#37)
10. Integrations, webhooks & data export (ERP/POS/CRM) (#38)
11. Report builder & scheduled delivery (#39)
12. Multi-language localization (#40)

Sequencing note: #35 (territories) underpins #30 (beat planning); #29→#33
(campaign → ROI) is the tightest activation feedback loop; #7/#35 also
unblocks the Phase-2 dispatch data gap (#45).

## Phase 4 — Scale & Optimise (months 10-12) — ⚪ not yet ticketed

White-label & multi-tenant admin at scale, self-serve API marketplace,
multi-currency finance / trade-spend deduction management, and ML route
optimisation / next-best-action (on top of the Phase-3 beat-planning
foundation). To be ticketed once Phase 3 lands.
