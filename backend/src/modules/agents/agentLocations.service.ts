import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { personLabel } from '../../lib/personName';
import {
  LOCATION_NOTICE_VERSION,
  MAX_AT_STORE_ACCURACY_M,
  OFFLINE_AFTER_SECONDS,
  confirmsStore,
  pingIntervalSeconds,
  staleAfterSeconds,
} from '../locations/locationPolicy';
import { containingOutlet, outletsNear } from '../locations/outletFence';

/**
 * Six states. T0 (`agents.service.ts`) had three and deliberately no `offline`,
 * because without a heartbeat it could not tell a phone that is off from an
 * agent between stores. A foreground heartbeat can: pings stop.
 *
 * Added after product review on #153:
 * - `near_store` — a fresh ping inside an outlet fence whose GPS accuracy is
 *   too poor (or unknown) to say the agent is IN the store
 *   (`MAX_AT_STORE_ACCURACY_M`).
 * - `not_sharing` — the agent's latest answer to the CURRENT location notice is
 *   `declined`. Distinct from `offline`, which also covers an agent who never
 *   answered at all.
 */
export type LiveAgentState = 'at_store' | 'near_store' | 'in_transit' | 'stale' | 'offline' | 'not_sharing';

export interface DeriveLiveStateInput {
  /** Seconds since the latest ping was recorded; null if there has never been one. */
  ageSeconds: number | null;
  /** Whether the latest ping sits inside an outlet geofence. */
  insideOutlet: boolean;
  /** The latest ping's horizontal accuracy in metres; null when the platform gave none. */
  accuracyM: number | null;
  intervalSeconds: number;
  /** The agent's latest answer to the current notice is `declined`. */
  declined: boolean;
}

/**
 * In order, first match wins:
 * 1. **Declined → not_sharing**, whatever pings exist. A manager must not read
 *    an agent who said no as merely offline, nor see a pre-decline ping as live.
 * 2. **Age** — never shared, or older than `OFFLINE_AFTER_SECONDS` → offline;
 *    older than `staleAfterSeconds` → stale. A position is only described by
 *    place while it is recent enough to be where the agent IS — an old ping
 *    inside a store fence is stale, not at_store, because risk 2 on #153 is
 *    exactly a marker that reads live when it is 40 minutes old.
 * 3. **Place** — outside every fence → in_transit; inside one with accuracy
 *    that confirms it (`confirmsStore`) → at_store; inside one otherwise →
 *    near_store.
 */
export function deriveLiveState(input: DeriveLiveStateInput): LiveAgentState {
  const { ageSeconds } = input;
  if (input.declined) return 'not_sharing';
  if (ageSeconds === null || ageSeconds > OFFLINE_AFTER_SECONDS) return 'offline';
  if (ageSeconds > staleAfterSeconds(input.intervalSeconds)) return 'stale';
  if (!input.insideOutlet) return 'in_transit';
  return confirmsStore(input.accuracyM) ? 'at_store' : 'near_store';
}

export interface AgentLocation {
  agentId: string;
  name: string;
  displayName: string | null;
  email: string;
  state: LiveAgentState;
  /**
   * The newest ping by `recordedAt`, or null if the agent has never shared.
   * Always null for `not_sharing`: the stored pings are kept under normal
   * retention, but a map that kept pinning a declined agent's last position
   * would go on showing where they are after they said no.
   */
  lastPing: { lat: number; lng: number; accuracyM: number | null; recordedAt: Date } | null;
  /** Whole seconds between `lastPing.recordedAt` and `serverTime`; never negative. Null when `lastPing` is. */
  ageSeconds: number | null;
  /** Set only when `state` is `at_store`. */
  currentOutlet: { id: string; name: string } | null;
  /**
   * The best-known last store and where that knowledge came from: the latest
   * ping's fence (`ping`) when it was inside one, otherwise the latest
   * confirmed check-in (`check_in`). The source is named so a client never
   * presents a check-in from this morning as a live reading. For `near_store`
   * this is the fence the ping fell in; for `not_sharing` only a check-in is
   * ever given.
   */
  lastOutlet: { id: string; name: string; at: Date; source: 'ping' | 'check_in' } | null;
}

export interface ListAgentLocationsInput {
  clientId: string;
  territoryId?: string;
  limit: number;
  cursor?: string;
  now?: Date;
}

export interface AgentLocationsPage {
  /** The instant every `ageSeconds` is measured from. Clients show age against this, not their own clock. */
  serverTime: Date;
  intervalSeconds: number;
  staleAfterSeconds: number;
  offlineAfterSeconds: number;
  /** The worst accuracy a ping may have and still read `at_store`. */
  maxAtStoreAccuracyM: number;
  data: AgentLocation[];
  nextCursor: string | null;
}

interface LatestPingRow {
  agentId: string;
  lat: number;
  lng: number;
  accuracyM: number | null;
  recordedAt: Date;
}

interface LatestVisitRow {
  agentId: string;
  outletId: string;
  outletName: string;
  checkinTs: Date;
}

interface LatestConsentRow {
  agentId: string;
  decision: string;
}

/**
 * Each active field agent's latest position, paged by agent (#141): one page is
 * at most `limit` agents and one ping each, so the response is bounded however
 * long the tenant has been sharing.
 */
export async function listAgentLocations(input: ListAgentLocationsInput): Promise<AgentLocationsPage> {
  const { clientId, territoryId } = input;
  const serverTime = input.now ?? new Date();
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: { kpiThresholds: true },
  });
  const intervalSeconds = pingIntervalSeconds(client?.kpiThresholds);
  const envelope = {
    serverTime,
    intervalSeconds,
    staleAfterSeconds: staleAfterSeconds(intervalSeconds),
    offlineAfterSeconds: OFFLINE_AFTER_SECONDS,
    maxAtStoreAccuracyM: MAX_AT_STORE_ACCURACY_M,
  };

  let agentIdFilter: string[] | undefined;
  if (territoryId !== undefined) {
    // A Territory.id, matched through UserTerritory's real foreign key — the
    // same resolution as GET /agents/activity, for the reasons documented there.
    const assignments = await prisma.userTerritory.findMany({
      where: { territory: { clientId, id: territoryId } },
      select: { userId: true },
    });
    agentIdFilter = assignments.map((a) => a.userId);
    if (agentIdFilter.length === 0) return { ...envelope, data: [], nextCursor: null };
  }

  const agents = await prisma.user.findMany({
    where: {
      clientId,
      role: 'field_agent',
      active: true,
      ...(agentIdFilter ? { id: { in: agentIdFilter } } : {}),
    },
    select: { id: true, email: true, displayName: true },
    orderBy: { id: 'asc' },
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  const page = agents.slice(0, input.limit);
  const nextCursor = agents.length > input.limit ? page[page.length - 1].id : null;
  if (page.length === 0) return { ...envelope, data: [], nextCursor: null };

  const ids = Prisma.join(page.map((a) => a.id));
  // DISTINCT ON walks the (client_id, agent_id, recorded_at) index backwards:
  // one row per agent, newest by RECORDED time — never by arrival.
  const [latestPings, latestVisits, latestConsents] = await Promise.all([
    prisma.$queryRaw<LatestPingRow[]>`
      SELECT DISTINCT ON (agent_id)
        agent_id AS "agentId", lat, lng, accuracy_m AS "accuracyM", recorded_at AS "recordedAt"
      FROM agent_location_pings
      WHERE client_id = ${clientId} AND agent_id IN (${ids})
      ORDER BY agent_id, recorded_at DESC, id DESC`,
    prisma.$queryRaw<LatestVisitRow[]>`
      SELECT DISTINCT ON (v.agent_id)
        v.agent_id AS "agentId", v.outlet_id AS "outletId", o.name AS "outletName", v.checkin_ts AS "checkinTs"
      FROM visits v
      JOIN outlets o ON o.id = v.outlet_id
      WHERE v.client_id = ${clientId} AND v.agent_id IN (${ids})
      ORDER BY v.agent_id, v.checkin_ts DESC, v.id DESC`,
    // The latest answer to the CURRENT notice, ordered as `currentConsent`
    // (locations.service.ts) orders it, so the map and the ingest gate agree.
    prisma.$queryRaw<LatestConsentRow[]>`
      SELECT DISTINCT ON (agent_id) agent_id AS "agentId", decision
      FROM location_consents
      WHERE client_id = ${clientId} AND agent_id IN (${ids}) AND notice_version = ${LOCATION_NOTICE_VERSION}
      ORDER BY agent_id, created_at DESC, id DESC`,
  ]);

  const declined = new Set(latestConsents.filter((c) => c.decision === 'declined').map((c) => c.agentId));
  // A declined agent's pings are never shown, so they are not matched to fences either.
  const shownPings = latestPings.filter((p) => !declined.has(p.agentId));
  const pingByAgent = new Map(shownPings.map((p) => [p.agentId, p]));
  const visitByAgent = new Map(latestVisits.map((v) => [v.agentId, v]));
  const outlets = await outletsNear(clientId, shownPings);

  return {
    ...envelope,
    nextCursor,
    data: page.map((agent) => {
      const ping = pingByAgent.get(agent.id) ?? null;
      const visit = visitByAgent.get(agent.id) ?? null;
      const fence = ping ? containingOutlet(ping, outlets) : null;
      const ageSeconds = ping
        ? Math.max(0, Math.floor((serverTime.getTime() - ping.recordedAt.getTime()) / 1000))
        : null;
      const state = deriveLiveState({
        ageSeconds,
        insideOutlet: fence !== null,
        accuracyM: ping?.accuracyM ?? null,
        intervalSeconds,
        declined: declined.has(agent.id),
      });

      let lastOutlet: AgentLocation['lastOutlet'] = null;
      if (fence && ping) {
        lastOutlet = { id: fence.id, name: fence.name, at: ping.recordedAt, source: 'ping' };
      } else if (visit) {
        lastOutlet = { id: visit.outletId, name: visit.outletName, at: visit.checkinTs, source: 'check_in' };
      }

      return {
        agentId: agent.id,
        name: personLabel(agent.displayName, agent.email),
        displayName: agent.displayName,
        email: agent.email,
        state,
        lastPing: ping
          ? { lat: ping.lat, lng: ping.lng, accuracyM: ping.accuracyM, recordedAt: ping.recordedAt }
          : null,
        ageSeconds,
        currentOutlet: state === 'at_store' && fence ? { id: fence.id, name: fence.name } : null,
        lastOutlet,
      };
    }),
  };
}
