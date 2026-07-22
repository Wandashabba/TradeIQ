# Agent Visit Trail (T0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a manager a dashboard panel and a drill-in map answering "where are my agents, and which store is each one at?", derived entirely from `Visit` rows that already exist.

**Architecture:** A new read-only backend module (`backend/src/modules/agents/`) exposes `GET /agents/activity?from=&to=`, grouping a tenant's visits by agent into ordered stops and deriving a three-state status. The Flutter app adds a list-only dashboard panel and a separate `flutter_map` screen. No schema change, no new data capture, no new permissions.

**Tech Stack:** Express + Prisma + Jest/supertest (backend); Flutter + Riverpod + `flutter_map` + `flutter_test` (app).

**Spec:** `docs/superpowers/specs/2026-07-22-agent-visit-trail-design.md`

---

## Background you need before starting

Read the spec above first. Four constraints drive nearly every decision here and will look arbitrary otherwise:

1. **T0 shows confirmed presence, not live movement.** Between two check-ins an agent's position is unknown. The UI must never imply otherwise — hence dashed polylines, three states rather than four, and data age on every row.
2. **`Outlet.territoryId` stores a territory *code*, not an id.** Matching on id returns nothing silently. This shipped as a real bug once (#97). Copy the resolution in `backend/src/modules/outlets/outlets.service.ts:41-49`.
3. **There is no timezone support anywhere in the backend.** That is why this endpoint takes `from`/`to` instants instead of a `date`. Do not add a `date` param.
4. **State is never colour alone.** Every state needs a shape or text label too. See `territory_map_screen.dart:130-181` for the established pattern.

## File structure

**Backend — create:**
- `backend/src/modules/agents/agents.service.ts` — query + state derivation. Pure logic, no Express types.
- `backend/src/modules/agents/agents.routes.ts` — validation, role guard, tenant scoping.
- `backend/src/modules/agents/agents.service.test.ts` — service unit tests (Tasks 1–2).
- `backend/src/modules/agents/agents.routes.test.ts` — HTTP route tests (Task 3).

> **Amended 2026-07-22, after Task 1 review.** The first draft of this plan put every
> test in `agents.routes.test.ts`, including pure-function unit tests. That contradicts
> the repo's convention — `auth`, `fraud`, `reports` and `stock` all pair a
> `.service.test.ts` (direct service calls) against a `.routes.test.ts` (HTTP via
> supertest) — and it would have forced Task 3's real route tests to share a file
> already full of unit tests. Tasks 1 and 2 write to `agents.service.test.ts`; Task 3
> writes to `agents.routes.test.ts`.

> **Amended 2026-07-22, after Task 4 review.** `listActivity` originally returned a bare
> `List<AgentActivity>`, discarding the response's `nextCursor` and never sending a
> `limit` — so it always received the backend default of 50 agents and a manager with
> more than 50 would silently see only the first 50, with nothing on screen suggesting
> anything was missing. On a feature whose entire premise is not overstating what we
> know, that is the worst available failure. It now requests `limit: 200` (the backend's
> own `MAX_LIMIT`) and returns `AgentActivityPage { agents, truncated }`, and Tasks 5
> and 6 render a truncation notice. This is not pagination UI — that stays out of scope
> for T0 — it is just refusing to present a cut list as a complete one.

**Backend — modify:**
- `backend/src/app.ts` — register the router.

**App — create:**
- `app/lib/features/agents/data/agents_repository.dart` — models + `AgentsRepository` + providers.
- `app/lib/features/agents/presentation/agent_trail_screen.dart` — the map screen.
- `app/test/features/agents/agents_repository_test.dart`
- `app/test/features/agents/agent_trail_screen_test.dart`
- `app/test/features/dashboard/agent_activity_panel_test.dart`

**App — modify:**
- `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart` — add `_AgentActivityPanel`, add it to `_refresh`.
- `app/lib/core/router/app_router.dart` — add the `/agents/activity` route.

The panel lives in `dashboard_shell_screen.dart` alongside the other panels rather than in its own file, because that is how every existing panel in this codebase is organised. The map screen gets its own file because it is a full screen, matching `territory_map_screen.dart`.

---

## Task 1: State derivation logic

The pure function first, with no database and no Express. Everything else builds on it.

**Files:**
- Create: `backend/src/modules/agents/agents.service.ts`
- Create: `backend/src/modules/agents/agents.service.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/modules/agents/agents.service.test.ts` with only the state-derivation block for now:

```typescript
import { deriveAgentState, VisitStop } from './agents.service';

const stop = (over: Partial<VisitStop> = {}): VisitStop => ({
  visitId: 'v1',
  outletId: 'o1',
  outletName: 'Sandton Spar',
  lat: -26.1,
  lng: 28.05,
  checkinTs: new Date('2026-07-22T08:00:00Z'),
  status: 'submitted',
  ...over,
});

describe('deriveAgentState', () => {
  it('reports idle when the agent has no stops', () => {
    expect(deriveAgentState([])).toEqual({ state: 'idle', currentOutlet: null });
  });

  it('reports at_store when a visit is still in progress', () => {
    const stops = [stop({ status: 'submitted' }), stop({ visitId: 'v2', outletId: 'o2', outletName: 'Rosebank PnP', status: 'in_progress' })];
    expect(deriveAgentState(stops)).toEqual({
      state: 'at_store',
      currentOutlet: { id: 'o2', name: 'Rosebank PnP' },
    });
  });

  it('reports in_transit when the latest visit is submitted', () => {
    const stops = [stop({ checkinTs: new Date('2026-07-22T08:00:00Z') })];
    expect(deriveAgentState(stops)).toEqual({ state: 'in_transit', currentOutlet: null });
  });

  // Two open visits is a data anomaly (an agent who checked in twice without
  // submitting). It must not throw, and it must pick the later one — that is
  // where the agent most plausibly is now.
  it('picks the latest of two in-progress visits rather than throwing', () => {
    const stops = [
      stop({ visitId: 'v1', outletId: 'o1', outletName: 'First', status: 'in_progress', checkinTs: new Date('2026-07-22T08:00:00Z') }),
      stop({ visitId: 'v2', outletId: 'o2', outletName: 'Second', status: 'in_progress', checkinTs: new Date('2026-07-22T11:00:00Z') }),
    ];
    expect(deriveAgentState(stops)).toEqual({
      state: 'at_store',
      currentOutlet: { id: 'o2', name: 'Second' },
    });
  });
});
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd backend && npx jest src/modules/agents/agents.service.test.ts
```

Expected: FAIL — `Cannot find module './agents.service'`.

- [ ] **Step 3: Write the implementation**

Create `backend/src/modules/agents/agents.service.ts`:

```typescript
import { prisma } from '../../lib/prisma';

/// One confirmed store presence: an agent stood inside this outlet's geofence
/// at this moment. The whole T0 feature is a list of these per agent.
export interface VisitStop {
  visitId: string;
  outletId: string;
  outletName: string;
  lat: number;
  lng: number;
  checkinTs: Date;
  status: 'in_progress' | 'submitted';
}

export type AgentState = 'at_store' | 'in_transit' | 'idle';

export interface AgentStateResult {
  state: AgentState;
  currentOutlet: { id: string; name: string } | null;
}

/**
 * Derives where an agent is from their stops, in any order.
 *
 * Sorts internally rather than trusting the caller to pre-sort. Both the
 * `at_store` outlet and the two-open-visits tie-break depend on order, and an
 * unsorted input would silently return the WRONG outlet — no throw, no signal.
 * On a feature whose whole premise is "do not claim to know where someone is
 * when you don't", a redundant sort over a day's worth of stops is a trivial
 * price for removing that failure mode.
 *
 * Three states, not four. #153's sketch proposed an `offline` state, but T0
 * has no heartbeat — it cannot tell "phone is off" from "driving between
 * stores". Reporting `offline` would assert something we do not observe.
 */
export function deriveAgentState(stops: VisitStop[]): AgentStateResult {
  if (stops.length === 0) {
    return { state: 'idle', currentOutlet: null };
  }

  // A copy — callers hand us their own arrays and must not have them reordered.
  const ordered = [...stops].sort((a, b) => a.checkinTs.getTime() - b.checkinTs.getTime());

  // Two open visits means the agent checked in somewhere without submitting
  // the previous one. Real data, not hypothetical. Take the latest: that is
  // where they most plausibly are now.
  const open = ordered.filter((s) => s.status === 'in_progress');
  if (open.length > 0) {
    const latest = open[open.length - 1];
    return {
      state: 'at_store',
      currentOutlet: { id: latest.outletId, name: latest.outletName },
    };
  }

  return { state: 'in_transit', currentOutlet: null };
}
```

- [ ] **Step 4: Run it and watch it pass**

```bash
cd backend && npx jest src/modules/agents/agents.service.test.ts
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/agents/
git commit -m "feat(backend): derive agent state from visit stops (#153)"
```

---

## Task 2: The activity query

**Files:**
- Modify: `backend/src/modules/agents/agents.service.ts`
- Modify: `backend/src/modules/agents/agents.service.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `agents.service.test.ts`. Note the harness shape — it matches `territories.routes.test.ts`, which you should skim first.

```typescript
import { prisma } from '../../lib/prisma';
import { listAgentActivity } from './agents.service';

describe('listAgentActivity', () => {
  let clientId: string;
  let otherClientId: string;
  let agentId: string;
  let otherAgentId: string;
  let outletId: string;

  const FROM = new Date('2026-07-22T00:00:00Z');
  const TO = new Date('2026-07-23T00:00:00Z');

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'AGT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const other = await prisma.client.create({
      data: { name: 'AGT-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const agent = await prisma.user.create({
      data: { email: 'AGT-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;

    const otherAgent = await prisma.user.create({
      data: { email: 'AGT-other@example.com', passwordHash: 'x', role: 'field_agent', clientId: otherClientId },
    });
    otherAgentId = otherAgent.id;

    const outlet = await prisma.outlet.create({
      data: { name: 'Sandton Spar', code: 'AGT-O1', lat: -26.1, lng: 28.05, clientId, territoryId: 'AGT-T1' },
    });
    outletId = outlet.id;

    const otherOutlet = await prisma.outlet.create({
      data: { name: 'Other Store', code: 'AGT-O2', lat: -26.2, lng: 28.15, clientId: otherClientId, territoryId: 'AGT-T2' },
    });

    await prisma.visit.create({
      data: {
        outletId, agentId, clientId,
        checkinTs: new Date('2026-07-22T08:00:00Z'),
        checkinLat: -26.1, checkinLng: 28.05,
        geofencePass: true, status: 'submitted',
      },
    });

    // Another tenant's visit, same day. Must never appear.
    await prisma.visit.create({
      data: {
        outletId: otherOutlet.id, agentId: otherAgentId, clientId: otherClientId,
        checkinTs: new Date('2026-07-22T09:00:00Z'),
        checkinLat: -26.2, checkinLng: 28.15,
        geofencePass: true, status: 'submitted',
      },
    });
  });

  afterAll(async () => {
    await prisma.visit.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
  });

  it('returns the agent with their stop and derived state', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO });
    const mine = result.agents.find((a) => a.agentId === agentId);
    expect(mine).toBeDefined();
    expect(mine!.stops).toHaveLength(1);
    expect(mine!.stops[0].outletName).toBe('Sandton Spar');
    expect(mine!.state).toBe('in_transit');
    expect(mine!.lastSeenAt).toEqual(new Date('2026-07-22T08:00:00Z'));
  });

  it('never returns another tenant\'s agents', async () => {
    const result = await listAgentActivity({ clientId, from: FROM, to: TO });
    expect(result.agents.map((a) => a.agentId)).not.toContain(otherAgentId);
  });

  it('reports an agent with no visits in range as idle with a null lastSeenAt', async () => {
    const result = await listAgentActivity({
      clientId,
      from: new Date('2026-07-01T00:00:00Z'),
      to: new Date('2026-07-02T00:00:00Z'),
    });
    const mine = result.agents.find((a) => a.agentId === agentId);
    expect(mine!.state).toBe('idle');
    expect(mine!.lastSeenAt).toBeNull();
    expect(mine!.stops).toEqual([]);
  });
});
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd backend && npx jest src/modules/agents/agents.service.test.ts -t listAgentActivity
```

Expected: FAIL — `listAgentActivity is not a function`.

- [ ] **Step 3: Write the implementation**

Append to `agents.service.ts`:

```typescript
export interface AgentActivity {
  agentId: string;
  name: string;
  state: AgentState;
  currentOutlet: { id: string; name: string } | null;
  lastSeenAt: Date | null;
  stops: VisitStop[];
}

export interface ListAgentActivityInput {
  clientId: string;
  from: Date;
  to: Date;
  territoryId?: string;
  limit?: number;
  cursor?: string;
}

/** Default and hard maximum for the agent page. Mirrors the shape #141 will standardise. */
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

/**
 * Every field agent in the tenant with their stops in range.
 *
 * Agents with no visits are included deliberately — "Sipho has not checked in
 * today" is the single most actionable thing on this panel, and omitting the
 * row would render it as an absence the manager has to notice.
 *
 * Bounded by shape rather than a blanket `take:` on visits (#141): the AGENT
 * list is paged, and each included agent's day is returned whole. Truncating
 * mid-route would draw a wrong line rather than a short one.
 */
export async function listAgentActivity(
  input: ListAgentActivityInput,
): Promise<{ agents: AgentActivity[]; nextCursor: string | null }> {
  const { clientId, from, to, territoryId } = input;
  const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);

  let agentIdFilter: string[] | undefined;
  if (territoryId !== undefined) {
    // `Outlet.territoryId` and `UserTerritory` both key off the territory
    // CODE, not its id — see outlets.service.ts and the #97 postmortem.
    const assignments = await prisma.userTerritory.findMany({
      where: { territory: { clientId, code: territoryId } },
      select: { userId: true },
    });
    agentIdFilter = assignments.map((a) => a.userId);
    if (agentIdFilter.length === 0) {
      return { agents: [], nextCursor: null };
    }
  }

  const agents = await prisma.user.findMany({
    where: {
      clientId,
      role: 'field_agent',
      active: true,
      ...(agentIdFilter ? { id: { in: agentIdFilter } } : {}),
    },
    select: { id: true, email: true },
    orderBy: { id: 'asc' },
    take: limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  const page = agents.slice(0, limit);
  const nextCursor = agents.length > limit ? page[page.length - 1].id : null;

  if (page.length === 0) {
    return { agents: [], nextCursor: null };
  }

  const visits = await prisma.visit.findMany({
    where: {
      clientId,
      agentId: { in: page.map((a) => a.id) },
      checkinTs: { gte: from, lt: to },
    },
    select: {
      id: true,
      agentId: true,
      outletId: true,
      checkinTs: true,
      checkinLat: true,
      checkinLng: true,
      status: true,
      outlet: { select: { name: true } },
    },
    orderBy: { checkinTs: 'asc' },
  });

  const byAgent = new Map<string, VisitStop[]>();
  for (const v of visits) {
    const stop: VisitStop = {
      visitId: v.id,
      outletId: v.outletId,
      outletName: v.outlet.name,
      lat: v.checkinLat,
      lng: v.checkinLng,
      checkinTs: v.checkinTs,
      status: v.status,
    };
    const existing = byAgent.get(v.agentId);
    if (existing) existing.push(stop);
    else byAgent.set(v.agentId, [stop]);
  }

  return {
    agents: page.map((a) => {
      const stops = byAgent.get(a.id) ?? [];
      const { state, currentOutlet } = deriveAgentState(stops);
      return {
        agentId: a.id,
        name: a.email,
        state,
        currentOutlet,
        // Scoped to the requested range on purpose. `User.lastSeenAt` is
        // written on every successful check-in regardless of date, so using it
        // would print a timestamp from a different day than the one on screen.
        lastSeenAt: stops.length > 0 ? stops[stops.length - 1].checkinTs : null,
        stops,
      };
    }),
    nextCursor,
  };
}
```

- [ ] **Step 4: Run it and watch it pass**

```bash
cd backend && npx jest src/modules/agents/agents.service.test.ts
```

Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/agents/
git commit -m "feat(backend): query agent activity from visit rows (#153)"
```

---

## Task 3: The route

**Files:**
- Create: `backend/src/modules/agents/agents.routes.ts`
- Modify: `backend/src/app.ts`
- Create: `backend/src/modules/agents/agents.routes.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/modules/agents/agents.routes.test.ts` — a **new** file, separate from
`agents.service.test.ts`, per the repo convention noted in the File structure section above.

It needs its own fixtures, since it does not share a scope with the service tests. Use
distinct email addresses and outlet codes from the ones in `agents.service.test.ts`
(prefix `AGTR-` rather than `AGT-`) so the two suites cannot collide if they run
concurrently against the same database.

```typescript
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('agents routes', () => {
  let clientId: string;
  let managerToken: string;
  let agentToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'AGTR-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'AGTR-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'AGTR-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.deleteMany({ where: { id: clientId } });
  });
```

Then, nested inside that `describe`:

```typescript
describe('GET /agents/activity', () => {
  const qs = '?from=2026-07-22T00:00:00Z&to=2026-07-23T00:00:00Z';

  it('returns 200 with agents for a manager', async () => {
    const res = await request(app)
      .get(`/agents/activity${qs}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.agents)).toBe(true);
  });

  it('refuses a field agent', async () => {
    const res = await request(app)
      .get(`/agents/activity${qs}`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('requires both from and to', async () => {
    const res = await request(app)
      .get('/agents/activity?from=2026-07-22T00:00:00Z')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects a malformed instant', async () => {
    const res = await request(app)
      .get('/agents/activity?from=yesterday&to=2026-07-23T00:00:00Z')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects an inverted range', async () => {
    const res = await request(app)
      .get('/agents/activity?from=2026-07-23T00:00:00Z&to=2026-07-22T00:00:00Z')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  // The 48h cap is the second bound, alongside the paged agent list (#141).
  it('rejects a range wider than 48 hours', async () => {
    const res = await request(app)
      .get('/agents/activity?from=2026-07-01T00:00:00Z&to=2026-07-30T00:00:00Z')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });
  });
});
```

The two closing braces are both needed: the inner one closes
`describe('GET /agents/activity')`, the outer one closes `describe('agents routes')`
opened above.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd backend && npx jest src/modules/agents/agents.routes.test.ts -t "GET /agents/activity"
```

Expected: FAIL — all six 404, since nothing is mounted at `/agents`.

- [ ] **Step 3: Write the route**

Create `backend/src/modules/agents/agents.routes.ts`:

```typescript
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { listAgentActivity } from './agents.service';

export const agentsRouter = Router();
agentsRouter.use(requireAuth);

/** Two days. See the range-cap note below. */
const MAX_RANGE_MS = 48 * 60 * 60 * 1000;

/**
 * Where each field agent has been confirmed present in a time window.
 *
 * Takes `from`/`to` as ISO-8601 INSTANTS rather than a `date`, deliberately.
 * There is no `Client.timezone` and no timezone handling anywhere in this
 * backend, so resolving a calendar date server-side would mean UTC — which
 * cuts the day at 02:00 SAST and splits a South African field team's morning
 * across two "days". The client knows the manager's locale; it sends explicit
 * instants and the server does no timezone reasoning at all.
 */
agentsRouter.get('/activity', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { from, to, territoryId, limit, cursor } = req.query as {
    from?: string;
    to?: string;
    territoryId?: string;
    limit?: string;
    cursor?: string;
  };

  if (typeof from !== 'string' || typeof to !== 'string') {
    res.status(400).json({ error: 'from and to are required ISO-8601 instants' });
    return;
  }

  const fromDate = new Date(from);
  const toDate = new Date(to);
  if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
    res.status(400).json({ error: 'from and to must be valid ISO-8601 instants' });
    return;
  }

  if (toDate.getTime() <= fromDate.getTime()) {
    res.status(400).json({ error: 'to must be after from' });
    return;
  }

  if (toDate.getTime() - fromDate.getTime() > MAX_RANGE_MS) {
    res.status(400).json({ error: 'range must not exceed 48 hours' });
    return;
  }

  let parsedLimit: number | undefined;
  if (limit !== undefined) {
    parsedLimit = Number(limit);
    if (!Number.isInteger(parsedLimit) || parsedLimit < 1) {
      res.status(400).json({ error: 'limit must be a positive integer' });
      return;
    }
  }

  const result = await listAgentActivity({
    // Never from a parameter. The tenant comes from the token.
    clientId: req.user!.clientId,
    from: fromDate,
    to: toDate,
    territoryId: typeof territoryId === 'string' ? territoryId : undefined,
    limit: parsedLimit,
    cursor: typeof cursor === 'string' ? cursor : undefined,
  });

  res.status(200).json(result);
});
```

- [ ] **Step 4: Register the router**

In `backend/src/app.ts`, add the import beside the other module imports:

```typescript
import { agentsRouter } from './modules/agents/agents.routes';
```

and the mount beside the other `app.use` calls (near `app.use('/territories', territoriesRouter);`):

```typescript
app.use('/agents', agentsRouter);
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd backend && npx jest src/modules/agents/agents.routes.test.ts
```

Expected: PASS, 13 tests.

- [ ] **Step 6: Run the whole backend suite for regressions**

```bash
cd backend && npx jest
```

Expected: PASS. If anything unrelated fails, stop and report it rather than proceeding.

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/agents/ backend/src/app.ts
git commit -m "feat(backend): GET /agents/activity (#153)"
```

---

## Task 4: The Flutter repository

**Files:**
- Create: `app/lib/features/agents/data/agents_repository.dart`
- Create: `app/test/features/agents/agents_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/agents/agents_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';

void main() {
  group('AgentActivity.fromJson', () {
    test('parses an agent with stops', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a1',
        'name': 'thabo@example.com',
        'state': 'at_store',
        'currentOutlet': {'id': 'o1', 'name': 'Sandton Spar'},
        'lastSeenAt': '2026-07-22T08:00:00.000Z',
        'stops': [
          {
            'visitId': 'v1',
            'outletId': 'o1',
            'outletName': 'Sandton Spar',
            'lat': -26.1,
            'lng': 28.05,
            'checkinTs': '2026-07-22T08:00:00.000Z',
            'status': 'in_progress',
          },
        ],
      });

      expect(activity.agentId, 'a1');
      expect(activity.state, AgentState.atStore);
      expect(activity.currentOutletName, 'Sandton Spar');
      expect(activity.stops, hasLength(1));
      expect(activity.stops.first.lat, -26.1);
      expect(activity.lastSeenAt, DateTime.utc(2026, 7, 22, 8));
    });

    test('parses an idle agent with no stops and no last-seen', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a2',
        'name': 'sipho@example.com',
        'state': 'idle',
        'currentOutlet': null,
        'lastSeenAt': null,
        'stops': <Map<String, dynamic>>[],
      });

      expect(activity.state, AgentState.idle);
      expect(activity.currentOutletName, isNull);
      expect(activity.lastSeenAt, isNull);
      expect(activity.stops, isEmpty);
    });

    // An unknown state must not crash the panel. Falling back to idle is the
    // honest default: it claims nothing.
    test('falls back to idle on an unrecognised state', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a3',
        'name': 'x@example.com',
        'state': 'teleporting',
        'currentOutlet': null,
        'lastSeenAt': null,
        'stops': <Map<String, dynamic>>[],
      });
      expect(activity.state, AgentState.idle);
    });
  });

  group('dayBoundsLocal', () {
    // The client owns the timezone decision — see the route comment on
    // GET /agents/activity. These must be local midnights, not UTC ones.
    test('returns local midnight to the next local midnight', () {
      final (from, to) = dayBoundsLocal(DateTime(2026, 7, 22, 14, 30));
      expect(from, DateTime(2026, 7, 22));
      expect(to, DateTime(2026, 7, 23));
    });

    test('spans exactly one day across a month boundary', () {
      final (from, to) = dayBoundsLocal(DateTime(2026, 7, 31, 9));
      expect(from, DateTime(2026, 7, 31));
      expect(to, DateTime(2026, 8, 1));
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/agents/agents_repository_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../agents_repository.dart'`.

- [ ] **Step 3: Write the implementation**

Create `app/lib/features/agents/data/agents_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../dashboard/data/dashboard_repository.dart' show dashboardFilterProvider;

/// Where an agent is, as far as check-in data can tell us.
///
/// Three states, not four. #153 sketched an `offline` state, but T0 has no
/// heartbeat: it cannot distinguish a phone that is off from an agent driving
/// between stores. A marker claiming `offline` would assert something we do
/// not observe.
enum AgentState { atStore, inTransit, idle }

/// One confirmed store presence.
class AgentStop {
  const AgentStop({
    required this.visitId,
    required this.outletId,
    required this.outletName,
    required this.lat,
    required this.lng,
    required this.checkinTs,
    required this.inProgress,
  });

  final String visitId;
  final String outletId;
  final String outletName;
  final double lat;
  final double lng;
  final DateTime checkinTs;
  final bool inProgress;

  factory AgentStop.fromJson(Map<String, dynamic> json) => AgentStop(
        visitId: json['visitId'] as String,
        outletId: json['outletId'] as String,
        outletName: json['outletName'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        checkinTs: DateTime.parse(json['checkinTs'] as String),
        inProgress: json['status'] == 'in_progress',
      );
}

/// One agent's day, as returned by GET /agents/activity.
class AgentActivity {
  const AgentActivity({
    required this.agentId,
    required this.name,
    required this.state,
    required this.stops,
    this.currentOutletName,
    this.lastSeenAt,
  });

  final String agentId;
  final String name;
  final AgentState state;
  final List<AgentStop> stops;

  /// Set only when [state] is [AgentState.atStore].
  final String? currentOutletName;

  /// The latest check-in IN THE REQUESTED RANGE, or null if there was none.
  final DateTime? lastSeenAt;

  /// The last outlet the agent was confirmed at, whether or not they are still
  /// there. Drives the "left Pick n Pay" half of the panel copy.
  String? get lastOutletName => stops.isEmpty ? null : stops.last.outletName;

  factory AgentActivity.fromJson(Map<String, dynamic> json) {
    final outlet = json['currentOutlet'] as Map<String, dynamic>?;
    final lastSeen = json['lastSeenAt'] as String?;
    return AgentActivity(
      agentId: json['agentId'] as String,
      name: json['name'] as String,
      state: switch (json['state']) {
        'at_store' => AgentState.atStore,
        'in_transit' => AgentState.inTransit,
        // Anything unrecognised falls back to idle rather than throwing. Idle
        // is the state that claims the least.
        _ => AgentState.idle,
      },
      currentOutletName: outlet?['name'] as String?,
      lastSeenAt: lastSeen == null ? null : DateTime.parse(lastSeen),
      stops: ((json['stops'] as List?) ?? const [])
          .map((s) => AgentStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Local midnight to the next local midnight around [day].
///
/// The server does no timezone reasoning — see the comment on
/// `GET /agents/activity`. The day boundary is decided here, on the client,
/// which is the only place that knows the manager's locale.
(DateTime, DateTime) dayBoundsLocal(DateTime day) {
  final from = DateTime(day.year, day.month, day.day);
  return (from, from.add(const Duration(days: 1)));
}

abstract class AgentsRepository {
  /// GET /agents/activity (manager/admin).
  Future<List<AgentActivity>> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  });
}

class DioAgentsRepository implements AgentsRepository {
  @override
  Future<List<AgentActivity>> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/agents/activity',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (territoryId != null) 'territoryId': territoryId,
      },
    );
    final agents = (response.data?['agents'] as List?) ?? const [];
    return agents
        .map((a) => AgentActivity.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}

final agentsRepositoryProvider =
    Provider<AgentsRepository>((ref) => DioAgentsRepository());

/// Today's activity, scoped by the dashboard's territory filter so the panel
/// agrees with every other panel by construction rather than by convention.
///
/// Retries disabled, matching `territory_map_screen.dart`: Riverpod's default
/// backs off silently for seconds before surfacing an error, leaving a bare
/// spinner with no explanation on a screen the manager is looking at.
final agentActivityTodayProvider =
    FutureProvider<List<AgentActivity>>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  final (from, to) = dayBoundsLocal(DateTime.now());
  return ref.read(agentsRepositoryProvider).listActivity(
        from: from,
        to: to,
        territoryId: filter.territoryId,
      );
}, retry: (retryCount, error) => null);

/// One chosen day's activity, for the drill-in map's date picker.
final agentActivityForDayProvider =
    FutureProvider.family<List<AgentActivity>, DateTime>((ref, day) {
  final filter = ref.watch(dashboardFilterProvider);
  final (from, to) = dayBoundsLocal(day);
  return ref.read(agentsRepositoryProvider).listActivity(
        from: from,
        to: to,
        territoryId: filter.territoryId,
      );
}, retry: (retryCount, error) => null);
```

- [ ] **Step 4: Run it and watch it pass**

```bash
cd app && flutter test test/features/agents/agents_repository_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/agents/ app/test/features/agents/
git commit -m "feat(app): agent activity repository and providers (#153)"
```

---

## Task 5: The dashboard panel

**Files:**
- Modify: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart`
- Create: `app/test/features/dashboard/agent_activity_panel_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/dashboard/agent_activity_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

import '../../helpers/routed_app.dart';

class _FakeAgentsRepository implements AgentsRepository {
  _FakeAgentsRepository(this.agents, {this.truncated = false});
  final List<AgentActivity> agents;
  final bool truncated;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      AgentActivityPage(agents: agents, truncated: truncated);
}

AgentActivity _agent({
  required String id,
  required String name,
  required AgentState state,
  String? currentOutlet,
  DateTime? lastSeen,
  List<AgentStop> stops = const [],
}) =>
    AgentActivity(
      agentId: id,
      name: name,
      state: state,
      currentOutletName: currentOutlet,
      lastSeenAt: lastSeen,
      stops: stops,
    );

void main() {
  testWidgets('renders an at-store agent with their outlet', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentActivityPanel(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'thabo@example.com',
              state: AgentState.atStore,
              currentOutlet: 'Sandton Spar',
              lastSeen: DateTime.now().subtract(const Duration(minutes: 4)),
            ),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('thabo@example.com'), findsOneWidget);
    expect(find.textContaining('Sandton Spar'), findsOneWidget);
    expect(find.textContaining('At store'), findsOneWidget);
  });

  testWidgets('renders an idle agent as not checked in', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentActivityPanel(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(id: 'a2', name: 'sipho@example.com', state: AgentState.idle),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No check-in'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no agents', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentActivityPanel(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No agents'), findsOneWidget);
  });

  // A cut list must never read as the whole team. Without this notice a
  // manager sees 200 rows and concludes that is everyone.
  testWidgets('says so when the server had more agents than it returned', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentActivityPanel(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository(
            [_agent(id: 'a1', name: 'a@x.com', state: AgentState.idle)],
            truncated: true,
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('first 200'), findsOneWidget);
  });

  testWidgets('shows no truncation notice when the list is complete', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentActivityPanel(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository(
            [_agent(id: 'a1', name: 'a@x.com', state: AgentState.idle)],
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('first 200'), findsNothing);
  });

  // State must never be carried by colour alone (#144's N4 rule). Each state
  // has a distinct icon AND a text label.
  testWidgets('gives each state a distinct icon as well as a label', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentActivityPanel(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(id: 'a1', name: 'a@x.com', state: AgentState.atStore, currentOutlet: 'Spar'),
            _agent(id: 'a2', name: 'b@x.com', state: AgentState.inTransit),
            _agent(id: 'a3', name: 'c@x.com', state: AgentState.idle),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('agent-state-icon-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-state-icon-a2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-state-icon-a3')), findsOneWidget);

    final icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .map((i) => i.icon)
        .toSet();
    // Three states rendered → at least three distinct glyphs.
    expect(icons.length, greaterThanOrEqualTo(3));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/dashboard/agent_activity_panel_test.dart
```

Expected: FAIL — `AgentActivityPanel isn't defined`.

- [ ] **Step 3: Write the panel**

In `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart`, add these imports beside the existing ones:

```dart
import '../../agents/data/agents_repository.dart';
```

Then add the panel. Put it after `_AvailabilityPanel` and before `_FilterBar`, following the file's existing section-comment style:

```dart
// ═══════════════════════════════════════════════════════════════════════
// Where are my agents — today's confirmed stops
// ═══════════════════════════════════════════════════════════════════════

/// A list, deliberately — no map tiles on the manager's morning screen.
///
/// The question "which store is each agent at" is answered by text; rendering
/// OpenStreetMap tiles to answer it would cost every dashboard load a set of
/// network round-trips for information the list already carries. The map is
/// one tap away for when geography actually matters.
///
/// Public rather than private so the widget test can pump it on its own.
class AgentActivityPanel extends ConsumerWidget {
  const AgentActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(agentActivityTodayProvider);

    return PanelCard(
      title: 'Where are my agents',
      subtitle: "Today's check-ins",
      padded: false,
      trailing: TextButton(
        key: const ValueKey<String>('agent-activity-view-map'),
        onPressed: () => context.go('/agents/activity'),
        child: const Text('View map'),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: AsyncSection<AgentActivityPage>(
          value: activity,
          label: 'agent activity',
          onRetry: () => ref.invalidate(agentActivityTodayProvider),
          builder: (page) {
            if (page.agents.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No agents to show for this filter.'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final agent in page.agents) _AgentRow(agent: agent),
                // Never let a cut list read as the whole team. A manager who
                // cannot see an agent concludes they did not work, not that
                // the list ran out.
                if (page.truncated)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing the first 200 agents. Filter by territory to narrow.',
                      style: TextStyle(fontSize: 12, color: context.colors.ink3),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One agent, one line.
///
/// Every row leads with WHEN, not just where. A row that says "Sandton Spar"
/// with no age reads as live; this data is never live, and the age is the
/// only thing that keeps the row honest.
class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final AgentActivity agent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, label, color) = switch (agent.state) {
      AgentState.atStore => (Icons.storefront, 'At store', colors.good),
      AgentState.inTransit => (Icons.trending_flat, 'In transit', colors.warn),
      AgentState.idle => (Icons.remove_circle_outline, 'No check-in', colors.ink4),
    };

    final where = switch (agent.state) {
      AgentState.atStore => agent.currentOutletName ?? 'unknown store',
      AgentState.inTransit =>
        agent.lastOutletName == null ? 'in transit' : 'left ${agent.lastOutletName}',
      AgentState.idle => 'nothing today',
    };

    return Semantics(
      label: '${agent.name}, $label, $where, ${_age(agent.lastSeenAt)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              key: ValueKey<String>('agent-state-icon-${agent.agentId}'),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(agent.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '$label · $where',
                    style: TextStyle(fontSize: 12, color: colors.ink3),
                  ),
                ],
              ),
            ),
            Text(
              _age(agent.lastSeenAt),
              style: TextStyle(fontSize: 12, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/// How stale this row is, in words. Never a bare timestamp: "11:20" invites
/// the reader to assume it is current, "38m ago" does not.
String _age(DateTime? at) {
  if (at == null) return 'no check-in today';
  final delta = DateTime.now().difference(at);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}
```

- [ ] **Step 4: Mount the panel and wire the refresh**

In `DashboardShellScreen.build`, add the panel to the `ListView` children, after the `_TerritoryPanel`/`_AvailabilityPanel` row and before `_StubCaveat`:

```dart
                const SizedBox(height: 12),
                const AgentActivityPanel(),
```

In `DashboardShellScreen._refresh`, add the invalidation alongside the others — the method's own comment explains why every panel must refresh together:

```dart
    ref.invalidate(agentActivityTodayProvider);
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/dashboard/agent_activity_panel_test.dart
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/dashboard/ app/test/features/dashboard/agent_activity_panel_test.dart
git commit -m "feat(app): 'where are my agents' dashboard panel (#153)"
```

---

## Task 6: The trail map screen

**Files:**
- Create: `app/lib/features/agents/presentation/agent_trail_screen.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Create: `app/test/features/agents/agent_trail_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/agents/agent_trail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/agents/presentation/agent_trail_screen.dart';

import '../../helpers/routed_app.dart';

class _FakeAgentsRepository implements AgentsRepository {
  _FakeAgentsRepository(this.agents, {this.truncated = false});
  final List<AgentActivity> agents;
  final bool truncated;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      AgentActivityPage(agents: agents, truncated: truncated);
}

AgentStop _stop(String id, String name, double lat, double lng, int hour) => AgentStop(
      visitId: id,
      outletId: 'o-$id',
      outletName: name,
      lat: lat,
      lng: lng,
      checkinTs: DateTime(2026, 7, 22, hour),
      inProgress: false,
    );

final _thabo = AgentActivity(
  agentId: 'a1',
  name: 'thabo@example.com',
  state: AgentState.inTransit,
  currentOutletName: null,
  lastSeenAt: DateTime(2026, 7, 22, 11),
  stops: [
    _stop('v1', 'Sandton Spar', -26.10, 28.05, 8),
    _stop('v2', 'Rosebank Pick n Pay', -26.14, 28.04, 11),
  ],
);

void main() {
  testWidgets('renders a marker per stop', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-stop-a1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-stop-a1-1')), findsOneWidget);
  });

  testWidgets('shows an empty state for a day with no stops', (tester) async {
    final idle = AgentActivity(
      agentId: 'a2',
      name: 'sipho@example.com',
      state: AgentState.idle,
      stops: const [],
    );
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([idle])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No check-ins'), findsOneWidget);
  });

  // The dashes are load-bearing: a solid line would assert a route between two
  // check-ins that we did not observe.
  testWidgets('draws the trail as a dashed polyline', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(layer.polylines, hasLength(1));
    // `segments` is non-null only on StrokePattern.dashed — asserting on it
    // actually proves the line is dashed. Comparing against
    // `StrokePattern.solid()` would not: StrokePattern has no value equality,
    // so that assertion passes even against a solid line.
    expect(layer.polylines.first.pattern.segments, isNotNull);
  });

  testWidgets('surfaces an error with a retry', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_ThrowingRepository()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}

class _ThrowingRepository implements AgentsRepository {
  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      throw Exception('boom');
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/agents/agent_trail_screen_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../agent_trail_screen.dart'`.

- [ ] **Step 3: Write the screen**

Create `app/lib/features/agents/presentation/agent_trail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/worklist.dart';
import '../data/agents_repository.dart';

/// The selected day, defaulting to today. Local dates only — the day boundary
/// is a client-side decision, see [dayBoundsLocal].
final _selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Each agent's confirmed stops for one day, drawn in sequence.
///
/// This map shows where agents HAVE BEEN, not where they are. Everything about
/// its presentation is chosen to keep that distinction visible — see the
/// dashed polylines and the numbered markers below.
class AgentTrailScreen extends ConsumerWidget {
  const AgentTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(_selectedDayProvider);
    final activity = ref.watch(agentActivityForDayProvider(day));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent trail'),
        actions: [
          TextButton.icon(
            key: const ValueKey<String>('agent-trail-date'),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('${day.year}-${_two(day.month)}-${_two(day.day)}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ref.read(_selectedDayProvider.notifier).state =
                    DateTime(picked.year, picked.month, picked.day);
              }
            },
          ),
        ],
      ),
      body: AsyncSection<AgentActivityPage>(
        value: activity,
        label: 'agent activity',
        onRetry: () => ref.invalidate(agentActivityForDayProvider(day)),
        builder: (page) {
          final withStops = page.agents.where((a) => a.stops.isNotEmpty).toList();
          if (withStops.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No check-ins on this day.'),
              ),
            );
          }

          final points = [
            for (final a in withStops)
              for (final s in a.stops) LatLng(s.lat, s.lng),
          ];

          // A single point has a zero-area bounds box, so centre on it rather
          // than asking flutter_map to "fit" it — same reasoning as
          // territory_map_screen.dart.
          final cameraFit = points.length > 1
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(40),
                )
              : null;

          return Column(
            children: [
              _TrailLegend(truncated: page.truncated),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 13,
                    initialCameraFit: cameraFit,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tradeiq.tradeiq_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        for (final a in withStops)
                          if (a.stops.length > 1)
                            Polyline(
                              points: [
                                for (final s in a.stops) LatLng(s.lat, s.lng),
                              ],
                              strokeWidth: 3,
                              color: context.colors.brand,
                              // Dashed, deliberately. A solid line would claim
                              // we know the route between two check-ins. We
                              // know two points; the rest is inference, and
                              // the stroke should look like inference.
                              pattern: StrokePattern.dashed(segments: const [8.0, 6.0]),
                            ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final a in withStops)
                          for (var i = 0; i < a.stops.length; i++)
                            Marker(
                              point: LatLng(a.stops[i].lat, a.stops[i].lng),
                              width: 34,
                              height: 34,
                              child: _StopPin(
                                key: ValueKey<String>('agent-stop-${a.agentId}-$i'),
                                agentName: a.name,
                                stop: a.stops[i],
                                ordinal: i + 1,
                                isLast: i == a.stops.length - 1,
                              ),
                            ),
                      ],
                    ),
                    // Required by OSM's ODbL licence — separate from, and in
                    // addition to, the TileLayer's userAgentPackageName.
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Says in words what the dashes mean. Without this the map still overstates
/// its own certainty to anyone who does not read stroke styles as semantics.
class _TrailLegend extends StatelessWidget {
  const _TrailLegend({required this.truncated});

  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: colors.surface2,
      child: Text(
        'Numbered pins are confirmed check-ins. Dashed lines connect them in '
        'order — they are not a recorded route.'
        // A partial map that looks complete is worse than no map. If the
        // server had more agents than we asked for, say so here rather than
        // let the manager read empty space as "nobody else worked".
        '${truncated ? ' Showing the first 200 agents only.' : ''}',
        style: TextStyle(fontSize: 12, color: colors.ink3),
      ),
    );
  }
}

/// One stop. Numbered so the sequence reads without needing colour, and the
/// final stop is filled so "where they ended up" is findable at a glance.
class _StopPin extends StatelessWidget {
  const _StopPin({
    super.key,
    required this.agentName,
    required this.stop,
    required this.ordinal,
    required this.isLast,
  });

  final String agentName;
  final AgentStop stop;
  final int ordinal;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '$agentName, stop $ordinal, ${stop.outletName}, '
          '${_two(stop.checkinTs.hour)}:${_two(stop.checkinTs.minute)}',
      child: Tooltip(
        message: '${stop.outletName} · '
            '${_two(stop.checkinTs.hour)}:${_two(stop.checkinTs.minute)}',
        child: DecoratedBox(
          // A white disc under the glyph. OSM tiles range from pale fields to
          // dark roads, so a bare numeral has no reliable contrast anywhere.
          decoration: BoxDecoration(
            color: isLast ? colors.brand : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: colors.line, width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Center(
            child: Text(
              '$ordinal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLast ? Colors.white : colors.ink1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the route**

In `app/lib/core/router/app_router.dart`, add the import beside the others:

```dart
import '../../features/agents/presentation/agent_trail_screen.dart';
```

and the route beside the other manager routes (near `/territories`):

```dart
      GoRoute(
        path: '/agents/activity',
        builder: (context, state) => const AgentTrailScreen(),
      ),
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/agents/
```

Expected: PASS, 9 tests across both files.

- [ ] **Step 6: Run the whole app suite for regressions**

```bash
cd app && flutter test
```

Expected: PASS. `app_router_test.dart` asserts on the route table and may need the new route added to its expectations — if it fails, read the assertion and update it rather than reverting the route.

- [ ] **Step 7: Analyze**

```bash
cd app && flutter analyze
```

Expected: no issues. Fix any warning introduced by these files before committing.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/agents/ app/lib/core/router/app_router.dart app/test/features/agents/
git commit -m "feat(app): agent trail map screen (#153)"
```

---

## Task 7: Full verification and PR

- [ ] **Step 1: Run both suites clean**

```bash
cd backend && npx jest
cd ../app && flutter test && flutter analyze
```

Expected: all green. Do not proceed on a failure — report it.

- [ ] **Step 2: Verify against the real app**

Use the `run` skill to launch the app, log in as a manager, and confirm: the panel appears on the dashboard, states render, "View map" opens the trail screen, and the date picker refetches. A passing test suite is not evidence the feature works end to end.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin feat/agent-visit-trail
gh pr create --title "feat: T0 agent visit trail on the manager dashboard (#153)" --body "$(cat <<'EOF'
Implements tier **T0** of #153 — the visit trail — per `docs/superpowers/specs/2026-07-22-agent-visit-trail-design.md`.

## What this is
A manager can now see where each agent has been confirmed present today, and which store they are at. A list panel on the dashboard answers it at a glance; a drill-in map shows the day's route.

## What this is not
**This is not live tracking.** Every point is a check-in — a moment, not a stream. Between two check-ins an agent's position is unknown. Three things in the UI exist specifically to keep that visible:
- every row leads with data age, never a bare timestamp
- trail polylines are dashed, because a solid line would assert a route we did not observe
- there are three states, not #153's proposed four — T0 has no heartbeat, so it cannot tell "offline" from "between stores", and claiming otherwise would be inventing data

## No new data
No schema change, no new capture, no new permissions. Everything derives from `Visit` rows the system has recorded since check-in shipped. T1 (heartbeat) and T2 (background tracking, POPIA-gated) remain out of scope.

## Timezone
The endpoint takes `from`/`to` **instants**, not a date. There is no `Client.timezone` and no timezone handling in the backend, so a server-resolved date would mean UTC — cutting the day at 02:00 SAST. The client computes local midnight-to-midnight.

## Bounding (#141)
`GET /agents/activity` is bounded by shape: the agent list is paged (default 50, max 200) and the range is capped at 48h, while each included agent's day is returned whole — truncating mid-route would draw a *wrong* line rather than a short one. It should adopt the shared `parsePagination` helper once #141 lands.

## Tests
- Backend: state derivation incl. the two-open-visits anomaly, tenant isolation, territory filter, empty range, and six request-validation cases.
- App: repository parsing incl. unknown-state fallback, day-bounds maths, panel states, map markers, dashed polyline, empty and error states.

Closes the T0 half of #153.
EOF
)"
```

- [ ] **Step 4: Update #153**

Comment on #153 noting T0 has shipped and that T1 remains open, gated on the POPIA decision and #178 (retention policy). Do **not** close #153 — it tracks all three tiers.

---

## Self-review notes

Checked against the spec:

- Placement (panel + drill-in) → Tasks 5, 6
- `Visit`-only data source → Task 2
- Today default + date picker → Tasks 4 (`dayBoundsLocal`, both providers), 6 (picker)
- Three states → Task 1
- `from`/`to` instants, no server timezone → Tasks 3, 4
- Bounded endpoint → Tasks 2, 3
- Territory filter via `UserTerritory` codes → Task 2
- Dashed polylines, data age, shape-not-colour → Tasks 5, 6
- All spec test cases → Tasks 1, 2, 3, 4, 5, 6

Type consistency: `AgentState`/`VisitStop`/`AgentActivity` are defined in Task 1–2 and used unchanged after; the Dart mirror (`AgentState`, `AgentStop`, `AgentActivity`) is defined in Task 4 and used unchanged in Tasks 5–6. `agentsRepositoryProvider`, `agentActivityTodayProvider`, and `agentActivityForDayProvider` are named identically everywhere they appear.

One thing left deliberately open for the implementer: `AgentActivity.name` currently carries the user's **email**, because `User` has no display-name column. That is honest but ugly in the UI. Adding `User.displayName` is out of scope here — if it matters, it is a separate ticket.
