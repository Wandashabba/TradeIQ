# Backend Scale & Efficiency Remediation — Plan 2 of 4

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make the backend survive production data volume without changing any API contract — add the missing database indexes, kill the two worst N+1 loops and the fraud base64 over-fetch, close the intra-tenant capture-write gap and CSV formula injection, and remove the duplicated KPI math and dead CI config the audit flagged.

**Architecture:** Every change is backend-only and non-breaking. No response shape changes (pagination is deliberately split into Plan 2b because it breaks the Flutter client's parsing). One Prisma migration adds indexes; one adds a global `omit`. The rest are query rewrites and small guards in existing service files, each independently verifiable.

**Tech Stack:** Express 5 + Prisma 6.19.3 + TypeScript (strict) + Jest + supertest against a real Postgres.

**Source:** The 2026-07-17 audit. Finding ids (H3/H5/M1/M5/M9/N5/N9 + the deferred omit floor and dispatch over-fetch) are referenced per task. See the "Active — remediation" section of `docs/ROADMAP.md`.

**Prerequisite:** Plan 1 (`fix/security-critical-audit`, PR #129) should be merged first — it touches `auth.service.ts`, `webhooks.service.ts`, `users.service.ts`, and `territories.service.ts`. This plan does not touch those, so it can branch from either `main` (post-merge) or the Plan 1 branch, but starting post-merge avoids a rebase.

**Not in this plan** — deliberately scoped out:
- **H4 pagination** and **M4/N7 per-tenant uniqueness migrations** → Plan 2b, because both change contracts the Flutter client depends on (response shape / the `409` on duplicate code). Coordinated backend+app work.
- **H11 photos → object storage** → tracked as #65; needs the breaking `closurePhotoUrl → closurePhotoId` API change.
- **Webhook DNS-rebinding TOCTOU**, **H2 token revocation**, **role-union consolidation** → recorded in ROADMAP; each needs its own decision.

---

## CRITICAL — testing on this machine

The dev host runs at load ~30 on 8 cores with Postgres sharing a constrained Docker VM. **Never run `npm test` or parallel jest — it produces mass phantom failures** (timeouts, `Can't reach database server`, truncated-body 400s) that look like real regressions but are environmental.

**Always `npx jest --runInBand`.** A `Can't reach database server` failure is a transient Docker stall — re-run before believing it. Never run two test processes at once. See the full explanation in `docs/ROADMAP.md`.

Establish the baseline before Task 1: `cd backend && npx jest --runInBand` — record the suite/test count. Every task must leave it green.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `backend/prisma/schema.prisma` | Data model | Modify — add `@@index` blocks |
| `backend/prisma/migrations/<new>/migration.sql` | Generated index migration | Create (via `prisma migrate dev`) |
| `backend/src/lib/prisma.ts` | Prisma client singleton | Modify — global `omit` for `passwordHash` |
| `backend/src/modules/auth/auth.service.ts` | `authenticateUser` reads the hash | Modify — opt back in to `passwordHash` |
| `backend/src/modules/fraud/fraud.service.ts` | Fraud scoring | Modify — select only `gpsTag` from photos |
| `backend/src/modules/dispatch/dispatch.service.ts` | Agent ranking | Modify — narrow the `user` select |
| `backend/src/modules/gamification/gamification.service.ts` | Leaderboard | Modify — N+1 → `groupBy` |
| `backend/src/modules/incentives/incentives.service.ts` | Earned incentives | Modify — nested N+1 → `groupBy` |
| `backend/src/modules/{stock,pricing,competitive,capability,visibility,photos,templateResponses,scorecards}/*.service.ts` + their `.routes.ts` | Section capture | Modify — scope writes by `agentId` |
| `backend/src/modules/reports/reports.service.ts` | CSV export | Modify — neutralize formula injection |
| `backend/src/modules/{gamification,incentives,campaigns}/*.service.ts`, `backend/src/services/forecast.service.ts` | KPI math | Modify — import from `lib/kpiMath` |
| `backend/.github/workflows/backend-ci.yml` | CI | Modify — drop dead `JWT_SECRET` |

Each task lists the exact files it touches. New test files are created next to the code they cover.

---

### Task 1: H3 — add the missing database indexes

**Why:** `schema.prisma` has **zero** `@@index`. Postgres does not auto-index foreign keys, and Prisma only emits indexes for `@id`/`@unique`/`@@index` — so all 57 FK/filter columns are sequential-scanned. This is multi-tenant: *every* query filters `clientId` unindexed, so each request scans every tenant's rows. This is the highest value-to-effort change in the codebase — one migration, no code change.

**Files:**
- Modify: `backend/prisma/schema.prisma`
- Create: `backend/prisma/migrations/<generated>/migration.sql` (Prisma generates it)

- [x] **Step 1: Add `@@index` blocks to the schema**

For each model below, add the `@@index` line(s) immediately above the existing `@@map(...)` line. Do not remove or alter any existing `@@unique`/`@@map`. Field names are the Prisma (camelCase) names, not the `@map` column names.

```prisma
// model User — leaderboard/incentives filter clientId + role
@@index([clientId, role])

// model Outlet — dashboard scopes by client; territory coverage joins on territoryId
@@index([clientId])
@@index([territoryId])

// model Sku
@@index([clientId])

// model PromoCalendar
@@index([clientId])

// model Visit — the hottest table: dashboard/trends/fraud all filter these
@@index([clientId, status])
@@index([clientId, checkinTs])
@@index([outletId])
@@index([agentId])

// model VisitStock — trends/forecast read by sku over time; sections read by visit
@@index([visitId])
@@index([skuId])

// model VisitPricing
@@index([visitId])

// model VisitCompetitive
@@index([visitId])

// model VisitRisk
@@index([visitId])

// model Task — gamification/incentives count by owner+status; SLA + section joins
@@index([ownerId, status])
@@index([outletId])
@@index([visitId])

// model Photo
@@index([visitId])

// model Scorecard — trend windowing reads by createdAt (visitId is already @unique)
@@index([createdAt])

// model Campaign
@@index([clientId])

// model BeatPlan
@@index([clientId])
@@index([agentId])

// model AlertRule
@@index([clientId])

// model Alert — manager view filters unacknowledged
@@index([clientId, acknowledged])

// model CheckInAttempt — fraud reads failed attempts by (agent, outlet) and by client
@@index([clientId, passed])
@@index([agentId, outletId])

// model Order
@@index([clientId])

// model Message
@@index([clientId])
@@index([recipientId])

// model Announcement
@@index([clientId])

// model Webhook — dispatch filters clientId + event + active
@@index([clientId, event, active])

// model ReportDefinition
@@index([clientId])

// model IncentiveScheme
@@index([clientId, active])

// model ReportSchedule
@@index([clientId])
```

Note: `VisitVisibility`, `VisitCapability`, `Scorecard` already have `@unique` on `visitId`, which creates an index — do not add a duplicate `@@index([visitId])` to those three.

- [x] **Step 2: Generate the migration**

```bash
cd backend && npx prisma migrate dev --name add_indexes
```

This creates `prisma/migrations/<timestamp>_add_indexes/migration.sql` containing `CREATE INDEX` statements, applies it to the dev DB, and regenerates the client. If it prompts to reset, say NO and investigate — a reset means schema drift that must be understood first.

- [x] **Step 3: Verify the SQL is index-only**

```bash
grep -c "CREATE INDEX" prisma/migrations/*_add_indexes/migration.sql
grep -iE "DROP|ALTER TABLE.*DROP|DELETE" prisma/migrations/*_add_indexes/migration.sql || echo "no destructive statements — good"
```

Expected: a count matching the number of `@@index` lines added (~30), and no destructive statements. A migration that drops or alters a column means the schema drifted — stop and investigate.

- [x] **Step 4: Prove an index is actually used**

Pick the hottest query and confirm Postgres uses an index rather than a sequential scan:

```bash
psql "$DATABASE_URL" -c "EXPLAIN SELECT * FROM visits WHERE client_id = '00000000-0000-0000-0000-000000000000' AND status = 'submitted';" 2>/dev/null || docker exec tradeiq-postgres-1 psql -U tradeiq -d tradeiq -c "EXPLAIN SELECT * FROM visits WHERE client_id = '00000000-0000-0000-0000-000000000000' AND status = 'submitted';"
```

Expected: the plan shows `Index Scan` / `Bitmap Index Scan` using an index on `visits`, not `Seq Scan`. (On an empty table Postgres may still choose a seq scan — if so, note it and rely on the migration SQL as evidence; the index exists regardless.)

- [x] **Step 5: Run the full suite — nothing should change behaviorally**

```bash
npx jest --runInBand
```

Expected: the recorded baseline, all green. Indexes change performance, not results.

- [x] **Step 6: Commit**

```bash
git add prisma/schema.prisma prisma/migrations/
git commit -m "perf(backend): index every tenant-scoped and FK filter column

The schema had zero @@index — Postgres does not auto-index foreign keys,
so every multi-tenant query sequentially scanned across all tenants. Add
compound and single-column indexes matching the actual filters (clientId,
visitId, outletId, agentId, and the createdAt/checkinTs ranges). No code
or behavior change — this is the migration only."
```
End the commit message with a blank line then: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

### Task 2: H5 — stop the fraud engine loading base64 photo blobs it never reads

**Why:** `fraud.service.ts:200` has `photos: true` in `fraudVisitInclude`, which selects every `Photo` column including the base64 `url` (up to ~8MB each). The consumer reads **only** `gpsTag` — the interface says so at `fraud.service.ts:59` (`photos: Array<{ gpsTag: Prisma.JsonValue }>`). `listFlagged` runs this over every submitted visit, so `GET /fraud/flagged` detoasts and ships gigabytes of image data it immediately discards. One-line fix, enormous win.

**Files:**
- Modify: `backend/src/modules/fraud/fraud.service.ts`
- Test: `backend/src/modules/fraud/fraud.dwell.test.ts` (add an assertion) or a new focused test

- [x] **Step 1: Write a failing test proving the select is narrowed**

The cleanest behavioral test is that fraud scoring still works with photos that have a `gpsTag` but whose `url` is never needed. Add to `backend/src/modules/fraud/fraud.service.test.ts` (create it if absent; if fraud tests live only in `fraud.routes.test.ts`, add there instead and adapt). First, prove the current shape leaks by asserting the Prisma include used at runtime selects only `gpsTag`. Because that is an implementation detail, prefer a behavioral test: seed a visit with a photo carrying a large `url` and a `gpsTag`, call `getVisitFraud`, and assert it returns a score (i.e. it read `gpsTag`) — then assert, via a spy on `prisma.photo`/query logging if available, that `url` was not selected. If spying is impractical, make this a **refactor-safe** change: keep the existing behavioral fraud tests green and add a unit assertion on the exported include shape.

Concretely, export the include and assert its photo select:

```ts
// in fraud.service.ts, ensure fraudVisitInclude is exported (it may already be
// module-private — export it for this test)
```

```ts
// fraud.service.test.ts
import { fraudVisitInclude } from './fraud.service';

it('fraud scoring selects only gpsTag from photos, never the base64 url', () => {
  const photos = fraudVisitInclude.photos as { select?: Record<string, boolean> };
  expect(photos.select).toEqual({ gpsTag: true });
});
```

- [x] **Step 2: Run it — expect FAIL**

```bash
npx jest src/modules/fraud/fraud.service.test.ts --runInBand
```

Expected: FAIL — `photos` is currently `true`, so `photos.select` is `undefined`.

- [x] **Step 3: Narrow the select**

In `backend/src/modules/fraud/fraud.service.ts`, change the `photos: true` line in `fraudVisitInclude` (line 200) to:

```ts
  // Fraud only inspects each photo's gpsTag (see FraudRelatedInput). Selecting
  // the base64 `url` too meant listFlagged detoasted every stored image — MBs
  // per row — only to discard them. Select the one field we read.
  photos: { select: { gpsTag: true } },
```

Ensure `fraudVisitInclude` is exported (`export const fraudVisitInclude = ...`) if the test imports it.

- [x] **Step 4: Run the fraud tests — all green**

```bash
npx jest src/modules/fraud --runInBand
```

Expected: all pass, including the existing dwell/flagged tests — the consumer never read `url`, so behavior is identical.

- [x] **Step 5: Full suite + commit**

```bash
npx jest --runInBand
git add src/modules/fraud/
git commit -m "perf(backend): fraud scoring selects only photo gpsTag, not the base64 url

fraudVisitInclude had photos: true, selecting every Photo column including
the ~MB base64 url, but computeFraudSignals reads only gpsTag. listFlagged
ran this over every submitted visit, detoasting gigabytes it discarded.
Select { gpsTag: true }."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 3: Structural floor — global Prisma `omit` for `passwordHash`

**Why:** Plan 1 closed the one known `passwordHash` leak by allowlisting. This makes the whole *class* impossible: a global `omit` means `passwordHash` never comes back from any query — even a future `include: { user: true }` — unless a call site explicitly opts in. Verified working on Prisma 6.19.3 (GA, no preview flag); forgetting the opt-in is a **compile error**, not a silent `undefined`. It also structurally fixes the `dispatch.service.ts` over-fetch (Task 4 narrows the select regardless, for defense in depth).

**Files:**
- Modify: `backend/src/lib/prisma.ts`
- Modify: `backend/src/modules/auth/auth.service.ts` (opt back in where the hash is genuinely needed)
- Test: `backend/src/lib/prisma.test.ts` (new)

- [x] **Step 1: Write the failing test**

Create `backend/src/lib/prisma.test.ts`:

```ts
import { prisma } from './prisma';

describe('global passwordHash omit', () => {
  it('omits passwordHash from a default user query', async () => {
    const client = await prisma.client.create({
      data: { name: 'OMIT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const user = await prisma.user.create({
      data: { email: 'omit-test@example.com', passwordHash: 'SHOULD-NOT-APPEAR', role: 'manager', clientId: client.id },
    });

    const fetched = await prisma.user.findUniqueOrThrow({ where: { id: user.id } });
    expect((fetched as Record<string, unknown>).passwordHash).toBeUndefined();

    await prisma.user.deleteMany({ where: { clientId: client.id } });
    await prisma.client.delete({ where: { id: client.id } });
  });
});
```

- [x] **Step 2: Run — expect FAIL** (`passwordHash` currently present).

```bash
npx jest src/lib/prisma.test.ts --runInBand
```

- [x] **Step 3: Add the global omit**

In `backend/src/lib/prisma.ts`, replace:

```ts
export const prisma = new PrismaClient();
```

with:

```ts
// passwordHash never leaves the DB layer unless a call site explicitly opts in
// (see authenticateUser). This makes credential disclosure a compile error
// rather than something every author must remember to allowlist.
export const prisma = new PrismaClient({
  omit: { user: { passwordHash: true } },
});
```

- [x] **Step 4: Opt back in where the hash is legitimately needed**

`authenticateUser` compares the hash, so it must read it. In `backend/src/modules/auth/auth.service.ts`, find the `prisma.user.findUnique({ where: { email } })` call in `authenticateUser` and change it to:

```ts
  const user = await prisma.user.findUnique({
    where: { email },
    omit: { passwordHash: false },
  });
```

Run `npx tsc --noEmit` — if any OTHER call site read `passwordHash`, it will now be a compile error naming the exact line. There should be exactly one (authenticateUser). If tsc flags others, report them — do not blindly opt them in.

- [x] **Step 5: Run auth + prisma tests, then the full suite**

```bash
npx jest src/lib/prisma.test.ts src/modules/auth --runInBand
npx jest --runInBand
```

Expected: login still works (auth suite green), the new omit test passes, full suite green.

- [x] **Step 6: Commit**

```bash
git add src/lib/prisma.ts src/modules/auth/auth.service.ts src/lib/prisma.test.ts
git commit -m "fix(backend): omit passwordHash globally, opt in only in authenticateUser

A global Prisma omit makes credential disclosure a compile error instead
of relying on every author to allowlist. authenticateUser opts back in
because it compares the hash; tsc proves nothing else reads it."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 4: Narrow the dispatch agent-ranking select

**Why:** `dispatch.service.ts` fetches candidate agents with `findMany({ where: { clientId, role: 'field_agent' } })` and no `select`, pulling `passwordHash` (and after Task 3, it wouldn't — but the over-fetch of GPS/other columns remains, and explicit selects are the house norm: dashboard and gamification already hand-pick). This is defense-in-depth and matches the pattern.

**Files:**
- Modify: `backend/src/modules/dispatch/dispatch.service.ts`
- Test: existing `dispatch.routes.test.ts` must stay green (behavior unchanged)

- [x] **Step 1: Read the current query and its consumer**

Open `backend/src/modules/dispatch/dispatch.service.ts`. Find the `prisma.user.findMany` around line 31 and note exactly which fields `rankAgentsForOutlet` reads off each agent (it projects into `DispatchCandidate` — `agentId`, `email`, `distanceM`, `inTerritory`, `lastSeenAt`, and the `lastLat`/`lastLng` used to compute distance).

- [x] **Step 2: Add an explicit select**

Change the `findMany` to select only what the projection uses:

```ts
  const agents = await prisma.user.findMany({
    where: { clientId, role: 'field_agent' },
    select: { id: true, email: true, lastLat: true, lastLng: true, lastSeenAt: true },
  });
```

Adjust field references if the code used `agent.id` vs a destructured name — keep it compiling. Do NOT change the ranking logic.

- [x] **Step 3: Run dispatch tests + typecheck**

```bash
npx jest src/modules/dispatch --runInBand
npx tsc --noEmit
```

Expected: green — the ranking output is identical, only the columns fetched changed.

- [x] **Step 4: Commit**

```bash
git add src/modules/dispatch/
git commit -m "perf(backend): dispatch ranking selects only the fields it projects

findMany had no select, over-fetching every User column. Hand-pick the
five fields DispatchCandidate uses, matching dashboard/gamification."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 5: M9 — replace the gamification leaderboard N+1 with `groupBy`

**Why:** `computeLeaderboard` (`gamification.service.ts:55`) does `agents.map(async …)` issuing 3 queries per agent (`visit.count`, `task.count`, `scorecard.aggregate`). At 50 agents that's **1 + 3×50 = 151 queries** per `GET /gamification/leaderboard`, each an unindexed scan (Task 1 helps, but the query count is the real problem). Three `groupBy` calls replace all of it.

**Files:**
- Modify: `backend/src/modules/gamification/gamification.service.ts`
- Test: `backend/src/modules/gamification/gamification.routes.test.ts` (existing — must stay green; the numbers must be identical)

- [x] **Step 1: Characterize current output with a test**

Read `gamification.routes.test.ts`. Confirm there is a test asserting concrete leaderboard numbers (points, visitsSubmitted, tasksClosed, avgScorecard) for a seeded fixture. If the existing coverage is thin, ADD a test that seeds 2 agents with known visits/tasks/scorecards and asserts the exact computed `points` and ordering — this is the safety net that proves the `groupBy` rewrite produces identical results. Run it green against the CURRENT code first.

```bash
npx jest src/modules/gamification --runInBand
```

- [x] **Step 2: Rewrite `computeLeaderboard` with `groupBy`**

Replace the `Promise.all(agents.map(async (agent) => { … }))` block in `computeLeaderboard` with three aggregate queries over the whole agent set, then join in JS. The metric definitions must match exactly: `visitsSubmitted` = count of the agent's submitted visits in the check-in window; `tasksClosed` = count of tasks the agent owns with status `closed` (scoped to the client via the outlet relation); `avgScorecard` = mean of the agent's `Scorecard.weightedTotal` in the created window; `points = round2(avgScorecard + tasksClosed*5 + visitsSubmitted*2)`.

```ts
  const agentIds = agents.map((a) => a.id);
  if (agentIds.length === 0) return [];

  const visitWhere: Prisma.VisitWhereInput = {
    clientId,
    agentId: { in: agentIds },
    status: 'submitted',
    ...(checkinRange ? { checkinTs: checkinRange } : {}),
  };

  const [visitGroups, taskGroups, scorecardGroups] = await Promise.all([
    prisma.visit.groupBy({
      by: ['agentId'],
      where: visitWhere,
      _count: { _all: true },
    }),
    prisma.task.groupBy({
      by: ['ownerId'],
      where: { ownerId: { in: agentIds }, status: 'closed', outlet: { clientId } },
      _count: { _all: true },
    }),
    prisma.scorecard.groupBy({
      by: ['agentId'],
      // Scorecard has no agentId column; it relates via visit. If groupBy by a
      // relation field is unavailable, aggregate through a raw join instead —
      // see the fallback note below. Otherwise group by the visit's agentId.
      where: {
        visit: { clientId, agentId: { in: agentIds } },
        ...(createdRange ? { createdAt: createdRange } : {}),
      },
      _avg: { weightedTotal: true },
    }),
  ]);
```

**Important correctness note the implementer MUST resolve:** `Scorecard` has no `agentId` scalar — it links to the agent through `visit.agentId` (`schema.prisma:325-333`). Prisma `groupBy` groups by *scalar* columns on the model, so `by: ['agentId']` on `Scorecard` will not compile. Two valid options — pick the one that keeps the numbers identical and is simplest:
  1. **Add `agentId` to the `Scorecard` model** denormalized from the visit (a schema change + backfill) — heavier, out of scope here.
  2. **Aggregate scorecards with `$queryRaw`** joining `scorecards` → `visits` and grouping by `visits.agent_id`, or fetch the per-agent scorecard rows with a narrow `select: { visit: { select: { agentId: true } }, weightedTotal: true }` in ONE query and reduce in JS.

Use option 2b (one `findMany` + JS reduce) — it is a single query, needs no schema change, and is easy to prove identical:

```ts
    // Scorecard links to the agent only via visit, so we cannot groupBy agentId
    // on it. One scoped query + a JS reduce keeps this to a single round trip
    // while producing the same per-agent mean the old per-agent aggregate did.
    prisma.scorecard.findMany({
      where: {
        visit: { clientId, agentId: { in: agentIds } },
        ...(createdRange ? { createdAt: createdRange } : {}),
      },
      select: { weightedTotal: true, visit: { select: { agentId: true } } },
    }),
```

Then build lookup maps and assemble the rows:

```ts
  const visitCount = new Map(visitGroups.map((g) => [g.agentId, g._count._all]));
  const taskCount = new Map(taskGroups.map((g) => [g.ownerId, g._count._all]));

  const scoreSum = new Map<string, { sum: number; n: number }>();
  for (const s of scorecardRows) {
    const id = s.visit.agentId;
    const acc = scoreSum.get(id) ?? { sum: 0, n: 0 };
    acc.sum += s.weightedTotal;
    acc.n += 1;
    scoreSum.set(id, acc);
  }

  const rows = agents.map((agent) => {
    const visitsSubmitted = visitCount.get(agent.id) ?? 0;
    const tasksClosed = taskCount.get(agent.id) ?? 0;
    const acc = scoreSum.get(agent.id);
    const avgScorecard = acc && acc.n > 0 ? round2(acc.sum / acc.n) : 0;
    const points = round2(avgScorecard + tasksClosed * 5 + visitsSubmitted * 2);
    return { agentId: agent.id, email: agent.email, visitsSubmitted, tasksClosed, avgScorecard, points };
  });
```

Keep the existing sort (`b.points - a.points || a.email.localeCompare(b.email)`). This takes the query count from `1 + 3N` to a constant **4** (agents + 3 aggregates).

- [x] **Step 3: Run the gamification tests — numbers must be identical**

```bash
npx jest src/modules/gamification --runInBand
```

Expected: green, including the concrete-number test from Step 1. If any number differs, the reduce logic diverged from the old per-agent aggregate — reconcile before proceeding.

- [x] **Step 4: Full suite + commit**

```bash
npx jest --runInBand
git add src/modules/gamification/
git commit -m "perf(backend): leaderboard uses groupBy, not 1+3N per-agent queries

computeLeaderboard issued 3 queries per agent (151 at 50 agents). Replace
with 2 groupBy aggregates plus one scoped scorecard fetch reduced in JS —
4 queries total, identical numbers."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 6: M9 — flatten the incentives nested N+1

**Why:** `computeEarnedIncentives` (`incentives.service.ts:119`) loops schemes × agents, issuing one aggregate/count per (scheme, agent) pair — **S×A** queries (10 schemes × 50 agents = 500), serialized per scheme. But there are only three distinct metrics (`scorecard`, `tasks_closed`, `visits`), so each metric needs computing **once per agent**, not once per (scheme, agent).

**Files:**
- Modify: `backend/src/modules/incentives/incentives.service.ts`
- Test: `backend/src/modules/incentives/incentives.routes.test.ts` (existing — numbers must stay identical)

- [x] **Step 1: Pin current output**

Read `incentives.routes.test.ts`. Ensure a test seeds multiple schemes (across different metrics) and multiple agents and asserts the exact `earned` rows. Add one if coverage is thin. Green against current code first.

```bash
npx jest src/modules/incentives --runInBand
```

- [x] **Step 2: Compute each metric once per agent, then evaluate thresholds in JS**

Replace the `for (const scheme … Promise.all(agents.map(async …)))` block. Compute all three per-agent metric maps up front (reusing the same aggregation the leaderboard uses — consider extracting a shared helper if it reads cleanly, but do NOT over-abstract), then iterate schemes and agents purely in memory:

```ts
  const agentIds = agents.map((a) => a.id);
  if (schemes.length === 0 || agentIds.length === 0) return [];

  // Each metric computed ONCE per agent, not once per (scheme, agent).
  const [visitGroups, taskGroups, scorecardRows] = await Promise.all([
    prisma.visit.groupBy({
      by: ['agentId'],
      where: { clientId, agentId: { in: agentIds }, status: 'submitted' },
      _count: { _all: true },
    }),
    prisma.task.groupBy({
      by: ['ownerId'],
      where: { ownerId: { in: agentIds }, status: 'closed', outlet: { clientId } },
      _count: { _all: true },
    }),
    prisma.scorecard.findMany({
      where: { visit: { clientId, agentId: { in: agentIds } } },
      select: { weightedTotal: true, visit: { select: { agentId: true } } },
    }),
  ]);

  const visitsBy = new Map(visitGroups.map((g) => [g.agentId, g._count._all]));
  const tasksBy = new Map(taskGroups.map((g) => [g.ownerId, g._count._all]));
  const scoreAcc = new Map<string, { sum: number; n: number }>();
  for (const s of scorecardRows) {
    const acc = scoreAcc.get(s.visit.agentId) ?? { sum: 0, n: 0 };
    acc.sum += s.weightedTotal; acc.n += 1;
    scoreAcc.set(s.visit.agentId, acc);
  }

  function metricValue(metric: IncentiveMetric, agentId: string): number {
    if (metric === 'scorecard') {
      const acc = scoreAcc.get(agentId);
      return acc && acc.n > 0 ? round2(acc.sum / acc.n) : 0;
    }
    if (metric === 'tasks_closed') return tasksBy.get(agentId) ?? 0;
    return visitsBy.get(agentId) ?? 0; // 'visits'
  }

  const earned: EarnedIncentive[] = [];
  for (const scheme of schemes) {
    const metric = scheme.metric as IncentiveMetric;
    for (const agent of agents) {
      const value = metricValue(metric, agent.id);
      if (value >= scheme.threshold) {
        earned.push({
          schemeId: scheme.id, schemeName: scheme.name, metric,
          agentId: agent.id, email: agent.email,
          metricValue: value, rewardPoints: scheme.rewardPoints,
        });
      }
    }
  }
  return earned;
```

This is a constant **3** queries regardless of scheme/agent count. The per-metric values match the old per-(scheme,agent) computation exactly because the underlying aggregations are identical.

- [x] **Step 3: Run incentives tests — identical rows**

```bash
npx jest src/modules/incentives --runInBand
```

Expected: green, same `earned` rows and order.

- [x] **Step 4: Full suite + commit**

```bash
npx jest --runInBand
git add src/modules/incentives/
git commit -m "perf(backend): earned incentives computes each metric once per agent

The nested schemes×agents loop issued S×A queries (500 at 10×50). There
are only 3 distinct metrics, so compute each once per agent (3 queries)
and evaluate every scheme's threshold in memory. Identical output."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 7: M1 — scope section-capture writes by `agentId`, not just `clientId`

**Why:** `submitVisit` scopes its visit lookup by `{ id, clientId, agentId }` (`visits.service.ts:94`), but every section-capture path scopes by `{ id, clientId }` only — so within one tenant, agent A can write stock/pricing/competitive/capability/visibility/photos/template-responses/scorecard onto agent B's in-progress visit. That corrupts fraud attribution (scored by visit) and creates tasks owned by the wrong agent. The module contradicts itself; align the capture paths with `submitVisit`.

**Files (service + route for each capture module):**
- `backend/src/modules/stock/{stock.service.ts, stock.routes.ts}`
- `backend/src/modules/pricing/{pricing.service.ts, pricing.routes.ts}`
- `backend/src/modules/competitive/{competitive.service.ts, competitive.routes.ts}`
- `backend/src/modules/capability/{capability.service.ts, capability.routes.ts}`
- `backend/src/modules/visibility/{visibility.service.ts, visibility.routes.ts}`
- `backend/src/modules/photos/{photos.service.ts, photos.routes.ts}`
- `backend/src/modules/templateResponses/{templateResponses.service.ts, templateResponses.routes.ts}`
- `backend/src/modules/scorecards/{scorecards.service.ts, scorecards.routes.ts}`
- Tests: each module's `.routes.test.ts`

- [x] **Step 1: Verify no legitimate manager-capture flow exists**

Before scoping by `agentId`, confirm these capture routes are only ever used by the owning field agent. For each `.routes.ts`, check the guards: capture should be `requireAuth` with the agent acting on their own visit. If any capture route is intentionally `requireRole('manager', …)` (a manager editing an agent's capture), scoping by `agentId` would break it — STOP and report. Also confirm the Flutter app only captures as the acting agent (it does — the audit flow is agent-only), so no client breakage.

Record the finding explicitly in your report. Assuming (as the audit found) all capture is agent-self:

- [x] **Step 2: Write a failing cross-agent test for ONE module first (stock)**

In `backend/src/modules/stock/stock.routes.test.ts`, add a test: seed two agents in the same client, agent A creates an in-progress visit, agent B (their token) attempts `POST /stock` for A's visit, assert **404** (matching `submitVisit`'s "Visit not found" for a foreign agent):

```ts
  it("forbids an agent from writing stock onto another agent's visit", async () => {
    // agentA owns the visit; agentB attempts to capture on it
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send({ visitId: agentAVisitId, items: [/* one valid item */] });
    expect(res.status).toBe(404);
  });
```

Adapt fixtures to the file's existing conventions (read its `beforeAll`). Run it — expect FAIL (currently 200/201, because only `clientId` is checked).

- [x] **Step 3: Thread `agentId` through the stock route and service**

In `stock.routes.ts`, pass the acting agent:

```ts
  const rows = await recordStock({
    visitId,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    items,
  });
```

In `stock.service.ts`, add `agentId: string` to `RecordStockInput` and scope the lookup:

```ts
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
```

Do the same for `listStockForVisit` if the audit intends reads to be agent-scoped too — BUT note: reads may legitimately be manager-visible. Scope **writes** by `agentId`; leave **reads** (`listStockForVisit` and the manager GET listings) scoped by `clientId` only, matching the existing manager-facing read pattern. Confirm which functions are writes vs reads before changing each.

- [x] **Step 4: Green for stock, then repeat the identical pattern for the other 7 modules**

```bash
npx jest src/modules/stock --runInBand
```

Then apply the same write-scoping to pricing, competitive, capability, visibility, photos, templateResponses, scorecards — each: add `agentId` to the write input, pass `req.user!.userId` from the route, add `agentId` to the write's `findFirst` where clause, and add the cross-agent 404 test. Keep manager-facing reads scoped by `clientId` only.

- [x] **Step 5: Full suite + commit**

```bash
npx jest --runInBand
git add src/modules/stock/ src/modules/pricing/ src/modules/competitive/ src/modules/capability/ src/modules/visibility/ src/modules/photos/ src/modules/templateResponses/ src/modules/scorecards/
git commit -m "fix(backend): scope section-capture writes by agentId, matching submitVisit

Every capture path scoped its visit lookup by clientId only, so within a
tenant an agent could write onto a colleague's visit — corrupting fraud
attribution and task ownership. submitVisit already scopes by agentId;
align the eight capture writes. Manager-facing reads stay client-scoped."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 8: M5 — neutralize CSV formula injection in report export

**Why:** `csvCell` (`reports.service.ts:188`) quotes correctly per RFC4180 but does not defend against formula injection. Report rows carry agent-entered free text (outlet names, task `requiredFix`), so a cell like `=cmd|'/C calc'!A0` executes when a manager opens the export in Excel/Sheets (CWE-1236).

**Files:**
- Modify: `backend/src/modules/reports/reports.service.ts`
- Test: `backend/src/modules/reports/reports.service.test.ts` (new or existing)

- [x] **Step 1: Write the failing test**

```ts
import { rowsToCsv } from './reports.service';

it('neutralizes formula-injection cells with a leading apostrophe', () => {
  const csv = rowsToCsv([{ note: "=cmd|'/C calc'!A0", plus: '+1+1', at: '@SUM(1)', minus: '-2' }]);
  const line = csv.split('\n')[1];
  // Each dangerous cell is prefixed with a single quote so a spreadsheet
  // treats it as text, not a formula.
  expect(line).toContain("'=cmd");
  expect(line).toContain("'+1+1");
  expect(line).toContain("'@SUM(1)");
  expect(line).toContain("'-2");
});

it('leaves ordinary cells untouched', () => {
  const csv = rowsToCsv([{ name: 'Corner Shop', qty: '5' }]);
  expect(csv.split('\n')[1]).toBe('Corner Shop,5');
});
```

- [x] **Step 2: Run — expect FAIL** (dangerous cells currently emitted raw).

- [x] **Step 3: Prefix formula-triggering cells before quoting**

In `reports.service.ts`, in the `csvCell` function, immediately before the final `return /[",\n\r]/.test(cell) ? … : cell;`, add:

```ts
  // Formula-injection guard (CWE-1236): a spreadsheet treats a cell beginning
  // with = + - @ (or a leading tab/CR) as a formula. Prefix with an apostrophe
  // so it is rendered as text. Applied before CSV quoting.
  if (/^[=+\-@\t\r]/.test(cell)) {
    cell = `'${cell}`;
  }
```

Also set a download disposition so the CSV is treated as an attachment, not rendered — in `reports.routes.ts`, where the CSV is sent (`.type('text/csv')`), add `res.setHeader('Content-Disposition', 'attachment; filename="report.csv"')` if not already present. Confirm the route first; if it already sets a filename, leave it.

- [x] **Step 4: Run report tests + full suite**

```bash
npx jest src/modules/reports --runInBand
npx jest --runInBand
```

- [x] **Step 5: Commit**

```bash
git add src/modules/reports/
git commit -m "fix(backend): neutralize CSV formula injection in report export

Agent-entered cells (=, +, -, @) executed as formulas when a manager
opened the export. Prefix such cells with an apostrophe and send the CSV
as an attachment. CWE-1236."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 9: N5 — dedupe the KPI math back into `lib/kpiMath`

**Why:** Commits `5ad8c7d` and `68ffcbd` extracted `round2`/`pct`/`mean` into `lib/kpiMath.ts` "to stop #93-class drift" — but it reached only three consumers. `round2` is redefined verbatim in `incentives.service.ts:13`, `gamification.service.ts:4`, `campaigns.service.ts:35` (which also copies `pct`/`mean` *including the comment*), and `services/forecast.service.ts:26`. And `beatplans.service.ts:13` computes `adherenceRate` **without** `round2`, emitting `66.66666666666667` where every other rate is 2dp — real behavioral drift.

**Files:**
- Modify: `backend/src/modules/incentives/incentives.service.ts`
- Modify: `backend/src/modules/gamification/gamification.service.ts`
- Modify: `backend/src/modules/campaigns/campaigns.service.ts`
- Modify: `backend/src/services/forecast.service.ts`
- Modify: `backend/src/modules/beatplans/beatplans.service.ts`

- [x] **Step 1: Write a failing test for the beatplans rounding drift**

In `beatplans` tests, assert `adherenceRate` is 2dp for a fixture that currently produces a long float (e.g. 2 of 3 stops visited → expect `66.67`, currently `66.66666666666667`):

```ts
  it('rounds adherenceRate to 2dp like every other rate', async () => {
    // seed a plan with 3 stops, 2 visited
    // ...
    expect(res.body.adherenceRate).toBe(66.67);
  });
```

Run — expect FAIL (`66.66666666666667`).

- [x] **Step 2: Replace each local definition with an import**

In each of `incentives.service.ts`, `gamification.service.ts`, `campaigns.service.ts`, `services/forecast.service.ts`: delete the local `round2` (and in campaigns, the local `pct`/`mean`) and add `import { round2 } from '../../lib/kpiMath';` (adjust the relative path — `services/forecast.service.ts` is `../lib/kpiMath`). For campaigns, import `{ round2, pct, mean }`.

If Tasks 5/6 already changed gamification/incentives, they may still carry the local `round2` — remove it now and import instead.

In `beatplans.service.ts:13`, wrap the rate: `const adherenceRate = stopsTotal === 0 ? 0 : round2((100 * stopsVisited) / stopsTotal);` and import `round2`.

- [x] **Step 3: Typecheck + run the affected suites**

```bash
npx tsc --noEmit
npx jest src/modules/incentives src/modules/gamification src/modules/campaigns src/services src/modules/beatplans --runInBand
```

Expected: green, and the beatplans rate is now `66.67`.

- [x] **Step 4: Full suite + commit**

```bash
npx jest --runInBand
git add src/modules/incentives/ src/modules/gamification/ src/modules/campaigns/ src/services/forecast.service.ts src/modules/beatplans/
git commit -m "refactor(backend): dedupe round2/pct/mean into lib/kpiMath

The shared KPI math was copied into four services (campaigns duplicated
the comment too), and beatplans' adherenceRate skipped round2 entirely,
emitting 66.66666666666667 where every other rate is 2dp. Import the
canonical helpers; round adherenceRate."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 10: N9 — remove the dead `JWT_SECRET` from CI

**Why:** `backend-ci.yml:28` sets `JWT_SECRET: ci-test-secret`, but `jest.setup-env.ts` loads the tracked `backend/.env.test` with `override: true`, so the workflow value never reaches the tests. It is dead config — and `ci-test-secret` is in Plan 1's blocklist, so keeping it invites confusion. Also confirm nothing else in CI needs it.

**Files:**
- Modify: `backend/.github/workflows/backend-ci.yml` (repo root `.github/`, verify the path)

- [x] **Step 1: Confirm it is genuinely dead**

Verify: `jest.setup-env.ts` loads `.env.test` with `override: true`; `backend/.env.test` is tracked (`git ls-files backend/.env.test`); no CI step other than `npm test` reads `JWT_SECRET` (`npm run build` is `tsc`; `prisma migrate deploy` doesn't need it). If all hold, it is safe to remove. If `backend/.env.test` is NOT tracked, STOP — the workflow value is load-bearing and must stay.

- [x] **Step 2: Remove the line**

In `.github/workflows/backend-ci.yml`, delete the `JWT_SECRET: ci-test-secret` line from the job `env:` block. Leave `DATABASE_URL` (that one is used by `prisma migrate deploy`, which runs before jest loads `.env.test`). If removing `JWT_SECRET` leaves the migrate step without a secret it never needed, that's fine — verify by reading the workflow.

- [x] **Step 3: Sanity-check the workflow still parses**

```bash
cd backend && npx --yes js-yaml ../.github/workflows/backend-ci.yml > /dev/null && echo "yaml valid" || echo "check yaml"
```
(If `js-yaml` isn't handy, just re-read the file and confirm indentation is intact.)

- [x] **Step 4: Commit**

```bash
git add ../.github/workflows/backend-ci.yml
git commit -m "chore(ci): drop dead JWT_SECRET from backend-ci

jest.setup-env.ts loads backend/.env.test with override: true, so the
workflow's JWT_SECRET never reached the tests. Removing the blocklisted
ci-test-secret avoids confusion; DATABASE_URL stays for migrate deploy."
```
Blank line, then the Co-Authored-By trailer.

---

### Task 11: Verify the whole plan

- [x] **Step 1: Full gate**

```bash
cd backend && npx jest --runInBand && npx tsc --noEmit && npm run lint && npm run build
```
Expected: all green, typecheck/lint/build clean.

- [x] **Step 2: Confirm the query-count wins with a smoke check**

With the dev server up (`npm run dev`) and a seeded client, hit `GET /gamification/leaderboard` and `GET /incentives/earned` and confirm they return the same shape as before at a fraction of the query count (enable Prisma query logging via `DEBUG` or a temporary `log: ['query']` if you want to count — revert any such debug change). This is a sanity check, not a committed test.

- [x] **Step 3: Update the status doc**

In `docs/ROADMAP.md`, mark Plan 2 done in the remediation table and note the branch.

---

## Self-Review

**Spec coverage.** H3 → Task 1. H5 → Task 2. Prisma `omit` floor → Task 3. Dispatch over-fetch → Task 4. M9 → Tasks 5–6. M1 → Task 7. M5 → Task 8. N5 → Task 9. N9 → Task 10. Deferred to Plan 2b / later: H4 pagination, M4/N7 uniqueness, H11 object storage, DNS rebinding, H2, role-union consolidation (all recorded in ROADMAP).

**Ordering constraints.** Task 3 (global `omit`) must land before or independently of Task 4 (dispatch select) — Task 4 is defense-in-depth and correct either way. Tasks 5/6 and Task 9 both touch gamification/incentives; if 5/6 land first, Task 9 removes the now-redundant local `round2` from those files (called out in Task 9 Step 2). Task 1 (indexes) should land first so later tasks' test runs are faster, but it is not a hard dependency.

**Non-breaking guarantee.** No task changes a response shape, status code (except adding a correct 404 in Task 7's cross-agent case, which was previously an incorrect 200/201), or DB column that the Flutter client reads. Pagination and uniqueness — the two contract-breaking items — are explicitly deferred to Plan 2b.

**Correctness risk concentrated in Tasks 5–6.** The N+1 rewrites must produce byte-identical numbers; each has a Step-1 characterization test against the current code as the safety net, and the `Scorecard`-has-no-`agentId` trap is called out explicitly with the chosen resolution.
