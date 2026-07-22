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
 * Derives where an agent is from their stops. Callers need not pre-sort —
 * this function sorts a copy by `checkinTs` ascending internally, because a
 * caller-trusted ordering that silently breaks (a missing `orderBy` in the
 * query, or stops merged from two sources) would make this function report
 * a confidently wrong outlet with no throw and no signal. A redundant sort
 * over a day's worth of stops (tens of rows) is free next to that risk.
 *
 * Three states, not four. #153's sketch proposed an `offline` state, but T0
 * has no heartbeat — it cannot tell "phone is off" from "driving between
 * stores". Reporting `offline` would assert something we do not observe.
 */
export function deriveAgentState(stops: VisitStop[]): AgentStateResult {
  if (stops.length === 0) {
    return { state: 'idle', currentOutlet: null };
  }

  const sorted = [...stops].sort((a, b) => a.checkinTs.getTime() - b.checkinTs.getTime());

  // Two open visits means the agent checked in somewhere without submitting
  // the previous one. Real data, not hypothetical. Take the latest: that is
  // where they most plausibly are now.
  const open = sorted.filter((s) => s.status === 'in_progress');
  if (open.length > 0) {
    const latest = open[open.length - 1];
    return {
      state: 'at_store',
      currentOutlet: { id: latest.outletId, name: latest.outletName },
    };
  }

  return { state: 'in_transit', currentOutlet: null };
}

export interface AgentActivity {
  agentId: string;
  /// Currently the agent's email. `User` has no display-name column, so
  /// email is the best available value for what the UI shows for this
  /// agent — the field is named for its role (display label), not its
  /// current source. Adding a real display-name column is out of scope here.
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
 *
 * This function does not itself cap `to - from` — that guard lives in the
 * route (Task 3 rejects any range over 48 hours) so there is exactly one
 * place range validation can drift out of sync, rather than two that can
 * disagree.
 */
export async function listAgentActivity(
  input: ListAgentActivityInput,
): Promise<{ agents: AgentActivity[]; nextCursor: string | null }> {
  const { clientId, from, to, territoryId } = input;
  // Clamp both ends. A non-positive `limit` (a bad query param, or a `NaN`
  // forwarded from the route) must not be read as "unbounded" — left
  // unclamped below, `limit: 0` makes `page` empty while `agents.length >
  // limit` is still true, so the page-1 math below claims pagination is
  // exhausted (or throws) when there may be many more rows. The route
  // (Task 3) already rejects non-positive `limit` with a 400; this is
  // defence in depth for callers that hit this function directly.
  const limit = Math.max(1, Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT));

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
    // Secondary sort on `id` because Postgres does not guarantee row order
    // for ties on `checkinTs` alone, and two open visits sharing an exact
    // timestamp is plausible from a retried offline sync. `deriveAgentState`'s
    // sort is stable, so an unordered tie here would make `currentOutlet`
    // flip between reads of unchanged data — exactly the nondeterminism that
    // function exists to avoid.
    orderBy: [{ checkinTs: 'asc' }, { id: 'asc' }],
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
