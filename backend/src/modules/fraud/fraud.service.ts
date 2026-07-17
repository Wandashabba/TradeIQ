import { Prisma, VisitStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { haversineDistanceMeters } from '../../lib/geofence';
import { NotFoundError } from '../../middleware/errorHandler';

// ── Heuristic thresholds & weights ────────────────────────────────────────
// A borderline check-in that sits inside the 50m geofence but hugs its edge.
const GEOFENCE_EDGE_M = 40;
// A photo whose GPS tag lands further than this from the check-in is suspect.
const PHOTO_DIVERGENCE_M = 150;
// Failed check-in attempts are only relevant if they precede the visit by <6h.
const FAILED_ATTEMPT_WINDOW_MS = 6 * 60 * 60 * 1000;
// A submitted visit whose capture finished within a minute of check-in.
const FAST_COMPLETION_MS = 60_000;

const WEIGHT_GEOFENCE = 20;
const WEIGHT_FAILED_ATTEMPTS = 25;
const WEIGHT_FAILED_ATTEMPT_PER = 10;
const WEIGHT_PHOTO_DIVERGENCE = 25;
const WEIGHT_FAST_COMPLETION = 20;
const WEIGHT_NO_CAPTURE = 30;

const RISK_MIN = 0;
const RISK_MAX = 100;

export interface FraudSignal {
  code: string;
  detail: string;
  weight: number;
}

export interface FraudResult {
  visitId: string;
  riskScore: number;
  signals: FraudSignal[];
}

/** The subset of a Visit the heuristics reason over. */
export interface FraudVisitInput {
  id: string;
  status: VisitStatus;
  agentId: string;
  outletId: string;
  checkinTs: Date;
  checkinLat: number;
  checkinLng: number;
  checkinDistanceM: number | null;
  /**
   * The device's completion timestamp — the same clock that produced
   * `checkinTs`. Null for visits recorded before this existed, in which case no
   * dwell is measurable and no fast-completion signal is emitted (#101).
   */
  submittedAtClient?: Date | null;
}

/** Related rows the heuristics reason over, pre-loaded by the caller. */
export interface FraudRelatedInput {
  // Photos captured on the visit; only the gpsTag is inspected.
  photos: Array<{ gpsTag: Prisma.JsonValue }>;
  // createdAt of every captured row across the five audit sections (stock,
  // visibility, pricing, competitive, capability).
  sectionCreatedAts: Date[];
  // Failed CheckInAttempt rows for this visit's (agentId, outletId). The 6h
  // window is applied inside computeFraudSignals so it owns the whole heuristic.
  failedAttempts: Array<{ createdAt: Date }>;
}

/** Safely read a {lat,lng} pair out of a photo's gpsTag Json column. */
function readCoords(value: Prisma.JsonValue): { lat: number; lng: number } | null {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return null;
  }
  const obj = value as Record<string, unknown>;
  const { lat, lng } = obj;
  if (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    Number.isFinite(lat) &&
    Number.isFinite(lng)
  ) {
    return { lat, lng };
  }
  return null;
}

/**
 * Score a single visit against the fraud/ghost-visit heuristics. Pure: every
 * input it needs is passed in, so it is trivially unit-testable and reused by
 * both the per-visit and the flagged-list endpoints. riskScore is the summed
 * signal weights, clamped to [0, 100].
 */
export function computeFraudSignals(
  visit: FraudVisitInput,
  related: FraudRelatedInput,
): FraudResult {
  const signals: FraudSignal[] = [];

  // 1. Borderline geofence — inside the 50m fence but hugging its edge.
  if (visit.checkinDistanceM !== null && visit.checkinDistanceM > GEOFENCE_EDGE_M) {
    signals.push({
      code: 'geofence_distance',
      detail: `Check-in was ${visit.checkinDistanceM}m from the outlet, near the 50m fence edge`,
      weight: WEIGHT_GEOFENCE,
    });
  }

  // 2. Failed check-in attempts for this (agent, outlet) in the 6h before
  //    check-in — a hallmark of retrying until the GPS finally "passes".
  const windowStart = visit.checkinTs.getTime() - FAILED_ATTEMPT_WINDOW_MS;
  const checkinMs = visit.checkinTs.getTime();
  const recentFailures = related.failedAttempts.filter((attempt) => {
    const at = attempt.createdAt.getTime();
    return at >= windowStart && at <= checkinMs;
  }).length;
  if (recentFailures >= 1) {
    signals.push({
      code: 'failed_attempts',
      detail: `${recentFailures} failed check-in attempt(s) in the 6h before check-in`,
      weight: Math.min(WEIGHT_FAILED_ATTEMPTS, WEIGHT_FAILED_ATTEMPT_PER * recentFailures),
    });
  }

  // 3. A photo's GPS tag diverges far from the recorded check-in location.
  const checkin = { lat: visit.checkinLat, lng: visit.checkinLng };
  let maxDivergenceM = 0;
  for (const photo of related.photos) {
    const coords = readCoords(photo.gpsTag);
    if (!coords) {
      continue;
    }
    const distance = haversineDistanceMeters(checkin, coords);
    if (distance > maxDivergenceM) {
      maxDivergenceM = distance;
    }
  }
  if (maxDivergenceM > PHOTO_DIVERGENCE_M) {
    signals.push({
      code: 'photo_gps_divergence',
      detail: `A photo's GPS tag is ${Math.round(maxDivergenceM)}m from the check-in location`,
      weight: WEIGHT_PHOTO_DIVERGENCE,
    });
  }

  const hasSections = related.sectionCreatedAts.length > 0;

  // 4. Implausibly fast completion — dwell = submit - check-in, measured on ONE
  //    clock (#101).
  //
  //    This used to subtract the client's `checkinTs` from a section row's
  //    SERVER `createdAt`. Those are two different clocks, and on an
  //    offline-first app the server one is "whenever the outbox flushed", so the
  //    figure was wrong in both directions:
  //
  //      * a device clock running ahead made dwell negative, which read as
  //        "completed 0s after check-in" and put 20 points on an honest agent;
  //      * a delayed sync inflated dwell, so a genuine 20-second ghost visit
  //        sailed through unflagged.
  //
  //    So we now use the device's own completion timestamp. When we do not have
  //    one, dwell is UNMEASURABLE and we emit nothing: a fabricated signal that
  //    gets someone investigated is worse than a missing one.
  if (visit.status === 'submitted' && hasSections && visit.submittedAtClient) {
    const dwellMs = visit.submittedAtClient.getTime() - checkinMs;

    // A negative dwell means the device clock moved between check-in and submit
    // (or was changed). It is not evidence of a fast visit, so it is not
    // evidence of fraud — say nothing rather than guess.
    if (dwellMs >= 0 && dwellMs < FAST_COMPLETION_MS) {
      const dwellSeconds = Math.round(dwellMs / 1000);
      signals.push({
        code: 'fast_completion',
        detail: `Visit completed ${dwellSeconds}s after check-in (device clock)`,
        weight: WEIGHT_FAST_COMPLETION,
      });
    }
  }

  // 5. A submitted visit with no captured data at all across the five sections.
  if (visit.status === 'submitted' && !hasSections) {
    signals.push({
      code: 'no_capture',
      detail: 'Submitted visit has no captured section data',
      weight: WEIGHT_NO_CAPTURE,
    });
  }

  const rawScore = signals.reduce((sum, signal) => sum + signal.weight, 0);
  const riskScore = Math.max(RISK_MIN, Math.min(RISK_MAX, rawScore));

  return { visitId: visit.id, riskScore, signals };
}

// The Visit shape (with every section + photos) loaded for scoring.
export const fraudVisitInclude = {
  stock: true,
  visibility: true,
  pricing: true,
  competitive: true,
  capability: true,
  // Fraud only inspects each photo's gpsTag (see FraudRelatedInput). Selecting
  // the base64 `url` too meant listFlagged detoasted every stored image — MBs
  // per row — only to discard them. Select the one field we read.
  photos: { select: { gpsTag: true } },
} as const satisfies Prisma.VisitInclude;

type FraudVisitPayload = Prisma.VisitGetPayload<{ include: typeof fraudVisitInclude }>;

function toFraudVisitInput(visit: FraudVisitPayload): FraudVisitInput {
  return {
    id: visit.id,
    status: visit.status,
    agentId: visit.agentId,
    outletId: visit.outletId,
    checkinTs: visit.checkinTs,
    checkinLat: visit.checkinLat,
    checkinLng: visit.checkinLng,
    checkinDistanceM: visit.checkinDistanceM,
    submittedAtClient: visit.submittedAtClient,
  };
}

/** Collect the createdAt of every captured row across the five sections. */
function sectionCreatedAts(visit: FraudVisitPayload): Date[] {
  const dates: Date[] = [];
  for (const row of visit.stock) {
    dates.push(row.createdAt);
  }
  if (visit.visibility) {
    dates.push(visit.visibility.createdAt);
  }
  for (const row of visit.pricing) {
    dates.push(row.createdAt);
  }
  for (const row of visit.competitive) {
    dates.push(row.createdAt);
  }
  if (visit.capability) {
    dates.push(visit.capability.createdAt);
  }
  return dates;
}

/** GET /fraud/visits/:visitId — score one tenant-scoped visit. */
export async function getVisitFraud(visitId: string, clientId: string): Promise<FraudResult> {
  const visit = await prisma.visit.findFirst({
    where: { id: visitId, clientId },
    include: fraudVisitInclude,
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const failedAttempts = await prisma.checkInAttempt.findMany({
    where: { clientId, agentId: visit.agentId, outletId: visit.outletId, passed: false },
  });

  return computeFraudSignals(toFraudVisitInput(visit), {
    photos: visit.photos,
    sectionCreatedAts: sectionCreatedAts(visit),
    failedAttempts,
  });
}

export interface AttemptFilters {
  clientId: string;
  outletId?: string;
  agentId?: string;
  passed?: boolean;
}

/** GET /fraud/attempts — tenant-scoped, optionally filtered, newest first. */
export async function listAttempts(filters: AttemptFilters) {
  const where: Prisma.CheckInAttemptWhereInput = { clientId: filters.clientId };
  if (filters.outletId) {
    where.outletId = filters.outletId;
  }
  if (filters.agentId) {
    where.agentId = filters.agentId;
  }
  if (filters.passed !== undefined) {
    where.passed = filters.passed;
  }

  return prisma.checkInAttempt.findMany({ where, orderBy: { createdAt: 'desc' } });
}

export interface FlaggedVisit {
  visitId: string;
  outletId: string;
  agentId: string;
  riskScore: number;
  signals: FraudSignal[];
}

/** GET /fraud/flagged — submitted visits scoring at or above minScore. */
export async function listFlagged(clientId: string, minScore: number): Promise<FlaggedVisit[]> {
  const [visits, failedAttempts] = await Promise.all([
    prisma.visit.findMany({
      where: { clientId, status: 'submitted' },
      include: fraudVisitInclude,
    }),
    prisma.checkInAttempt.findMany({ where: { clientId, passed: false } }),
  ]);

  const flagged: FlaggedVisit[] = [];
  for (const visit of visits) {
    const attemptsForVisit = failedAttempts.filter(
      (attempt) => attempt.agentId === visit.agentId && attempt.outletId === visit.outletId,
    );
    const result = computeFraudSignals(toFraudVisitInput(visit), {
      photos: visit.photos,
      sectionCreatedAts: sectionCreatedAts(visit),
      failedAttempts: attemptsForVisit,
    });
    if (result.riskScore >= minScore) {
      flagged.push({
        visitId: visit.id,
        outletId: visit.outletId,
        agentId: visit.agentId,
        riskScore: result.riskScore,
        signals: result.signals,
      });
    }
  }

  flagged.sort((a, b) => b.riskScore - a.riskScore);
  return flagged;
}
