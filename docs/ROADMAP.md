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

**Phase-1 follow-ups:** ✅ admin clients-config (#46, `modules/clients`),
✅ admin user provisioning + deactivation (#42, `modules/users`), ✅ auto-tasks
from stockouts/price-deviations (#47). Still app-side: real in-app camera
capture (#41), dashboard filter UI (#48), per-route role guards (#43). Closed
audit-section issues: #8-#16; login #5.

## Phase 2 — Intelligence (months 4-6) — 🟢 in-house parts implemented; CV/OCR vendor-blocked

Real logic behind the stub interfaces. The in-house-implementable capabilities
(heuristic/statistical) are shipped; CV and OCR need a trained model or paid
vendor and stay stubbed. Detail: `docs/architecture/phase2-intelligence.md`.

| Capability | Status | Issue |
|---|---|---|
| Behavioural fraud / ghost-visit detection | ✅ real heuristic engine (`modules/fraud`) | #3 |
| Predictive field dispatch | ✅ real nearest-agent (`modules/dispatch`) | #4 |
| ML demand forecasting | ✅ real exponential smoothing (`forecast.service` + `modules/forecast`) | — |
| Persist failed geofence attempts | ✅ `CheckInAttempt` model | #44 |
| Agent location / territory for dispatch | ✅ `User.lastLat/lng` + Territories | #45 |
| Computer vision (branding/planogram/facings/cleanliness/POSM) | 🔴 stub wired; needs model/vendor | #1 |
| OCR price extraction | 🔴 stub wired; needs model/vendor | #2 |

CV/OCR are **blocked on a vendor/model decision, not on integration** — the
seams are wired and Phase 1 captures the photos they would consume. Infra
deferred: Kafka, PostGIS, Redis (ADR 0002).

## Phase 3 — Activation (months 7-9) — 🟢 Tier-1 backend implemented

Turning captured audit data into field action and business outcomes. Grounded
in a competitive scan (Repsly, GoSpotCheck/FORM, Salesforce Consumer Goods
Cloud, Wiser, Movista, FieldAssist, Bizom, BeatRoute, StayinFront). Backend
detail: `docs/architecture/phase3-activation.md`.

**Tier 1 — backend ✅ implemented (app UIs tracked as sub-tickets):**
1. Trade Promotion & Campaign Management — CRUD + audit-derived compliance (#29) ✅ backend
2. Journey / Beat planning & visit scheduling (#30) ✅ backend
3. Rules-based alerting & exception evaluation (#31) ✅ backend
4. Configurable audit/survey template builder (#32) ✅ backend
5. Perfect-store / availability / scorecard trend analytics (#33) ✅ backend
   (Territories (#35) shipped alongside as the Tier-1 enabler.)

App UIs for the Tier-1 features and campaign-ROI dashboards are the next step
(sub-tickets on #29-#33/#35). Event-driven alerting/streaming is Phase 4.

**Tier 2 — backend ✅ implemented (app UIs tracked separately):**
6. Field-agent gamification & leaderboard (#34) ✅ backend (`modules/gamification` + `modules/incentives` reward schemes)
7. Territory management & coverage (#35) ✅ backend (shipped in Tier-1)
8. In-store order-taking / sell-in capture (#36) ✅ backend (`modules/orders`)
9. In-app messaging & announcements (#37) ✅ backend (`modules/collaboration`)
10. Integrations, webhooks & data export (#38) ✅ backend (`modules/webhooks` + event wiring on visit/order/alert, report CSV export)
11. Report builder + scheduling (#39) ✅ backend (`modules/reports` + `modules/reportschedules`); recurring delivery infra is Phase 4
12. Multi-language localization (#40) — 🟣 app-side, planned

Now shipped: retailer/agent **incentive schemes** (`modules/incentives`),
**event-driven webhooks** (fire on visit.submitted / order.created /
alert.raised), and **report schedules** (definition + on-demand run). The
recurring scheduler + email/webhook delivery transport is Phase 4.

Sequencing note: #35 (territories) underpins #30 (beat planning); #29→#33
(campaign → ROI) is the tightest activation feedback loop; #7/#35 also
unblocks the Phase-2 dispatch data gap (#45).

## Phase 4 — Scale & Optimise (months 10-12) — ⚪ not yet ticketed

White-label & multi-tenant admin at scale, self-serve API marketplace,
multi-currency finance / trade-spend deduction management, and ML route
optimisation / next-best-action (on top of the Phase-3 beat-planning
foundation). To be ticketed once Phase 3 lands.
