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

  // competitive: Phase-1 capture-completeness proxy — the agent gets full
  // marks for capturing any competitive intel at all. A quality-weighted
  // competitive score is a Phase-2 concern.
  const competitiveScore = competitive.length > 0 ? 100 : 0;

  // salesCapability: staff product-knowledge quiz score.
  const salesCapability = capability ? clamp(capability.quizScore) : 0;

  const dimensionScores: Record<ScorecardDimension, number> = {
    availability: round2(availability),
    visibility: round2(visibilityScore),
    display: round2(display),
    pricing: round2(pricingScore),
    competitive: round2(competitiveScore),
    salesCapability: round2(salesCapability),
  };

  // Weighted total over the dimensions present in the client's configured
  // weights; if the weights json is empty/invalid, fall back to equal weights
  // across all six dimensions.
  const configuredWeights = asNumberRecord(client.scorecardWeights);
  let weightedSum = 0;
  let weightSum = 0;
  for (const dimension of SCORECARD_DIMENSIONS) {
    const weight = configuredWeights[dimension];
    if (typeof weight === 'number' && weight > 0) {
      weightedSum += dimensionScores[dimension] * weight;
      weightSum += weight;
    }
  }
  const weightedTotal =
    weightSum > 0
      ? round2(weightedSum / weightSum)
      : round2(
          SCORECARD_DIMENSIONS.reduce((sum, dimension) => sum + dimensionScores[dimension], 0) /
            SCORECARD_DIMENSIONS.length,
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
