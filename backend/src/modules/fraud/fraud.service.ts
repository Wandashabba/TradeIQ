import { Prisma, VisitStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { haversineDistanceMeters } from '../../lib/geofence';
import { kpiThreshold } from '../../lib/kpiThresholds';
import { NotFoundError } from '../../middleware/errorHandler';

// ── Heuristic thresholds & weights ────────────────────────────────────────
// A borderline check-in that sits inside the 50m geofence but hugs its edge.
const GEOFENCE_EDGE_M = 40;
// A photo whose GPS tag lands further than this from the check-in is suspect.
const PHOTO_DIVERGENCE_M = 150;
// Failed check-in attempts are only relevant if they precede the visit by <6h.
const FAILED_ATTEMPT_WINDOW_MS = 6 * 60 * 60 * 1000;
// ── The dwell band (#247) ──────────────────────────────────────────────────
// Dwell is device check-in → device submit. Both edges are per-client, read
// from `Client.kpiThresholds` via kpiThreshold() — the same reader the stock
// and pricing engines use — under these keys. The key names ARE the contract:
// the #97-era seed wrote keys nothing read, and the bands silently fell back to
// defaults. Change a key here and every stored override stops applying.
export const FAST_COMPLETION_MINUTES_KEY = 'fastCompletionMinutes';
export const SLOW_COMPLETION_MINUTES_KEY = 'slowCompletionMinutes';

// A submitted visit whose capture finished within a minute of check-in.
export const DEFAULT_FAST_COMPLETION_MINUTES = 1;
// The practitioner's benchmark is ~12 minutes for a full audit — for ONE
// client's audit shape. The default upper edge is 4x that (48 min): wide
// enough that an honest, thorough audit of a big-format store does not trip it
// on a tenant that has never configured its band, while a visit that sat open
// for most of an hour still surfaces. A client whose audits are genuinely short
// tightens it through kpiThresholds.slowCompletionMinutes.
export const DEFAULT_SLOW_COMPLETION_MINUTES = 48;

// ── The capture timeline (#246) ────────────────────────────────────────────
// Were the stock counts and the shelf photos captured in the same sitting?
//
// The literal comparison — "stock entered at 10:02, photo taken at 14:30" — is
// NOT computable honestly. A stock row carries only its SERVER `createdAt`
// (whenever the outbox flushed); the device never sends when a count was keyed
// in. A photo's `timestamp` is the DEVICE clock at capture. Subtracting one from
// the other is exactly the two-clock mistake #101 removed from dwell: an agent
// who synced from a dead zone four hours later would read as a four-hour gap.
//
// What IS on one clock: the device's `checkinTs`, its `submittedAtClient`, and
// every photo's `timestamp`. Stock can only be keyed in while the visit draft is
// open — after check-in, before submit — so that device window brackets every
// count. A photo stamped well outside it was not taken in the sitting where the
// counts were entered: it was taken before the agent checked in, or after they
// submitted, which is the "assembled rather than observed" pattern the issue
// describes, measured without trusting the server clock for anything.
//
// The tolerance covers the edges of the window: a shelf photographed while
// walking up to the door, and ordinary clock jitter (an NTP correction
// mid-visit). Minutes between counting a section and photographing it fall
// inside the window and never need a tolerance. Per client, like the dwell band.
export const CAPTURE_TIMELINE_TOLERANCE_MINUTES_KEY = 'captureTimelineToleranceMinutes';
export const DEFAULT_CAPTURE_TIMELINE_TOLERANCE_MINUTES = 15;
// Closing a task uploads its evidence photo against the ORIGINATING visit, days
// later and by design (tasks_screen.dart). It is not part of the audit sitting.
const TASK_CLOSURE_PHOTO_SECTION = 'task_closure';

const WEIGHT_GEOFENCE = 20;
const WEIGHT_FAILED_ATTEMPTS = 25;
const WEIGHT_FAILED_ATTEMPT_PER = 10;
const WEIGHT_PHOTO_DIVERGENCE = 25;
const WEIGHT_FAST_COMPLETION = 20;
// Deliberately low, and flat. The slow tail has a benign explanation the fast
// tail does not: an app left open in a pocket, or an agent pulled away mid-visit,
// inflates dwell without anything being faked. So the weight does not scale
// with how far over the band a visit ran (a phone left open overnight would
// otherwise out-score a spoofed GPS fix), and at 10 it can never reach the
// default review threshold (50) on its own. It corroborates other evidence; it
// does not accuse anyone by itself.
const WEIGHT_SLOW_COMPLETION = 10;
// Flat, and below the review threshold alone. Stronger than slow_completion: an
// app left open does not move a photo's capture time outside the visit. Weaker
// than photo_gps_divergence: a device clock that was changed mid-visit does, and
// the size of the gap is not evidence of anything more (a clock reset by a day
// is not 100x more fraudulent than one off by fifteen minutes), so it does not
// scale.
const WEIGHT_CAPTURE_TIMELINE_GAP = 15;
// When every out-of-window photo is ALSO a photo whose GPS diverged, the two
// signals are describing one stale photo from two angles — where it was taken
// and when. photo_gps_divergence has already scored that photo, so the timeline
// signal is still reported (a reviewer should see the "when") but only tops it
// up: 25 + 5 = 30 for one photo, not 25 + 15 = 40. A second, independent photo
// out of the window is new evidence and scores the full weight.
const WEIGHT_CAPTURE_TIMELINE_GAP_SAME_PHOTO = 5;
const WEIGHT_NO_CAPTURE = 30;

const MS_PER_MINUTE = 60_000;

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
   * dwell is measurable and neither dwell signal (fast_completion,
   * slow_completion) is emitted (#101, #247), and there is no device window to
   * place photos in, so capture_timeline_gap is not emitted either (#246).
   */
  submittedAtClient?: Date | null;
}

/** One visit photo, as the heuristics see it. */
export interface FraudPhotoInput {
  gpsTag: Prisma.JsonValue;
  /** The DEVICE clock at capture. Absent → the photo has no place on the timeline. */
  timestamp?: Date | null;
  /** The audit section it evidences; `task_closure` photos are not audit captures. */
  section?: string;
}

/** Related rows the heuristics reason over, pre-loaded by the caller. */
export interface FraudRelatedInput {
  // Photos captured on the visit: gpsTag (divergence), timestamp + section
  // (capture timeline, #246).
  photos: FraudPhotoInput[];
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

/** The dwell band, in ms, for one client. See the DEFAULT_*_MINUTES notes. */
export function dwellBand(kpiThresholds: unknown): { fastMs: number; slowMs: number } {
  const fastMinutes = kpiThreshold(
    kpiThresholds,
    FAST_COMPLETION_MINUTES_KEY,
    DEFAULT_FAST_COMPLETION_MINUTES,
  );
  const slowMinutes = kpiThreshold(
    kpiThresholds,
    SLOW_COMPLETION_MINUTES_KEY,
    DEFAULT_SLOW_COMPLETION_MINUTES,
  );
  return {
    // 0 is a meaningful setting here — it switches the fast tail off.
    fastMs: Math.max(0, fastMinutes) * MS_PER_MINUTE,
    // A non-positive upper edge would flag every visit the tenant has, which is
    // a typo, not a policy. Fall back rather than accuse the whole workforce.
    slowMs: (slowMinutes > 0 ? slowMinutes : DEFAULT_SLOW_COMPLETION_MINUTES) * MS_PER_MINUTE,
  };
}

/** The capture-timeline tolerance, in ms, for one client. See #246 above. */
export function captureTimelineToleranceMs(kpiThresholds: unknown): number {
  const minutes = kpiThreshold(
    kpiThresholds,
    CAPTURE_TIMELINE_TOLERANCE_MINUTES_KEY,
    DEFAULT_CAPTURE_TIMELINE_TOLERANCE_MINUTES,
  );
  // Zero or negative would flag ordinary clock jitter on every visit with a
  // photo: a typo, not a policy. Same fallback rule as the dwell band's upper edge.
  return (minutes > 0 ? minutes : DEFAULT_CAPTURE_TIMELINE_TOLERANCE_MINUTES) * MS_PER_MINUTE;
}

/**
 * Score a single visit against the fraud/ghost-visit heuristics. Pure: every
 * input it needs is passed in, so it is trivially unit-testable and reused by
 * both the per-visit and the flagged-list endpoints. riskScore is the summed
 * signal weights, clamped to [0, 100].
 *
 * `kpiThresholds` is the visit's client's raw `Client.kpiThresholds` column;
 * the dwell band and the capture-timeline tolerance read it. Absent, every
 * edge takes its default.
 */
export function computeFraudSignals(
  visit: FraudVisitInput,
  related: FraudRelatedInput,
  kpiThresholds: unknown = {},
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
  // Remembered so the capture-timeline signal (6) can tell a second piece of
  // evidence from the same photo seen again.
  const divergentPhotos = new Set<FraudPhotoInput>();
  for (const photo of related.photos) {
    const coords = readCoords(photo.gpsTag);
    if (!coords) {
      continue;
    }
    const distance = haversineDistanceMeters(checkin, coords);
    if (distance > PHOTO_DIVERGENCE_M) {
      divergentPhotos.add(photo);
    }
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

  // 4. Dwell outside the client's band — implausibly fast (fast_completion) or
  //    implausibly slow (slow_completion, #247). A one-sided threshold is easy
  //    to game once agents learn where it sits: pad the visit and it goes
  //    quiet. dwell = submit - check-in, measured on ONE clock (#101).
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
    const band = dwellBand(kpiThresholds);

    // A negative dwell means the device clock moved between check-in and submit
    // (or was changed). It is not evidence of a fast visit, so it is not
    // evidence of fraud — say nothing rather than guess.
    if (dwellMs >= 0 && dwellMs < band.fastMs) {
      const dwellSeconds = Math.round(dwellMs / 1000);
      signals.push({
        code: 'fast_completion',
        detail: `Visit completed ${dwellSeconds}s after check-in (device clock)`,
        weight: WEIGHT_FAST_COMPLETION,
      });
    } else if (dwellMs > band.slowMs) {
      // The same one-clock rule applies to the slow tail: a delayed sync lands
      // in the server's createdAt, never here, so an offline agent is not
      // mistaken for a slow one. The weight is capped — see
      // WEIGHT_SLOW_COMPLETION for why an idle app must not read as fraud.
      const dwellMinutes = Math.round(dwellMs / MS_PER_MINUTE);
      const bandMinutes = Math.round((band.slowMs / MS_PER_MINUTE) * 10) / 10;
      signals.push({
        code: 'slow_completion',
        detail:
          `Visit took ${dwellMinutes} min from check-in to submit (device clock), ` +
          `over the ${bandMinutes} min benchmark; an app left open also does this`,
        weight: WEIGHT_SLOW_COMPLETION,
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

  // 6. Capture timeline (#246) — a shelf photo taken outside the device window
  //    in which the stock counts were keyed in. See the CAPTURE_TIMELINE notes at
  //    the top for why the window stands in for the stock rows' own times.
  //
  //    Silent unless every input is on the device clock and present: a
  //    submitted visit (a draft's window has no end yet), with captured sections
  //    (no counts → no_capture already says the stronger thing), a device submit
  //    time, and at least one device-stamped audit photo.
  if (visit.status === 'submitted' && hasSections && visit.submittedAtClient) {
    const submitMs = visit.submittedAtClient.getTime();
    // Submit before check-in means the device clock moved. The window is then
    // meaningless, and nothing measured against it is evidence — same rule as dwell.
    if (submitMs >= checkinMs) {
      const toleranceMs = captureTimelineToleranceMs(kpiThresholds);
      const outside: Array<{ photo: FraudPhotoInput; gapMs: number; after: boolean }> = [];
      for (const photo of related.photos) {
        if (photo.section === TASK_CLOSURE_PHOTO_SECTION || !photo.timestamp) {
          continue;
        }
        const takenMs = photo.timestamp.getTime();
        if (!Number.isFinite(takenMs)) {
          continue;
        }
        const beforeMs = checkinMs - takenMs;
        const afterMs = takenMs - submitMs;
        const gapMs = Math.max(beforeMs, afterMs);
        if (gapMs > toleranceMs) {
          outside.push({ photo, gapMs, after: afterMs > beforeMs });
        }
      }

      if (outside.length > 0) {
        const worst = outside.reduce((a, b) => (b.gapMs > a.gapMs ? b : a));
        const gapMinutes = Math.round(worst.gapMs / MS_PER_MINUTE);
        const toleranceMinutes = Math.round((toleranceMs / MS_PER_MINUTE) * 10) / 10;
        const sameAsGps = outside.every((o) => divergentPhotos.has(o.photo));
        signals.push({
          code: 'capture_timeline_gap',
          detail:
            `${outside.length} photo(s) taken outside the visit; the furthest was ` +
            `${gapMinutes} min ${worst.after ? 'after submit' : 'before check-in'} ` +
            `(device clock), beyond the ${toleranceMinutes} min tolerance` +
            (sameAsGps ? '; the same photo(s) as the GPS divergence' : ''),
          weight: sameAsGps ? WEIGHT_CAPTURE_TIMELINE_GAP_SAME_PHOTO : WEIGHT_CAPTURE_TIMELINE_GAP,
        });
      }
    }
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
  // Fraud inspects each photo's gpsTag, device timestamp and section (see
  // FraudRelatedInput). Selecting the base64 `url` too meant listFlagged
  // detoasted every stored image — MBs per row — only to discard them. Select
  // only the fields we read.
  photos: { select: { gpsTag: true, timestamp: true, section: true } },
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

  const [failedAttempts, client] = await Promise.all([
    prisma.checkInAttempt.findMany({
      where: { clientId, agentId: visit.agentId, outletId: visit.outletId, passed: false },
    }),
    prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } }),
  ]);

  return computeFraudSignals(
    toFraudVisitInput(visit),
    {
      photos: visit.photos,
      sectionCreatedAts: sectionCreatedAts(visit),
      failedAttempts,
    },
    client?.kpiThresholds,
  );
}

export interface AttemptFilters {
  clientId: string;
  outletId?: string;
  agentId?: string;
  passed?: boolean;
  limit: number;
  cursor?: string;
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

  const rows = await prisma.checkInAttempt.findMany({
    where,
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    // Attempts arrive in bursts (an agent retrying at the door), so identical
    // createdAt values are the norm here rather than the exception.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: filters.limit + 1,
    ...(filters.cursor ? { cursor: { id: filters.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, filters.limit);
}

export interface FlaggedVisit {
  visitId: string;
  outletId: string;
  agentId: string;
  riskScore: number;
  signals: FraudSignal[];
}

/** GET /fraud/flagged — submitted visits scoring at or above minScore. */
/** How many submitted visits one call will score. See [listFlagged]. */
export const MAX_FRAUD_SCAN = 2000;

/** Default scan window when the caller does not name one. */
export const DEFAULT_FRAUD_WINDOW_DAYS = 30;

export interface ListFlaggedInput {
  clientId: string;
  minScore: number;
  from?: Date;
  to?: Date;
}

export interface FlaggedPage {
  data: FlaggedVisit[];
  /** How many visits were actually scored. */
  scanned: number;
  /** True when the scan hit [MAX_FRAUD_SCAN] and older visits went unscored. */
  truncated: boolean;
}

/**
 * Submitted visits scoring at or above `minScore`, newest-first within a
 * bounded window.
 *
 * This endpoint cannot paginate the way every other list does (#236): it
 * filters and sorts by a risk score **computed in memory**, so there is no
 * column to key a cursor on. What it can do — and now does — is refuse to scan
 * without limit. Previously it loaded every submitted visit the tenant had ever
 * recorded, on every request, which grows without bound at the ~190k
 * visits/year this schema anticipates.
 *
 * Two bounds, because either alone can be defeated: a date window (default the
 * last 30 days, which is the horizon a fraud review actually cares about) and a
 * hard `MAX_FRAUD_SCAN` ceiling on rows scored.
 *
 * `truncated` exists because a flagged list that quietly stops short is worse
 * than one that says it stopped. A manager who cannot see a suspicious visit
 * concludes there was not one. Same rule as `AgentActivityPage.truncated`.
 */
export async function listFlagged(input: ListFlaggedInput): Promise<FlaggedPage> {
  const { clientId, minScore } = input;
  const to = input.to ?? new Date();
  const from =
    input.from ?? new Date(to.getTime() - DEFAULT_FRAUD_WINDOW_DAYS * 24 * 60 * 60 * 1000);

  const [visits, failedAttempts, client] = await Promise.all([
    prisma.visit.findMany({
      where: { clientId, status: 'submitted', checkinTs: { gte: from, lte: to } },
      include: fraudVisitInclude,
      // Newest first, so a truncated scan drops the OLDEST visits — the ones
      // least likely to still be actionable — rather than an arbitrary slice.
      orderBy: [{ checkinTs: 'desc' }, { id: 'desc' }],
      take: MAX_FRAUD_SCAN + 1,
    }),
    // Scoped to the same window: the failed-attempt signal only ever matches
    // attempts by the same agent at the same outlet, so attempts from outside
    // the window cannot contribute to a visit inside it.
    prisma.checkInAttempt.findMany({
      where: { clientId, passed: false, createdAt: { gte: from, lte: to } },
    }),
    // One read for the whole scan: every visit here belongs to this client, so
    // they all share its dwell band and capture-timeline tolerance.
    prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } }),
  ]);

  const truncated = visits.length > MAX_FRAUD_SCAN;
  if (truncated) {
    visits.length = MAX_FRAUD_SCAN;
  }

  const flagged: FlaggedVisit[] = [];
  for (const visit of visits) {
    const attemptsForVisit = failedAttempts.filter(
      (attempt) => attempt.agentId === visit.agentId && attempt.outletId === visit.outletId,
    );
    const result = computeFraudSignals(
      toFraudVisitInput(visit),
      {
        photos: visit.photos,
        sectionCreatedAts: sectionCreatedAts(visit),
        failedAttempts: attemptsForVisit,
      },
      client?.kpiThresholds,
    );
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
  return { data: flagged, scanned: visits.length, truncated };
}
