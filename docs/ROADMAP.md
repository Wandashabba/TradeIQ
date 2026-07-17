# TradeIQ Roadmap

TradeIQ is a multi-industry trade-marketing / retail-execution platform. The
product roadmap follows the pitch deck's four phases; this document maps each
phase to its implementation status and the GitHub issues that track it.

Scope authority: `docs/superpowers/specs/2026-07-02-tradeiq-scaffold-design.md`
(§2 reconciles the detailed build prompt with the pitch deck). Real-vs-stubbed
detail: `docs/architecture/stubs-and-interfaces.md`.

## Active — remediation of the 2026-07-17 audit — 🟢 Plan 1 done, 2–4 pending

A full-codebase audit on 2026-07-17 found 2 Critical and ~13 High issues. The
phases below describe what is *built*; this section tracks what must be *fixed*
before Phase 1 can honestly be called shippable. Work is split into four plans
so each produces working, testable software on its own. **Execute in order — the
sequence is by exploitability, not convenience.**

**Plan 1 is complete** on branch `fix/security-critical-audit` (both Criticals +
three Highs closed, 575 tests green, every finding proven end-to-end against the
real app). Not yet merged. Residuals it deliberately left open — token
revocation (H2), the webhook DNS-rebinding TOCTOU, and the structural `omit`
floor — are recorded below and carried into Plan 2. Plans 2–4 are not yet
written.

| # | Plan | Covers | Status |
|---|---|---|---|
| 1 | `docs/superpowers/plans/2026-07-17-security-critical.md` | C3 JWT payload cast → cross-tenant read · H1 published default secret · C1 bcrypt-hash disclosure · H6 webhook SSRF (+H7 timeout) · N8 401-instead-of-404 | ✅ **done** (branch `fix/security-critical-audit`; 575 tests green, proven end-to-end) |
| 2 | `2026-07-17-backend-scale.md` | **backend-only, non-breaking** — H3 zero DB indexes · H5 fraud base64 over-fetch · M9 N+1 (gamification 151 queries, incentives ~500) · dispatch over-fetch · global Prisma `omit` floor · M1 capture paths not agent-scoped · M5 CSV formula injection · N5 kpiMath drift · N9 dead `JWT_SECRET` in `backend-ci.yml` | 🟡 written, not started |
| 2b | `2026-07-17-pagination-uniqueness.md` (not yet written) | **coordinated backend + Flutter** (contract-breaking, split out of Plan 2) — H4 pagination (`?limit`/cursor + `{data,nextCursor}`, every list repository + screen) · M4/N7 per-tenant uniqueness migrations on `Outlet.code` / `User.email` | ⚪ not started |
| 3 | `2026-07-17-flutter-shipblockers.md` (not yet written) | H8 no INTERNET permission in release · H9 debug signing keys · C2 (leak half) clear DB on logout + user-scope the outbox · H10 no 401 handling / no `exp` check · H12 web token key beside ciphertext · M11 no Dio timeouts · M12 `_rememberMe` no-op · M14 `allowBackup` | ⚪ not started |
| 4 | `2026-07-17-design-integration.md` (not yet written) | N1 Inter declared but never bundled · M6 `ink3` 3.48:1 contrast (66 text sites) + crit banner 3.74:1 · M7 raw `$err` via `AsyncSection` (20 screens) · N2 landing video WCAG 2.2 A · N3 error-renders-as-spinner · N4 map pins color-alone · N6 `PrimaryGradientButton` fossil · M10 2.6MB dead asset | ⚪ not started |

**Structural follow-up worth taking — global Prisma `omit`.** Verified working on
the installed Prisma 6.19.3 (GA, no preview flag needed):

```ts
export const prisma = new PrismaClient({ omit: { user: { passwordHash: true } } });
```

Confirmed empirically: `include: { user: true }` then returns without
`passwordHash`, auth's legitimate read still works via `omit: { passwordHash:
false }`, and — critically — forgetting the opt-out is a **compile error**
(TS2339), not a silent `undefined`. Two lines total. This makes C1's whole bug
class structurally impossible rather than relying on every author remembering an
allowlist, and fixes the `dispatch.service.ts:31` over-fetch for free. It is
**not** a replacement for `safeUserSelect`: `omit` only hides the hash, while the
allowlist also withholds `clientId`/GPS. `omit` is the floor; the allowlist is
the deliberate public ceiling.

**Known residual after Plan 1 — webhook SSRF is narrowed, not sealed.** Plan 1
blocks `169.254.169.254`, `localhost`, RFC1918, `[::1]` and every obfuscated
encoding (`new URL()` normalises decimal/octal/hex/IDNA before the guard sees
them), catches pre-existing private URLs at dispatch, kills redirect-to-metadata
via `redirect: 'manual'`, and caps the 300s hang at 5s. Two gaps remain:

1. **DNS rebinding (TOCTOU).** `assertPublicHostname` and `fetch` perform two
   *independent* resolutions, so an attacker with authoritative DNS and TTL=0
   flips the answer between check and connect. Proven end-to-end against the
   real `urlGuard` during review: the guard passed on `93.184.216.34` while the
   fetch returned attacker content. Re-resolving closes *registration→fire*
   drift, not *check→connect* drift. **Fix:** an undici `Agent` with a custom
   `connect.lookup` that runs `isPrivateAddress` on the address actually handed
   to the socket, so validation and connection share one resolution. Needs
   `undici` as a direct dependency — a deliberate decision, hence deferred. Do
   NOT hand-roll a substitute: resolving then fetching the raw IP breaks TLS SNI
   and certificate validation for https.
2. `::7f00:1` (IPv4-compatible IPv6) classifies as public. Deprecated and
   verified `EHOSTUNREACH` in practice; left alone deliberately.

Exploiting either requires a manager/admin role, so this is a real but
materially harder attack than the one Plan 1 closed.

**Other small items logged during Plan 1:**
- `dispatch.service.ts:31` — `findMany` with no `select` loads `passwordHash`
  into memory. Projected into `DispatchCandidate` before serializing, so it is
  an over-fetch, **not** a disclosure. Low priority; global `omit` fixes it.
- `territories.routes.ts:44` — `GET /territories` has no `requireRole`. Returns
  no user data, so not a leak, but it is inconsistent with the rest of that
  router now that `/coverage` is gated.

**Trap discovered during Plan 1 — read before touching roles.** There are three
declarations of the role union: `ROLES` in `auth.service.ts` (now the source of
truth for `AuthTokenPayload['role']`), the Prisma `UserRole` enum, and a
hand-written literal union in `middleware/roleGuard.ts:4`. Drift is currently
closed in both directions, but by two *different* mechanisms: the Prisma link
catches a **removed** role (via `auth.routes.ts:20` feeding `UserRole` into
`issueToken`), while an **added** role is caught only incidentally by
`roleGuard.ts:4`. Retyping `roleGuard.ts:4` as `AuthTokenPayload['role']` — the
obvious-looking cleanup — silently removes the add-direction guard. Consolidate
deliberately, with a test, or not at all.

**Testing constraint — verify with `npx jest --runInBand`, not `npm test`.**

The suite reports mass phantom failures at default parallelism on a loaded
machine, and they look exactly like real regressions. They are not. Measured on
byte-identical code:

| Command | Result |
|---|---|
| `npm test` (default ~7 workers, host load ~30) | 366 failed, then 74 failed |
| `npx jest --maxWorkers=2` | 1 failed (a phantom 400 from a truncated request body) |
| **`npx jest --runInBand`** | **513 passed, 54 suites, 45s** |

Serialized is both deterministic *and* fastest here — parallel runs took 876s
while failing. Two independent causes, both real:

1. **Resource starvation (dominant).** `tradeiq-postgres-1` shares a ~3.8 GiB /
   8-vCPU Docker VM with an unrelated 10-container Supabase stack. Jest's
   default worker count starves it: failures are `Exceeded timeout of 20000 ms`,
   `Can't reach database server`, and HTTP-level `Parse Error` / truncated
   bodies surfacing as bogus 400s. Zero are assertion failures.
2. **Cross-run truncation.** `jest.global-setup.ts` runs `TRUNCATE TABLE ...
   RESTART IDENTITY CASCADE` across every table on *every* invocation against
   one shared `tradeiq_test` DB. Two concurrent runs — or a stray `ts-node-dev`
   from a manual boot check — wipe each other's fixtures mid-flight, giving
   bogus 404s and a different failure set each time.

Never run two test processes at once, and treat a suspicious mass failure as
environmental until reproduced with `--runInBand`. Adding `maxWorkers` to
`jest.config.js` is worth considering, but CI's runner is not this machine —
decide it deliberately rather than pinning a laptop's constraint into CI.

`--runInBand` removes parallel contention but **is not immune** to the starved
VM: one serialized run still failed `trends.routes.test.ts` with `Can't reach
database server at localhost:5432` ×26, while `tradeiq-postgres-1` showed
`RestartCount=0`, stayed `healthy`, and was reachable immediately after — a
transient Docker Desktop port-forwarding stall, not a crash. A `Can't reach
database server` failure on this box should be re-run before being believed.
The real fix is host-side: stop the unrelated Supabase stack, or give Docker
more headroom.

**Deferred with a reason — not forgotten:**

- **H2 — no token revocation.** A valid JWT for a deactivated or demoted user
  keeps working for up to 12h; `requireAuth` never re-checks the DB. The fix
  needs a lookup in `requireAuth`, which turns the fabricated-userId tokens in
  19 test files into 401s — including the 16 cross-tenant tests that rely on
  `clientId: 'no-such-client'`. Multi-day change; own plan. **This is the
  largest auth gap remaining after Plan 1.**
- **H11 photos → object storage** — already tracked as #65 (ADR 0007 commits to
  it). Independently urgent: `tasks.service.ts:98` matches on the base64 `url`
  column, which is unindexable (btree caps ~2704 bytes), so closing one task
  seq-scans every photo. Needs the breaking `closurePhotoUrl → closurePhotoId`
  API change regardless of storage.
- **Durable webhook outbox** — related to #62. Plan 1 adds the 5s timeout that
  caps the 300s hang; the retry/outbox half stays ticketed.
- **C2 (encryption half) — SQLCipher at rest for the Drift DB.** Not yet
  ticketed. The offline DB holds GPS trails and base64 shelf photos in plain
  SQLite. Plan 3 closes the *leak* half (clear on logout, user-scope the
  outbox); encryption at rest needs its own ticket.

## Phase 1 — Foundation (months 1-3) — ✅ implemented

The field-agent offline-first audit app + manager dashboard, on lean infra
(plain Postgres + haversine, no Kafka/PostGIS/Redis).

| Capability | Status |
|---|---|
| Auth (JWT, bcrypt, rate-limited login, RBAC route guards) | ⚠️ built, but **not shippable** — the 2026-07-17 audit found the JWT payload is cast not validated (cross-tenant read), the default secret is published, and there is no revocation. See "Active — remediation" above. |
| Outlet registry + create + haversine geofence check-in | ✅ |
| S1-S10 audit capture (offline-first Drift + sync queue) | ✅ |
| S2 stock (coverage-days, server-derived — see note below), S3-4 visibility (vision-stub wired), S5 pricing (OCR-stub wired) | ✅ |
| S6 competitive, S7 capability, S8 risks (auto-creates SLA tasks) | ✅ |
| S9 task lifecycle (create / list / PATCH close / verify) | ✅ |
| S10 scorecard (local on-device + server-authoritative, per-client weights/thresholds) | ✅ (submit→scoring wiring fixed by #117 — see note below) |
| Manager dashboard — 8 KPIs (`GET /dashboard`, filterable server-side) + `GET /dashboard/by-territory` | ✅ (territory-filter bug fixed by #97 — see note below) |
| Photo pipeline (`POST /photos`) + photo-verified task closure | ✅ (base64/Postgres, ADR 0007) |
| Real camera capture — closure + S3-S4/S5 section photos (#41) | ✅ (offline-first via the sync outbox) |
| Manager-facing GET listings for every section + `GET /visits` | ✅ |
| Per-row `createdAt` timestamps + measured check-in distance | ✅ |
| Field-agent UX polish — Today screen, submit gate, outcome screen, motion/haptics (#110/#113/#116/#117) | ✅ |
| Seed: client/users/outlets/SKUs/planograms/promos/demo visits+scorecards+tasks+**admin** | ✅ |
| Migrations, docker-compose (Postgres), isolated test DB (#109), CI (app + backend) | ✅ |

**Phase-1 follow-ups — all closed:** admin clients-config (#46), admin user
provisioning + deactivation (#42), auto-tasks from stockouts/price-deviations
(#47), per-route role guards (#43), dashboard filter UI (#48), and **real
in-app camera capture (#41)** — task closure and the S3–S4 / S5 sections now
capture genuine photos (offline-first, via the sync outbox). Closed
audit-section issues: #8-#16; login #5.

**Three "claimed fully wired, actually wasn't" gaps found and closed since
the last audit (2026-07-13 → 2026-07-16):**

- **Admin role was unreachable in practice (#118, closed).** `requireRole('admin')`
  and every admin-gated route (`POST /users`, `PATCH /clients/me`, etc.) existed
  in code, but no admin user could ever exist — the seed only created a manager
  and a field agent, there is no public registration, and minting a new admin
  requires an existing admin. Fixed: seed now creates a demo admin, and
  `backend/scripts/create-admin.ts` adds a deliberately-CLI-only bootstrap path
  for real deployments.
- **Visit submission didn't reliably trigger scoring (#117, part of the
  agent-screens work, closed).** Server-authoritative scoring only ran if the
  agent happened to open S10 and tap Finalize — most submitted visits were
  never scored. Fixed by queuing scoring on submit; also added
  `GET /scorecards/history?outletId=` since agents previously couldn't read
  their own score history (that route was manager-only).
- **Territory filtering silently returned zeroed KPIs (#97, closed
  2026-07-16).** `Outlet.territoryId` stores `Territory.code`, not
  `Territory.id`, but both the dashboard's territory dropdown and the
  by-territory chart filtered on `id` — every real territory filter matched
  nothing and degraded to all-zero KPIs rather than erroring, so the bug was
  invisible. Fixed alongside adding `GET /dashboard/by-territory` (closes the
  N+1 of calling `GET /dashboard` once per territory).
- **S2 stock form asked agents for four numbers they cannot observe (#112,
  closed 2026-07-16).** `daysOutOfStock` and `velocityAvg` are now computed
  server-side from `VisitStock` history and stamped on write — there is no
  longer a client-writable path for either, closing the risk of a guessed
  `velocityAvg` silently propagating into `coverageDaysPredicted`.
  `salesActual`/`salesTarget` were removed from the form entirely rather than
  given a fake source, since no sell-through/quota data exists anywhere in the
  system (tracked separately, see #119).

Two things that capture unblocks, and one trap it exposed:

- The photos are the **corpus Phase-2 CV/OCR (#1, #2) need**. Before this, the
  app uploaded a 1×1 transparent PNG, so "photo-verified closure" verified
  nothing and no training data existed.
- Section photos are stored via `POST /photos` but are deliberately **not**
  passed as `photoUrl` on `POST /visibility`. That is not an oversight:
  `visibility.service.ts` treats a non-empty `photoUrl` as the CV seam and
  *overwrites* the agent's measured planogram %, facings and cleanliness with
  `vision.stub.ts` — which is `Math.random()`. Wiring the photo through would
  silently replace real field data with noise that feeds the scorecard and the
  dashboard. Connect it only when the stub is a real model.
- `kpiThresholds` had a **key mismatch**: the seed wrote
  `excellent`/`good`/`needsImprovement`, but the engine reads
  `green`/`amber`/`stockoutUnits`/`priceDeviationPct`. The seeded bands were
  inert and the RAG scores silently fell back to their defaults. Fixed, and the
  config screen now edits exactly the four keys that are actually read.

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

> **Read this before trusting a ✅ below.** An audit of the tickets against the
> code (2026-07-13, refreshed 2026-07-16) found that "backend ✅" had been
> claiming more than the code does. Each capability's *CRUD* is real; the
> *analytics* each ticket is named for is, in several cases, absent from the
> backend as well as the app. Those are now marked 🔴 rather than ✅, because
> "no app UI yet" and "the endpoint does not exist" are very different kinds
> of missing. The 2026-07-16 refresh found one capability that moved the other
> way — template-response persistence (#32, item 4 below) shipped since the
> last audit and is now genuinely done, narrowing what had looked like one
> big gap into a smaller, more specific one (#122).

**Tier 1:**
1. Trade Promotion & Campaign Management (#29) — ✅ backend CRUD + audit-derived
   compliance; app UI ✅. **🔴 ROI is not built** (#94) — `Campaign.budget` is
   stored and read by nothing, and `Order` has no `campaignId`, so spend cannot
   be attributed to a campaign at all.
2. Journey / Beat planning & visit scheduling (#30) — ✅ backend, ✅ manager app UI.
   **🔴 No recurrence** (#98): a `BeatPlan` has a single `scheduledDate`, so
   these are one-off dated plans, not permanent journey plans. **🔴 No
   field-agent route screen** (#52) — agents see the manager list behind a
   role gate.
3. Rules-based alerting & exception evaluation (#31) — ✅ backend (auto-evaluates
   on visit submit), ✅ alerts inbox, ✅ rules-management UI. Push/email delivery
   is Phase 4 (#67); in-app + outbound webhook only.
4. Configurable audit/survey template builder (#32) — ✅ backend store/serve,
   ✅ schema renderer, **and ✅ response persistence** (`modules/templateResponses`,
   `POST/GET /template-responses`, added 2026-07-13 — this used to be a gap,
   it no longer is). **🔴 No builder** (#54 — the app can list and preview
   templates, not author them) and **🔴 nothing calls the persistence
   endpoint** (#122) — the S1–S10 audit flow is still hard-coded, so selecting
   a template still has zero effect on what the agent sees or where answers go.
5. Trend analytics (#33) — ✅ scorecards / availability / perfect-store series,
   ✅ charts in-app. **🔴 No campaign-ROI trend** (#94), **🔴 no share-of-shelf
   trend** (#95), **🔴 no benchmark comparison** (#123) — those endpoints do
   not exist.

**Tier 2:**
6. Gamification & incentives (#34) — ✅ leaderboard (computed on the fly) and
   reward schemes, ✅ app UIs. **🔴 No badges, contests, or persisted points
   model, and retailer/trade loyalty is absent** (#124) — incentives reward
   *agents* only, not the retailers the pitch names.
7. Territory management & coverage (#35) — ✅ CRUD, agent assignment, app UI.
   **🔴 No heatmap and no coverage rate** (#96): `/territories/:id/coverage`
   returns outlet and agent *lists*, and `Outlet.lat/lng` is not used for any
   geographic analytics. App UI: #54.
8. In-store order-taking / sell-in capture (#36) — ✅ backend + app UI.
   **🔴 No campaign attribution** (`Order` has no `campaignId` — tracked under
   #94, the same root cause as campaign ROI) and **🔴 no promo pricing** (#99
   — `unitPrice` is hand-entered; `PromoCalendar` is never consulted).
9. In-app messaging & announcements (#37) — ✅ backend, ✅ messages + announcements
   UI. **🔴 No attachments** (#125).
10. Integrations & webhooks (#38) — ✅ `modules/webhooks`, firing on
    visit.submitted / order.created / alert.raised, ✅ **HMAC-SHA256 signed**
    (`X-TradeIQ-Signature`, timestamp signed with the body to block replay).
    **🔴 No retry and no queue** (#100) — a subscriber that is down misses the
    event; a durable outbox is Phase 4. **🔴 No ERP/POS/CRM connectors** (#126
    — needs a named vendor target before any code, not buildable generically).
11. Report builder + scheduling (#39) — ✅ report definitions + on-demand
    generate. **🔴 Export is JSON-only, no CSV/PDF/Excel, no schedules UI**
    (#103). **🔴 Scheduling does not fire**: there is no cron/scheduler
    anywhere, so `ReportSchedule.cadence` is stored and ignored, and delivery is
    a documented no-op (`deliveredTo` merely echoes the recipients). Phase 4 (#66).
12. Multi-language localization (#40) — 🔴 not started: no `.arb` files, no
    `intl`/`flutter_localizations` dependency, every string a hard-coded literal.

Sequencing note: #35 (territories) underpins #30 (beat planning); #29→#33/#94
(campaign → ROI) is the tightest activation feedback loop — and it is the one
that is **not built on either side**, so it is the highest-value Phase-3 gap.

**Dead models:** `PlanogramTemplate` and `PromoCalendar` are in the schema and
seeded, but no module, route or service reads them.

## Phase 4 — Scale & Optimise (months 10-12) — 🟣 ticketed

Scale, enterprise, and optimisation on top of the Phase 1-3 foundation:
1. Multi-tenant admin & white-labeling at scale (#58)
2. Self-serve API marketplace & partner integrations (#59)
3. Trade-spend / deduction management & multi-currency finance (#60)
4. ML route optimisation & next-best-action (#61)
5. Event streaming backbone — Kafka (#62)
6. PostGIS spatial engine — territory polygons, spatial dispatch, heatmaps (#63)
7. Redis caching & soft-reserve (#64)
8. Object storage + CDN for photos — migrate off base64/Postgres, ADR 0007 (#65)
9. Scheduled report delivery infra — cron + email/webhook (#66)
10. Push notifications for alerts & messaging — FCM/APNs (#67)
11. Enterprise auth (SSO/SAML), audit logging & compliance (#68)
