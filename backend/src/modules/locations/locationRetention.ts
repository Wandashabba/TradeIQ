import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { RAW_PING_RETENTION_DAYS } from './locationPolicy';
import { FenceOutlet, containingOutlet, outletsNear } from './outletFence';

/**
 * Retention for agent location pings (#178).
 *
 * Product decision: raw pings are kept 90 days, then deleted while a per-day
 * stop summary (AgentDaySummary) is kept; a deactivated agent's raw pings are
 * deleted straight away, summaries kept the same way.
 *
 * NOTHING SCHEDULES THIS YET. The report scheduler (#66) is not on main; until
 * it is, run `npm run prune-location-pings` by hand or from cron. When the
 * scheduler exists it should call pruneLocationPings() directly — the loop
 * lives here, not in the script, for exactly that reason.
 *
 * **Day boundaries are UTC.** TODO(#309): use Client.timezone once it exists.
 * A UTC day cuts at 02:00 SAST, so an agent's 00:00–02:00 pings land in the
 * previous day's summary. The summary still records exact first/last instants,
 * so nothing is lost — only which row a late-night stop is filed under.
 *
 * Unit of work: one agent's one UTC day. Inside a single transaction it reads
 * that day's pings, folds them into the day's summary (merging with any summary
 * already there), and deletes exactly the pings it read. So:
 * - summaries are always written BEFORE, and atomically with, the delete — a
 *   crash leaves either both or neither;
 * - idempotent: a finished agent-day has no raw pings left, so a re-run finds
 *   nothing to fold and cannot double-count;
 * - resumable: nothing is remembered between runs; each loop picks the oldest
 *   remaining eligible ping, so a killed run continues where it stopped;
 * - race-safe: a ping inserted mid-transaction is not among the ids deleted,
 *   and is folded on a later run instead of vanishing unsummarised.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/** Midnight UTC at the start of `at`'s UTC day. TODO(#309): tenant timezone. */
export function utcDayStart(at: Date): Date {
  return new Date(Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate()));
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
  recordedAt: Date;
}

/**
 * Consecutive pings inside the same outlet fence become one stop, in
 * `recordedAt` order. A ping outside every fence ends the current stop, so
 * leaving a store and coming back is two stops — which is what happened.
 * `leftAt` is the last ping seen inside, not an exit time we never observed.
 */
export function foldStops(pings: PingForFold[], outlets: FenceOutlet[]): StopSummary[] {
  const sorted = [...pings].sort((a, b) => a.recordedAt.getTime() - b.recordedAt.getTime());
  const stops: StopSummary[] = [];
  let open: StopSummary | null = null;
  for (const ping of sorted) {
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
 * Folds one agent's one UTC day, atomically. Returns how many raw pings it
 * deleted (0 when there were none left).
 */
export async function summariseAgentDay(agentId: string, dayStart: Date): Promise<number> {
  const dayEnd = new Date(dayStart.getTime() + DAY_MS);
  return prisma.$transaction(
    async (tx) => {
      const pings = await tx.agentLocationPing.findMany({
        where: { agentId, recordedAt: { gte: dayStart, lt: dayEnd } },
        orderBy: [{ recordedAt: 'asc' }, { id: 'asc' }],
        select: { id: true, clientId: true, lat: true, lng: true, recordedAt: true },
      });
      if (pings.length === 0) return 0;

      const clientId = pings[0].clientId;
      const outlets = await outletsNear(clientId, pings, tx);
      const folded = foldStops(pings, outlets);
      const existing = await tx.agentDaySummary.findUnique({
        where: { agentId_day: { agentId, day: dayStart } },
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
        where: { agentId_day: { agentId, day: dayStart } },
        create: { clientId, agentId, day: dayStart, ...data },
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

export interface PurgeResult {
  agentDays: number;
  pingsDeleted: number;
}

/**
 * Folds and deletes EVERY raw ping of one agent — the deactivation path (#178).
 * Walks the agent's days oldest first, one transaction per day.
 */
export async function purgeAgentLocationPings(input: {
  clientId: string;
  agentId: string;
  log?: (line: string) => void;
}): Promise<PurgeResult> {
  const result: PurgeResult = { agentDays: 0, pingsDeleted: 0 };
  for (;;) {
    const oldest = await prisma.agentLocationPing.findFirst({
      where: { clientId: input.clientId, agentId: input.agentId },
      orderBy: { recordedAt: 'asc' },
      select: { recordedAt: true },
    });
    if (!oldest) break;
    const deleted = await summariseAgentDay(input.agentId, utcDayStart(oldest.recordedAt));
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
  /** Pings recorded before this are past retention. Start of a UTC day. */
  cutoff: Date;
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
 * 2. Pings past 90 days, whole UTC days only: the cutoff is the START of the
 *    day 90 days ago, so no day is ever summarised while part of it is still
 *    inside the window (and so could still gain raw pings from ingest).
 */
export async function pruneLocationPings(options: PruneOptions = {}): Promise<PruneResult> {
  const now = options.now ?? new Date();
  const cutoff = utcDayStart(new Date(now.getTime() - RAW_PING_RETENTION_DAYS * DAY_MS));
  const tenant = options.clientId ? { clientId: options.clientId } : {};
  const deactivatedWhere: Prisma.AgentLocationPingWhereInput = { ...tenant, agent: { active: false } };
  const expiredWhere: Prisma.AgentLocationPingWhereInput = { ...tenant, recordedAt: { lt: cutoff } };
  const result: PruneResult = {
    cutoff,
    dryRun: options.dryRun ?? false,
    expiredPings: 0,
    deactivatedAgentPings: 0,
    agentDaysSummarised: 0,
    pingsDeleted: 0,
    deactivatedAgentsPurged: 0,
    stoppedEarly: false,
  };

  if (result.dryRun) {
    [result.expiredPings, result.deactivatedAgentPings] = await Promise.all([
      prisma.agentLocationPing.count({ where: expiredWhere }),
      prisma.agentLocationPing.count({ where: deactivatedWhere }),
    ]);
    return result;
  }

  const budgetLeft = () =>
    options.maxAgentDays === undefined || result.agentDaysSummarised < options.maxAgentDays;

  // Pass 1: deactivated agents.
  while (budgetLeft()) {
    const ping = await prisma.agentLocationPing.findFirst({
      where: deactivatedWhere,
      orderBy: { recordedAt: 'asc' },
      select: { agentId: true, recordedAt: true },
    });
    if (!ping) break;
    result.pingsDeleted += await summariseAgentDay(ping.agentId, utcDayStart(ping.recordedAt));
    result.agentDaysSummarised += 1;
    const remaining = await prisma.agentLocationPing.count({ where: { agentId: ping.agentId } });
    if (remaining === 0) result.deactivatedAgentsPurged += 1;
    options.log?.(`deactivated: ${result.agentDaysSummarised} agent-day(s), ${result.pingsDeleted} ping(s) deleted`);
  }

  // Pass 2: whole days past retention.
  while (budgetLeft()) {
    const ping = await prisma.agentLocationPing.findFirst({
      where: expiredWhere,
      orderBy: { recordedAt: 'asc' },
      select: { agentId: true, recordedAt: true },
    });
    if (!ping) break;
    result.pingsDeleted += await summariseAgentDay(ping.agentId, utcDayStart(ping.recordedAt));
    result.agentDaysSummarised += 1;
    options.log?.(`expired: ${result.agentDaysSummarised} agent-day(s), ${result.pingsDeleted} ping(s) deleted`);
  }

  if (!budgetLeft()) {
    result.stoppedEarly =
      (await prisma.agentLocationPing.count({ where: { OR: [expiredWhere, deactivatedWhere] } })) > 0;
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
