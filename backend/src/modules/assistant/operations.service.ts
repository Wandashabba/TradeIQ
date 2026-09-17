import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { round2 } from '../../lib/kpiMath';
import { kpiThreshold } from '../../lib/kpiThresholds';
import { personLabel } from '../../lib/personName';
import { DEFAULT_PRICE_DEVIATION_THRESHOLD } from '../alerts/alerts.service';
import { campaignWindow } from '../campaigns/campaignWindow';
import {
  getCampaignCompliance,
  getCampaignRoi,
  listCampaigns,
  type CampaignCompliance,
  type CampaignRoi,
} from '../campaigns/campaigns.service';
import { getContestStandings, listContests, type ContestView } from '../contests/contests.service';
import { RECENTLY_ENDED_DAYS } from '../contests/contestRules';
import { getClientTimeZone } from '../clients/clients.service';
import { FORECAST_HISTORY_DAYS, getSkuForecast } from '../forecast/forecast.service';

/**
 * The assistant's read-only view of the operational modules (#362): territory
 * lookup, shelf pricing, campaigns, contests, tasks, alerts and the sell-in
 * forecast.
 *
 * **Why beside `pillars.service.ts` rather than inside it.** Same argument that
 * file makes for itself: tools wrap services and never write Prisma, and these
 * summaries are a different shape from what the modules expose (a page of
 * rows for a screen). Where a module already computes the figure — campaign
 * ROI and compliance, contest standings, the forecast — this delegates to it,
 * so the assistant and the console cannot quote different numbers. Where the
 * module only lists rows a page at a time (tasks, alerts, pricing), the
 * summary is an aggregate in the database instead, so no answer depends on how
 * many rows fit in a scan.
 *
 * Every function takes `clientId` and filters on it. Tenancy is never assumed
 * from the caller.
 */

/** Whether a territory id belongs to this tenant, and its outlet code if so. */
async function territoryCode(clientId: string, territoryId: string | undefined) {
  if (!territoryId) return undefined;
  const territory = await prisma.territory.findFirst({
    where: { id: territoryId, clientId },
    select: { code: true },
  });
  // An id from another tenant, or a guessed one, matches NOTHING rather than
  // everything — see `territoryFilter` in pillars.service.ts.
  return territory?.code ?? '__no-such-territory__';
}

// ── Territory lookup ──────────────────────────────────────────────────────

export interface TerritoryMatch {
  territoryId: string;
  name: string;
  code: string;
  region: string | null;
  outlets: number;
}

export interface TerritoryLookup {
  query: string | null;
  matchedBy: 'all' | 'exact' | 'partial' | 'region' | 'beat_plan' | 'none';
  matches: TerritoryMatch[];
  /** More matched than are listed. */
  truncated: boolean;
  note: string;
}

const MAX_TERRITORY_MATCHES = 25;

/** Words a manager adds to a place name that no territory is called. */
const GENERIC_PLACE_WORDS = /\b(the|beat|beats|territory|territories|area|region|district|route)\b/gi;

/**
 * Resolve what a manager called a place to territory ids.
 *
 * Steps, first hit wins: exact name or code; name or code containing the
 * query; region; a beat plan of that name. Each step is tenant-scoped, so a
 * name that exists only in another client resolves to nothing.
 */
export async function findTerritories(input: {
  clientId: string;
  query?: string;
}): Promise<TerritoryLookup> {
  const raw = input.query?.trim() ?? '';
  const cleaned = raw.replace(GENERIC_PLACE_WORDS, ' ').replace(/\s+/g, ' ').trim();
  const query = cleaned.length > 0 ? cleaned : raw;
  const select = { id: true, name: true, code: true, region: true } as const;
  const order = [{ name: 'asc' as const }, { id: 'asc' as const }];

  const find = (where: Prisma.TerritoryWhereInput) =>
    prisma.territory.findMany({
      where: { clientId: input.clientId, ...where },
      select,
      orderBy: order,
      take: MAX_TERRITORY_MATCHES + 1,
    });

  let matchedBy: TerritoryLookup['matchedBy'] = 'none';
  let rows: Awaited<ReturnType<typeof find>> = [];

  if (query.length === 0) {
    rows = await find({});
    matchedBy = 'all';
  } else {
    const steps: [TerritoryLookup['matchedBy'], Prisma.TerritoryWhereInput][] = [
      [
        'exact',
        {
          OR: [
            { name: { equals: query, mode: 'insensitive' } },
            { code: { equals: query, mode: 'insensitive' } },
          ],
        },
      ],
      [
        'partial',
        {
          OR: [
            { name: { contains: query, mode: 'insensitive' } },
            { code: { contains: query, mode: 'insensitive' } },
          ],
        },
      ],
      ['region', { region: { contains: query, mode: 'insensitive' } }],
    ];
    for (const [kind, where] of steps) {
      rows = await find(where);
      if (rows.length > 0) {
        matchedBy = kind;
        break;
      }
    }

    if (rows.length === 0) {
      const plans = await prisma.beatPlan.findMany({
        where: {
          clientId: input.clientId,
          name: { contains: query, mode: 'insensitive' },
          territoryId: { not: null },
        },
        select: { territoryId: true },
        distinct: ['territoryId'],
        take: MAX_TERRITORY_MATCHES + 1,
      });
      const ids = plans.map((p) => p.territoryId).filter((id): id is string => id !== null);
      if (ids.length > 0) {
        rows = await find({ id: { in: ids } });
        if (rows.length > 0) matchedBy = 'beat_plan';
      }
    }
  }

  const listed = rows.slice(0, MAX_TERRITORY_MATCHES);
  const counts =
    listed.length > 0
      ? await prisma.outlet.groupBy({
          by: ['territoryId'],
          where: { clientId: input.clientId, territoryId: { in: listed.map((t) => t.code) } },
          _count: { _all: true },
        })
      : [];
  const outletsByCode = new Map(counts.map((c) => [c.territoryId, c._count._all]));

  return {
    query: raw.length > 0 ? raw : null,
    matchedBy,
    matches: listed.map((t) => ({
      territoryId: t.id,
      name: t.name,
      code: t.code,
      region: t.region,
      outlets: outletsByCode.get(t.code) ?? 0,
    })),
    truncated: rows.length > MAX_TERRITORY_MATCHES,
    note:
      matchedBy === 'none'
        ? 'No territory matches. Do not guess an id; tell the user and offer the territories that exist.'
        : 'Pass territoryId to the tool that answers the question. If several match and the user ' +
          'meant one place, ask which; if they meant a whole region, say which territories it covers.',
  };
}

// ── Shelf pricing against RRP ─────────────────────────────────────────────

export interface PriceComplianceWindow {
  clientId: string;
  from: Date;
  to: Date;
  territoryId?: string;
  /** Part of an outlet or retail chain name, e.g. "QuickSave". */
  outletName?: string;
  /** A SKU id, or part of one of our SKU names. */
  sku?: string;
}

export interface PriceCompliance {
  /** Client's price-deviation threshold, in percent either side of RRP. */
  thresholdPct: number;
  pricedLines: number;
  outletsPriced: number;
  /** Signed mean of (shelf price − RRP) / RRP. Positive is above RRP. */
  avgDeviationPct: number;
  avgAbsDeviationPct: number;
  /** Share of priced lines more than `thresholdPct` ABOVE RRP. */
  linesAboveThresholdPct: number;
  /** Share of priced lines more than `thresholdPct` BELOW RRP. */
  linesBelowThresholdPct: number;
  promoActivePct: number;
  bySku: {
    skuId: string;
    skuName: string;
    rrp: number;
    avgShelfPrice: number;
    avgDeviationPct: number;
    lines: number;
    linesAboveThresholdPct: number;
  }[];
  /** Largest average deviation from RRP first, either direction. */
  worstOutlets: {
    outletId: string;
    outletName: string;
    outletCode: string;
    territoryCode: string;
    avgDeviationPct: number;
    lines: number;
    linesAboveThresholdPct: number;
  }[];
  basis: string;
}

const pctOf = (part: number, whole: number) => (whole > 0 ? round2((100 * part) / whole) : 0);

/**
 * Our shelf prices against RRP, from the pricing section agents capture.
 *
 * `deviation_pct` is stored at capture against the SKU's RRP then
 * (`price_master`), so a later RRP change does not rewrite history. Aggregated
 * in SQL: a business-wide month is tens of thousands of priced lines, and a
 * capped scan would report a partial average as the average.
 *
 * The threshold is the client's `kpiThresholds.priceDeviationPct` — the same
 * line the alert rule and the auto-created pricing tasks use.
 */
export async function getPriceCompliance(input: PriceComplianceWindow): Promise<PriceCompliance> {
  const [client, code] = await Promise.all([
    prisma.client.findUnique({ where: { id: input.clientId }, select: { kpiThresholds: true } }),
    territoryCode(input.clientId, input.territoryId),
  ]);
  const threshold = kpiThreshold(
    client?.kpiThresholds,
    'priceDeviationPct',
    DEFAULT_PRICE_DEVIATION_THRESHOLD,
  );

  const where = Prisma.sql`
    v."client_id" = ${input.clientId}
    AND o."client_id" = ${input.clientId}
    AND s."client_id" = ${input.clientId}
    AND v."checkin_ts" >= ${input.from.toISOString()}::timestamp
    AND v."checkin_ts" < ${input.to.toISOString()}::timestamp
    ${code !== undefined ? Prisma.sql`AND o."territory_id" = ${code}` : Prisma.empty}
    ${input.outletName ? Prisma.sql`AND o."name" ILIKE ${`%${escapeLike(input.outletName)}%`}` : Prisma.empty}
    ${
      input.sku
        ? Prisma.sql`AND (s."id" = ${input.sku} OR s."name" ILIKE ${`%${escapeLike(input.sku)}%`})`
        : Prisma.empty
    }
  `;
  const from = Prisma.sql`
    FROM "visit_pricing" p
    JOIN "visits" v ON v."id" = p."visit_id"
    JOIN "outlets" o ON o."id" = v."outlet_id"
    JOIN "skus" s ON s."id" = p."sku_id"
  `;
  const measures = Prisma.sql`
    COUNT(*)::int AS "lines",
    AVG(p."deviation_pct")::float AS "avgDev",
    COUNT(*) FILTER (WHERE p."deviation_pct" > ${threshold})::int AS "above"
  `;

  const [totals, bySku, byOutlet] = await Promise.all([
    prisma.$queryRaw<
      Array<{
        lines: number;
        outlets: number;
        avgDev: number | null;
        avgAbs: number | null;
        above: number;
        below: number;
        promo: number;
      }>
    >`
      SELECT ${measures},
        COUNT(DISTINCT v."outlet_id")::int AS "outlets",
        AVG(ABS(p."deviation_pct"))::float AS "avgAbs",
        COUNT(*) FILTER (WHERE p."deviation_pct" < ${-threshold})::int AS "below",
        COUNT(*) FILTER (WHERE p."promo_active")::int AS "promo"
      ${from} WHERE ${where}
    `,
    prisma.$queryRaw<
      Array<{ skuId: string; skuName: string; rrp: number; avgPrice: number; lines: number; avgDev: number; above: number }>
    >`
      SELECT s."id" AS "skuId", s."name" AS "skuName", AVG(p."price_master")::float AS "rrp",
        AVG(p."price_actual")::float AS "avgPrice", ${measures}
      ${from} WHERE ${where}
      GROUP BY s."id", s."name"
      ORDER BY ABS(AVG(p."deviation_pct")) DESC, s."name" ASC
      LIMIT 20
    `,
    prisma.$queryRaw<
      Array<{ outletId: string; outletName: string; outletCode: string; territoryCode: string; lines: number; avgDev: number; above: number }>
    >`
      SELECT o."id" AS "outletId", o."name" AS "outletName", o."code" AS "outletCode",
        o."territory_id" AS "territoryCode", ${measures}
      ${from} WHERE ${where}
      GROUP BY o."id", o."name", o."code", o."territory_id"
      ORDER BY ABS(AVG(p."deviation_pct")) DESC, o."name" ASC
      LIMIT 10
    `,
  ]);

  const t = totals[0];
  const lines = t?.lines ?? 0;
  return {
    thresholdPct: threshold,
    pricedLines: lines,
    outletsPriced: t?.outlets ?? 0,
    avgDeviationPct: round2(t?.avgDev ?? 0),
    avgAbsDeviationPct: round2(t?.avgAbs ?? 0),
    linesAboveThresholdPct: pctOf(t?.above ?? 0, lines),
    linesBelowThresholdPct: pctOf(t?.below ?? 0, lines),
    promoActivePct: pctOf(t?.promo ?? 0, lines),
    bySku: bySku.map((r) => ({
      skuId: r.skuId,
      skuName: r.skuName,
      rrp: round2(r.rrp),
      avgShelfPrice: round2(r.avgPrice),
      avgDeviationPct: round2(r.avgDev),
      lines: r.lines,
      linesAboveThresholdPct: pctOf(r.above, r.lines),
    })),
    worstOutlets: byOutlet.map((r) => ({
      outletId: r.outletId,
      outletName: r.outletName,
      outletCode: r.outletCode,
      territoryCode: r.territoryCode,
      avgDeviationPct: round2(r.avgDev),
      lines: r.lines,
      linesAboveThresholdPct: pctOf(r.above, r.lines),
    })),
    basis:
      'Shelf prices of OUR SKUs captured by agents on visits, against each SKU\'s RRP at capture. ' +
      'Positive deviation is above RRP. Competitor prices are not included.',
  };
}

/** `%` and `_` in a name are literal characters, not wildcards. */
function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (c) => `\\${c}`);
}

// ── Campaigns ─────────────────────────────────────────────────────────────

export type CampaignWindowState = 'upcoming' | 'running' | 'ended';

export interface CampaignSummary {
  campaignId: string;
  name: string;
  objective: string | null;
  /** The status a manager set: draft | active | completed. */
  status: string;
  /** Where today falls against the campaign's dates. */
  windowState: CampaignWindowState;
  /** Calendar dates, inclusive. */
  startDate: string;
  endDate: string;
  daysTotal: number;
  daysElapsed: number;
  budget: number | null;
  outlets: number;
  /** Null for a campaign that has not started: there is nothing to measure. */
  performance: {
    roi: CampaignRoi;
    /** incremental / baseline, in percent. Null when the baseline is zero. */
    liftPct: number | null;
    /** False while running: a partial window is measured against a full baseline. */
    liftComparable: boolean;
    execution: CampaignCompliance;
  } | null;
}

export interface CampaignPerformance {
  campaigns: CampaignSummary[];
  /** Campaigns that matched but were not measured, beyond the limit. */
  omitted: number;
  note: string;
}

/** How many campaigns one answer measures. Each is several queries. */
export const MAX_CAMPAIGNS = 8;

const calendarDate = (d: Date) => d.toISOString().slice(0, 10);

/**
 * Campaigns, with the ROI and execution figures the console shows for each.
 *
 * Delegates the measurement to `getCampaignRoi` and `getCampaignCompliance`, so
 * the numbers are the campaign screen's. What this adds is selection — by name,
 * by where today falls against the dates, by overlap with a period — and the
 * one caveat those endpoints leave to the reader: a running campaign's lift
 * compares the days so far against a full-length baseline.
 */
export async function getCampaignPerformance(input: {
  clientId: string;
  now: Date;
  campaign?: string;
  state?: CampaignWindowState;
  /** Campaigns whose dates overlap this window. */
  window?: { from: Date; to: Date };
}): Promise<CampaignPerformance> {
  const [page, timeZone] = await Promise.all([
    // A tenant has tens of campaigns, not thousands; one generous page is the
    // whole list, and `nextCursor` says so when it is not.
    listCampaigns({ clientId: input.clientId, limit: 200 }),
    getClientTimeZone(input.clientId),
  ]);

  const needle = input.campaign?.trim().toLowerCase();
  const matched = page.data
    .map((row) => {
      const window = campaignWindow(row.startDate, row.endDate, timeZone);
      const windowState: CampaignWindowState =
        input.now < window.from ? 'upcoming' : input.now >= window.to ? 'ended' : 'running';
      return { row, window, windowState };
    })
    .filter(({ row }) => !needle || row.name.toLowerCase().includes(needle))
    .filter(({ windowState }) => !input.state || windowState === input.state)
    .filter(
      ({ window }) => !input.window || (window.from < input.window.to && window.to > input.window.from),
    );

  const measured = matched.slice(0, MAX_CAMPAIGNS);
  const campaigns: CampaignSummary[] = [];
  // Sequential: each campaign is a handful of aggregates, and fanning eight out
  // at once doubles the peak load on a database also serving the console.
  for (const { row, window, windowState } of measured) {
    const daysElapsed =
      windowState === 'upcoming'
        ? 0
        : windowState === 'ended'
          ? window.days
          : Math.min(window.days, Math.floor((input.now.getTime() - window.from.getTime()) / 86_400_000) + 1);

    let performance: CampaignSummary['performance'] = null;
    if (windowState !== 'upcoming') {
      const roi = await getCampaignRoi(row.id, input.clientId);
      const execution = await getCampaignCompliance(row.id, input.clientId);
      performance = {
        roi,
        liftPct: roi.baselineRevenue > 0 ? round2((100 * roi.incrementalRevenue) / roi.baselineRevenue) : null,
        liftComparable: windowState === 'ended',
        execution,
      };
    }

    campaigns.push({
      campaignId: row.id,
      name: row.name,
      objective: row.objective,
      status: row.status,
      windowState,
      startDate: calendarDate(row.startDate),
      endDate: calendarDate(row.endDate),
      daysTotal: window.days,
      daysElapsed,
      budget: row.budget,
      outlets: row._count.outlets,
      performance,
    });
  }

  return {
    campaigns,
    omitted: matched.length - measured.length + (page.nextCursor ? 1 : 0),
    note:
      'Revenue figures are SELL-IN value (orders through TradeIQ), not consumer sales. ' +
      'Lift and ROI compare attributed orders with the same outlets over an equal-length ' +
      'window just before the campaign. For a running campaign (liftComparable false) the ' +
      'days so far are compared with a full baseline, so its lift and ROI are not yet ' +
      'meaningful. roiPct is null when no budget is recorded.',
  };
}

// ── Contests ──────────────────────────────────────────────────────────────

export type ContestFilter = 'current' | 'active' | 'ended' | 'upcoming' | 'cancelled' | 'all';

export interface ContestLeaderboard {
  contestId: string;
  name: string;
  description: string | null;
  prize: string | null;
  status: ContestView['status'];
  startDate: string;
  endDate: string;
  daysLeft: number | null;
  territory: string | null;
  countedEvents: string[];
  participants: number;
  /** Top of the board. Empty for an upcoming contest. */
  standings: {
    rank: number;
    agentId: string;
    agentName: string;
    points: number;
    visitsSubmitted: number;
    tasksClosed: number;
    avgScorecard: number;
  }[];
}

export const MAX_CONTESTS = 5;
export const STANDINGS_SHOWN = 10;

/**
 * Contests and who is leading them, from the contest module's own standings.
 *
 * `current` is what the agent app shows: active contests, and ones that ended
 * in the last {@link RECENTLY_ENDED_DAYS} days.
 */
export async function getContestLeaderboards(input: {
  clientId: string;
  now: Date;
  contest?: string;
  filter: ContestFilter;
}): Promise<{ contests: ContestLeaderboard[]; omitted: number }> {
  const page = await listContests({ clientId: input.clientId, limit: 200, now: input.now });
  const needle = input.contest?.trim().toLowerCase();
  const recentCutoff = new Date(input.now.getTime() - RECENTLY_ENDED_DAYS * 86_400_000);

  const matched = page.data
    .filter((c) => !needle || c.name.toLowerCase().includes(needle))
    .filter((c) => {
      switch (input.filter) {
        case 'all':
          return true;
        case 'current':
          return c.status === 'active' || (c.status === 'ended' && new Date(c.window.to) >= recentCutoff);
        default:
          return c.status === input.filter;
      }
    });

  const shown = matched.slice(0, MAX_CONTESTS);
  const contests: ContestLeaderboard[] = [];
  for (const contest of shown) {
    const board =
      contest.status === 'upcoming' ? null : await getContestStandings(contest.id, input.clientId);
    contests.push({
      contestId: contest.id,
      name: contest.name,
      description: contest.description,
      prize: contest.prizeDescription,
      status: contest.status,
      startDate: contest.startDate,
      endDate: contest.endDate,
      daysLeft: contest.daysLeft,
      territory: contest.territory?.name ?? null,
      countedEvents: contest.eventTypes.length > 0 ? contest.eventTypes : ['all'],
      participants: board?.participantCount ?? 0,
      standings: (board?.standings ?? []).slice(0, STANDINGS_SHOWN).map((s) => ({
        rank: s.rank,
        agentId: s.agentId,
        agentName: personLabel(s.displayName, s.email),
        points: s.points,
        visitsSubmitted: s.visitsSubmitted,
        tasksClosed: s.tasksClosed,
        avgScorecard: s.avgScorecard,
      })),
    });
  }

  return { contests, omitted: matched.length - shown.length + (page.nextCursor ? 1 : 0) };
}

// ── Tasks ─────────────────────────────────────────────────────────────────

export interface TaskSummary {
  /** As of now, whatever the period. */
  backlog: {
    open: number;
    inProgress: number;
    overdue: number;
    overdueByPriority: { priority: string; overdue: number }[];
  };
  /** Present only when a period was given: tasks raised inside it. */
  raisedInPeriod: { raised: number; closed: number; stillOpen: number; overdue: number } | null;
  overdueByAgent: { agentId: string; agentName: string; overdue: number }[];
  overdueByTerritory: { territoryCode: string; territoryName: string | null; overdue: number }[];
  oldestOverdue: {
    taskId: string;
    findingType: string;
    requiredFix: string;
    priority: string;
    slaDueAt: string;
    outletName: string;
    ownerName: string;
  }[];
  note: string;
}

/**
 * Follow-up tasks: the backlog now, who and where it sits, and — for a period
 * — what was raised and closed.
 *
 * Overdue means not closed and past its SLA due time at `now`. Tasks carry no
 * client id of their own; tenancy goes through the outlet, as in
 * `tasks.service.ts`.
 */
export async function getTaskSummary(input: {
  clientId: string;
  now: Date;
  window?: { from: Date; to: Date };
  territoryId?: string;
  agentId?: string;
}): Promise<TaskSummary> {
  const code = await territoryCode(input.clientId, input.territoryId);
  const scope: Prisma.TaskWhereInput = {
    outlet: { clientId: input.clientId, ...(code !== undefined ? { territoryId: code } : {}) },
    ...(input.agentId ? { ownerId: input.agentId } : {}),
  };
  const overdue: Prisma.TaskWhereInput = {
    ...scope,
    status: { not: 'closed' },
    slaDueAt: { lt: input.now },
  };

  const open = await prisma.task.count({ where: { ...scope, status: 'open' } });
  const inProgress = await prisma.task.count({ where: { ...scope, status: 'in_progress' } });
  const overdueCount = await prisma.task.count({ where: overdue });
  const byPriority = await prisma.task.groupBy({
    by: ['priority'],
    where: overdue,
    _count: { _all: true },
  });

  let raisedInPeriod: TaskSummary['raisedInPeriod'] = null;
  if (input.window) {
    const raised: Prisma.TaskWhereInput = {
      ...scope,
      createdAt: { gte: input.window.from, lt: input.window.to },
    };
    const byStatus = await prisma.task.groupBy({ by: ['status'], where: raised, _count: { _all: true } });
    const count = (s: string) => byStatus.find((g) => g.status === s)?._count._all ?? 0;
    raisedInPeriod = {
      raised: byStatus.reduce((sum, g) => sum + g._count._all, 0),
      closed: count('closed'),
      stillOpen: count('open') + count('in_progress'),
      overdue: await prisma.task.count({
        where: { ...raised, status: { not: 'closed' }, slaDueAt: { lt: input.now } },
      }),
    };
  }

  const byOwner = await prisma.task.groupBy({
    by: ['ownerId'],
    where: overdue,
    _count: { _all: true },
    orderBy: { _count: { ownerId: 'desc' } },
    take: 10,
  });
  const owners = await prisma.user.findMany({
    where: { clientId: input.clientId, id: { in: byOwner.map((g) => g.ownerId) } },
    select: { id: true, email: true, displayName: true },
  });
  const ownerName = new Map(owners.map((u) => [u.id, personLabel(u.displayName, u.email)]));

  const byOutlet = await prisma.task.groupBy({ by: ['outletId'], where: overdue, _count: { _all: true } });
  const outlets = await prisma.outlet.findMany({
    where: { clientId: input.clientId, id: { in: byOutlet.map((g) => g.outletId) } },
    select: { id: true, territoryId: true },
  });
  const codeOfOutlet = new Map(outlets.map((o) => [o.id, o.territoryId]));
  const perCode = new Map<string, number>();
  for (const g of byOutlet) {
    const c = codeOfOutlet.get(g.outletId);
    if (c !== undefined) perCode.set(c, (perCode.get(c) ?? 0) + g._count._all);
  }
  const territories = await prisma.territory.findMany({
    where: { clientId: input.clientId, code: { in: [...perCode.keys()] } },
    select: { code: true, name: true },
  });
  const territoryName = new Map(territories.map((t) => [t.code, t.name]));

  const oldest = await prisma.task.findMany({
    where: overdue,
    orderBy: [{ slaDueAt: 'asc' }, { id: 'asc' }],
    take: 5,
    select: {
      id: true,
      findingType: true,
      requiredFix: true,
      priority: true,
      slaDueAt: true,
      outlet: { select: { name: true } },
      owner: { select: { email: true, displayName: true } },
    },
  });

  return {
    backlog: {
      open,
      inProgress,
      overdue: overdueCount,
      overdueByPriority: byPriority
        .map((g) => ({ priority: g.priority, overdue: g._count._all }))
        .sort((a, b) => b.overdue - a.overdue || a.priority.localeCompare(b.priority)),
    },
    raisedInPeriod,
    overdueByAgent: byOwner
      .filter((g) => ownerName.has(g.ownerId))
      .map((g) => ({ agentId: g.ownerId, agentName: ownerName.get(g.ownerId)!, overdue: g._count._all })),
    overdueByTerritory: [...perCode.entries()]
      .map(([territoryCode, count]) => ({
        territoryCode,
        territoryName: territoryName.get(territoryCode) ?? null,
        overdue: count,
      }))
      .sort((a, b) => b.overdue - a.overdue || a.territoryCode.localeCompare(b.territoryCode))
      .slice(0, 15),
    oldestOverdue: oldest.map((t) => ({
      taskId: t.id,
      findingType: t.findingType,
      requiredFix: t.requiredFix,
      priority: t.priority,
      slaDueAt: t.slaDueAt.toISOString(),
      outletName: t.outlet.name,
      ownerName: personLabel(t.owner.displayName, t.owner.email),
    })),
    note:
      'Overdue means not closed and past its SLA due time now. The backlog and overdue ' +
      'breakdowns are as of now whatever the period; raisedInPeriod covers tasks created in the period.',
  };
}

// ── Alerts ────────────────────────────────────────────────────────────────

export const ALERT_TYPES = ['out_of_stock', 'price_deviation', 'low_scorecard', 'sla_breach'] as const;
export type AlertType = (typeof ALERT_TYPES)[number];

export interface AlertSummary {
  raised: number;
  unacknowledged: number;
  byType: { type: string; raised: number; unacknowledged: number }[];
  unacknowledgedBySeverity: { severity: string; unacknowledged: number }[];
  /** Outlets with the most unacknowledged alerts. */
  topOutlets: { outletId: string; outletName: string; unacknowledged: number }[];
  newestUnacknowledged: {
    alertId: string;
    type: string;
    severity: string;
    message: string;
    outletName: string | null;
    raisedAt: string;
  }[];
}

/**
 * Alerts raised by the alert rules, and whether anyone has acknowledged them.
 *
 * Counts are grouped in the database rather than paged through
 * `listAlerts`, which serves a screen twenty rows at a time.
 */
export async function getAlertSummary(input: {
  clientId: string;
  window?: { from: Date; to: Date };
  territoryId?: string;
  type?: AlertType;
}): Promise<AlertSummary> {
  const code = await territoryCode(input.clientId, input.territoryId);
  let outletIds: string[] | undefined;
  if (code !== undefined) {
    const outlets = await prisma.outlet.findMany({
      where: { clientId: input.clientId, territoryId: code },
      select: { id: true },
    });
    outletIds = outlets.map((o) => o.id);
  }

  const scope: Prisma.AlertWhereInput = {
    clientId: input.clientId,
    ...(input.window ? { createdAt: { gte: input.window.from, lt: input.window.to } } : {}),
    ...(input.type ? { metric: input.type } : {}),
    ...(outletIds ? { outletId: { in: outletIds } } : {}),
  };
  const open: Prisma.AlertWhereInput = { ...scope, acknowledged: false };

  const byTypeState = await prisma.alert.groupBy({
    by: ['metric', 'acknowledged'],
    where: scope,
    _count: { _all: true },
  });
  const types = new Map<string, { raised: number; unacknowledged: number }>();
  for (const g of byTypeState) {
    const entry = types.get(g.metric) ?? { raised: 0, unacknowledged: 0 };
    entry.raised += g._count._all;
    if (!g.acknowledged) entry.unacknowledged += g._count._all;
    types.set(g.metric, entry);
  }

  const bySeverity = await prisma.alert.groupBy({ by: ['severity'], where: open, _count: { _all: true } });
  const byOutlet = await prisma.alert.groupBy({
    by: ['outletId'],
    where: { ...open, outletId: outletIds ? { in: outletIds } : { not: null } },
    _count: { _all: true },
    orderBy: [{ _count: { outletId: 'desc' } }, { outletId: 'asc' }],
    take: 10,
  });
  const newest = await prisma.alert.findMany({
    where: open,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: 10,
    select: { id: true, metric: true, severity: true, message: true, outletId: true, createdAt: true },
  });

  const namedIds = [
    ...new Set([
      ...byOutlet.map((g) => g.outletId),
      ...newest.map((a) => a.outletId),
    ].filter((id): id is string => id !== null)),
  ];
  const outlets = await prisma.outlet.findMany({
    where: { clientId: input.clientId, id: { in: namedIds } },
    select: { id: true, name: true },
  });
  const outletName = new Map(outlets.map((o) => [o.id, o.name]));

  const byType = [...types.entries()]
    .map(([type, v]) => ({ type, ...v }))
    .sort((a, b) => b.raised - a.raised || a.type.localeCompare(b.type));

  return {
    raised: byType.reduce((sum, t) => sum + t.raised, 0),
    unacknowledged: byType.reduce((sum, t) => sum + t.unacknowledged, 0),
    byType,
    unacknowledgedBySeverity: bySeverity
      .map((g) => ({ severity: g.severity, unacknowledged: g._count._all }))
      .sort((a, b) => b.unacknowledged - a.unacknowledged || a.severity.localeCompare(b.severity)),
    topOutlets: byOutlet
      .filter((g) => g.outletId !== null && outletName.has(g.outletId))
      .map((g) => ({
        outletId: g.outletId!,
        outletName: outletName.get(g.outletId!)!,
        unacknowledged: g._count._all,
      })),
    newestUnacknowledged: newest.map((a) => ({
      alertId: a.id,
      type: a.metric,
      severity: a.severity,
      message: a.message,
      outletName: a.outletId ? (outletName.get(a.outletId) ?? null) : null,
      raisedAt: a.createdAt.toISOString(),
    })),
  };
}

// ── Sell-in forecast ──────────────────────────────────────────────────────

export class SkuLookupError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SkuLookupError';
  }
}

export class OutletLookupError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'OutletLookupError';
  }
}

/** Resolve an id or a name to one of this tenant's SKUs, or say why not. */
export async function resolveSku(clientId: string, query: string) {
  const q = query.trim();
  const select = { id: true, name: true } as const;
  const byId = await prisma.sku.findFirst({ where: { id: q, clientId }, select });
  if (byId) return byId;

  for (const where of [
    { name: { equals: q, mode: 'insensitive' as const } },
    { name: { contains: q, mode: 'insensitive' as const } },
  ]) {
    const matches = await prisma.sku.findMany({
      where: { clientId, ...where },
      select,
      orderBy: { name: 'asc' },
      take: 6,
    });
    if (matches.length === 1) return matches[0];
    if (matches.length > 1) {
      throw new SkuLookupError(
        `More than one product matches "${q}": ${matches
          .slice(0, 5)
          .map((m) => m.name)
          .join(', ')}${matches.length > 5 ? ', and others' : ''}. Ask which one.`,
      );
    }
  }
  throw new SkuLookupError(`No product matches "${q}".`);
}

export interface SellInForecast {
  skuId: string;
  skuName: string;
  outletId: string | null;
  outletName: string | null;
  /** Units a day outlets are expected to order, next day. */
  forecastDailyUnits: number;
  /** Latest counted shelf units ÷ forecast daily units. Null when the forecast is zero. */
  daysOfCover: number | null;
  historyDays: number;
  /** Units ordered per complete local day, oldest first, zero-filled. */
  historyPoints: number[];
  historyTotalUnits: number;
  daysWithOrders: number;
  method: string;
  confidence: null;
  confidenceNote: string;
}

/**
 * The per-SKU sell-in forecast, from `modules/forecast`.
 *
 * `confidence` is always null, and that is the point of the field: the
 * forecast is simple exponential smoothing with no error model, and a result
 * with no confidence field invites a model to supply one.
 */
export async function getSellInForecast(input: {
  clientId: string;
  now: Date;
  sku: string;
  outletId?: string;
}): Promise<SellInForecast> {
  const sku = await resolveSku(input.clientId, input.sku);
  let outlet: { id: string; name: string } | null = null;
  if (input.outletId) {
    outlet = await prisma.outlet.findFirst({
      where: { id: input.outletId, clientId: input.clientId },
      select: { id: true, name: true },
    });
    if (!outlet) throw new OutletLookupError('No outlet with that id.');
  }

  const forecast = await getSkuForecast(
    { clientId: input.clientId, skuId: sku.id, ...(outlet ? { outletId: outlet.id } : {}) },
    input.now,
  );
  const daysWithOrders = forecast.historyPoints.filter((units) => units > 0).length;

  return {
    skuId: sku.id,
    skuName: sku.name,
    outletId: outlet?.id ?? null,
    outletName: outlet?.name ?? null,
    forecastDailyUnits: forecast.forecastNextPeriod,
    daysOfCover: Number.isFinite(forecast.forecastCoverageDays) ? forecast.forecastCoverageDays : null,
    historyDays: forecast.historyDays,
    historyPoints: forecast.historyPoints,
    historyTotalUnits: forecast.historyPoints.reduce((sum, units) => sum + units, 0),
    daysWithOrders,
    method:
      `Simple exponential smoothing (alpha 0.5) over the last ${FORECAST_HISTORY_DAYS} complete ` +
      'days of SELL-IN (units ordered through TradeIQ, not consumer sales). Recent days weigh most.',
    confidence: null,
    confidenceNote:
      'No confidence interval, error band or measured accuracy exists for this forecast. It is a ' +
      `single smoothed estimate from ${daysWithOrders} of ${FORECAST_HISTORY_DAYS} days with orders; ` +
      'it does not model seasonality, promotions or trend.',
  };
}
