# TradeIQ Scaffold — Design Spec

Date: 2026-07-02
Status: Approved

## 1. Purpose

Scaffold the TradeIQ platform: a monorepo, tech stack, documentation system, and
initial project structure that a small team can onboard onto and build the
Phase 1 ("Foundation") feature set on top of. This spec covers the scaffold
only — not the full implementation of the 10-section audit flow or dashboard
KPIs, which get their own follow-up specs/plans once the scaffold exists.

## 2. Source material and how it reconciles

Two source documents informed this project, and they don't fully agree on
scope, so this section is the tie-breaker:

- **The detailed build prompt** (React-based MVP prompt, later revised to
  Flutter) — describes a Phase-1-scoped MVP: 10-section audit flow, manager
  dashboard with 8 KPIs, task lifecycle, plain Postgres with haversine
  geofencing, CV/OCR/ML explicitly stubbed behind interfaces.
- **The pitch deck** ("TradeIQ — Multi-Industry Trade Marketing Platform",
  20 slides) — describes the full 12-month, 4-phase vision: Foundation
  (months 1-3) → Intelligence (4-6) → Activation (7-9) → Scale & Optimise
  (10-12). Infrastructure shown (Kafka, PostgreSQL+PostGIS, Redis, real
  ML/CV/fraud/dispatch engines) spans all four phases, not just Phase 1.

**Decision: build Phase 1 (Foundation) only, on lean infrastructure.**

Phase 1 scope, per the deck's own "Foundation" column plus the detailed
prompt:
- Field agent mobile app (offline-first), full S1–S10 audit flow
- Outlet registry + GPS geofence engine (haversine, no PostGIS)
- Manager/admin dashboard with the 8 live KPIs
- Task lifecycle: auto-create → assign → SLA → photo-verified closure
- Basic, configurable scorecard engine

Explicitly deferred to Phase 2+ (stubbed behind interfaces now, tracked as
GitHub issues as each stub is written — see §8):
- Real computer vision (branding detection, planogram compliance, facings
  count, cleanliness scoring, POSM classification)
- Real OCR (price extraction)
- ML demand forecasting, behavioural fraud detection, predictive dispatch
- Kafka event streaming, PostGIS, Redis soft-reserve cache
- Territory heatmaps, campaign ROI measurement, retailer incentive engine,
  API marketplace / ERP/POS integrations

Rationale: stubs behind narrow interfaces let Phase 2+ swap in real
implementations without rewriting callers, and a small team can ship and
validate the core workflow before taking on Kafka/PostGIS/ML operational
complexity that Phase 1 doesn't yet need.

## 3. Tech stack

| Layer | Choice | Why |
|---|---|---|
| Mobile + web app | Flutter (single codebase) | One team, one skillset, covers both the field-agent mobile flow and the manager/admin web dashboard via responsive layouts |
| App state management | Riverpod | Compile-safe, testable, strong async/offline support, well-documented for new hires |
| App local persistence | Drift (SQLite) | Backs the offline-first sync queue |
| App navigation | go_router | Role-based route guards (field_agent/manager/admin) |
| Backend | Node.js + Express + TypeScript | Matches the detailed MVP prompt; large ecosystem, easy onboarding |
| Backend DB access | Prisma + PostgreSQL | Type-safe queries, single schema.prisma as source of truth, built-in migrations |
| Geofencing | Plain lat/lng + haversine formula | PostGIS deferred to Phase 2+ |
| Auth | JWT, role-based route/middleware guards | field_agent / manager / admin |
| Local dev infra | Docker Compose (Postgres only) | No local Postgres install required |
| CI | GitHub Actions | Separate workflows for `app/` and `backend/` |
| Docs | Structured markdown in `/docs`, rendered on GitHub | No build step; ADRs for key decisions |
| Issue tracking | GitHub Issues on `Wandashabba/TradeIQ` | Labeled by phase/capability, created as each stub is written |

## 4. Repo layout

```
TradeIQ/
  app/                     # Flutter — mobile (agent audit flow) + web (manager/admin dashboard)
    lib/
      core/
        theme/             # colors/typography derived from brand deck palette
        router/            # go_router, role-based guards
        network/           # dio client, JWT interceptor
        storage/
          local_db.dart    # Drift — mirrors visit/audit tables locally
          sync_queue.dart  # queued mutations, flushed on connectivity restore
        auth/              # session, secure token storage
      features/
        auth/
        audit/             # S1-S10 flow, one module per section
          s1_outlet_info/
          s2_stock/
          s3_4_visibility_display/
          s5_pricing_promotions/
          s6_competitive/
          s7_capability/
          s8_risks/
          s9_action_plan/
          s10_scorecard/
        tasks/             # agent task list + manager closure/verification
        dashboard/         # manager/admin — 8 KPI tiles, filters
        outlets/           # registry browsing
    test/
  backend/
    prisma/
      schema.prisma
    src/
      modules/
        outlets/ visits/ stock/ visibility/ pricing/ competitive/
        capability/ risks/ tasks/ scorecards/ dashboard/ auth/
      services/
        vision.stub.ts     # branding/planogram/facings/cleanliness — weighted-random
        ocr.stub.ts        # price extraction — manual-entry passthrough
        forecast.service.ts  # coverage-days prediction — REAL simple velocity formula (not a stub)
        fraud.stub.ts       # ghost-visit detection — throws NotImplemented (Phase 2+)
        dispatch.stub.ts    # predictive routing — throws NotImplemented (Phase 2+)
      lib/
        geofence.ts        # haversine distance check
        slaClock.ts        # critical=+24h, high=+3d, normal=+7d
      middleware/
        auth.ts roleGuard.ts errorHandler.ts
    openapi.yaml
    docker-compose.yml     # Postgres only
  docs/
    onboarding/
      getting-started.md  # clone -> running in <10 minutes
      environment-setup.md
    architecture/
      overview.md
      data-model.md
      stubs-and-interfaces.md  # definitive list of what's real vs stubbed, links to issues
    adr/
      0001-flutter-for-mobile-and-web.md
      0002-lean-phase-1-infra.md
      0003-nodejs-express-backend.md
      0004-riverpod-state-management.md
      0005-offline-first-drift-sync.md
      0006-prisma-orm.md
    api/
      (references openapi.yaml)
    superpowers/           # existing — brainstorming/plan artifacts, unchanged
  scripts/
    seed.ts                # realistic FMCG demo data: outlets, SKUs, one client, promo calendar
  .github/
    workflows/
      app-ci.yml            # flutter analyze + flutter test
      backend-ci.yml        # lint + jest (against dockerized Postgres)
    ISSUE_TEMPLATE/
  README.md
  CONTRIBUTING.md
  ONBOARDING.md
```

## 5. Data model

Postgres schema (managed via Prisma), matching the detailed prompt's entities:

`clients`, `users`, `outlets`, `skus`, `planogram_templates`, `promo_calendar`,
`visits`, `visit_stock`, `visit_visibility`, `visit_pricing`,
`visit_competitive`, `visit_capability`, `visit_risks`, `tasks`, `photos`,
`scorecards`.

Key fields/behaviors carried over verbatim from the detailed prompt:
- `clients.scorecard_weights` (jsonb) and `kpi_thresholds` — per-client
  configurable scoring, matching the deck's "Configurable Scoring Engine"
  slide.
- `visits.checkin_ts` is a server-side UTC timestamp, never the device clock.
- `visits.geofence_pass` computed via haversine against the outlet's
  registered lat/lng (≤50m).
- `tasks.sla_due_at` computed from `priority` via `slaClock.ts`
  (critical=+24h, high=+3d, normal=+7d).
- `scorecards.weighted_total` computed server-side from
  `clients.scorecard_weights` × each dimension's score.

Full column-level detail matches the "Data model (Postgres)" section of the
detailed build prompt; this spec does not repeat every column, since
`schema.prisma` becomes the single source of truth once scaffolded.

## 6. Backend architecture

- One module per data-model entity group under `src/modules/*`, each
  exposing routes + controller + service, matching REST resources 1:1 to
  tables (e.g. `visits`, `visit_stock`).
- Stub services live behind narrow interfaces so real implementations can
  swap in later without touching callers, e.g.:

  ```ts
  interface VisionService {
    detectBranding(photoUrl: string): Promise<BrandingResult>;
    scorePlanogramCompliance(photoUrl: string, templateId: string): Promise<number>;
    countFacings(photoUrl: string, skuId: string): Promise<number>;
    scoreCleanliness(photoUrl: string): Promise<number>;
  }
  ```

  `vision.stub.ts` and `ocr.stub.ts` implement these with weighted-random or
  passthrough logic and are clearly commented as stubs. `fraud.stub.ts` and
  `dispatch.stub.ts` throw `NotImplementedError` — they are Phase 2+ features
  with no Phase 1 caller.
- `forecast.service.ts` is **not** a stub — coverage-days prediction from
  stock velocity, SLA due-date computation, and geofence distance are real
  logic per the detailed prompt, and ship working in Phase 1.
- Auth: JWT issued on login, verified via middleware; `roleGuard.ts` restricts
  routes by role (field_agent/manager/admin).
- Errors: centralized `errorHandler.ts` middleware; domain errors (e.g. geofence
  rejection, NotImplemented stub calls) map to appropriate HTTP status codes
  rather than leaking stack traces.

## 7. Flutter app architecture

- `features/audit/s1_outlet_info` … `s10_scorecard`: one feature module per
  audit section, each with its own Riverpod providers/notifiers and a
  repository.
- Repositories write to the local Drift DB first, then enqueue a sync
  mutation; `sync_queue.dart` flushes to the backend when connectivity is
  restored (checked via a connectivity listener in `core/network`).
- The agent's S10 scorecard is computed from local data immediately after
  S1–S9 are captured, so the agent sees their score before leaving the
  outlet, even fully offline; it reconciles with the server-computed score
  once synced.
- `core/theme` derives colors/typography from the pitch deck's dark-navy/blue
  brand palette (exact tokens finalized during scaffold implementation, not
  fixed in this spec).
- `core/router` uses go_router with role-based guards so field agents only
  reach the audit flow and managers/admins only reach the dashboard/task
  screens (unless a role has explicit access to both).

## 8. Documentation and issue-tracking workflow

- `docs/architecture/stubs-and-interfaces.md` is the definitive index of every
  stubbed capability: what it does today, what the real version needs to do,
  and a link to its GitHub issue.
- As each stub file is created during implementation, immediately open a
  GitHub issue on `Wandashabba/TradeIQ` (e.g. "[Phase 2] Replace
  visionService stub with real CV branding/planogram detection"), labeled by
  phase and capability (e.g. `phase-2`, `computer-vision`), linking back to
  the stub file. A comment in the stub file links back to the issue.
- ADRs (`docs/adr/*`) capture the decisions made in this brainstorming session
  (Flutter for mobile+web, lean Phase 1 infra, Node/Express backend,
  Riverpod, Drift offline sync, Prisma) plus any future architecturally
  significant decisions.
- `ONBOARDING.md` (root) plus `docs/onboarding/getting-started.md` describe the
  path from `git clone` to a running app + backend + seeded demo data in
  under 10 minutes, using `docker compose up -d` for Postgres and
  `scripts/seed.ts` for demo data.

## 9. CI and testing

- `.github/workflows/backend-ci.yml`: lint + Jest integration tests against a
  dockerized Postgres (no mocked DB — matches how scoring/SLA logic actually
  breaks), on PRs into `main`.
- `.github/workflows/app-ci.yml`: `flutter analyze` + `flutter test`
  (widget tests per audit-section screen, unit tests for sync-queue and
  scoring logic), on PRs into `main`.

## 10. Execution approach

Once this spec is approved, produce an implementation plan via the
`writing-plans` skill, then execute with parallel subagents split along
independent seams:
1. Repo scaffold, tooling, Docker Compose, CI workflows
2. Prisma schema + backend module skeletons + stub services (+ their
   GitHub issues)
3. Flutter app shell: theme, router, Drift local DB, sync-queue scaffolding
4. Docs: onboarding, architecture, ADRs; `scripts/seed.ts` demo data

Each track is independently reviewable rather than landing as one large
commit.

## 11. Explicitly out of scope for this spec

- Full implementation of S1–S10 screens and business logic (separate spec)
- Manager dashboard KPI screens/queries beyond the module skeleton (separate
  spec)
- Any Phase 2+ feature implementation (real CV/OCR/ML/fraud/dispatch,
  Kafka, PostGIS, territory heatmaps, campaign ROI, API marketplace)
- Deployment/hosting infrastructure (not decided; tracked as a future
  decision, not blocking scaffold work)
