# TradeIQ Roadmap

TradeIQ is a multi-industry trade-marketing / retail-execution platform. The
product roadmap follows the pitch deck's four phases; this document maps each
phase to its implementation status and the GitHub issues that track it.

Scope authority: `docs/superpowers/specs/2026-07-02-tradeiq-scaffold-design.md`
(§2 reconciles the detailed build prompt with the pitch deck). Real-vs-stubbed
detail: `docs/architecture/stubs-and-interfaces.md`.

## Audit remediation (2026-07-17) — ✅ COMPLETE, all plans merged

A full-codebase audit on 2026-07-17 found 2 Critical and ~13 High issues. The
phases below describe what is *built*; this section tracks what must be *fixed*
before Phase 1 can honestly be called shippable. Work is split into four plans
so each produces working, testable software on its own. **Execute in order — the
sequence is by exploitability, not convenience.**

**Plans 1 and 2 are merged.** Plan 1 closed both Criticals + three Highs (JWT
payload cast, published default secret, bcrypt-hash disclosure, webhook SSRF,
401-vs-404), proven end-to-end. Plan 2 closed the scale and correctness set (34
DB indexes, two N+1 rewrites, agent-scoped capture writes, CSV formula
injection, kpiMath drift). **Every residual they left open has since been
closed** — token revocation (#142), the webhook DNS-rebinding TOCTOU (#143),
and the small cleanups (#145). The entries below are kept as the record of what
was decided and why, not as outstanding work.

**Plans 3 and 4 have since merged.** Plan 3 closed every Flutter ship-blocker
(#137 release build, #138 offline-DB encryption, #139 session handling, #140
client hardening); Plan 4 closed the design/a11y integration (#144). The
release build that "could not ship at all" now can.

**Plan 2b (#141) closed 2026-07-30.** `Outlet.code` per-tenant uniqueness
shipped in PR #173. The pagination sweep finished in PRs #189–#192 (14
endpoints), #235 (the five tenant-wide lists — `/visits`, `/scorecards`,
`/scorecards/history`, `/fraud/attempts`, `/report-schedules`) and #237 (the
seven visit-scoped lists, plus the `agents` envelope-key rename that removed
the app's last `PaginatedResponse` special case). `User.email` was split out to
**#188**, because per-tenant email uniqueness needs a login-identity decision
rather than a migration. #153's T1 tier is no longer gated.

**One list endpoint is deliberately NOT paginated** (→ **#236**).
`GET /fraud/flagged` filters and sorts by a *computed* risk score, so there is
no column to key a cursor on. Its real exposure is the input scan —
`findMany` over every submitted visit **with photo bytes included** — not the
response size, so a cursor on the output would look like progress while
leaving the risk untouched. It needs a persisted score column or a bounded
window, which is a design decision, not a mechanical conversion.

**Two endpoints the pagination issue mislabelled as backend-only** were caught
by checking the Flutter client rather than trusting the ticket:
`/scorecards/history` (the agent's post-visit score delta) and `/photos` (the
manager's evidence dialog) both parsed `response.data as List`. Converting
either server-side alone would have broken the app at runtime — precisely the
silent contract break the sweep exists to prevent. Both moved with their
callers. **When converting a list endpoint, grep the Flutter app for it; do
not trust a "backend-only" label.**

**Separate workstream — premium UI** (not audit remediation): the dual light/dark
theme system (spec §1–3) is merged; motion & polish (spec §4–5) is **also
merged** (PR #136, 2026-07-18) — shared-axis manager transitions, drawer scrim
and staggered nav, elevation, hover/pressed/focus states. 395 app tests green.
See `docs/superpowers/specs/2026-07-17-premium-ui-theme-motion-design.md`.

| # | Plan | Covers | Status |
|---|---|---|---|
| 1 | `docs/superpowers/plans/2026-07-17-security-critical.md` | C3 JWT payload cast → cross-tenant read · H1 published default secret · C1 bcrypt-hash disclosure · H6 webhook SSRF (+H7 timeout) · N8 401-instead-of-404 | ✅ **done** (branch `fix/security-critical-audit`; 575 tests green, proven end-to-end) |
| 2 | `2026-07-17-backend-scale.md` | **backend-only, non-breaking** — H3 zero DB indexes · H5 fraud base64 over-fetch · M9 N+1 (gamification 151 queries, incentives ~500) · dispatch over-fetch · global Prisma `omit` floor · M1 capture paths not agent-scoped · M5 CSV formula injection · N5 kpiMath drift · N9 dead `JWT_SECRET` in `backend-ci.yml` | ✅ **done** — Tasks 1–7 merged via PR #130; Tasks 8–11 (CSV, kpiMath, CI, docs) in follow-up branch `fix/plan2-remainder` |
| 2b | **#141** | **coordinated backend + Flutter** (contract-breaking, split out of Plan 2) — H4 pagination (`?limit`/cursor + `{data,nextCursor}`, every list repository + screen) · M4/N7 per-tenant uniqueness migrations on `Outlet.code` / `User.email` | ✅ **done** — `Outlet.code` (PR #173); pagination PRs #189–#192, #235, #237. `User.email` → #188; `/fraud/flagged` → #236 |
| 3 | **#137 #138 #139 #140** | Flutter ship-blockers & client security — **#137 (CRITICAL)** H8 no INTERNET permission in release + H9 debug signing keys · **#138** C2 offline DB unencrypted/never cleared/outbox not user-scoped · **#139** H10 no 401 handling or `exp` check + H12 web token key beside ciphertext + M12 `_rememberMe` no-op · **#140** M11 no Dio timeouts + M14 `allowBackup` + M15 volatile web DB | ✅ **done** — all four closed |
| 4 | **#144** | N1 Inter declared but never bundled · M6 `ink3` 3.48:1 contrast (66 text sites) + crit banner 3.74:1 · M7 raw `$err` via `AsyncSection` (20 screens) · N2 landing video WCAG 2.2 A · N3 error-renders-as-spinner · N4 map pins color-alone · N6 `PrimaryGradientButton` fossil · M10 2.6MB dead asset | ✅ **done** — closed |

**Shipped — global Prisma `omit`.** Live in `backend/src/lib/prisma.ts:7`. Kept
here because the reasoning is worth preserving, not because it is outstanding.
Verified working on the installed Prisma 6.19.3 (GA, no preview flag needed):

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

**Webhook SSRF — ✅ sealed** (**#143**, closed). Plan 1 blocked
`169.254.169.254`, `localhost`, RFC1918, `[::1]` and every obfuscated encoding
(`new URL()` normalises decimal/octal/hex/IDNA before the guard sees them),
caught pre-existing private URLs at dispatch, killed redirect-to-metadata via
`redirect: 'manual'`, and capped the 300s hang at 5s. The DNS-rebinding gap it
left open is now closed too:

- **DNS rebinding (TOCTOU) — fixed** in `backend/src/lib/ssrfAgent.ts`.
  `assertPublicHostname` and `fetch` used to perform two *independent*
  resolutions, so an attacker with authoritative DNS and TTL=0 could flip the
  answer between check and connect. `createGuardedLookup` now runs
  `isPrivateAddress` inside undici's `connect.lookup`, so validation and
  connection share one resolution and the socket cannot be handed an address
  that was never checked. `webhooks.service.ts` passes `ssrfSafeAgent` as the
  `dispatcher` and imports `fetch` from `undici` rather than the global — the
  global silently drops `dispatcher`, which would have left rebinding open
  while the code read as though it were closed. Covered by `ssrfAgent.test.ts`.
  The pre-check in `webhooks.service.ts` is deliberately kept: it fails a bad
  host before a connection is attempted and gives a clearer error.
- `::7f00:1` (IPv4-compatible IPv6) still classifies as public. Deprecated and
  verified `EHOSTUNREACH` in practice; left alone deliberately.

**Small items logged during Plan 1 — ✅ all closed** (**#145**):
- `dispatch.service.ts` — the `findMany` that loaded `passwordHash` into memory
  now carries an explicit `select`, and the global Prisma `omit` in
  `lib/prisma.ts` is the floor underneath it.
- `territories.routes.ts` — `GET /territories` is now
  `requireRole('manager', 'admin')`, matching the rest of that router. No agent
  flow loses anything: both app callers are manager/admin actions at the write
  end.
- **The role-union triplication is consolidated.** `roleGuard.ts` now imports
  the shared `Role` from `auth.service.ts` instead of restating the union as a
  literal. That restatement was the only thing catching a role *added* to
  `ROLES` but not to Prisma — an accident, not a design, and the reason this
  cleanup was flagged as a trap. `auth.service.ts` now carries a mutual
  compile-time assignability assertion between `ROLES` and Prisma's `UserRole`,
  which guards both directions deliberately, so sharing the type is safe.

**Running the Flutter app on macOS desktop — no Apple account needed.**

`flutter run -d macos` signs ad-hoc (`CODE_SIGN_IDENTITY = "-"`). The
data-protection keychain that `flutter_secure_storage` uses by default
requires a signed `application-identifier`, so every keychain write returned
`errSecMissingEntitlement (-34018)` — including the one that generates the
local database's encryption key. The database therefore never opened and a
check-in could not save anything, from 2026-07-21 (when encryption landed)
until 2026-07-30.

Fixed by pinning macOS to the file-based keychain in
`app/lib/core/storage/secure_storage.dart` — one `appSecureStorage` that every
secret-holder shares. **Do not construct `FlutterSecureStorage()` inline**; a
test asserts nothing does, because an inline one silently takes the failing
default back and fails only on macOS, only at runtime.

Two remedies were measured and rejected: declaring `keychain-access-groups`
(what the plugin's README asks for) makes the build fail without a development
certificate, and dropping the app sandbox does not help — the data-protection
keychain wants a signing identity, not a sandbox exception. The entitlements
files are therefore untouched.

Related: **#159** — iOS has never been built, and there are currently *zero*
code-signing identities installed on the development machine.

**Testing — `npx jest --maxWorkers=4` locally; CI runs `--runInBand`.**

The two commands differ on purpose, and the difference is about the *machine*,
not the code. Two separate causes of parallel-run flakiness have been fixed, so
parallel is now *correct* — but CI's shared runner is small enough that four
workers still exhaust the Prisma connection pool (#181), which surfaces as a
wall of unrelated suite failures. So `.github/workflows/backend-ci.yml` runs
serially by choice. **Do not "fix" CI back to parallel** on the strength of the
two fixes below; they make parallel safe on a developer machine, not on a
2-core runner.

The `--runInBand` advice further down is kept only as the history of why:

1. **Shared test database** (#186, PR #228). Every worker now gets its own
   database, so `jest.global-setup.ts`'s TRUNCATE can no longer wipe another
   worker's fixtures mid-flight.
2. **Supertest socket churn** (#227). `request(app)` handed supertest an
   express *function*, which it wrapped in a fresh `http.Server` and bound an
   ephemeral port for — **per HTTP request**, then closed it again
   (`supertest/lib/test.js`: `if (!addr) this._server = app.listen(0)`). Ports
   linger in TIME_WAIT, and at thousands of bind/close cycles per run one gets
   rebound while a previous connection is still draining, crossing a response
   into the wrong client. The proof was an `errorHandler` test whose only route
   throws — no path through it can produce a 400 — receiving a 400. Route tests
   now import `httpServer` from `src/testHttpServer.ts`, a server that is
   already listening, so supertest reuses one socket per file instead of
   binding one per request.

   **If you write a new route test, import `httpServer as app` from
   `src/testHttpServer.ts` — not `app` from `src/app.ts`.**

Still true regardless: **never run two jest processes at once**, and this
laptop's Docker VM shares memory with an unrelated Supabase stack, so a
`Can't reach database server` failure here should be re-run before it is
believed.

<details>
<summary>Historical — the original --runInBand guidance (superseded)</summary>

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

</details>

**Deferred with a reason — not forgotten:**

- ~~**H2 — no token revocation**~~ (→ **#142**) — ✅ **shipped**. A valid JWT for
  a deactivated or demoted user used to keep working for up to 12h because
  `requireAuth` never re-checked the DB. It does now (`middleware/auth.ts`):
  one indexed primary-key read per request, checking `active`, `role` **and**
  `clientId` against the token's claims — the tenant is re-checked because it
  is the blast radius of every query built from that payload. Every mismatch
  returns the same 401, so a stale token cannot distinguish "deactivated" from
  "demoted" from "deleted". A DB failure is a 500, never a pass-through. The
  test-fixture churn this was deferred for (19 files minting fabricated
  userIds, 16 of them relying on `clientId: 'no-such-client'`) was absorbed
  along with it.
- **H11 photos → object storage** — already tracked as #65 (ADR 0007 commits to
  it). Independently urgent: `tasks.service.ts:98` matches on the base64 `url`
  column, which is unindexable (btree caps ~2704 bytes), so closing one task
  seq-scans every photo. Needs the breaking `closurePhotoUrl → closurePhotoId`
  API change regardless of storage.
- **Durable webhook outbox** — related to #62. Plan 1 adds the 5s timeout that
  caps the 300s hang; the retry/outbox half stays ticketed.
- ~~**C2 (encryption half) — SQLCipher at rest for the Drift DB** (→ **#138**)~~
  — ✅ **shipped**, listed here only so the history reads straight. The offline
  DB holds GPS trails and base64 shelf photos, and both halves of #138 are now
  done: the *leak* half (clear on logout, user-scope the outbox) and encryption
  at rest. `pubspec.yaml` overrides `sqlite3` to the `sqlcipher` source,
  `local_db_connection_native.dart` applies `PRAGMA key` and then **verifies**
  `PRAGMA cipher_version` rather than assuming it took, and `db_key.dart` keeps
  the 256-bit key in the platform keychain — never beside the file it encrypts.
  An existing plaintext database is migrated via `sqlcipher_export`.

## Conversational TradeIQ (2026-08-02) — 🚧 Phase 0 built, gate unmeasured

A cross-cutting interface initiative, orthogonal to the product phases below:
replace the 21-destination manager sidebar with a conversation. The manager
prompts or speaks; one orchestrator resolves their role, calls the existing
service layer through a role-scoped tool roster, and answers with narrative plus
the charts the dashboard already renders. Voice both directions; write actions
behind a risk gate; interactive, filterable, PDF-exportable artifacts.

- **Plan:** `docs/superpowers/plans/2026-08-02-conversational-tradeiq.md`
- **Spec:** `docs/superpowers/specs/2026-08-02-conversational-tradeiq-design.md`
- **Live status:** `STATUS.md` at the repo root

Six phases: read-only spine → voice → artifacts → actions → shrink the console →
memory and digests.

**Phase 0 is built end to end** — backend and app — across PRs #264 and #265,
green on CI. It is **not complete**: its exit gate is ≥90% tool-selection
accuracy, and that has never been measured, because no provider key exists in
this environment. Everything in the branch is tested against a scripted model.
Phases 1–5 are not started.

> **Correction (2026-08-07):** this section said *"Nothing is implemented yet."*
> That was true when written and is not now. `STATUS.md` is the live tracker —
> prefer it over this paragraph, which will go stale again.

> ⚠️ **Conflict with Phase 4 item 4 (#61, "ML route optimisation").** The
> 2026-07-29 practitioner interview ruled this out explicitly — *"you don't want
> to be a fleet management tool. There's fleet management companies that deal
> with your FMCGs."* Route planning is a solved, competitive market. #61 should
> be re-scoped to "next-best-action" only, or closed, before anyone builds it.

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
| Seed: realistic demo dataset — 3 territories, 31 outlets, 9 users, 20 SKUs, 12 weeks of visit history (342 visits), tasks/alerts/incentives, comms, orders, and a home-base outlet for live geofence check-in | ✅ |
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
   ✅ charts in-app, **✅ share-of-shelf** (`GET /trends/share-of-shelf`, closed
   by #95 on 2026-07-16 — bucketed day/week like its siblings, and `round2`/
   `pct`/`mean`/`facingsTotal` now live once in `lib/kpiMath.ts` so the
   dashboard KPI and the trend endpoint cannot drift). **🔴 No campaign-ROI
   trend** (#94) and **🔴 no benchmark comparison** (#123) — those endpoints do
   not exist.

**Tier 2:**
6. Gamification & incentives (#34) — ✅ leaderboard (computed on the fly) and
   reward schemes, ✅ app UIs. **🔴 No badges, contests, or persisted points
   model, and retailer/trade loyalty is absent** (#124) — incentives reward
   *agents* only, not the retailers the pitch names.
7. Territory management & coverage (#35) — ✅ CRUD, agent assignment, app UI,
   **✅ coverage rate** (#96, closed 2026-07-16 — `/territories/:id/coverage`
   returns `{outletsVisited, outletsTotal, coverageRate}` with optional
   `from`/`to`, counting `distinct` outlets and only `status: 'submitted'`
   check-ins, so abandoned offline drafts don't inflate it). **✅ Heatmap**
   (#127, split out of #96 so it wouldn't be lost, since closed). App UI: #54.
8. In-store order-taking / sell-in capture (#36) — ✅ backend + app UI,
   **✅ promo pricing** (#99, closed 2026-07-16 — `PromoCalendar` gained
   `discountType`/`discountValue`/`skuScope`, `GET /skus?outletId=` serves
   `effectivePrice`, and both the running total and the submitted
   `OrderLine.unitPrice` price at the discount. `matchesScope` fails *closed* on
   a malformed scope, so a typo cannot silently discount every outlet).
   **🔴 No campaign attribution** (`Order` has no `campaignId` — tracked under
   #94, the same root cause as campaign ROI).
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

**Dead models: none.** `PlanogramTemplate` was seeded and read by nothing; it
was dropped rather than wired (#150), because a seeded model with no readers
reads as working infrastructure and planogram compliance is exactly what a
future CV feature (#1) would assume already exists. If that feature is built it
should design its own schema rather than inherit an empty guess.
`PromoCalendar` was also listed here once; #99 gave it real discount fields and
wired it into order pricing, so it is genuinely in use.

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
