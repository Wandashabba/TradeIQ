import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { addCalendarDays, localCalendarDate, startOfLocalDay } from '../../lib/clientTime';
import { getClientTimeZone } from '../clients/clients.service';
import { PingSource, RAW_PING_RETENTION_DAYS, confirmsStorePresence } from './locationPolicy';
import { FenceOutlet, containingOutlet, outletsNear } from './outletFence';

/**
 * Retention for agent location pings (#178).
 *
 * Product decision: raw pings are kept 90 days, then deleted while a per-day
 * stop summary (AgentDaySummary) is kept; a deactivated agent's raw pings are
 * deleted straight away, summaries kept the same way.
 *
 * Runs daily on the in-process location prune worker
 * (locationPrune.worker.ts, started from server.ts), by hand with
 * `npm run prune-location-pings`, and for one agent on deactivation.
 *
 * **Days are the client's local calendar days** (`Client.timezone`, #309), in
 * the `clientTime.ts` conventions: `AgentDaySummary.day` is a calendar date
 * stored as UTC midnight of that date, and the pings that belong to it are the
 * instants from the start of that local day to the start of the next. A
 * Johannesburg agent's 23:30Z ping is 01:30 the next morning, so it is filed
 * under the next day. The 90-day cutoff is likewise the start of the client's
 * local day 90 days ago.
 *
 * Unit of work: one agent's one local day. Inside a single transaction it
 * reads that day's pings, folds them into the day's summary (merging with any
 * summary already there), and deletes exactly the pings it read. So:
 * - summaries are always written BEFORE, and atomically with, the delete — a
 *   crash leaves either both or neither;
 * - idempotent: a finished agent-day has no raw pings left, so a re-run finds
 *   nothing to fold and cannot double-count;
 * - resumable: nothing is remembered between runs; each loop picks the oldest
 *   remaining eligible ping, so a killed run continues where it stopped;
 * - race-safe: a ping inserted mid-transaction is not among the ids deleted,
 *   and is folded on a later run instead of vanishing unsummarised;
 * - safe to run concurrently (several API instances, the worker and the
 *   script, a deactivation): each fold takes a transaction-scoped advisory lock
 *   on the agent, so two folds of one agent queue rather than both reading the
 *   same pings and both merging them into the summary.
 */

/**
 * The instant before which a client's pings are past retention: the start of
 * the client's local calendar day {@link RAW_PING_RETENTION_DAYS} days ago.
 * Whole local days only, so no day is summarised while part of it is still
 * inside the window (and so could still gain raw pings from ingest).
 */
export function retentionCutoff(now: Date, timeZone: string): Date {
  const today = localCalendarDate(now, timeZone);
  return startOfLocalDay(addCalendarDays(today, -RAW_PING_RETENTION_DAYS), timeZone);
}

export interface StopSummary {
  outletId: string;
  outletName: string;
  arrivedAt: string;
  leftAt: string;
  pingCount: number;
}

interface PingForFold {
  lat: number;
  lng: number;
  accuracyM: number | null;
  recordedAt: Date;
  /** `foreground` or `background`; absent is read as `foreground`. */
  source?: string | null;
}

/**
 * Consecutive pings inside the same outlet fence become one stop, in
 * `recordedAt` order. A ping outside every fence ends the current stop, so
 * leaving a store and coming back is two stops — which is what happened.
 * `leftAt` is the last ping seen inside, not an exit time we never observed.
 *
 * **Only pings that can confirm a store count** (`confirmsStorePresence`, the
 * same rule that separates `at_store` from `near_store` on the live map, so the
 * two never disagree about what counted as being at a store). That excludes:
 *
 * - a ping with poor or unknown accuracy;
 * - **every background ping** (#153 T2) — taken by a service on a timer with
 *   the phone in a pocket, which is not evidence that anyone was in the shop.
 *
 * Such a ping is skipped entirely: it neither opens, extends nor ends a stop.
 * It cannot confirm the agent was in a store, and it cannot confirm they left
 * one either — poor fixes are mostly indoor fixes, and a background fix taken
 * mid-visit says nothing about leaving — so letting either end a stop would
 * split one long visit into several. They still count towards the day's
 * `pingCount`, `firstPingAt` and `lastPingAt`, because those describe sharing,
 * not stores.
 */
export function foldStops(pings: PingForFold[], outlets: FenceOutlet[]): StopSummary[] {
  const sorted = [...pings].sort((a, b) => a.recordedAt.getTime() - b.recordedAt.getTime());
  const stops: StopSummary[] = [];
  let open: StopSummary | null = null;
  for (const ping of sorted) {
    const source: PingSource = ping.source === 'background' ? 'background' : 'foreground';
    if (!confirmsStorePresence(source, ping.accuracyM)) continue;
    const outlet = containingOutlet(ping, outlets);
    if (!outlet) {
      open = null;
      continue;
    }
    if (open && open.outletId === outlet.id) {
      open.leftAt = ping.recordedAt.toISOString();
      open.pingCount += 1;
      continue;
    }
    open = {
      outletId: outlet.id,
      outletName: outlet.name,
      arrivedAt: ping.recordedAt.toISOString(),
      leftAt: ping.recordedAt.toISOString(),
      pingCount: 1,
    };
    stops.push(open);
  }
  return stops;
}

function asStops(value: Prisma.JsonValue): StopSummary[] {
  return Array.isArray(value) ? (value as unknown as StopSummary[]) : [];
}

/**
 * Folds one agent's one local calendar day (`day`, a calendar date in the
 * clientTime.ts convention, of `timeZone`), atomically. Returns how many raw
 * pings it deleted (0 when there were none left).
 */
export async function summariseAgentDay(agentId: string, day: Date, timeZone: string): Promise<number> {
  const from = startOfLocalDay(day, timeZone);
  const to = startOfLocalDay(addCalendarDays(day, 1), timeZone);
  return prisma.$transaction(
    async (tx) => {
      // Released at commit or rollback. See the concurrency note above.
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${agentId}))::text AS locked`;

      const pings = await tx.agentLocationPing.findMany({
        where: { agentId, recordedAt: { gte: from, lt: to } },
        orderBy: [{ recordedAt: 'asc' }, { id: 'asc' }],
        // `source` because a background ping counts towards the day's totals
        // but can never open a stop — see foldStops.
        select: {
          id: true,
          clientId: true,
          lat: true,
          lng: true,
          accuracyM: true,
          recordedAt: true,
          source: true,
        },
      });
      if (pings.length === 0) return 0;

      const clientId = pings[0].clientId;
      const outlets = await outletsNear(clientId, pings, tx);
      const folded = foldStops(pings, outlets);
      const existing = await tx.agentDaySummary.findUnique({
        where: { agentId_day: { agentId, day } },
      });

      const first = pings[0].recordedAt;
      const last = pings[pings.length - 1].recordedAt;
      const stops = [...(existing ? asStops(existing.stops) : []), ...folded].sort((a, b) =>
        a.arrivedAt.localeCompare(b.arrivedAt),
      );
      const data = {
        firstPingAt: existing && existing.firstPingAt < first ? existing.firstPingAt : first,
        lastPingAt: existing && existing.lastPingAt > last ? existing.lastPingAt : last,
        pingCount: (existing?.pingCount ?? 0) + pings.length,
        stops: stops as unknown as Prisma.InputJsonValue,
      };
      await tx.agentDaySummary.upsert({
        where: { agentId_day: { agentId, day } },
        create: { clientId, agentId, day, ...data },
        update: data,
      });

      const { count } = await tx.agentLocationPing.deleteMany({
        where: { id: { in: pings.map((p) => p.id) } },
      });
      return count;
    },
    // A busy day is a few hundred rows; the default 5s is for request paths.
    { timeout: 60_000 },
  );
}

/** Folds the local day `recordedAt` falls on, in `timeZone`. */
function summariseDayOf(agentId: string, recordedAt: Date, timeZone: string): Promise<number> {
  return summariseAgentDay(agentId, localCalendarDate(recordedAt, timeZone), timeZone);
}

export interface PurgeResult {
  agentDays: number;
  pingsDeleted: number;
}

/**
 * Folds and deletes EVERY raw ping of one agent — the deactivation path (#178).
 * Walks the agent's local days oldest first, one transaction per day.
 */
export async function purgeAgentLocationPings(input: {
  clientId: string;
  agentId: string;
  log?: (line: string) => void;
}): Promise<PurgeResult> {
  const timeZone = await getClientTimeZone(input.clientId);
  const result: PurgeResult = { agentDays: 0, pingsDeleted: 0 };
  for (;;) {
    const oldest = await prisma.agentLocationPing.findFirst({
      where: { clientId: input.clientId, agentId: input.agentId },
      orderBy: { recordedAt: 'asc' },
      select: { recordedAt: true },
    });
    if (!oldest) break;
    const deleted = await summariseDayOf(input.agentId, oldest.recordedAt, timeZone);
    result.agentDays += 1;
    result.pingsDeleted += deleted;
    input.log?.(`agent ${input.agentId}: folded ${result.agentDays} day(s), deleted ${result.pingsDeleted} ping(s)`);
  }
  return result;
}

export interface PruneOptions {
  /** Only this tenant. */
  clientId?: string;
  /** Count what would be deleted; delete nothing. */
  dryRun?: boolean;
  /** Stop after this many agent-days (the whole run is resumable). Default: no limit. */
  maxAgentDays?: number;
  /** The clock, for tests. */
  now?: Date;
  log?: (line: string) => void;
}

export interface PruneResult {
  /** Local days of raw pings kept, before a client's cutoff. */
  retentionDays: number;
  dryRun: boolean;
  /** Dry run: pings past retention. Otherwise 0. */
  expiredPings: number;
  /** Dry run: raw pings still held for deactivated agents. Otherwise 0. */
  deactivatedAgentPings: number;
  agentDaysSummarised: number;
  pingsDeleted: number;
  deactivatedAgentsPurged: number;
  /** True when `maxAgentDays` stopped the run before it ran out of work. */
  stoppedEarly: boolean;
}

/**
 * The retention job. Two passes:
 * 1. Deactivated agents — catches any the PATCH /users/:id hook missed (it is
 *    best-effort so that a failure cannot block a deactivation).
 * 2. Pings before each client's cutoff ({@link retentionCutoff}), client by
 *    client, since every client has its own calendar.
 */
export async function pruneLocationPings(options: PruneOptions = {}): Promise<PruneResult> {
  const now = options.now ?? new Date();
  const tenant = options.clientId ? { clientId: options.clientId } : {};
  const deactivatedWhere: Prisma.AgentLocationPingWhereInput = { ...tenant, agent: { active: false } };
  const result: PruneResult = {
    retentionDays: RAW_PING_RETENTION_DAYS,
    dryRun: options.dryRun ?? false,
    expiredPings: 0,
    deactivatedAgentPings: 0,
    agentDaysSummarised: 0,
    pingsDeleted: 0,
    deactivatedAgentsPurged: 0,
    stoppedEarly: false,
  };

  const zones = new Map<string, string>();
  const zoneOf = async (clientId: string) => {
    let zone = zones.get(clientId);
    if (!zone) {
      zone = await getClientTimeZone(clientId);
      zones.set(clientId, zone);
    }
    return zone;
  };

  // Only clients that hold any pings — a GROUP BY, not every tenant.
  const clientIds = (
    await prisma.agentLocationPing.groupBy({ by: ['clientId'], where: tenant, orderBy: { clientId: 'asc' } })
  ).map((row) => row.clientId);
  const expiredWhere = async (clientId: string): Promise<Prisma.AgentLocationPingWhereInput> => ({
    clientId,
    recordedAt: { lt: retentionCutoff(now, await zoneOf(clientId)) },
  });

  if (result.dryRun) {
    result.deactivatedAgentPings = await prisma.agentLocationPing.count({ where: deactivatedWhere });
    for (const clientId of clientIds) {
      result.expiredPings += await prisma.agentLocationPing.count({ where: await expiredWhere(clientId) });
    }
    return result;
  }

  const budgetLeft = () =>
    options.maxAgentDays === undefined || result.agentDaysSummarised < options.maxAgentDays;

  // Pass 1: deactivated agents.
  while (budgetLeft()) {
    const ping = await prisma.agentLocationPing.findFirst({
      where: deactivatedWhere,
      orderBy: { recordedAt: 'asc' },
      select: { agentId: true, clientId: true, recordedAt: true },
    });
    if (!ping) break;
    result.pingsDeleted += await summariseDayOf(ping.agentId, ping.recordedAt, await zoneOf(ping.clientId));
    result.agentDaysSummarised += 1;
    const remaining = await prisma.agentLocationPing.count({ where: { agentId: ping.agentId } });
    if (remaining === 0) result.deactivatedAgentsPurged += 1;
    options.log?.(`deactivated: ${result.agentDaysSummarised} agent-day(s), ${result.pingsDeleted} ping(s) deleted`);
  }

  // Pass 2: whole local days past retention, per client.
  for (const clientId of clientIds) {
    const where = await expiredWhere(clientId);
    const timeZone = await zoneOf(clientId);
    while (budgetLeft()) {
      const ping = await prisma.agentLocationPing.findFirst({
        where,
        orderBy: { recordedAt: 'asc' },
        select: { agentId: true, recordedAt: true },
      });
      if (!ping) break;
      result.pingsDeleted += await summariseDayOf(ping.agentId, ping.recordedAt, timeZone);
      result.agentDaysSummarised += 1;
      options.log?.(`expired: ${result.agentDaysSummarised} agent-day(s), ${result.pingsDeleted} ping(s) deleted`);
    }
  }

  if (!budgetLeft()) {
    let remaining = await prisma.agentLocationPing.count({ where: deactivatedWhere });
    for (const clientId of clientIds) {
      if (remaining > 0) break;
      remaining += await prisma.agentLocationPing.count({ where: await expiredWhere(clientId) });
    }
    result.stoppedEarly = remaining > 0;
  }
  return result;
}

/**
 * Parses scripts/prune-location-pings.ts flags. Here rather than in the script
 * so it is tested; throws on a malformed value because the command deletes rows.
 */
export function parsePruneArgs(argv: string[]): PruneOptions {
  const options: PruneOptions = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      options.dryRun = true;
      continue;
    }
    if (arg !== '--client' && arg !== '--max-agent-days') {
      throw new Error(`Unknown argument "${arg}"`);
    }
    const value = argv[i + 1];
    if (value === undefined || value.startsWith('--')) {
      throw new Error(`${arg} needs a value`);
    }
    i += 1;
    if (arg === '--client') {
      options.clientId = value;
    } else {
      const n = Number(value);
      if (!Number.isInteger(n) || n <= 0) {
        throw new Error(`--max-agent-days must be a positive integer, got "${value}"`);
      }
      options.maxAgentDays = n;
    }
  }
  return options;
}
