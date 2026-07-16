# Phase 3 — Activation (backend)

The Tier-1 activation backend turns captured audit data into field action and
business outcomes. All endpoints are tenant-scoped to the caller's `clientId`
and role-guarded; all live under the Bearer-JWT middleware. Models are defined
in `backend/prisma/schema.prisma` (migration `20260709130000_phase3_activation`).

Status: **backend implemented**. The app UIs for these features and the Tier-2
features are tracked as issues — see `docs/ROADMAP.md`.

## Territories (issue #35) — `backend/src/modules/territories`

Models: `Territory` (`code` mirrors the free-text `Outlet.territoryId`),
`UserTerritory` (agent↔territory).

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/territories` | manager/admin | Create a territory (409 on duplicate code) |
| GET | `/territories` | any | List the client's territories |
| POST | `/territories/:id/agents` | manager/admin | Assign an agent to a territory |
| GET | `/territories/:id/coverage` | any | Outlets (by matching `territoryId`) + assigned agents |

Enables beat planning (#30) and the Phase-2 dispatch data gap (#45).

## Campaigns / Trade Promotion Management (issue #29) — `campaigns`

Models: `Campaign`, `CampaignOutlet`. Builds on `PromoCalendar`.

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/campaigns` | manager/admin | Create a campaign + assign outlets |
| GET | `/campaigns` | any | List (with outlet counts) |
| GET | `/campaigns/:id` | any | Campaign + its outlets |
| PATCH | `/campaigns/:id` | manager/admin | Update status/fields |
| GET | `/campaigns/:id/compliance` | manager/admin | Audit-derived rollup over the campaign window |

Compliance rollup (zero-safe, over submitted visits at the campaign's outlets
within `[startDate,endDate]`): outlet visit-coverage rate, avg planogram
compliance, avg absolute price deviation, and promo-compliance rate.

## Beat plans / journey planning (issue #30) — `beatplans`

Models: `BeatPlan`, `BeatPlanStop`. Depends on Territories.

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/beatplans` | manager/admin | Create a plan with sequenced outlet stops |
| GET | `/beatplans` | any (agent sees own) | List, filter by agent/status |
| GET | `/beatplans/:id` | any (agent own-only) | Plan + stops + adherence |
| PATCH | `/beatplans/:id/stops/:stopId` | agent/manager | Mark a stop visited |
| PATCH | `/beatplans/:id` | manager/admin | Update plan status |

Adherence = visited stops / total stops.

## Alerting (issue #31) — `alerts`

Models: `AlertRule`, `Alert`. Metrics: `out_of_stock`, `price_deviation`,
`low_scorecard`.

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/alerts/rules` | manager/admin | Create a rule |
| GET | `/alerts/rules` | any | List rules |
| PATCH | `/alerts/rules/:id` | manager/admin | Toggle active / threshold |
| POST | `/alerts/evaluate` | manager/admin | Evaluate a visit's data against active rules → Alerts |
| GET | `/alerts` | any | List alerts (filter acknowledged/severity) |
| PATCH | `/alerts/:id/ack` | manager/admin | Acknowledge |

Phase-1-friendly synchronous evaluation. Event-driven streaming (Kafka) is
Phase 4.

## Audit template builder (issue #32) — `templates`

Model: `AuditTemplate` (versioned; `schema` is a free-form dynamic-form JSON
definition — sections/fields/conditions/scoring). Backend stores/serves it;
rendering + validation of the form is an app concern.

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/templates` | manager/admin | Create (version 1) |
| GET | `/templates` | any | List active (`?includeInactive=true` for all) |
| GET | `/templates/:id` | any | Fetch one |
| PATCH | `/templates/:id` | manager/admin | Update; a `schema` change bumps `version` |

### Response persistence — `templateResponses` (added 2026-07-13)

A `VisitTemplateResponse` model (`backend/prisma/migrations/20260713090000_visit_template_responses`)
persists an agent's answers to a template, keyed by `(visitId, templateId)`
and upserted so re-submitting the same template for the same visit is
idempotent. The service validates both the visit and the template belong to
the caller's tenant before writing.

| Method | Path | Role | Purpose |
|---|---|---|---|
| POST | `/template-responses` | field_agent | Upsert `answers` for a `(visitId, templateId)` pair |
| GET | `/template-responses` | any | Fetch one, by `visitId` + `templateId` query params |

**This closes the "responses are not persisted" half of #32.** The half that
remains open (#122): nothing in the app calls this endpoint, and nothing in
`visits.routes.ts`/`visits.service.ts` connects a *selected* template to the
S1–S10 audit flow the agent actually walks through — persistence exists, but
has no caller yet, and the flow itself is still the hard-coded S1–S10 screens
regardless of which template (if any) is associated with the visit.

## Trend analytics (issue #33) — `trends`

Time series bucketed by `day` or `week` over the per-row `createdAt`
timestamps. All manager/admin, client-scoped, zero-safe. Params: `from`, `to`,
`interval`.

| Path | Value |
|---|---|
| `GET /trends/scorecards` | mean scorecard `weightedTotal` per bucket |
| `GET /trends/availability` | on-shelf-availability % per bucket |
| `GET /trends/perfect-store` | % of green scorecards per bucket |

Predictive/ML analytics is Phase 4.
