import { Prisma, VisitStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { DEFAULT_LIMIT, buildPage } from '../../lib/pagination';
import { GEOFENCE_RADIUS_M, haversineDistanceMeters } from '../../lib/geofence';
import { kpiThreshold } from '../../lib/kpiThresholds';
import { NotFoundError } from '../../middleware/errorHandler';
import {
  MAX_NEAR_DUPLICATE_DISTANCE,
  PERCEPTUAL_HASH_BITS,
  perceptualHashBands,
  perceptualHashProbeKeys,
} from '../photos/photoHash';

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

/**
 * A task-closure photo: evidence attached to the originating visit when a task
 * is closed, often days later and from wherever it was closed. It says nothing
 * about when or where the audit happened, so no photo signal reads it:
 * capture_timeline_gap (#246), stock_outside_outlet (#248),
 * photo_gps_divergence (#317) and the duplicate_photo lookups (#244) all skip
 * it through this one rule.
 */
function isTaskClosurePhoto(photo: { section?: string | null }): boolean {
  return photo.section === TASK_CLOSURE_PHOTO_SECTION;
}

// ── Repeating stock counts (#245) ──────────────────────────────────────────
// "2-1, 2-1": the same counts submitted visit after visit. Real shelf stock
// moves, so a run of identical `unitsAvailable` for one (outlet, SKU) across
// consecutive submitted visits suggests the agent copied the last visit instead
// of counting.
//
// The calibration warning on the issue is the whole design: a slow SKU in a
// small outlet legitimately reads the same twice, and a screen that fires on
// every long-tail SKU trains managers to ignore it. So:
//
//   * a run must be at least `repeatingStockRunLength` visits long (default 3,
//     never less: 2 is exactly the benign slow-mover case the issue warns
//     about). Per client, like every other band.
//   * a SKU only counts if its OWN server-derived velocity (#112) says it should
//     have moved over the run — see MIN_EXPECTED_MOVEMENT_UNITS.
//   * a SKU at 0 units never counts: an out-of-stock shelf reads 0 until it is
//     restocked, and nothing about that is copied.
//   * the weight is low and never flags a visit alone.
//
// "Consecutive" and "previous" are ordered by each visit's device `checkinTs`
// (ties by id), never a stock row's server `createdAt`: that is when the outbox
// flushed, and an agent who synced a week of visits at once would otherwise have
// them in upload order, not the order they were counted in (#101).
export const REPEATING_STOCK_RUN_LENGTH_KEY = 'repeatingStockRunLength';
export const DEFAULT_REPEATING_STOCK_RUN_LENGTH = 3;
// The ceiling bounds how much history one scoring call loads. A client asking
// for 50 identical visits before anything is said has switched the signal off in
// all but name; 12 (a quarter of weekly visits) is as long a run as we look for.
export const MAX_REPEATING_STOCK_RUN_LENGTH = 12;
// How far past the minimum run we keep walking back to find where a run
// STARTED. The start matters because that row's stored velocity is the honest
// one — see repeatingStockCounts(). A run longer than this is scored with the
// oldest row we can see, whose velocity may already be diluted by earlier copies
// and so reads low: the signal errs silent, but only after the ten visits before
// it have each been scored while the start was still in view.
export const REPEATING_STOCK_START_LOOKBACK_VISITS = 10;
// A SKU is only evidence when its pre-run velocity (units/day) times the run's
// span (days) predicts at least this many units sold. At an expected 3 units, a
// genuinely unsold span is a ~5% event (Poisson P(0 | 3)); a SKU selling a unit
// a fortnight across a two-week run expects ~1 and is exactly the long tail the
// issue says must stay silent.
export const MIN_EXPECTED_MOVEMENT_UNITS = 3;
// A partial repeat only contributes when at least this share of the comparable
// basket is unchanged. One mover out of ten identical is one number an agent may
// have re-read correctly, or a shelf refilled to the same par level; half the
// basket is a pattern.
export const MIN_REPEATING_BASKET_SHARE = 0.5;
// "The whole basket unchanged" needs a basket: a one-SKU visit repeating is no
// stronger than one SKU repeating.
const MIN_BASKET_SKUS = 2;

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
// Flat and low, in two steps. Every count in the basket identical across the run
// — including SKUs whose velocity says they sold — is the "2-1, 2-1" pattern
// itself: copying one visit into the next reproduces the whole basket, while an
// honest count rarely freezes every line at once. It still tops out at 15, level
// with capture_timeline_gap, because a shelf refilled to a fixed par level before
// counting reads the same way. A partial repeat is weaker again (5): it is
// reported so a reviewer sees it, and adds a little to other evidence. Neither
// scales with run length or basket size, and neither reaches the default review
// threshold (50) alone.
const WEIGHT_REPEATING_STOCK_COUNTS_BASKET = 15;
const WEIGHT_REPEATING_STOCK_COUNTS_PARTIAL = 5;

// ── Duplicate photo reuse (#244) ───────────────────────────────────────────
// The same shelf photo submitted again — on a visit to a different outlet, or
// on a later visit to the same one — is a ghost-visit pattern: the agent did not
// photograph the shelf this time, they re-used a picture they already had.
//
// Photos are base64 in `url` (ADR 0007), which cannot be compared or indexed
// (btree caps at ~2704 bytes). Upload stores two small hashes instead (see
// photos/photoHash.ts), and only those are compared:
//
//   * exact: SHA-256 of the decoded bytes. Two captures never produce the same
//     file (sensor noise, EXIF capture time), so this is the same file twice.
//   * near: dHash Hamming distance within the client's threshold. Catches the
//     copy that went through a chat app (re-encoded, resized) on its way back.
//
// "Reuse" is directional. The match must belong to an EARLIER visit of the same
// client, by device checkinTs (ties by id, the #245 ordering): the first use of
// a photo is where it was taken, and must not be accused for being copied later.
// Photos without hashes (pre-#244 rows not yet backfilled) are simply not seen.
//
// A task-closure photo is not an audit capture — it is attached to the
// originating visit days later, by design (#246) — so it neither triggers the
// signal nor counts as the photo that was reused.
//
// The threshold is per client. Why bits and not a similarity %: it is what the
// index reasons in. Default 6: a re-encode moves ~1 bit and a half-size copy ~3,
// while unrelated shelf frames sit at 25+ (measured, photoHash.test.ts). It stays
// below 7 on purpose — the same planogram photographed in two stores of one chain
// is the false positive a near match risks, and the tighter bound keeps it rarer.
// Above 7 the band index cannot promise to return the match, so it clamps there.
export const DUPLICATE_PHOTO_MAX_DISTANCE_KEY = 'duplicatePhotoMaxDistance';
export const DEFAULT_DUPLICATE_PHOTO_MAX_DISTANCE = 6;

// Weights, flat — neither scales with how many photos were reused or how often:
// one reused photo already says the shelf was not photographed this time.
//
// A different outlet is the strong case: the photo contradicts where the agent
// claims to have been. Byte-identical, 35: it cannot be two captures, but alone
// it still stays under the review threshold (50), because one visit's evidence
// can be the wrong photo picked from the gallery. It is NOT folded into
// photo_gps_divergence the way capture_timeline_gap is: the GPS tag is metadata
// the device supplies (and can strip), while this is the image content itself,
// so the two agreeing is corroboration, not one fact counted twice.
const WEIGHT_DUPLICATE_PHOTO_OTHER_OUTLET_EXACT = 35;
// Near, 25: a re-encoded copy is reuse just the same, but at 64 bits two stores
// of one chain with the same planogram, shot from the same angle, can hash close.
const WEIGHT_DUPLICATE_PHOTO_OTHER_OUTLET_NEAR = 25;
// A previous visit to the SAME outlet is weaker: the agent may well have been
// there and skipped only the photo. Byte-identical, 15 — level with the other
// "not captured this time" signals (capture_timeline_gap, repeating_stock_counts).
const WEIGHT_DUPLICATE_PHOTO_SAME_OUTLET_EXACT = 15;
// Near, only 5: the same shelf photographed from the same spot a week later
// honestly looks alike, and an unchanged planogram is exactly what an audit
// hopes to see. Reported so a reviewer can look; corroboration only.
const WEIGHT_DUPLICATE_PHOTO_SAME_OUTLET_NEAR = 5;

// ── Stock counted outside its assigned outlet (#248) ───────────────────────
// "Stock recorded against outlet A while the capture happened somewhere that is
// not outlet A." The issue asks for "outside" to be pinned down first. It has
// two readings, and only one of them is implemented, on purpose:
//
// 1. WEAK — the stock was captured outside A's own fence. NOT IMPLEMENTED: there
//    is no evidence for it that some existing signal does not already score.
//      * The check-in position is inside A's fence by construction: a visit
//        only exists once POST /visits/checkin passed the fence. How close it
//        came to the edge is geofence_distance.
//      * A stock row carries no position at all, and nothing on the device
//        records one when a count is keyed in.
//      * A photo's gpsTag outside the fence is photo_gps_divergence (the
//        photo -> location join the issue says is not this question); a lower
//        line measured from the outlet instead of the check-in would score the
//        same field of the same photo a second time.
//      * Rejected check-in attempts from outside the fence are failed_attempts.
//    A weak reading would re-weigh one of those facts under a new name, so it is
//    left out rather than double-counted.
//
// 2. STRONG — the capture position sits inside the fence of a DIFFERENT outlet
//    of the same client, and clear of A's. That is new evidence none of the
//    other signals can see: the agent was standing in a real store this client
//    audits, and the counts were attributed to another one.
//
// What places the capture. A stock count has no position, but it can only be
// keyed in while the visit is open on the device (check-in -> submittedAtClient,
// the #246 window). So a visit photo whose DEVICE timestamp falls inside that
// window, widened by the client's captureTimelineToleranceMinutes, was taken in
// the sitting where the counts were entered, and its gpsTag is where that
// sitting happened. Photos outside the window, without a timestamp or
// coordinates, and task-closure photos place nothing. No submittedAtClient → no
// window → silent, the #101 one-clock rule.
//
// Rejected CheckInAttempt rows for this (agent, outlet) in the failed_attempts
// window are the negative-signal dataset: each carries the device position the
// agent tried to check in from. On their own they never fire this signal (an
// agent standing in store B who taps outlet A by mistake, then drives to A, is
// the benign case). When one sits inside the SAME other outlet a photo places
// the capture in, it is a second, independent device reading of where the agent
// was — see WEIGHT_STOCK_OUTSIDE_OUTLET_SAME_PHOTO.
//
// Why not the check-in position: it is inside A's fence by construction. It can
// also be inside B's when the two fences overlap (two stores in one mall), and
// that is ambiguous, not evidence.
//
// The fence is GEOFENCE_RADIUS_M, the same one check-in enforces. Inside B means
// within that radius of B. Clear of A needs the radius PLUS a per-client
// tolerance, because phone GPS indoors drifts by tens of metres: a count at the
// back of a big store must not read as "in the store next door".
export const STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS_KEY = 'stockOutsideOutletToleranceMeters';
// 25m: a typical indoor / urban-canyon smartphone fix error. Two outlets closer
// than radius + tolerance (75m) apart can never trip it, which is the intent —
// neighbouring stores in one centre are exactly where a fix is ambiguous.
export const DEFAULT_STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS = 25;
// Moderate-to-high, flat, and below the review threshold (50) alone. A photo from
// the counting sitting geotagged inside another of the client's stores is the
// most specific location evidence the engine has, and it is checkable (the
// reviewer knows which store). It still does not flag alone: a stale fix the
// camera reused, or the wrong photo picked from the gallery, do the same. It does
// not scale with distance or with how many photos agree.
const WEIGHT_STOCK_OUTSIDE_OUTLET = 30;
// When every placing photo is ALSO one photo_gps_divergence already scored (the
// two outlets are far apart), the position is one fact seen twice: divergence
// has said "far from the check-in" (25), and this adds only "and that spot is
// your store B". So 20, and the pair is 45: one more independent signal is needed
// to reach review. A photo between nearby stores (divergence is blind under
// 150m) scores the full 30 — more evidence never scores lower than less. A
// rejected check-in attempt from inside that same outlet B is independent of the
// photo (a different request, a different fix), so it restores the full 30.
const WEIGHT_STOCK_OUTSIDE_OUTLET_SAME_PHOTO = 20;
// The outlet lookup is a bounding box around each capture position, then exact
// haversine in JS. The box is widened by this factor so a true candidate is
// never lost to the flat-earth approximation or float rounding; the haversine
// check discards the corners. The box does not wrap the antimeridian (±180°).
const OUTLET_LOOKUP_BOX_MARGIN = 1.1;
// Fewest metres per degree of latitude (at the equator) and metres per degree of
// longitude at the equator. Dividing by them errs toward a bigger box.
const MIN_METRES_PER_DEGREE_LAT = 110_574;
const METRES_PER_DEGREE_LNG_AT_EQUATOR = 111_320;
// Near the poles cos(lat) → 0 and the longitude span explodes. Floor it: no
// outlet is audited there, and a wider box is only a bigger superset.
const MIN_COS_LAT = 0.01;

const MS_PER_MINUTE = 60_000;
const MS_PER_DAY = 24 * 60 * MS_PER_MINUTE;

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
  /**
   * The audit section it evidences; `task_closure` photos are not audit
   * captures, and no photo signal reads them (see isTaskClosurePhoto).
   */
  section?: string;
}

/** Related rows the heuristics reason over, pre-loaded by the caller. */
export interface FraudRelatedInput {
  // Photos captured on the visit: gpsTag + section (divergence, #317),
  // timestamp + section (capture timeline, #246).
  photos: FraudPhotoInput[];
  // createdAt of every captured row across the five audit sections (stock,
  // visibility, pricing, competitive, capability).
  sectionCreatedAts: Date[];
  // Failed CheckInAttempt rows for this visit's (agentId, outletId). The 6h
  // window is applied inside computeFraudSignals so it owns the whole heuristic.
  // lat/lng, where present, are the position the agent tried to check in from
  // (#248 corroboration).
  failedAttempts: FraudFailedAttempt[];
  // This visit's own stock counts (#245). Absent → no repeating_stock_counts.
  stockCounts?: FraudStockCount[];
  // Earlier SUBMITTED visits to the same outlet that recorded stock, newest
  // first by device checkinTs (ties by id) — see loadPriorStockVisits(). Only
  // the first repeatingStockLookbackVisits() are read. Absent or empty → silent.
  priorStockVisits?: FraudStockVisit[];
  // Hash matches for this visit's photos against the client's other photos
  // (#244) — see loadDuplicatePhotoMatches(). Absent or empty → no duplicate_photo.
  photoMatches?: FraudPhotoMatch[];
  // The visit's own outlet plus the client's outlets near its capture positions
  // (#248) — see loadNearbyOutlets(). Absent, or without the visit's own outlet
  // → no stock_outside_outlet.
  nearbyOutlets?: FraudOutletLocation[];
}

/** One rejected check-in attempt, as the heuristics see it. */
export interface FraudFailedAttempt {
  createdAt: Date;
  lat?: number;
  lng?: number;
}

/** One outlet's fence centre, as stock_outside_outlet sees it (#248). */
export interface FraudOutletLocation {
  outletId: string;
  code: string;
  lat: number;
  lng: number;
}

/** One of this visit's photos matching a photo on another visit (#244). */
export interface FraudPhotoMatch {
  /** This visit's photo. */
  photoId: string;
  section: string;
  /** Byte-identical: the SHA-256 of the decoded bytes is equal. */
  exact: boolean;
  /** dHash Hamming distance in bits; null when either photo has no comparable hash. */
  distance: number | null;
  matchVisitId: string;
  matchOutletId: string;
  /** The matched visit's DEVICE check-in, which decides which use came first. */
  matchCheckinTs: Date;
  matchSection: string;
}

/** One VisitStock row, as repeating_stock_counts sees it. */
export interface FraudStockCount {
  skuId: string;
  unitsAvailable: number;
  /** Server-derived at capture from the outlet's earlier history (#112). */
  velocityAvg: number;
}

/** One earlier visit's stock basket, placed on the device timeline. */
export interface FraudStockVisit {
  visitId: string;
  checkinTs: Date;
  stock: FraudStockCount[];
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

/** The minimum run of identical counts, in visits, for one client. See #245 above. */
export function repeatingStockRunLength(kpiThresholds: unknown): number {
  const raw = Math.floor(
    kpiThreshold(kpiThresholds, REPEATING_STOCK_RUN_LENGTH_KEY, DEFAULT_REPEATING_STOCK_RUN_LENGTH),
  );
  // Below 3 is not a stricter policy, it is the false positive the issue
  // warns about (a slow SKU reading the same twice), so it falls back rather
  // than being honoured. Above the ceiling clamps: the client asked for long
  // runs only, and gets the longest this engine looks for.
  if (raw < DEFAULT_REPEATING_STOCK_RUN_LENGTH) {
    return DEFAULT_REPEATING_STOCK_RUN_LENGTH;
  }
  return Math.min(raw, MAX_REPEATING_STOCK_RUN_LENGTH);
}

/** How many earlier stock visits per outlet scoring needs to see, for one client. */
export function repeatingStockLookbackVisits(kpiThresholds: unknown): number {
  return repeatingStockRunLength(kpiThresholds) - 1 + REPEATING_STOCK_START_LOOKBACK_VISITS;
}

interface BasketEntry {
  unitsAvailable: number;
  velocityAvg: number;
}

/**
 * One visit's counts keyed by SKU. A SKU recorded twice on one visit (a
 * re-submitted section) with two DIFFERENT counts is ambiguous — which one did
 * the agent see? — and is left out (null) rather than guessed. Identical
 * duplicates keep the lower velocity, the reading less likely to fire.
 */
function basketOf(stock: FraudStockCount[]): Map<string, BasketEntry | null> {
  const basket = new Map<string, BasketEntry | null>();
  for (const row of stock) {
    if (!basket.has(row.skuId)) {
      basket.set(row.skuId, { unitsAvailable: row.unitsAvailable, velocityAvg: row.velocityAvg });
      continue;
    }
    const seen = basket.get(row.skuId);
    if (!seen || seen.unitsAvailable !== row.unitsAvailable) {
      basket.set(row.skuId, null);
    } else {
      seen.velocityAvg = Math.min(seen.velocityAvg, row.velocityAvg);
    }
  }
  return basket;
}

/**
 * repeating_stock_counts (#245), or null. Pure; see the REPEATING_STOCK notes at
 * the top for the calibration.
 *
 * For each SKU on this visit, the run is this visit plus every immediately
 * preceding stock visit to the outlet that recorded the SAME count. A preceding
 * visit that did not record the SKU ends its run — absence is not agreement.
 *
 * A SKU is:
 *   - comparable when it was recorded on each of the (runLength - 1) preceding
 *     stock visits, i.e. a run of the minimum length was even possible;
 *   - repeating when its run reaches runLength;
 *   - a mover when it repeats at a non-zero count AND the velocity stored on the
 *     FIRST row of its run, times the run's span in days, predicts at least
 *     MIN_EXPECTED_MOVEMENT_UNITS sold.
 *
 * Why the first row's velocity: velocityAvg is the mean consumption over the
 * outlet's last few visits, and a copied count reads as zero consumption. By the
 * third copy the newest row's velocity has been pulled toward zero by the copies
 * themselves, so reading it would let a long enough run exonerate itself. The
 * first row of the run was derived from the history BEFORE the run began.
 *
 * No mover → silent, whatever repeats: slow and out-of-stock SKUs legitimately
 * read the same.
 */
function repeatingStockCounts(
  visit: FraudVisitInput,
  related: FraudRelatedInput,
  kpiThresholds: unknown,
): FraudSignal | null {
  const own = basketOf(related.stockCounts ?? []);
  if (own.size === 0) {
    return null;
  }
  const runLength = repeatingStockRunLength(kpiThresholds);
  const checkinMs = visit.checkinTs.getTime();
  // Defensive: newest first by device checkinTs. Array.prototype.sort is stable,
  // so equal timestamps keep the loader's (database) id order. Anything not
  // strictly earlier than this visit on the device clock is not "previous".
  const prior = (related.priorStockVisits ?? [])
    .filter((p) => p.visitId !== visit.id && p.checkinTs.getTime() <= checkinMs && p.stock.length > 0)
    .sort((a, b) => b.checkinTs.getTime() - a.checkinTs.getTime())
    .slice(0, repeatingStockLookbackVisits(kpiThresholds))
    .map((p) => ({ checkinMs: p.checkinTs.getTime(), basket: basketOf(p.stock) }));
  if (prior.length < runLength - 1) {
    return null; // too little history to see a run of the minimum length
  }

  let comparable = 0;
  let repeating = 0;
  let movers = 0;
  let longestRun = 0;
  for (const [skuId, entry] of own) {
    if (!entry) {
      continue;
    }
    let run = 1;
    let start = { checkinMs, entry };
    for (const earlier of prior) {
      const seen = earlier.basket.get(skuId);
      if (!seen || seen.unitsAvailable !== entry.unitsAvailable) {
        break;
      }
      run += 1;
      start = { checkinMs: earlier.checkinMs, entry: seen };
    }
    const minRunPossible = prior
      .slice(0, runLength - 1)
      .every((earlier) => Boolean(earlier.basket.get(skuId)));
    if (!minRunPossible) {
      continue;
    }
    comparable += 1;
    if (run < runLength) {
      continue;
    }
    repeating += 1;
    longestRun = Math.max(longestRun, run);
    const spanDays = (checkinMs - start.checkinMs) / MS_PER_DAY;
    const expectedSold = Math.max(0, start.entry.velocityAvg) * Math.max(0, spanDays);
    if (entry.unitsAvailable > 0 && expectedSold >= MIN_EXPECTED_MOVEMENT_UNITS) {
      movers += 1;
    }
  }

  if (movers === 0) {
    return null;
  }
  const wholeBasket = comparable >= MIN_BASKET_SKUS && repeating === comparable;
  if (!wholeBasket && repeating / comparable < MIN_REPEATING_BASKET_SHARE) {
    return null;
  }
  const movedClause =
    `${movers} of them selling fast enough by their own velocity that the count should have moved` +
    ` (longest run ${longestRun} visits, by device check-in)`;
  return wholeBasket
    ? {
        code: 'repeating_stock_counts',
        detail:
          `Whole basket unchanged: all ${comparable} SKU counts identical across the last ` +
          `${runLength} submitted visits to this outlet, ${movedClause}`,
        weight: WEIGHT_REPEATING_STOCK_COUNTS_BASKET,
      }
    : {
        code: 'repeating_stock_counts',
        detail:
          `${repeating} of ${comparable} SKU counts identical across the last ${runLength} ` +
          `submitted visits to this outlet, ${movedClause}`,
        weight: WEIGHT_REPEATING_STOCK_COUNTS_PARTIAL,
      };
}

/** The near-duplicate threshold, in dHash bits, for one client. See #244 above. */
export function duplicatePhotoMaxDistance(kpiThresholds: unknown): number {
  const raw = Math.floor(
    kpiThreshold(kpiThresholds, DUPLICATE_PHOTO_MAX_DISTANCE_KEY, DEFAULT_DUPLICATE_PHOTO_MAX_DISTANCE),
  );
  // 0 is a policy (identical perceptual hashes only); negative is a typo, and
  // falls back. Above the ceiling clamps: the lookup could not return those
  // matches, so honouring it would only pretend to look.
  if (raw < 0) {
    return DEFAULT_DUPLICATE_PHOTO_MAX_DISTANCE;
  }
  return Math.min(raw, MAX_NEAR_DUPLICATE_DISTANCE);
}

/** The weight of one qualifying match. See the WEIGHT_DUPLICATE_PHOTO_* notes. */
function duplicatePhotoWeight(exact: boolean, otherOutlet: boolean): number {
  if (otherOutlet) {
    return exact ? WEIGHT_DUPLICATE_PHOTO_OTHER_OUTLET_EXACT : WEIGHT_DUPLICATE_PHOTO_OTHER_OUTLET_NEAR;
  }
  return exact ? WEIGHT_DUPLICATE_PHOTO_SAME_OUTLET_EXACT : WEIGHT_DUPLICATE_PHOTO_SAME_OUTLET_NEAR;
}

/**
 * duplicate_photo (#244), or null. Pure; see the DUPLICATE_PHOTO notes at the
 * top. The loader has already narrowed the candidates, but every rule is applied
 * again here so the heuristic is whole and testable on its own:
 *
 *   - neither photo is a task-closure photo;
 *   - the match is on a different visit, strictly EARLIER on
 *     (device checkinTs, id) — ids compared bytewise, as the loader's SQL does;
 *   - it is byte-identical, or has a perceptual distance within the threshold.
 *
 * One signal per visit, at the strongest qualifying match; the detail counts how
 * many of this visit's photos matched.
 */
function duplicatePhoto(
  visit: FraudVisitInput,
  related: FraudRelatedInput,
  kpiThresholds: unknown,
): FraudSignal | null {
  const matches = related.photoMatches ?? [];
  if (matches.length === 0) {
    return null;
  }
  const maxDistance = duplicatePhotoMaxDistance(kpiThresholds);
  const checkinMs = visit.checkinTs.getTime();

  const matchedPhotos = new Set<string>();
  let best: { match: FraudPhotoMatch; weight: number; otherOutlet: boolean } | null = null;
  for (const match of matches) {
    if (
      match.section === TASK_CLOSURE_PHOTO_SECTION ||
      match.matchSection === TASK_CLOSURE_PHOTO_SECTION ||
      match.matchVisitId === visit.id
    ) {
      continue;
    }
    const matchMs = match.matchCheckinTs.getTime();
    const earlier = matchMs < checkinMs || (matchMs === checkinMs && match.matchVisitId < visit.id);
    const near = match.distance !== null && match.distance <= maxDistance;
    if (!earlier || !(match.exact || near)) {
      continue;
    }
    matchedPhotos.add(match.photoId);
    const otherOutlet = match.matchOutletId !== visit.outletId;
    const weight = duplicatePhotoWeight(match.exact, otherOutlet);
    const closer =
      best !== null &&
      weight === best.weight &&
      !match.exact &&
      (match.distance ?? Infinity) < (best.match.distance ?? Infinity);
    if (best === null || weight > best.weight || closer) {
      best = { match, weight, otherOutlet };
    }
  }
  if (best === null) {
    return null;
  }

  const { match, weight, otherOutlet } = best;
  const kind = match.exact
    ? 'byte-identical to'
    : `a near-duplicate (${match.distance} of ${PERCEPTUAL_HASH_BITS} bits differ, threshold ${maxDistance}) of`;
  const date = match.matchCheckinTs.toISOString().slice(0, 10);
  return {
    code: 'duplicate_photo',
    detail:
      `${matchedPhotos.size} photo(s) on this visit match a photo from an earlier visit by this client; ` +
      `the strongest is ${kind} a photo from a visit to ${otherOutlet ? 'a different outlet' : 'this outlet'} ` +
      `on ${date} (device check-in)` +
      (!otherOutlet && !match.exact ? '; the same shelf photographed from the same spot also looks alike' : ''),
    weight,
  };
}

/** The #248 tolerance beyond the visit's own fence, in metres, for one client. */
export function stockOutsideOutletToleranceMeters(kpiThresholds: unknown): number {
  const metres = kpiThreshold(
    kpiThresholds,
    STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS_KEY,
    DEFAULT_STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS,
  );
  // 0 is a policy (clear of the fence is enough); negative would put "clear of
  // A" inside A's own fence, which is a typo, and falls back.
  return metres >= 0 ? metres : DEFAULT_STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS;
}

/** Failed attempts inside the failed_attempts window: the 6h before check-in. */
function recentFailedAttempts<T extends FraudFailedAttempt>(visit: FraudVisitInput, attempts: T[]): T[] {
  const checkinMs = visit.checkinTs.getTime();
  const windowStart = checkinMs - FAILED_ATTEMPT_WINDOW_MS;
  return attempts.filter((attempt) => {
    const at = attempt.createdAt.getTime();
    return at >= windowStart && at <= checkinMs;
  });
}

function attemptCoords(attempt: FraudFailedAttempt): { lat: number; lng: number } | null {
  const { lat, lng } = attempt;
  return typeof lat === 'number' && typeof lng === 'number' && Number.isFinite(lat) && Number.isFinite(lng)
    ? { lat, lng }
    : null;
}

/**
 * The visit's photos that place the counting sitting (#248): audit photos whose
 * DEVICE timestamp is inside check-in -> submittedAtClient, widened by the
 * capture-timeline tolerance, and that carry coordinates. Empty for anything
 * but a submitted visit with an ordered device window.
 */
function captureSittingPhotos<P extends FraudPhotoInput>(
  visit: FraudVisitInput,
  photos: P[],
  kpiThresholds: unknown,
): Array<{ photo: P; coords: { lat: number; lng: number } }> {
  if (visit.status !== 'submitted' || !visit.submittedAtClient) {
    return [];
  }
  const checkinMs = visit.checkinTs.getTime();
  const submitMs = visit.submittedAtClient.getTime();
  if (submitMs < checkinMs) {
    return []; // the device clock moved; the window means nothing (#101)
  }
  const toleranceMs = captureTimelineToleranceMs(kpiThresholds);
  const placed: Array<{ photo: P; coords: { lat: number; lng: number } }> = [];
  for (const photo of photos) {
    if (isTaskClosurePhoto(photo) || !photo.timestamp) {
      continue;
    }
    const takenMs = photo.timestamp.getTime();
    if (!Number.isFinite(takenMs) || takenMs < checkinMs - toleranceMs || takenMs > submitMs + toleranceMs) {
      continue;
    }
    const coords = readCoords(photo.gpsTag);
    if (coords) {
      placed.push({ photo, coords });
    }
  }
  return placed;
}

/**
 * stock_outside_outlet (#248), or null — the STRONG reading only; see the notes
 * at the top for why the weak one is not scored. Pure: the loader has narrowed
 * the outlets to the ones near each position, and every rule is applied again
 * here with exact haversine.
 *
 * A position is placed in another outlet B when it is more than
 * GEOFENCE_RADIUS_M + tolerance from the visit's own outlet AND within
 * GEOFENCE_RADIUS_M of B (the nearest such B). Overlapping fences, positions near
 * A, and single-outlet tenants are therefore silent by construction.
 */
function stockOutsideOutlet(
  visit: FraudVisitInput,
  related: FraudRelatedInput,
  kpiThresholds: unknown,
  divergentPhotos: Set<FraudPhotoInput>,
): FraudSignal | null {
  // Stock recorded against this outlet is the claim under test; drafts are not final.
  if (visit.status !== 'submitted' || (related.stockCounts ?? []).length === 0) {
    return null;
  }
  const outlets = related.nearbyOutlets ?? [];
  const own = outlets.find((o) => o.outletId === visit.outletId);
  const others = outlets.filter((o) => o.outletId !== visit.outletId);
  if (!own || others.length === 0) {
    return null;
  }
  const toleranceM = stockOutsideOutletToleranceMeters(kpiThresholds);
  const clearOfOwnM = GEOFENCE_RADIUS_M + toleranceM;

  const placeInOther = (coords: { lat: number; lng: number }) => {
    const ownM = haversineDistanceMeters(own, coords);
    if (ownM <= clearOfOwnM) {
      return null;
    }
    let nearest: { outlet: FraudOutletLocation; otherM: number } | null = null;
    for (const outlet of others) {
      const otherM = haversineDistanceMeters(outlet, coords);
      if (otherM <= GEOFENCE_RADIUS_M && (nearest === null || otherM < nearest.otherM)) {
        nearest = { outlet, otherM };
      }
    }
    return nearest ? { ...nearest, ownM } : null;
  };

  const placements = captureSittingPhotos(visit, related.photos, kpiThresholds).flatMap(({ photo, coords }) => {
    const placed = placeInOther(coords);
    return placed ? [{ photo, ...placed }] : [];
  });
  if (placements.length === 0) {
    return null; // attempts alone never fire: the wrong-outlet tap is benign
  }

  const corroborated = new Set<string>();
  for (const attempt of recentFailedAttempts(visit, related.failedAttempts)) {
    const coords = attemptCoords(attempt);
    const placed = coords ? placeInOther(coords) : null;
    if (placed && placements.some((p) => p.outlet.outletId === placed.outlet.outletId)) {
      corroborated.add(placed.outlet.outletId);
    }
  }

  // Report a corroborated outlet first, then the nearest fix.
  const best = placements.reduce((a, b) => {
    const aC = corroborated.has(a.outlet.outletId);
    const bC = corroborated.has(b.outlet.outletId);
    if (aC !== bC) {
      return aC ? a : b;
    }
    return b.otherM < a.otherM ? b : a;
  });
  const sameAsGps = placements.every((p) => divergentPhotos.has(p.photo));
  const isCorroborated = corroborated.has(best.outlet.outletId);
  return {
    code: 'stock_outside_outlet',
    detail:
      `${placements.length} photo(s) taken while this visit's stock was being captured (device clock) are ` +
      `geotagged inside another of this client's outlets; the nearest is ${Math.round(best.otherM)}m from ` +
      `outlet ${best.outlet.code} (inside its ${GEOFENCE_RADIUS_M}m fence) and ${Math.round(best.ownM)}m from ` +
      `this visit's outlet (beyond its fence plus the ${toleranceM}m tolerance)` +
      (sameAsGps ? '; the same photo(s) as the GPS divergence' : '') +
      (isCorroborated ? `; a rejected check-in attempt for this outlet was also made from inside ${best.outlet.code}` : ''),
    weight: sameAsGps && !isCorroborated ? WEIGHT_STOCK_OUTSIDE_OUTLET_SAME_PHOTO : WEIGHT_STOCK_OUTSIDE_OUTLET,
  };
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
  const checkinMs = visit.checkinTs.getTime();
  const recentFailures = recentFailedAttempts(visit, related.failedAttempts).length;
  if (recentFailures >= 1) {
    signals.push({
      code: 'failed_attempts',
      detail: `${recentFailures} failed check-in attempt(s) in the 6h before check-in`,
      weight: Math.min(WEIGHT_FAILED_ATTEMPTS, WEIGHT_FAILED_ATTEMPT_PER * recentFailures),
    });
  }

  // 3. A photo's GPS tag diverges far from the recorded check-in location.
  //    Task-closure photos are skipped (#317): one is taken wherever the task
  //    was closed, days later, so a legitimate closure away from the outlet
  //    would otherwise score its originating visit as a divergence.
  const checkin = { lat: visit.checkinLat, lng: visit.checkinLng };
  let maxDivergenceM = 0;
  // Remembered so the capture-timeline signal (6) can tell a second piece of
  // evidence from the same photo seen again.
  const divergentPhotos = new Set<FraudPhotoInput>();
  for (const photo of related.photos) {
    if (isTaskClosurePhoto(photo)) {
      continue;
    }
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
        if (isTaskClosurePhoto(photo) || !photo.timestamp) {
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

  // 7. Repeating stock counts (#245) — the "2-1, 2-1" pattern. Submitted visits
  //    only: a draft's counts are not final, and the loader only ever supplies
  //    submitted visits as history. No counts → no_capture or nothing.
  if (visit.status === 'submitted') {
    const repeating = repeatingStockCounts(visit, related, kpiThresholds);
    if (repeating) {
      signals.push(repeating);
    }
  }

  // 8. Duplicate photo (#244) — this visit's photo already appeared on an
  //    earlier visit of the same client. Any status, like photo_gps_divergence:
  //    an uploaded photo is evidence whether or not the visit was submitted.
  const duplicate = duplicatePhoto(visit, related, kpiThresholds);
  if (duplicate) {
    signals.push(duplicate);
  }

  // 9. Stock outside its outlet (#248) — a photo from the counting sitting is
  //    geotagged inside another of the client's outlets. Submitted visits with
  //    stock only; see the STOCK_OUTSIDE_OUTLET notes at the top.
  const outside = stockOutsideOutlet(visit, related, kpiThresholds, divergentPhotos);
  if (outside) {
    signals.push(outside);
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
  // FraudRelatedInput; section is how every photo signal skips task-closure
  // photos), and its id and two hashes to look duplicates up (#244).
  // Selecting the base64 `url` too meant listFlagged detoasted every stored
  // image — MBs per row — only to discard them. Select only the fields we read:
  // a 64-char and a 16-char string, never the bytes (and not the band array,
  // which the lookup rebuilds from perceptualHash).
  photos: {
    select: {
      id: true,
      gpsTag: true,
      timestamp: true,
      section: true,
      contentHash: true,
      perceptualHash: true,
    },
  },
} as const satisfies Prisma.VisitInclude;

export type FraudVisitPayload = Prisma.VisitGetPayload<{ include: typeof fraudVisitInclude }>;

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

function toStockCounts(visit: FraudVisitPayload): FraudStockCount[] {
  return visit.stock.map((row) => ({
    skuId: row.skuId,
    unitsAvailable: row.unitsAvailable,
    velocityAvg: row.velocityAvg,
  }));
}

/** Where one visit's stock history ends: strictly before it, on (checkinTs, id). */
export interface PriorStockAnchor {
  outletId: string;
  checkinTs: Date;
  visitId: string;
}

interface PriorStockRow {
  anchor_visit_id: string;
  visit_id: string;
  checkin_ts: Date;
  sku_id: string;
  units_available: number;
  velocity_avg: number;
}

/**
 * Earlier submitted stock visits for many visits, in ONE round trip (#245).
 *
 * For each anchor, the `lookback` most recent SUBMITTED visits to its outlet
 * that recorded stock and sit strictly before it on (checkinTs, id), with their
 * stock rows. Returned per ANCHOR visit id, newest first.
 *
 * Keyed per anchor rather than per outlet because a scoring batch (#236) is not
 * a contiguous slice of an outlet's history: the rescore walks visits by id,
 * and a backfill only picks the unscored ones, so the visits between two batch
 * members are generally not in the batch and cannot stand in for each other's
 * history. Each anchor's history is a LATERAL walk capped at `lookback`, so the
 * cost is one query bounded by batch size x lookback however much history an
 * outlet has accumulated, never a query per visit (the N+1 #120 removed from
 * stock capture).
 */
export async function loadPriorStockVisits(
  clientId: string,
  anchors: PriorStockAnchor[],
  lookback: number,
): Promise<Map<string, FraudStockVisit[]>> {
  const byAnchor = new Map<string, FraudStockVisit[]>();
  if (anchors.length === 0 || lookback <= 0) {
    return byAnchor;
  }
  const rows = await prisma.$queryRaw<PriorStockRow[]>(
    Prisma.sql`
      SELECT anchor.visit_id AS anchor_visit_id, r.id AS visit_id, r.checkin_ts,
        vs.sku_id, vs.units_available, vs.velocity_avg
      FROM unnest(
        ${anchors.map((a) => a.outletId)}::text[],
        ${anchors.map((a) => a.checkinTs.toISOString())}::timestamp[],
        ${anchors.map((a) => a.visitId)}::text[]
      ) WITH ORDINALITY AS anchor(outlet_id, checkin_ts, visit_id, ord)
      CROSS JOIN LATERAL (
        SELECT v.id, v.checkin_ts
        FROM visits v
        WHERE v.client_id = ${clientId}
          AND v.outlet_id = anchor.outlet_id
          AND v.status = 'submitted'
          AND (v.checkin_ts, v.id) < (anchor.checkin_ts, anchor.visit_id)
          AND EXISTS (SELECT 1 FROM visit_stock s WHERE s.visit_id = v.id)
        ORDER BY v.checkin_ts DESC, v.id DESC
        LIMIT ${lookback}
      ) r
      JOIN visit_stock vs ON vs.visit_id = r.id
      ORDER BY anchor.ord, r.checkin_ts DESC, r.id DESC, vs.sku_id
    `,
  );

  // Rows arrive grouped by anchor, then newest visit first, so appending
  // preserves the database's (checkinTs, id) order exactly. One earlier visit
  // can be history for several anchors, so entries are keyed by the pair.
  const entries = new Map<string, FraudStockVisit>();
  for (const row of rows) {
    const key = `${row.anchor_visit_id}|${row.visit_id}`;
    let entry = entries.get(key);
    if (!entry) {
      entry = { visitId: row.visit_id, checkinTs: row.checkin_ts, stock: [] };
      entries.set(key, entry);
      const list = byAnchor.get(row.anchor_visit_id) ?? [];
      list.push(entry);
      byAnchor.set(row.anchor_visit_id, list);
    }
    entry.stock.push({
      skuId: row.sku_id,
      unitsAvailable: row.units_available,
      velocityAvg: row.velocity_avg,
    });
  }
  return byAnchor;
}

/** One photo to look duplicates up for: a scored visit's own, with its hashes. */
export interface DuplicatePhotoSource {
  photoId: string;
  section: string;
  visitId: string;
  outletId: string;
  checkinTs: Date;
  contentHash: string | null;
  perceptualHash: string | null;
}

interface DuplicatePhotoRow {
  photo_id: string;
  match_visit_id: string;
  match_outlet_id: string;
  match_checkin_ts: Date;
  match_section: string;
  exact: boolean;
  distance: number | null;
}

/** A scored visit's photos worth looking up: audit captures that carry a hash. */
function duplicatePhotoSources(visit: FraudVisitPayload): DuplicatePhotoSource[] {
  return visit.photos
    .filter((photo) => !isTaskClosurePhoto(photo) && photo.contentHash !== null)
    .map((photo) => ({
      photoId: photo.id,
      section: photo.section,
      visitId: visit.id,
      outletId: visit.outletId,
      checkinTs: visit.checkinTs,
      contentHash: photo.contentHash,
      perceptualHash: photo.perceptualHash,
    }));
}

/**
 * Duplicate-photo matches for many photos, in ONE round trip (#244).
 *
 * For each source photo, the strongest photo on an EARLIER visit (device
 * checkinTs, ties by id) of the same client that is byte-identical or within
 * `maxDistance` dHash bits — ranked as computeFraudSignals weighs them: another
 * outlet first, then exact, then closest. One row per source photo at most, so
 * a photo reused a hundred times (or a placeholder image every visit carries)
 * costs one row, not a hundred.
 *
 * Never touches `url`. Candidates come from two indexed branches:
 *   - exact: `content_hash` equality (btree);
 *   - near: `perceptual_hash_bands && probe keys` (GIN), the probe built by
 *     perceptualHashProbeKeys() — the pigeonhole scheme in photos/photoHash.ts
 *     that guarantees every hash within 7 bits shares a key. Candidates are a
 *     superset; the real distance is then measured on the 64-bit hashes.
 * A degenerate or malformed hash has no bands, so it is never compared as near,
 * on either side; exact matching still applies to it.
 *
 * Tenant scope is the join to visits: another client's identical photo is
 * found by the index and dropped by `client_id`, never returned.
 */
export async function loadDuplicatePhotoMatches(
  clientId: string,
  sources: DuplicatePhotoSource[],
  maxDistance: number,
): Promise<Map<string, FraudPhotoMatch[]>> {
  const byVisit = new Map<string, FraudPhotoMatch[]>();
  const hashed = sources.filter((s) => s.contentHash !== null && !isTaskClosurePhoto(s));
  if (hashed.length === 0) {
    return byVisit;
  }

  // Only a hash with bands is comparable as near; the rest go in as null.
  const comparable = hashed.map((s) => (perceptualHashBands(s.perceptualHash).length > 0 ? s.perceptualHash : null));
  const probeIds: string[] = [];
  const probeKeys: number[] = [];
  hashed.forEach((s, i) => {
    for (const key of perceptualHashProbeKeys(comparable[i], maxDistance)) {
      probeIds.push(s.photoId);
      probeKeys.push(key);
    }
  });

  const rows = await prisma.$queryRaw<DuplicatePhotoRow[]>(
    Prisma.sql`
      WITH src AS (
        SELECT * FROM unnest(
          ${hashed.map((s) => s.photoId)}::text[],
          ${hashed.map((s) => s.visitId)}::text[],
          ${hashed.map((s) => s.outletId)}::text[],
          ${hashed.map((s) => s.checkinTs.toISOString())}::timestamp[],
          ${hashed.map((s) => s.contentHash)}::text[],
          ${comparable}::text[]
        ) AS s(photo_id, visit_id, outlet_id, checkin_ts, content_hash, perceptual_hash)
      ),
      probe AS (
        SELECT k.photo_id, array_agg(k.band_key) AS band_keys
        FROM unnest(${probeIds}::text[], ${probeKeys}::int[]) AS k(photo_id, band_key)
        GROUP BY k.photo_id
      ),
      -- Each branch carries the matched photo's columns out of the index probe,
      -- so nothing joins back to photos by id: that re-join was planned as a
      -- sequential scan of the whole table once a batch had a few photos (#311).
      candidate AS (
        SELECT s.photo_id, p.id AS match_id, p.visit_id, p.section,
          p.content_hash, p.perceptual_hash, p.perceptual_hash_bands
        FROM src s
        JOIN photos p ON p.content_hash = s.content_hash
        UNION
        SELECT pr.photo_id, p.id AS match_id, p.visit_id, p.section,
          p.content_hash, p.perceptual_hash, p.perceptual_hash_bands
        FROM probe pr
        JOIN photos p ON p.perceptual_hash_bands && pr.band_keys
      ),
      scored AS (
        SELECT s.photo_id, s.outlet_id AS source_outlet_id,
          p.visit_id AS match_visit_id, v.outlet_id AS match_outlet_id,
          v.checkin_ts AS match_checkin_ts, p.section AS match_section,
          COALESCE(p.content_hash = s.content_hash, false) AS exact,
          -- Popcount of the XOR, spelled portably (bit_count() is Postgres 14+).
          CASE WHEN s.perceptual_hash IS NOT NULL AND cardinality(p.perceptual_hash_bands) > 0
            THEN length(replace(
              (('x' || p.perceptual_hash)::bit(64) # ('x' || s.perceptual_hash)::bit(64))::text, '0', ''
            ))
          END AS distance
        FROM candidate p
        JOIN src s ON s.photo_id = p.photo_id
        JOIN visits v ON v.id = p.visit_id
        WHERE v.client_id = ${clientId}
          AND p.visit_id <> s.visit_id
          AND p.section <> ${TASK_CLOSURE_PHOTO_SECTION}
          -- Bytewise id order, as computeFraudSignals compares ids in JS.
          AND (v.checkin_ts, v.id COLLATE "C") < (s.checkin_ts, s.visit_id COLLATE "C")
      )
      SELECT DISTINCT ON (photo_id)
        photo_id, match_visit_id, match_outlet_id, match_checkin_ts, match_section, exact, distance
      FROM scored
      WHERE exact OR distance <= ${maxDistance}
      ORDER BY photo_id,
        (match_outlet_id <> source_outlet_id) DESC,
        exact DESC,
        distance ASC NULLS LAST,
        match_checkin_ts DESC,
        match_visit_id DESC
    `,
  );

  const sourceById = new Map(hashed.map((s) => [s.photoId, s]));
  for (const row of rows) {
    const source = sourceById.get(row.photo_id);
    if (!source) {
      continue;
    }
    const list = byVisit.get(source.visitId) ?? [];
    list.push({
      photoId: row.photo_id,
      section: source.section,
      exact: row.exact,
      distance: row.distance === null ? null : Number(row.distance),
      matchVisitId: row.match_visit_id,
      matchOutletId: row.match_outlet_id,
      matchCheckinTs: row.match_checkin_ts,
      matchSection: row.match_section,
    });
    byVisit.set(source.visitId, list);
  }
  return byVisit;
}

/** One device position to look nearby outlets up for (#248). */
export interface OutletLookupPosition {
  visitId: string;
  /** The visit's own outlet, always returned so "clear of A" can be measured. */
  outletId: string;
  lat: number;
  lng: number;
}

interface NearbyOutletRow {
  visit_id: string;
  outlet_id: string;
  code: string;
  lat: number;
  lng: number;
}

/**
 * The positions a scored visit needs outlets for (#248): its counting-sitting
 * photos, plus its rejected attempts' positions when there is at least one such
 * photo (attempts alone never fire, so they never cost a lookup). Empty for a
 * visit without stock.
 */
function stockOutsideOutletPositions(
  visit: FraudVisitPayload,
  failedAttempts: FraudFailedAttempt[],
  kpiThresholds: unknown,
): OutletLookupPosition[] {
  if (visit.stock.length === 0) {
    return [];
  }
  const input = toFraudVisitInput(visit);
  const photos = captureSittingPhotos(input, visit.photos, kpiThresholds);
  if (photos.length === 0) {
    return [];
  }
  const coords = [
    ...photos.map((p) => p.coords),
    ...recentFailedAttempts(input, failedAttempts).flatMap((a) => attemptCoords(a) ?? []),
  ];
  return coords.map((c) => ({ visitId: visit.id, outletId: visit.outletId, lat: c.lat, lng: c.lng }));
}

/**
 * Outlets near many capture positions, in ONE round trip (#248).
 *
 * For each visit: its own outlet, plus every outlet of the same client whose
 * centre falls in a bounding box of GEOFENCE_RADIUS_M (widened) around any of the
 * visit's positions. The box is a cheap prefilter; computeFraudSignals applies
 * exact haversine to what comes back. Tenant scope is `client_id` on the outlet:
 * another client's store at the same spot is never returned.
 *
 * At today's scale the box filter runs over the client's outlets through the
 * `client_id` index and returns a handful of rows per visit. A spatial index is
 * where this belongs if the outlet count grows — #63 (PostGIS: ST_DWithin on a
 * GiST-indexed geography column replaces both the box and the haversine).
 */
export async function loadNearbyOutlets(
  clientId: string,
  positions: OutletLookupPosition[],
): Promise<Map<string, FraudOutletLocation[]>> {
  const byVisit = new Map<string, FraudOutletLocation[]>();
  if (positions.length === 0) {
    return byVisit;
  }
  const halfM = GEOFENCE_RADIUS_M * OUTLET_LOOKUP_BOX_MARGIN;
  const dLat = halfM / MIN_METRES_PER_DEGREE_LAT;
  const dLng = (lat: number) =>
    halfM / (METRES_PER_DEGREE_LNG_AT_EQUATOR * Math.max(MIN_COS_LAT, Math.cos((lat * Math.PI) / 180)));

  const rows = await prisma.$queryRaw<NearbyOutletRow[]>(
    Prisma.sql`
      SELECT DISTINCT p.visit_id, o.id AS outlet_id, o.code, o.lat, o.lng
      FROM unnest(
        ${positions.map((p) => p.visitId)}::text[],
        ${positions.map((p) => p.outletId)}::text[],
        ${positions.map((p) => p.lat - dLat)}::float8[],
        ${positions.map((p) => p.lat + dLat)}::float8[],
        ${positions.map((p) => p.lng - dLng(p.lat))}::float8[],
        ${positions.map((p) => p.lng + dLng(p.lat))}::float8[]
      ) AS p(visit_id, own_outlet_id, lat_min, lat_max, lng_min, lng_max)
      JOIN outlets o ON o.client_id = ${clientId}
        AND (
          o.id = p.own_outlet_id
          OR (o.lat BETWEEN p.lat_min AND p.lat_max AND o.lng BETWEEN p.lng_min AND p.lng_max)
        )
      ORDER BY p.visit_id, o.id
    `,
  );
  for (const row of rows) {
    const list = byVisit.get(row.visit_id) ?? [];
    list.push({ outletId: row.outlet_id, code: row.code, lat: Number(row.lat), lng: Number(row.lng) });
    byVisit.set(row.visit_id, list);
  }
  return byVisit;
}

/**
 * Score many loaded visits of ONE client, in a fixed number of queries (#236).
 *
 * The only scoring path. GET /fraud/visits/:id is a batch of one, the submit
 * hook goes through that same function, and the rescore routine
 * (fraudRescore.ts) feeds batches. Every lookup is batched: one read of
 * rejected check-in attempts and one of the client's thresholds, then one stock
 * history query (#245), one photo hash lookup (#244) and one outlet lookup
 * (#248), each skipping itself when nothing in the batch needs it. Each visit
 * gets exactly the inputs a batch of one would load, so a score does not depend
 * on which batch computed it.
 */
export async function scoreFraudBatch(clientId: string, visits: FraudVisitPayload[]): Promise<FraudResult[]> {
  if (visits.length === 0) {
    return [];
  }
  const checkins = visits.map((visit) => visit.checkinTs.getTime());
  const [attempts, client] = await Promise.all([
    prisma.checkInAttempt.findMany({
      where: {
        clientId,
        passed: false,
        agentId: { in: [...new Set(visits.map((visit) => visit.agentId))] },
        outletId: { in: [...new Set(visits.map((visit) => visit.outletId))] },
        // Only the 6h before a check-in can count. Every reader applies that
        // window again per visit (recentFailedAttempts); this only bounds the read.
        createdAt: {
          gte: new Date(Math.min(...checkins) - FAILED_ATTEMPT_WINDOW_MS),
          lte: new Date(Math.max(...checkins)),
        },
      },
    }),
    prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } }),
  ]);
  const kpiThresholds = client?.kpiThresholds;
  const attemptsByVisit = new Map(
    visits.map((visit) => [
      visit.id,
      attempts.filter((attempt) => attempt.agentId === visit.agentId && attempt.outletId === visit.outletId),
    ]),
  );

  const [priorByVisit, photoMatchesByVisit, nearbyOutletsByVisit] = await Promise.all([
    // Only a submitted visit with counts can repeat anything.
    loadPriorStockVisits(
      clientId,
      visits
        .filter((visit) => visit.status === 'submitted' && visit.stock.length > 0)
        .map((visit) => ({ outletId: visit.outletId, checkinTs: visit.checkinTs, visitId: visit.id })),
      repeatingStockLookbackVisits(kpiThresholds),
    ),
    // Skips itself when no photo in the batch has a hash.
    loadDuplicatePhotoMatches(
      clientId,
      visits.flatMap(duplicatePhotoSources),
      duplicatePhotoMaxDistance(kpiThresholds),
    ),
    // Skips itself unless a submitted visit with stock has a geotagged photo
    // from its counting sitting.
    loadNearbyOutlets(
      clientId,
      visits.flatMap((visit) =>
        stockOutsideOutletPositions(visit, attemptsByVisit.get(visit.id) ?? [], kpiThresholds),
      ),
    ),
  ]);

  return visits.map((visit) =>
    computeFraudSignals(
      toFraudVisitInput(visit),
      {
        photos: visit.photos,
        sectionCreatedAts: sectionCreatedAts(visit),
        failedAttempts: attemptsByVisit.get(visit.id) ?? [],
        stockCounts: toStockCounts(visit),
        priorStockVisits: priorByVisit.get(visit.id) ?? [],
        photoMatches: photoMatchesByVisit.get(visit.id) ?? [],
        nearbyOutlets: nearbyOutletsByVisit.get(visit.id) ?? [],
      },
      kpiThresholds,
    ),
  );
}

/**
 * GET /fraud/visits/:visitId — score one tenant-scoped visit, LIVE.
 *
 * Always recomputed from the current data and the client's current
 * kpiThresholds, never read from the stored `riskScore`: for one visit that is
 * cheap, and it is the view a reviewer opens to decide. The stored column is a
 * snapshot kept for the flagged list only (see listFlagged).
 */
export async function getVisitFraud(visitId: string, clientId: string): Promise<FraudResult> {
  const visit = await prisma.visit.findFirst({
    where: { id: visitId, clientId },
    include: fraudVisitInclude,
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const [result] = await scoreFraudBatch(clientId, [visit]);
  return result;
}

/**
 * Store fraud results on their visits (#236): `riskScore`, `fraudSignals` and
 * `fraudScoredAt`, always together, in one transaction.
 *
 * `scoredAt` is when the inputs were read, taken before the scoring queries, so
 * it measures how old the snapshot is, not when the row was written.
 *
 * Each write is guarded: a row is only written while its `fraudScoredAt` is
 * null or earlier than `notNewerThan`. A score taken after that moment (a
 * submit, or a second rescore that started later) is never replaced by this
 * one. Returns how many rows were written; the rest kept their newer score.
 */
export async function storeFraudScores(
  results: FraudResult[],
  scoredAt: Date,
  notNewerThan: Date = scoredAt,
): Promise<number> {
  if (results.length === 0) {
    return 0;
  }
  const writes = await prisma.$transaction(
    results.map((result) =>
      prisma.visit.updateMany({
        where: {
          id: result.visitId,
          OR: [{ fraudScoredAt: null }, { fraudScoredAt: { lt: notNewerThan } }],
        },
        data: {
          riskScore: result.riskScore,
          fraudSignals: result.signals as unknown as Prisma.InputJsonValue,
          fraudScoredAt: scoredAt,
        },
      }),
    ),
  );
  return writes.reduce((sum, write) => sum + write.count, 0);
}

/**
 * The submit hook (#236): score one visit and store the result on it.
 *
 * The same code path as GET /fraud/visits/:id, then one guarded write. It
 * throws whatever that throws; submitVisit catches and logs, because a
 * persisted submit must never fail on scoring.
 */
export async function scoreAndStoreVisitFraud(visitId: string, clientId: string): Promise<FraudResult> {
  const scoredAt = new Date();
  const result = await getVisitFraud(visitId, clientId);
  await storeFraudScores([result], scoredAt);
  return result;
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
  /** When the stored score's inputs were read: how old this snapshot is (#236). */
  scoredAt: Date | null;
}

/** Default review window when the caller does not name one. */
export const DEFAULT_FRAUD_WINDOW_DAYS = 30;

export interface ListFlaggedInput {
  clientId: string;
  minScore: number;
  from?: Date;
  to?: Date;
  /** Page size. Defaults to the standard list default (DEFAULT_LIMIT). */
  limit?: number;
  cursor?: string;
}

export interface FlaggedPage {
  data: FlaggedVisit[];
  nextCursor: string | null;
  /**
   * Submitted visits in the same window with no stored score yet (recorded
   * before #236 and not backfilled). They can be neither listed nor ruled out,
   * so they are counted: a list that silently skipped them would read as
   * "nothing suspicious" when the truth is "not looked at".
   */
  unscored: number;
  /** The window `data` and `unscored` cover, defaults applied. */
  from: Date;
  to: Date;
}

/**
 * GET /fraud/flagged — submitted visits whose STORED score is at or above
 * `minScore`, highest risk first, one standard keyset page at a time (#236).
 *
 * The score used to be computed in memory on every request, so the endpoint
 * could only bound its scan (a date window plus a 2000-visit ceiling, #239) and
 * could not paginate: both the filter and the sort were computed. It now reads
 * `Visit.riskScore`, written at submit and by `npm run rescore-fraud`, so the
 * filter and the sort are columns, served in order by the
 * (client_id, status, risk_score DESC, id DESC) index, and the standard
 * `take: limit + 1` / `cursor` template applies.
 *
 * Staleness, stated plainly. A stored score is a snapshot taken at submit
 * (`scoredAt`). Several signals read things that can change afterwards —
 * earlier visits' stock and photos, rejected check-in attempts, the client's
 * kpiThresholds — and this list does not see those changes until the visit is
 * rescored. A client that changes a fraud threshold runs
 * `npm run rescore-fraud -- --client <id> --all`. GET /fraud/visits/:id is
 * always live, so the visit a reviewer opens is scored against today's data.
 *
 * Visits without a stored score are excluded and counted in `unscored`.
 *
 * The window is a review horizon, no longer a scan bound: `checkinTs` within
 * [from, to], defaulting to the last DEFAULT_FRAUD_WINDOW_DAYS as before.
 */
export async function listFlagged(input: ListFlaggedInput): Promise<FlaggedPage> {
  const { clientId } = input;
  const limit = input.limit ?? DEFAULT_LIMIT;
  const to = input.to ?? new Date();
  const from = input.from ?? new Date(to.getTime() - DEFAULT_FRAUD_WINDOW_DAYS * MS_PER_DAY);
  // Scores are whole numbers in [0, 100] in an Int column: 49.5 means 50, and
  // anything above 100 matches nothing (a fraction or 1e12 would be refused by
  // the column's type rather than meaning "none").
  const minScore = Math.min(RISK_MAX + 1, Math.max(RISK_MIN, Math.ceil(input.minScore)));

  const inWindow: Prisma.VisitWhereInput = {
    clientId,
    status: 'submitted',
    checkinTs: { gte: from, lte: to },
  };
  const [rows, unscored] = await Promise.all([
    prisma.visit.findMany({
      where: { ...inWindow, riskScore: { gte: minScore } },
      select: {
        id: true,
        outletId: true,
        agentId: true,
        riskScore: true,
        fraudSignals: true,
        fraudScoredAt: true,
      },
      // `id` is the unique tiebreaker, in the same direction as the primary
      // sort — equal scores are the norm here (weights are a handful of flat
      // values), and a mismatch drops or repeats rows at page boundaries.
      orderBy: [{ riskScore: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
    }),
    prisma.visit.count({ where: { ...inWindow, riskScore: null } }),
  ]);

  const page = buildPage(rows, limit);
  return {
    data: page.data.map((row) => ({
      visitId: row.id,
      outletId: row.outletId,
      agentId: row.agentId,
      // Never null here: the filter requires a score.
      riskScore: row.riskScore ?? RISK_MIN,
      signals: (row.fraudSignals ?? []) as unknown as FraudSignal[],
      scoredAt: row.fraudScoredAt,
    })),
    nextCursor: page.nextCursor,
    unscored,
    from,
    to,
  };
}
