import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

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

/** Safely read `.total` out of the facingsCount Json column. */
function facingsTotal(value: Prisma.JsonValue): number {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return 0;
  }
  const total = (value as Record<string, unknown>).total;
  return typeof total === 'number' && Number.isFinite(total) ? total : 0;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
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
}

export async function generateScorecard(input: GenerateScorecardInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
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

export async function listScorecardsForClient(clientId: string) {
  return prisma.scorecard.findMany({
    where: { visit: { clientId } },
    orderBy: { createdAt: 'desc' },
  });
}

/// The scores this outlet has been given, most recent first.
///
/// A field agent may only see the ones from *their own* visits: "up 6 points
/// from your last visit here" is feedback on their own work, not a window onto
/// a colleague's. Managers see the outlet's whole history.
export async function listScorecardHistory(input: {
  clientId: string;
  outletId: string;
  agentId?: string;
  take?: number;
}) {
  return prisma.scorecard.findMany({
    where: {
      visit: {
        clientId: input.clientId,
        outletId: input.outletId,
        ...(input.agentId ? { agentId: input.agentId } : {}),
      },
    },
    orderBy: { createdAt: 'desc' },
    take: input.take ?? 5,
  });
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
