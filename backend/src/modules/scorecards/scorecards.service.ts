import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';
import { facingsTotal, mean, round2 } from '../../lib/kpiMath';
import { personLabel } from '../../lib/personName';

export const SCORECARD_DIMENSIONS = [
  'availability',
  'visibility',
  'display',
  'pricing',
  'competitive',
  'salesCapability',
] as const;

export type ScorecardDimension = (typeof SCORECARD_DIMENSIONS)[number];

const DEFAULT_GREEN_THRESHOLD = 80;
const DEFAULT_AMBER_THRESHOLD = 60;

function clamp(value: number, min = 0, max = 100): number {
  return Math.min(max, Math.max(min, value));
}

/**
 * Safely read a Prisma Json column as a string->number record, dropping any
 * non-numeric (or non-finite) values.
 */
function asNumberRecord(value: unknown): Record<string, number> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return {};
  }
  const out: Record<string, number> = {};
  for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
    if (typeof entry === 'number' && Number.isFinite(entry)) {
      out[key] = entry;
    }
  }
  return out;
}

export interface GenerateScorecardInput {
  visitId: string;
  clientId: string;
  agentId: string;
}

export async function generateScorecard(input: GenerateScorecardInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
    include: {
      client: true,
      stock: true,
      visibility: true,
      pricing: true,
      competitive: true,
      capability: true,
    },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const { client, stock, visibility, pricing, competitive, capability } = visit;

  // availability: share of captured SKUs that are on shelf.
  const availability =
    stock.length > 0
      ? clamp((100 * stock.filter((row) => row.unitsAvailable > 0).length) / stock.length)
      : 0;

  // visibility: planogram compliance as captured.
  const visibilityScore = visibility ? clamp(visibility.planogramCompliancePct) : 0;

  // display: cleanliness is captured on a 1-5 scale, mapped onto 0-100.
  const display = visibility ? clamp(visibility.cleanlinessScore * 20) : 0;

  // pricing: 100 minus the mean absolute deviation from master price.
  const pricingScore =
    pricing.length > 0
      ? clamp(100 - pricing.reduce((sum, row) => sum + Math.abs(row.deviationPct), 0) / pricing.length)
      : 0;

  // competitive: our share of shelf against the competitors observed here.
  //
  // This used to be `competitive.length > 0 ? 100 : 0` — full marks for logging
  // a single competitor, zero for logging none. That scored *data entry*, not
  // store reality: an agent who typed one row outscored nothing they actually
  // did in the store, and an outlet with genuinely no competition scored 0 (#93).
  //
  // Now it is the real ratio. When there is nothing to measure it against, the
  // dimension is UNKNOWN rather than 0 — see `unknownDimensions` below. Scoring
  // an unmeasurable dimension as zero silently drags down the weighted total.
  const ownFacings = visibility ? facingsTotal(visibility.facingsCount) : 0;
  const competitorFacings = competitive.reduce((sum, row) => sum + row.facingsCount, 0);
  const shelfTotal = ownFacings + competitorFacings;
  const competitiveScore = shelfTotal > 0 ? clamp((100 * ownFacings) / shelfTotal) : 0;
  const competitiveIsKnown = competitive.length > 0 && shelfTotal > 0;

  // salesCapability: staff product-knowledge quiz score.
  const salesCapability = capability ? clamp(capability.quizScore) : 0;

  // A dimension with nothing to measure is *unknown*, not zero. It is omitted
  // from the stored scores (so the app shows "—" rather than a damning 0) and
  // skipped in the weighted total, which normalises by the weights it actually
  // used — so the remaining dimensions simply carry the score between them.
  const unknownDimensions = new Set<ScorecardDimension>();
  if (!competitiveIsKnown) {
    unknownDimensions.add('competitive');
  }

  const allScores: Record<ScorecardDimension, number> = {
    availability: round2(availability),
    visibility: round2(visibilityScore),
    display: round2(display),
    pricing: round2(pricingScore),
    competitive: round2(competitiveScore),
    salesCapability: round2(salesCapability),
  };

  const dimensionScores: Partial<Record<ScorecardDimension, number>> = {};
  for (const dimension of SCORECARD_DIMENSIONS) {
    if (!unknownDimensions.has(dimension)) {
      dimensionScores[dimension] = allScores[dimension];
    }
  }

  // Weighted total over the dimensions present in the client's configured
  // weights; if the weights json is empty/invalid, fall back to equal weights
  // across all six dimensions.
  const configuredWeights = asNumberRecord(client.scorecardWeights);
  const scored = SCORECARD_DIMENSIONS.filter((dimension) => !unknownDimensions.has(dimension));

  let weightedSum = 0;
  let weightSum = 0;
  for (const dimension of scored) {
    const weight = configuredWeights[dimension];
    if (typeof weight === 'number' && weight > 0) {
      weightedSum += allScores[dimension] * weight;
      weightSum += weight;
    }
  }
  const weightedTotal =
    weightSum > 0
      ? round2(weightedSum / weightSum)
      : round2(
          scored.reduce((sum, dimension) => sum + allScores[dimension], 0) /
            Math.max(1, scored.length),
        );

  const thresholds = asNumberRecord(client.kpiThresholds);
  const green = thresholds.green ?? DEFAULT_GREEN_THRESHOLD;
  const amber = thresholds.amber ?? DEFAULT_AMBER_THRESHOLD;
  const ratingBand = weightedTotal >= green ? 'green' : weightedTotal >= amber ? 'amber' : 'red';

  const fields = {
    dimensionScores: dimensionScores as Prisma.InputJsonValue,
    weightedTotal,
    ratingBand,
  };

  // One Scorecard per visit (unique visitId) — upsert so re-submitting is
  // idempotent, mirroring the section-capture services.
  return prisma.scorecard.upsert({
    where: { visitId: input.visitId },
    create: { visitId: input.visitId, ...fields },
    update: fields,
  });
}

export async function listScorecardsForClient(input: {
  clientId: string;
  limit: number;
  cursor?: string;
}) {
  const rows = await prisma.scorecard.findMany({
    where: { visit: { clientId: input.clientId } },
    // The `id` tiebreaker must share the primary sort's direction — see the
    // note in alerts.service.ts. Scorecards are written in bursts as a day's
    // offline visits sync, so equal createdAt values are routine.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, input.limit);
}

/// The scores this outlet has been given, most recent first.
///
/// A field agent may only see the ones from *their own* visits: "up 6 points
/// from your last visit here" is feedback on their own work, not a window onto
/// a colleague's. Managers see the outlet's whole history.
/// Note on the page size: this was the codebase's only `take:` before the
/// pagination sweep, a bare `take: 5` meaning "the last handful". That intent
/// survives as the *default limit* the route asks for, rather than a second,
/// invisible cap layered under the shared helper — two ceilings on one query
/// is how a caller asks for 50 and silently gets 5.
export const SCORECARD_HISTORY_DEFAULT_LIMIT = 5;

export async function listScorecardHistory(input: {
  clientId: string;
  outletId: string;
  agentId?: string;
  limit: number;
  cursor?: string;
}) {
  const rows = await prisma.scorecard.findMany({
    where: {
      visit: {
        clientId: input.clientId,
        outletId: input.outletId,
        ...(input.agentId ? { agentId: input.agentId } : {}),
      },
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, input.limit);
}

export async function getScorecardByVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const scorecard = await prisma.scorecard.findUnique({ where: { visitId } });
  if (!scorecard) {
    throw new NotFoundError('Scorecard not found');
  }
  return scorecard;
}

export interface ResolvedAgent {
  id: string;
  email: string;
  displayName: string | null;
}

/** "Sipho Ndlovu <sipho@acme.com>", or just the email when there is no name. */
function describeCandidate(candidate: ResolvedAgent): string {
  const name = candidate.displayName?.trim();
  return name ? `${name} <${candidate.email}>` : candidate.email;
}

export class AgentNotFoundError extends Error {}
export class AmbiguousAgentError extends Error {
  constructor(readonly query: string, readonly candidates: ResolvedAgent[]) {
    super(
      `"${query}" matches ${candidates.length} people: ` +
        `${candidates.map(describeCandidate).join(', ')}. Ask which one they mean.`,
    );
    this.name = 'AmbiguousAgentError';
  }
}

/** How many candidates to name back before it stops being a useful question. */
const MAX_AGENT_CANDIDATES = 5;

/**
 * Turn what a manager actually typed into an agent id.
 *
 * **This exists because the first live eval sweep found it missing.** The exit
 * demo — *"How has Tumo been performing this month?"* — routed to
 * `getVisitHistory` rather than the scorecard, and the model was right to do
 * that: `getAgentPerformance` needs an id, nothing resolved a name to one, and
 * the visit list was the only tool returning agent identities. The model was
 * doing a discovery hop because the roster gave it no alternative.
 *
 * Managers say names. Ids come from tool results. Without something in between,
 * every question about a person costs an extra paid round trip — or fails.
 *
 * **Matching runs most-specific first, and the first step that hits wins:**
 *
 * 1. exact `id` — what a follow-up turn supplies after a tool result;
 * 2. exact `email`, case-insensitive;
 * 3. exact `displayName`, case-insensitive — "Sipho Ndlovu";
 * 4. `displayName` contains the query — "Sipho", "Ndlovu";
 * 5. `email` contains the query — the fallback for people with no name yet.
 *
 * Names come before the email substring because a name is what a manager
 * actually says, and a full name with a space ("Sipho Ndlovu") can never be a
 * substring of `sipho.ndlovu@acme.com` (#280). The email step stays because
 * `displayName` is nullable: accounts that predate it were not given one, and
 * we do not guess one from the address.
 *
 * An exact step beats a partial one even when the partial would also hit: "Sam
 * Taylor" must not be ambiguous merely because "Sam Taylor-Smith" exists.
 *
 * **Ambiguity is answered, not guessed.** Two people matching "Sipho" raises
 * {@link AmbiguousAgentError} naming both, so the assistant can ask. Picking
 * the first would silently report one person's numbers under another's name,
 * which is the kind of wrong that gets taken into a meeting.
 *
 * Tenant-scoped on every branch. A name from another client resolves to nothing.
 */
export async function resolveAgent(input: {
  clientId: string;
  query: string;
}): Promise<ResolvedAgent> {
  const query = input.query.trim();
  if (query.length === 0) {
    throw new AgentNotFoundError('No agent was named.');
  }

  const { clientId } = input;
  const select = { id: true, email: true, displayName: true } as const;

  // An exact id, which is what a follow-up turn supplies after a tool result.
  const byId = await prisma.user.findFirst({
    where: { id: query, clientId },
    select,
  });
  if (byId) return byId;

  // An exact email beats a partial match even when the partial would also hit:
  // "sam@acme.com" must not be ambiguous merely because "sam.taylor@acme.com"
  // exists. Email is unique, so this cannot be ambiguous itself.
  const byEmail = await prisma.user.findFirst({
    where: { email: { equals: query, mode: 'insensitive' }, clientId },
    select,
  });
  if (byEmail) return byEmail;

  // Names are not unique, so every name step can be ambiguous — two people
  // really can both be called "Sipho Ndlovu", and that must still ask.
  const steps: Prisma.UserWhereInput[] = [
    { displayName: { equals: query, mode: 'insensitive' } },
    { displayName: { contains: query, mode: 'insensitive' } },
    { email: { contains: query, mode: 'insensitive' } },
  ];

  for (const step of steps) {
    const matches = await prisma.user.findMany({
      where: { clientId, ...step },
      select,
      // One more than we will name, so "and others" is honest rather than a guess.
      take: MAX_AGENT_CANDIDATES + 1,
      orderBy: [{ displayName: { sort: 'asc', nulls: 'last' } }, { email: 'asc' }],
    });
    if (matches.length === 1) return matches[0];
    if (matches.length > 1) {
      throw new AmbiguousAgentError(query, matches.slice(0, MAX_AGENT_CANDIDATES));
    }
  }

  throw new AgentNotFoundError(
    `No one matching "${query}" works here. Ask the user to check the name, ` +
      'or use a tool that lists agents.',
  );
}

export interface AgentPerformanceInput {
  clientId: string;
  agentId: string;
  /** Half-open `[from, to)`. A day boundary belongs to exactly one period. */
  from: Date;
  to: Date;
}

export interface AgentPerformance {
  agentId: string;
  /** What to call the agent: their display name, or their email when they have none. */
  agentName: string | null;
  /** The agent's display name as stored; `null` when none was ever set. */
  agentDisplayName: string | null;
  agentEmail: string;
  visits: number;
  outletsVisited: number;
  scoredVisits: number;
  averageScore: number;
  ratingBands: Record<string, number>;
  dimensionAverages: Record<string, number>;
  /** Same window, every other agent in the tenant. `null` when there are none. */
  teamAverageScore: number | null;
  /** The agent's score minus the team's. Positive is better than the team. */
  deltaVsTeam: number | null;
}

/**
 * One agent's execution quality over a window, against their team's.
 *
 * **The comparison is not an extra.** The workflow this replaces is "export,
 * save, export again, overlay in Excel" — so a scorecard that reports a number
 * without something to read it against has reproduced the problem rather than
 * solved it. "82" means nothing; "82, against a team average of 71" is the
 * answer to the question the manager actually asked.
 *
 * The team baseline deliberately **excludes the agent being scored**. Including
 * them pulls the average toward their own figure, which compresses the gap most
 * for exactly the outliers a manager is looking for — and does it worst on
 * small teams, where the outliers matter most.
 *
 * Scoped by `clientId` on every query. This function is reached from an
 * assistant tool bound to the caller, but it is also an ordinary service and
 * must not rely on its callers for tenancy.
 */
export async function getAgentPerformance(input: AgentPerformanceInput): Promise<AgentPerformance> {
  const { clientId, agentId, from, to } = input;

  const agent = await prisma.user.findFirst({
    where: { id: agentId, clientId },
    select: { id: true, email: true, displayName: true },
  });
  // Not a NotFoundError: an agent id from another tenant and an agent id that
  // does not exist must be indistinguishable, or the endpoint becomes an
  // existence oracle for other clients' user ids.
  if (!agent) {
    throw new NotFoundError('Agent not found');
  }

  const window = { gte: from, lt: to };

  const [visits, scorecards, teamScorecards] = await Promise.all([
    prisma.visit.findMany({
      where: { clientId, agentId, checkinTs: window },
      select: { outletId: true },
    }),
    prisma.scorecard.findMany({
      where: { visit: { clientId, agentId, checkinTs: window } },
      select: { weightedTotal: true, ratingBand: true, dimensionScores: true },
    }),
    prisma.scorecard.findMany({
      where: { visit: { clientId, agentId: { not: agentId }, checkinTs: window } },
      select: { weightedTotal: true },
    }),
  ]);

  const ratingBands: Record<string, number> = {};
  for (const row of scorecards) {
    ratingBands[row.ratingBand] = (ratingBands[row.ratingBand] ?? 0) + 1;
  }

  const dimensionAverages: Record<string, number> = {};
  for (const dimension of SCORECARD_DIMENSIONS) {
    const values = scorecards
      .map((row) => asNumberRecord(row.dimensionScores)[dimension])
      .filter((value): value is number => typeof value === 'number');
    // Omitted rather than reported as 0 when nothing was captured. A zero here
    // reads as "they scored nothing on pricing" instead of "pricing was never
    // captured", and those call for opposite responses from a manager.
    if (values.length > 0) dimensionAverages[dimension] = mean(values);
  }

  const averageScore = mean(scorecards.map((row) => row.weightedTotal));
  const teamAverageScore =
    teamScorecards.length > 0 ? mean(teamScorecards.map((row) => row.weightedTotal)) : null;

  return {
    agentId,
    agentName: personLabel(agent.displayName, agent.email),
    agentDisplayName: agent.displayName,
    agentEmail: agent.email,
    visits: visits.length,
    outletsVisited: new Set(visits.map((v) => v.outletId)).size,
    scoredVisits: scorecards.length,
    averageScore,
    ratingBands,
    dimensionAverages,
    teamAverageScore,
    deltaVsTeam: teamAverageScore === null ? null : round2(averageScore - teamAverageScore),
  };
}
