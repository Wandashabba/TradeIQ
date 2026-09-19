import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { haversineDistanceMeters, isWithinGeofence } from '../../lib/geofence';
import {
  ConflictError,
  GeofenceRejectedError,
  NotFoundError,
  TooManyRequestsError,
} from '../../middleware/errorHandler';
import { Prisma, type Visit } from '@prisma/client';
import type { AuthTokenPayload } from '../auth/auth.service';
import { dispatchWebhookEvent } from '../webhooks/webhooks.service';
import { DEFAULT_PRICE_DEVIATION_THRESHOLD, evaluateVisit } from '../alerts/alerts.service';
import { computeFraudSignals, scoreAndStoreVisitFraud, type FraudResult } from '../fraud/fraud.service';
import {
  DEFAULT_GREEN_THRESHOLD,
  SCORECARD_DIMENSIONS,
  type ScorecardDimension,
} from '../scorecards/scorecards.service';
import { coverageStatus } from '../../services/forecast.service';
import { kpiThreshold } from '../../lib/kpiThresholds';
import { DEFAULT_CLIENT_TIME_ZONE, localCalendarDate, startOfLocalDay } from '../../lib/clientTime';
import { markRouteStopsVisited } from '../beatplans/beatplans.service';
import { recordPointsBestEffort, recordVisitSubmitted } from '../gamification/pointsLedger';

/** Longest accepted clientVisitId. A UUID is 36; this leaves room, not abuse.
 *  The same bound as `Message.clientMessageId` (#308), deliberately. */
export const MAX_CLIENT_VISIT_ID_LENGTH = 128;

// ── The "the pin is wrong" override (#386) ────────────────────────────────
/**
 * The furthest an agent may be from a pin and still claim the PIN is what is
 * wrong. Per client, read from `Client.kpiThresholds` like every other tunable.
 */
export const PIN_DISPUTE_MAX_DISTANCE_M_KEY = 'pinDisputeMaxDistanceM';
/**
 * 25 km.
 *
 * Deliberately generous, because the failure this exists for is generous: the
 * issue's own case is a store pinned to a depot 8.4 km away, and a tenant whose
 * depot sits on the far side of a metro can easily be further. A tight cap here
 * would recreate the bug it fixes — an agent standing in a real shop, told no,
 * with nothing to press.
 *
 * It is still a bound, and the bound is the point: it separates "the office
 * pinned this store to the wrong place in this city" from "this phone is in a
 * different province from the shop it says it is standing in". The second is
 * not a pin error, and the fraud engine should never be asked to treat it as
 * one.
 */
export const DEFAULT_PIN_DISPUTE_MAX_DISTANCE_M = 25_000;
// Operator-facing notes on both of these, and on the fraud weight they feed:
// docs/operations/pin-repair-and-geofence-override.md
/** Longest note an agent may attach to a pin dispute. */
export const MAX_PIN_DISPUTE_NOTE_LENGTH = 1000;

/**
 * How many pin disputes one agent may open in one CLIENT-LOCAL day.
 *
 * The distance cap above bounds one claim. Nothing bounded the tenth. An agent
 * sitting at home is within 25 km of every outlet in their metro, and each
 * claim, scored on its own, came to 30 — under the 50 review threshold — so a
 * morning of them reached no manager at all while every visit earned its
 * points. A cap is the crude half of the answer (the fraud engine's
 * override-rate and override-cluster signals are the other half): past N the
 * eleventh claim is REFUSED, not merely scored.
 *
 * Per client, from `Client.kpiThresholds`, like every other tunable.
 */
export const PIN_DISPUTE_DAILY_CAP_KEY = 'pinDisputeDailyCap';
/**
 * Three a day.
 *
 * An honest agent meets a wrongly pinned outlet rarely — the depot-onboarding
 * case puts several on one beat, which is why this is not one — but an agent
 * who files a fourth in a day is either working a beat that needs a bulk fix
 * from the office or is not where they say they are. Both want a person, and
 * the ceiling is what gets one: it turns an unbounded morning into three
 * claims and a message naming the manager's queue.
 *
 * A tenant whose data really is that broken can raise it. Zero or negative is
 * a typo, not a policy — "no agent may ever report a wrong pin" reinstates the
 * bug this whole feature exists for — and falls back to the default.
 */
export const DEFAULT_PIN_DISPUTE_DAILY_CAP = 3;

/** The daily cap for one client, defended against a typo. See the default. */
export function pinDisputeDailyCap(kpiThresholds: unknown): number {
  const raw = Math.floor(
    kpiThreshold(kpiThresholds, PIN_DISPUTE_DAILY_CAP_KEY, DEFAULT_PIN_DISPUTE_DAILY_CAP),
  );
  return raw > 0 ? raw : DEFAULT_PIN_DISPUTE_DAILY_CAP;
}

export interface CheckInInput {
  outletId: string;
  lat: number;
  lng: number;
  clientId: string;
  agentId: string;
  // Client-captured check-in time (ISO). Preserved for offline-first: a visit
  // may be captured hours before it syncs, so the client's timestamp is the
  // real one. Falls back to the server clock when absent.
  checkinTs?: string;
  /**
   * The DEVICE's own id for this visit — its idempotency key (#379, #385).
   *
   * Optional, so an older app build that sends none behaves exactly as it
   * always did: no key, no dedupe, and Postgres treats the NULLs as distinct so
   * the unique index does not constrain it.
   */
  clientVisitId?: string;
  /**
   * True when the agent RESUMED a saved draft rather than checking in fresh
   * (#379). Defaults false, which is what every older build and every existing
   * visit honestly is.
   */
  resumed?: boolean;
  /**
   * "The pin is wrong" (#386) — the agent's claim that the fence they just
   * failed is around the wrong place, with the note they typed.
   *
   * Absent on every ordinary check-in, which is every check-in that passes the
   * fence. Present, it does NOT make the geofence pass: the visit is created
   * with `geofencePass: false` and a `PinDispute` row beside it, so the manager
   * and the fraud engine both see an override rather than a clean check-in.
   * See `checkIn` for why it is not a bypass.
   */
  pinDispute?: { note?: string };
  /**
   * What the device said about the QUALITY of the fix it just sent (#386
   * follow-up): its reported horizontal accuracy in metres, and whether the
   * platform called it a mock location.
   *
   * Both optional and both recorded, never acted on as a permission: they
   * cannot make a failing check-in pass, and a build that sends neither
   * behaves exactly as it did. What they change is the repair — a manager
   * adopting an agent's position onto an outlet's pin is moving an access
   * boundary on one phone's word, and `isMocked: true` makes that refusable
   * rather than invisible.
   */
  accuracyM?: number;
  isMocked?: boolean;
}

export interface CheckInResult {
  visit: Visit;
  /**
   * True when this request found a visit already stored under its
   * `clientVisitId` and returned THAT one instead of creating a second.
   *
   * The route answers 200 rather than 201 for it — the resource was not created
   * by this request — but the body is the same visit either way, so a client
   * that only reads `id` needs no change at all.
   */
  deduplicated: boolean;
}

/**
 * Geofenced check-in — idempotent when the device sends a `clientVisitId`
 * (#379, #385).
 *
 * The app mints a local uuid the moment an agent checks in and flushes the
 * outbox later. When that POST succeeded but its response was lost — a dead
 * zone at the shop door, which is the normal case, not the edge case — the
 * retry created a SECOND visit: one store walk, two rows, two scorecards, two
 * fraud scores, and a manager with no way to tell which was the real one.
 *
 * With a key, the retry finds the first row and returns it.
 *
 * **The dedupe lookup runs FIRST, before anything is written.** That ordering
 * is the point, not a micro-optimisation: `checkIn` records a `CheckInAttempt`
 * row and moves `User.lastLat/lastLng` before the visit is created, and a retry
 * is not a second attempt to check in. Letting a retry write an attempt row
 * would feed the fraud engine's negative-signal dataset a rejected-looking
 * burst of attempts for a visit that actually happened once, and would move the
 * agent's last-known position to wherever they were when the outbox finally
 * flushed — which may be the next town.
 */
export async function checkIn(input: CheckInInput): Promise<CheckInResult> {
  // Before the attempt row, before the location update, before the outlet is
  // even looked up: this request may not be a check-in at all.
  if (input.clientVisitId !== undefined) {
    const existing = await findByClientVisitId(input);
    if (existing) {
      return { visit: existing, deduplicated: true };
    }
  }

  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  // Measure the check-in distance once and derive both the pass decision and
  // the persisted distance from it, so what we store matches what we evaluated.
  const distanceMeters = haversineDistanceMeters(
    { lat: outlet.lat, lng: outlet.lng },
    { lat: input.lat, lng: input.lng },
  );
  const geofencePass = isWithinGeofence(
    { lat: outlet.lat, lng: outlet.lng },
    { lat: input.lat, lng: input.lng },
  );
  const distanceM = Math.round(distanceMeters * 10) / 10;

  // Record EVERY attempt — including rejected/borderline ones — as the
  // negative-signal dataset for fraud/ghost-visit detection (Phase 2 #3).
  await prisma.checkInAttempt.create({
    data: {
      clientId: input.clientId,
      outletId: input.outletId,
      agentId: input.agentId,
      lat: input.lat,
      lng: input.lng,
      distanceM,
      passed: geofencePass,
      // Recorded on EVERY attempt, passing or not: the attempt a manager later
      // adopts as an outlet's pin is usually a failed one, and by then the only
      // thing that can say whether that coordinate was real is this row.
      accuracyM: input.accuracyM,
      isMocked: input.isMocked,
    },
  });

  // ── The override, and why it is not a bypass (#386) ──────────────────────
  //
  // A wrongly pinned outlet is permanently un-visitable: the create form took
  // the phone's position as the only source of an outlet's coordinates, so a
  // store onboarded at the depot is pinned to the depot, and the agent standing
  // inside it measures 8.4 km forever. Refusing them is refusing the only
  // person who can see that the data is wrong.
  //
  // Letting them through anyway is the exact control check-in fraud detection
  // exists to impose, so the override buys its way in:
  //
  //  1. It never fakes a pass. `geofencePass` stays FALSE on the visit — the
  //     value is the measurement, not a permission. Everything downstream that
  //     reads it (the manager's review, the fraud engine's signals) sees an
  //     override, not a clean check-in.
  //  2. It leaves evidence in the same transaction as the visit: where the
  //     agent actually was, how far that was from the pin — measured here,
  //     never accepted from the device — and the pin as it read at the time.
  //  3. It is bounded. Beyond `pinDisputeMaxDistanceM` the claim is refused:
  //     a pin can be in the wrong part of town, and that is what the default
  //     allows for generously, but at some distance "the pin is wrong" stops
  //     being the likeliest explanation for where the phone is.
  //  4. It cannot be self-granted. Resolving a dispute means moving the pin,
  //     and PATCH /outlets/:id is manager/admin only.
  if (!geofencePass && input.pinDispute) {
    const client = await prisma.client.findUnique({
      where: { id: input.clientId },
      select: { kpiThresholds: true, timezone: true },
    });
    const maxDistanceM = kpiThreshold(
      client?.kpiThresholds,
      PIN_DISPUTE_MAX_DISTANCE_M_KEY,
      DEFAULT_PIN_DISPUTE_MAX_DISTANCE_M,
    );
    if (distanceM > maxDistanceM) {
      // The same 422 an ordinary rejection gets, with the reason named. The
      // attempt row above is already written either way, so a run of these is
      // visible to the fraud engine exactly as a run of retries is.
      throw new GeofenceRejectedError(
        `Check-in is ${Math.round(distanceM)}m from this outlet, beyond the ` +
          `${maxDistanceM}m limit for reporting a wrong pin. Ask a manager to ` +
          'correct the outlet instead.',
      );
    }

    // ── The two bounds the distance cap does not give (#386 follow-up) ────
    //
    // Both read the same range — this agent's claims since the start of their
    // client's local day — and both refuse rather than score, because a score
    // under the review threshold is a refusal nobody performs.
    //
    // The day is the CLIENT's, not UTC: an agent checking in at 01:00 SAST is
    // still on the same working day, and a cap that reset in the middle of a
    // night shift would be a cap that reset in the middle of a night shift.
    const timeZone = client?.timezone ?? DEFAULT_CLIENT_TIME_ZONE;
    const now = new Date();
    const dayStart = startOfLocalDay(localCalendarDate(now, timeZone), timeZone);
    const todaysClaims = await prisma.pinDispute.findMany({
      where: { clientId: input.clientId, agentId: input.agentId, createdAt: { gte: dayStart } },
      select: { id: true, outletId: true, visitId: true, status: true },
    });

    // 1. The REPLAY. One failed position posted three times made three visits,
    //    three disputes and three submitted-visit counts, because a POST with
    //    no clientVisitId is deduplicated by nothing. A second claim about the
    //    same pin on the same day says nothing the first did not: the pin has
    //    not moved, and the manager's queue does not need the claim twice.
    //    409 with the existing visit named, so the app can resume it rather
    //    than reading the refusal as "your evidence was lost".
    const alreadyClaimed = todaysClaims.find((claim) => claim.outletId === input.outletId);
    if (alreadyClaimed) {
      throw new ConflictError(
        alreadyClaimed.status === 'open'
          ? `You already reported this pin (visit ${alreadyClaimed.visitId}); a manager has not answered it yet.`
          : `You already reported this pin today (visit ${alreadyClaimed.visitId}).`,
      );
    }

    // 2. The RATE. Nothing stopped the tenth override, or the hundredth.
    const dailyCap = pinDisputeDailyCap(client?.kpiThresholds);
    if (todaysClaims.length >= dailyCap) {
      throw new TooManyRequestsError(
        `You have reported ${todaysClaims.length} wrong pins today, which is the limit of ` +
          `${dailyCap}. Ask a manager to correct these outlets before reporting more.`,
      );
    }

    await prisma.user.update({
      where: { id: input.agentId },
      data: { lastLat: input.lat, lastLng: input.lng, lastSeenAt: new Date() },
    });

    try {
      // One transaction: the visit and the evidence for why it was allowed
      // exist together or not at all. A visit created outside the fence with no
      // dispute row beside it would be an unexplained override, which is worse
      // than either a refusal or an explained one.
      const visit = await prisma.$transaction(async (tx) => {
        const created = await tx.visit.create({
          data: {
            outletId: input.outletId,
            agentId: input.agentId,
            clientId: input.clientId,
            checkinTs: input.checkinTs ? new Date(input.checkinTs) : new Date(),
            checkinLat: input.lat,
            checkinLng: input.lng,
            // FALSE. The whole point.
            geofencePass: false,
            checkinDistanceM: distanceM,
            status: 'in_progress',
            clientVisitId: input.clientVisitId,
            resumedFromDraft: input.resumed ?? false,
          },
        });
        await tx.pinDispute.create({
          data: {
            clientId: input.clientId,
            outletId: input.outletId,
            agentId: input.agentId,
            visitId: created.id,
            lat: input.lat,
            lng: input.lng,
            distanceM,
            outletLat: outlet.lat,
            outletLng: outlet.lng,
            note: input.pinDispute?.note ?? null,
            // Frozen onto the claim beside the coordinate, so the manager who
            // judges it months later reads the quality of the fix and not only
            // the fix. Null means the device did not say.
            accuracyM: input.accuracyM,
            isMocked: input.isMocked,
          },
        });
        return created;
      });
      return { visit, deduplicated: false };
    } catch (err) {
      // Same idempotency race as the ordinary path below.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002' &&
        input.clientVisitId !== undefined
      ) {
        const winner = await findByClientVisitId(input);
        if (winner) {
          return { visit: winner, deduplicated: true };
        }
      }
      throw err;
    }
  }

  if (!geofencePass) {
    throw new GeofenceRejectedError('Check-in location is outside the outlet geofence');
  }

  // Update the agent's last-known location (feeds predictive dispatch #4).
  await prisma.user.update({
    where: { id: input.agentId },
    data: { lastLat: input.lat, lastLng: input.lng, lastSeenAt: new Date() },
  });

  try {
    const visit = await prisma.visit.create({
      data: {
        outletId: input.outletId,
        agentId: input.agentId,
        clientId: input.clientId,
        checkinTs: input.checkinTs ? new Date(input.checkinTs) : new Date(),
        checkinLat: input.lat,
        checkinLng: input.lng,
        geofencePass,
        checkinDistanceM: distanceM,
        status: 'in_progress',
        clientVisitId: input.clientVisitId,
        resumedFromDraft: input.resumed ?? false,
      },
    });
    return { visit, deduplicated: false };
  } catch (err) {
    // The race: two retries of one lost response arriving at once. Both miss
    // the lookup above, and the unique (agent_id, client_visit_id) index lets
    // exactly one insert win. The loser reads the winner back and answers as a
    // retry would — a 500 here would send the app away to retry again, which is
    // how one lost response becomes an endless one.
    //
    // The loser has already written its CheckInAttempt row by this point, and
    // that row stays. Deleting it would be deleting evidence the geofence
    // genuinely evaluated, and a concurrent double-flush is rare enough that a
    // duplicate PASSED attempt is the lesser distortion.
    if (
      err instanceof Prisma.PrismaClientKnownRequestError &&
      err.code === 'P2002' &&
      input.clientVisitId !== undefined
    ) {
      const winner = await findByClientVisitId(input);
      if (winner) {
        return { visit: winner, deduplicated: true };
      }
    }
    throw err;
  }
}

/**
 * The visit this agent already stored under this device key, or null.
 *
 * Scoped to the agent AND the tenant. The unique index is (agent_id,
 * client_visit_id) — per agent, for the same reason `Message.clientMessageId`
 * is per sender: two agents' local uuids are separate namespaces, and one
 * agent's key must never resolve to another's visit.
 */
function findByClientVisitId(input: CheckInInput): Promise<Visit | null> {
  return prisma.visit.findFirst({
    where: {
      agentId: input.agentId,
      clientId: input.clientId,
      clientVisitId: input.clientVisitId,
    },
  });
}

export interface SubmitVisitInput {
  visitId: string;
  clientId: string;
  agentId: string;
  /**
   * The DEVICE's completion timestamp (ISO 8601), from the same clock that
   * produced `checkinTs`. Dwell time is only meaningful measured on one clock —
   * see `Visit.submittedAtClient` and #101. Optional: an older client that does
   * not send it simply yields no dwell measurement, which is the honest outcome.
   */
  submittedAtClient?: string;
}

export async function submitVisit(input: SubmitVisitInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  // Only accept a parseable timestamp — a junk string must not become an
  // Invalid Date that silently poisons the dwell calculation.
  const clientCompletedAt = input.submittedAtClient
    ? new Date(input.submittedAtClient)
    : undefined;
  const submittedAtClient =
    clientCompletedAt && !Number.isNaN(clientCompletedAt.getTime())
      ? clientCompletedAt
      : undefined;

  const submitted = await prisma.visit.update({
    where: { id: input.visitId },
    data: { status: 'submitted', ...(submittedAtClient ? { submittedAtClient } : {}) },
  });

  // Issue #52: the visit is the stop being visited, so the agent's route
  // progresses without a manager ticking it. Done here, server-side, so an
  // offline visit that syncs hours later is handled exactly like a live one.
  // Best-effort, like evaluateVisit below: the submission is already persisted
  // and must not fail because route bookkeeping did.
  try {
    await markRouteStopsVisited({
      clientId: submitted.clientId,
      agentId: submitted.agentId,
      outletId: submitted.outletId,
      checkinTs: submitted.checkinTs,
    });
  } catch (err) {
    console.error(`Marking beat-plan stops visited failed for visit ${submitted.id}:`, err);
  }

  // Issue #124: the submission earns points — record it on the ledger so the
  // leaderboard can say where they came from. Best-effort and idempotent: a
  // re-submit adds nothing, and a failed write never fails the submission (the
  // backfill script fills anything missed).
  await recordPointsBestEffort(`visit ${submitted.id}`, () => recordVisitSubmitted(submitted));

  // Issue #38: fire best-effort to any webhooks the client has subscribed to
  // this event. dispatchWebhookEvent never throws (swallows delivery errors),
  // so awaiting is safe and avoids open-handle warnings.
  await dispatchWebhookEvent(submitted.clientId, 'visit.submitted', {
    visitId: submitted.id,
    outletId: submitted.outletId,
  });

  // Issue #53: auto-evaluate the client's alert rules against the just-submitted
  // visit so exceptions surface without a manual POST /alerts/evaluate.
  // Best-effort — a rules-evaluation failure must not fail a submission that has
  // already been persisted. evaluateVisit itself fires the alert.raised webhook.
  try {
    await evaluateVisit({ clientId: submitted.clientId, visitId: submitted.id });
  } catch (err) {
    console.error(`Auto-evaluate alerts failed for visit ${submitted.id}:`, err);
  }

  // Issue #236: store the visit's fraud score, so GET /fraud/flagged filters and
  // sorts on a column instead of scoring every visit on every request. The same
  // code path as GET /fraud/visits/:id. Best-effort, like the alerts above: the
  // submission is already persisted, and a visit left unscored is reported by
  // the flagged list as `unscored` and picked up by `npm run rescore-fraud`.
  // The stored score is a snapshot of today's history and thresholds; see
  // listFlagged for how that is handled.
  try {
    await scoreAndStoreVisitFraud(submitted.id, submitted.clientId);
  } catch (err) {
    console.error(`Fraud scoring failed for visit ${submitted.id}:`, err);
  }

  return submitted;
}

export interface ListVisitsInput {
  clientId: string;
  role: AuthTokenPayload['role'];
  // Required in practice for a field_agent (they only see their own visits);
  // ignored for managers/admins, who see the whole client's visits.
  agentId?: string;
  outletId?: string;
  status?: 'in_progress' | 'submitted';
  limit: number;
  cursor?: string;
}

/**
 * The tenant-wide visit list — the worst case #141 named explicitly: roughly
 * 190k rows a year for a busy client, previously returned in one unbounded
 * `findMany`.
 */
export async function listVisits(input: ListVisitsInput) {
  const where: Prisma.VisitWhereInput = { clientId: input.clientId };
  if (input.role === 'field_agent') {
    where.agentId = input.agentId;
  }
  if (input.outletId) {
    where.outletId = input.outletId;
  }
  if (input.status) {
    where.status = input.status;
  }

  const rows = await prisma.visit.findMany({
    where,
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two visits share a checkinTs — offline drafts sync in bursts, so equal
    // timestamps are ordinary here rather than theoretical. Its direction must
    // match the primary sort's (both `desc`): Prisma seeks the cursor by the
    // whole orderBy tuple, and a mismatch silently drops or repeats rows at
    // every page boundary.
    orderBy: [{ checkinTs: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, input.limit);
}

// ── GET /visits/:id — the manager's review of one visit (#208) ─────────────
//
// Everything a reviewer needs on one screen: who, where, when, the score and
// its dimensions, what each capture section found, the evidence photos, and
// the fraud signals. One tenant-scoped query with narrow selects, then pure
// summarising in memory.
//
// Photos are METADATA ONLY. `Photo.url` is the stored base64 image (MBs per
// row) and is never selected here; the app fetches each thumbnail through
// `GET /photos/:id/thumbnail`, which is tenant-guarded and cached.

/** Rows read per list section. A visit's children are bounded by the client's
 * SKU catalogue, so this is a ceiling against a pathological visit, not a page
 * size: `count` always comes from `_count`, and `truncated` says when the
 * findings were drawn from fewer rows than exist. */
export const VISIT_DETAIL_MAX_SECTION_ROWS = 500;
/** Photo metadata rows returned (and scored for fraud). */
export const VISIT_DETAIL_MAX_PHOTOS = 200;
/** Findings named per section, worst first. The count carries the rest. */
export const VISIT_DETAIL_MAX_FINDINGS = 3;

const FAILED_ATTEMPT_LOOKBACK_MS = 6 * 60 * 60 * 1000;

export type VisitSectionKey = 'stock' | 'visibility' | 'pricing' | 'competitive' | 'risks';

export interface VisitSectionSummary {
  key: VisitSectionKey;
  /** Rows captured in this section (visibility: 0 or 1). */
  count: number;
  /** How many of those rows need a manager's attention. */
  flagged: number;
  /** Plain-language findings, worst first, at most VISIT_DETAIL_MAX_FINDINGS. */
  findings: string[];
  /** True when there were more rows than were read to build the findings. */
  truncated: boolean;
}

export interface VisitDetail {
  id: string;
  status: VisitStatusValue;
  outlet: { id: string; name: string; code: string; channelType: string };
  agent: { id: string; email: string };
  /** Device clock at check-in. */
  checkinTs: Date;
  /** Device clock at submit; null for a draft or a pre-#101 visit. */
  submittedAtClient: Date | null;
  geofence: { pass: boolean; distanceM: number | null };
  /**
   * The agent's "the pin is wrong" claim, when this visit was allowed through
   * the fence on one (#386), else null.
   *
   * `pass: false` above is the fact; this is the reason. Without it a reviewer
   * sees a visit recorded 8.4 km from the store and no way to tell an agent
   * reporting a depot-pinned outlet from one faking a visit — which is the
   * whole difference. `outletLat`/`outletLng` are the pin AS IT READ when the
   * claim was made, so a dispute read after the pin was corrected still shows
   * what the agent was arguing with.
   */
  pinDispute: {
    id: string;
    lat: number;
    lng: number;
    distanceM: number;
    outletLat: number;
    outletLng: number;
    note: string | null;
    status: string;
    resolvedByLabel: string | null;
    resolvedAt: Date | null;
    createdAt: Date;
  } | null;
  /**
   * True when the agent resumed a saved draft rather than checking in fresh
   * (#379).
   *
   * A reviewer reading the timeline needs it: a resumed visit's check-in
   * happened earlier and its dwell spans an interruption, so without the marker
   * a paused visit and an idle agent are indistinguishable. False for every
   * visit recorded before it existed, and for every older app build, which is
   * what those genuinely are.
   */
  resumedFromDraft: boolean;
  /** Null until the visit has been scored. */
  score: {
    weightedTotal: number;
    ratingBand: string;
    /** The client's current green line — the standard the total is read against. */
    target: number;
    /** Every dimension, in the fixed order; `score` null means not measurable. */
    dimensions: Array<{ key: ScorecardDimension; score: number | null }>;
    /**
     * When the SERVER computed `weightedTotal`.
     *
     * This reads `Scorecard.scoredAt`, not `createdAt`. `createdAt` survives the
     * regenerate upsert, so after a rescore it named when the FIRST score was
     * written — a screen saying "scored 71 on Tuesday" about a number decided on
     * Thursday. Same field, same type; it just stopped being wrong (#390).
     */
    scoredAt: Date;
    /**
     * The score the DEVICE showed the agent, or null (#390, #399).
     *
     * **Null means "we do not know what they saw", and must never render as 0.**
     * Every scorecard written before #390, and every one an older app build
     * sends, has no provisional — that is not a device that scored zero, it is a
     * device whose number was thrown away on sync. `seenAt` is null in turn when
     * the client sent a score but no device clock for it.
     */
    provisional: { weightedTotal: number; ratingBand: string; seenAt: Date | null } | null;
  } | null;
  sections: VisitSectionSummary[];
  photos: {
    total: number;
    items: Array<{ id: string; section: string; timestamp: Date; thumbnailUrl: string }>;
  };
  fraud: Pick<FraudResult, 'riskScore' | 'signals'>;
  /**
   * The visit's answers to its client's audit template — the "client
   * questions" section that supplements S1–S10 (#122). Empty when the client
   * uses no template or the agent answered none. `schema` is the template's
   * CURRENT schema (templates keep no version history), so the app resolves
   * question labels from it and says when `templateVersion` is older than
   * `currentVersion`. Never part of `score`.
   */
  templateResponses: Array<{
    templateId: string;
    templateName: string;
    /** The version the answers were given against. */
    templateVersion: number;
    currentVersion: number;
    schema: Prisma.JsonValue;
    answers: Prisma.JsonValue;
    recordedAt: Date;
  }>;
}

type VisitStatusValue = 'in_progress' | 'submitted';

function plural(n: number, one: string, many = `${one}s`): string {
  return `${n} ${n === 1 ? one : many}`;
}

function asDimensionRecord(value: Prisma.JsonValue): Record<string, number> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return {};
  const out: Record<string, number> = {};
  for (const [k, v] of Object.entries(value)) {
    if (typeof v === 'number' && Number.isFinite(v)) out[k] = v;
  }
  return out;
}

/** GET /visits/:id — manager/admin, tenant-scoped. 404 for another tenant's visit. */
export async function getVisitDetail(visitId: string, clientId: string): Promise<VisitDetail> {
  const take = VISIT_DETAIL_MAX_SECTION_ROWS;
  const visit = await prisma.visit.findFirst({
    where: { id: visitId, clientId },
    select: {
      id: true,
      status: true,
      agentId: true,
      outletId: true,
      checkinTs: true,
      checkinLat: true,
      checkinLng: true,
      submittedAtClient: true,
      resumedFromDraft: true,
      geofencePass: true,
      checkinDistanceM: true,
      outlet: { select: { id: true, name: true, code: true, channelType: true } },
      agent: { select: { id: true, email: true } },
      // The reason behind `geofencePass: false` (#386). Null on every visit
      // that passed the fence, which is every ordinary visit.
      pinDispute: {
        select: {
          id: true,
          lat: true,
          lng: true,
          distanceM: true,
          outletLat: true,
          outletLng: true,
          note: true,
          status: true,
          resolvedByLabel: true,
          resolvedAt: true,
          createdAt: true,
        },
      },
      scorecard: {
        select: {
          weightedTotal: true,
          ratingBand: true,
          dimensionScores: true,
          scoredAt: true,
          // What the agent SAW. Read here only to report it back; no scoring,
          // KPI or aggregate anywhere reads these columns (#390).
          provisionalTotal: true,
          provisionalBand: true,
          provisionalAt: true,
        },
      },
      stock: {
        select: {
          unitsAvailable: true,
          daysOutOfStock: true,
          coverageDaysPredicted: true,
          createdAt: true,
          sku: { select: { name: true } },
        },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take,
      },
      visibility: {
        select: {
          planogramCompliancePct: true,
          cleanlinessScore: true,
          highTrafficPass: true,
          createdAt: true,
        },
      },
      pricing: {
        select: {
          priceActual: true,
          priceMaster: true,
          deviationPct: true,
          promoActive: true,
          createdAt: true,
          sku: { select: { name: true } },
        },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take,
      },
      competitive: {
        select: {
          competitorSku: true,
          competitorPrice: true,
          competitorPromoterPresent: true,
          facingsCount: true,
          createdAt: true,
        },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take,
      },
      // Capability is not a summary section, but it is captured data: the
      // fraud engine's no_capture signal counts it, so its timestamp is read.
      capability: { select: { createdAt: true } },
      risks: {
        select: { flagType: true, severity: true, note: true },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take,
      },
      photos: {
        // NEVER `url` — see the note above.
        select: { id: true, section: true, timestamp: true, gpsTag: true },
        orderBy: [{ timestamp: 'asc' }, { id: 'asc' }],
        take: VISIT_DETAIL_MAX_PHOTOS,
      },
      _count: {
        select: { stock: true, pricing: true, competitive: true, risks: true, photos: true },
      },
      // The client-questions section (#122). One row per template at most.
      templateResponses: {
        select: {
          templateId: true,
          templateVersion: true,
          answers: true,
          createdAt: true,
          template: { select: { name: true, version: true, schema: true } },
        },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      },
    },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const [failedAttempts, client] = await Promise.all([
    // Only the window the heuristic looks at — not the pair's whole history.
    prisma.checkInAttempt.findMany({
      where: {
        clientId,
        agentId: visit.agentId,
        outletId: visit.outletId,
        passed: false,
        createdAt: {
          gte: new Date(visit.checkinTs.getTime() - FAILED_ATTEMPT_LOOKBACK_MS),
          lte: visit.checkinTs,
        },
      },
      select: { createdAt: true },
    }),
    prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true, timezone: true } }),
  ]);

  const sectionCreatedAts: Date[] = [
    ...visit.stock.map((r) => r.createdAt),
    ...(visit.visibility ? [visit.visibility.createdAt] : []),
    ...visit.pricing.map((r) => r.createdAt),
    ...visit.competitive.map((r) => r.createdAt),
    ...(visit.capability ? [visit.capability.createdAt] : []),
  ];

  const fraud = computeFraudSignals(
    {
      id: visit.id,
      status: visit.status,
      agentId: visit.agentId,
      outletId: visit.outletId,
      checkinTs: visit.checkinTs,
      checkinLat: visit.checkinLat,
      checkinLng: visit.checkinLng,
      checkinDistanceM: visit.checkinDistanceM,
      submittedAtClient: visit.submittedAtClient,
    },
    { photos: visit.photos, sectionCreatedAts, failedAttempts },
    client?.kpiThresholds,
    // Resolved in the same client read as the thresholds (#325).
    client?.timezone ?? DEFAULT_CLIENT_TIME_ZONE,
  );

  let score: VisitDetail['score'] = null;
  if (visit.scorecard) {
    const stored = asDimensionRecord(visit.scorecard.dimensionScores);
    score = {
      weightedTotal: visit.scorecard.weightedTotal,
      ratingBand: visit.scorecard.ratingBand,
      target: kpiThreshold(client?.kpiThresholds, 'green', DEFAULT_GREEN_THRESHOLD),
      dimensions: SCORECARD_DIMENSIONS.map((key) => ({ key, score: stored[key] ?? null })),
      scoredAt: visit.scorecard.scoredAt,
      // Both halves or neither: a total without a band is not a score anyone saw.
      provisional:
        visit.scorecard.provisionalTotal !== null && visit.scorecard.provisionalBand !== null
          ? {
              weightedTotal: visit.scorecard.provisionalTotal,
              ratingBand: visit.scorecard.provisionalBand,
              seenAt: visit.scorecard.provisionalAt,
            }
          : null,
    };
  }

  return {
    id: visit.id,
    status: visit.status,
    outlet: visit.outlet,
    agent: visit.agent,
    checkinTs: visit.checkinTs,
    submittedAtClient: visit.submittedAtClient,
    resumedFromDraft: visit.resumedFromDraft,
    geofence: { pass: visit.geofencePass, distanceM: visit.checkinDistanceM },
    pinDispute: visit.pinDispute,
    score,
    sections: [
      summariseStock(visit.stock, visit._count.stock),
      summariseVisibility(visit.visibility),
      summarisePricing(visit.pricing, visit._count.pricing),
      summariseCompetitive(visit.competitive, visit._count.competitive),
      summariseRisks(visit.risks, visit._count.risks),
    ],
    photos: {
      total: visit._count.photos,
      items: visit.photos.map((p) => ({
        id: p.id,
        section: p.section,
        timestamp: p.timestamp,
        thumbnailUrl: `/photos/${p.id}/thumbnail`,
      })),
    },
    fraud: { riskScore: fraud.riskScore, signals: fraud.signals },
    templateResponses: visit.templateResponses.map((r) => ({
      templateId: r.templateId,
      templateName: r.template.name,
      templateVersion: r.templateVersion,
      currentVersion: r.template.version,
      schema: r.template.schema,
      answers: r.answers,
      recordedAt: r.createdAt,
    })),
  };
}

function summariseStock(
  rows: Array<{
    unitsAvailable: number | null;
    daysOutOfStock: number;
    coverageDaysPredicted: number | null;
    sku: { name: string };
  }>,
  count: number,
): VisitSectionSummary {
  // `unitsAvailable === null` is a SKU the agent never reached (#389). It is
  // not out of stock, it has no coverage to be low on, and — crucially — it is
  // not in the "N of M" denominator: "3 of 40 SKUs out of stock" must not be
  // built on 37 shelves nobody looked at.
  const counted = rows.filter((r) => r.unitsAvailable !== null);
  const out = counted
    .filter((r) => r.unitsAvailable! <= 0)
    .sort((a, b) => b.daysOutOfStock - a.daysOutOfStock);
  // Coverage uses the forecast service's own red line, not a number made up here.
  const low = counted.filter(
    (r) =>
      r.unitsAvailable! > 0 &&
      r.coverageDaysPredicted !== null &&
      coverageStatus(r.coverageDaysPredicted) === 'red',
  );
  const findings: string[] = [];
  if (counted.length > 0) findings.push(`${out.length} of ${plural(counted.length, 'SKU')} out of stock`);
  const uncounted = rows.length - counted.length;
  if (uncounted > 0 && findings.length < VISIT_DETAIL_MAX_FINDINGS) {
    findings.push(`${plural(uncounted, 'SKU')} not counted`);
  }
  for (const r of out.slice(0, VISIT_DETAIL_MAX_FINDINGS - 1)) {
    findings.push(`${r.sku.name}: out of stock, ${plural(r.daysOutOfStock, 'day')}`);
  }
  if (low.length > 0 && findings.length < VISIT_DETAIL_MAX_FINDINGS) {
    findings.push(`${plural(low.length, 'SKU')} under 3 days of cover`);
  }
  return {
    key: 'stock',
    count,
    flagged: out.length + low.length,
    findings: findings.slice(0, VISIT_DETAIL_MAX_FINDINGS),
    truncated: count > rows.length,
  };
}

function summariseVisibility(
  row: { planogramCompliancePct: number; cleanlinessScore: number; highTrafficPass: boolean } | null,
): VisitSectionSummary {
  if (!row) return { key: 'visibility', count: 0, flagged: 0, findings: [], truncated: false };
  return {
    key: 'visibility',
    count: 1,
    flagged: row.highTrafficPass ? 0 : 1,
    findings: [
      `Planogram compliance ${Math.round(row.planogramCompliancePct)}%`,
      `Cleanliness ${row.cleanlinessScore}/5`,
      row.highTrafficPass ? 'High-traffic placement met' : 'High-traffic placement missed',
    ],
    truncated: false,
  };
}

function summarisePricing(
  rows: Array<{
    priceActual: number;
    priceMaster: number;
    deviationPct: number;
    promoActive: boolean;
    sku: { name: string };
  }>,
  count: number,
): VisitSectionSummary {
  const off = rows
    .filter((r) => Math.abs(r.deviationPct) > DEFAULT_PRICE_DEVIATION_THRESHOLD)
    .sort((a, b) => Math.abs(b.deviationPct) - Math.abs(a.deviationPct));
  const findings: string[] = [];
  if (count > 0) {
    findings.push(
      `${off.length} of ${plural(count, 'price')} more than ${DEFAULT_PRICE_DEVIATION_THRESHOLD}% off master`,
    );
  }
  for (const r of off.slice(0, VISIT_DETAIL_MAX_FINDINGS - 1)) {
    const sign = r.deviationPct > 0 ? '+' : '';
    findings.push(
      `${r.sku.name}: ${r.priceActual.toFixed(2)} vs ${r.priceMaster.toFixed(2)} (${sign}${Math.round(r.deviationPct)}%)`,
    );
  }
  const promos = rows.filter((r) => r.promoActive).length;
  if (promos > 0 && findings.length < VISIT_DETAIL_MAX_FINDINGS) {
    findings.push(`${plural(promos, 'SKU')} on promotion`);
  }
  return {
    key: 'pricing',
    count,
    flagged: off.length,
    findings: findings.slice(0, VISIT_DETAIL_MAX_FINDINGS),
    truncated: count > rows.length,
  };
}

function summariseCompetitive(
  rows: Array<{
    competitorSku: string;
    competitorPrice: number;
    competitorPromoterPresent: boolean;
    facingsCount: number;
  }>,
  count: number,
): VisitSectionSummary {
  const promoters = rows.filter((r) => r.competitorPromoterPresent);
  const findings: string[] = [];
  if (promoters.length > 0) {
    findings.push(`Competitor promoter present (${plural(promoters.length, 'SKU')})`);
  }
  const byShelf = [...rows].sort((a, b) => b.facingsCount - a.facingsCount);
  for (const r of byShelf.slice(0, VISIT_DETAIL_MAX_FINDINGS - findings.length)) {
    findings.push(
      `${r.competitorSku}: ${r.competitorPrice.toFixed(2)}, ${plural(r.facingsCount, 'facing')}`,
    );
  }
  return {
    key: 'competitive',
    count,
    flagged: promoters.length,
    findings: findings.slice(0, VISIT_DETAIL_MAX_FINDINGS),
    truncated: count > rows.length,
  };
}

const RISK_SEVERITY_RANK: Record<string, number> = { critical: 0, high: 1, normal: 2 };

function summariseRisks(
  rows: Array<{ flagType: string; severity: string; note: string }>,
  count: number,
): VisitSectionSummary {
  const ordered = [...rows].sort(
    (a, b) => (RISK_SEVERITY_RANK[a.severity] ?? 3) - (RISK_SEVERITY_RANK[b.severity] ?? 3),
  );
  return {
    key: 'risks',
    count,
    flagged: rows.filter((r) => r.severity === 'critical' || r.severity === 'high').length,
    findings: ordered
      .slice(0, VISIT_DETAIL_MAX_FINDINGS)
      .map((r) => `${r.severity}: ${r.flagType}, ${r.note}`),
    truncated: count > rows.length,
  };
}

// ── GET /visits/me — the agent's own record (#383) ─────────────────────────
//
// The counterweight to a fraud engine that scores an agent on evidence the
// agent cannot see. Everything here is about the CALLER's own work: the
// `agentId` is taken from the token and is never a parameter, so there is no
// shape of this request that returns somebody else's day.
//
// It is deliberately NOT `getVisitDetail` with a relaxed guard. That read is
// supervisory — fraud signals, per-section findings, the reviewer's evidence —
// and handing an agent the scoring function's inputs teaches them to game it.
// What an agent needs is the proof they were there and the number they were
// given: where, when, how far from the door, how long, how much they captured,
// and the authoritative score.

/** Capturable sections on a visit. `outletInfo` is excluded — it is completed
 *  by checking in — which is unify §6's `captureCount`. */
export const MY_VISIT_SECTION_TOTAL = 7;

export interface MyVisitScore {
  /** The SERVER's number. The only score this endpoint calls a score. */
  weightedTotal: number;
  ratingBand: string;
  scoredAt: Date;
  /** What the DEVICE showed the agent on the way out, when it recorded one.
   *  Null means there is nothing to reconcile, not that the two agreed. */
  seen: { weightedTotal: number; ratingBand: string; seenAt: Date | null } | null;
}

export interface MyVisitSummary {
  id: string;
  outletId: string;
  outletName: string;
  outletCode: string;
  checkinTs: Date;
  /** Metres from the outlet's pin at check-in, when the fix was good enough to
   *  measure one. Null is "not measured", which is not zero. */
  checkinDistanceM: number | null;
  geofencePass: boolean;
  status: string;
  /** Minutes between check-in and submit, both on the DEVICE's clock (#101).
   *  Null on a visit with no client submit stamp — an honest gap, never a
   *  subtraction across two clocks. */
  dwellMinutes: number | null;
  sectionsCaptured: number;
  sectionsTotal: number;
  photos: number;
  tasksRaised: number;
  score: MyVisitScore | null;
  /** A reviewer ruled on this visit. A fact the agent is entitled to, and the
   *  only fraud output exposed here: the risk score and its signals stay on
   *  the console. */
  reviewedVerdict: string | null;
  /** The agent said "the pin is wrong" to start this visit (#386). Their own
   *  claim, so it is theirs to see — and it is why a visit they were allowed
   *  to start still reads out of fence. */
  pinReported: boolean;
}

export async function listMyVisits(input: {
  clientId: string;
  agentId: string;
  limit: number;
  cursor?: string;
}): Promise<{ data: MyVisitSummary[]; nextCursor: string | null }> {
  const rows = await prisma.visit.findMany({
    where: { clientId: input.clientId, agentId: input.agentId },
    select: {
      id: true,
      outletId: true,
      checkinTs: true,
      checkinDistanceM: true,
      geofencePass: true,
      status: true,
      submittedAtClient: true,
      outlet: { select: { name: true, code: true } },
      scorecard: {
        select: {
          weightedTotal: true,
          ratingBand: true,
          scoredAt: true,
          provisionalTotal: true,
          provisionalBand: true,
          provisionalAt: true,
        },
      },
      fraudVerdict: { select: { verdict: true } },
      pinDispute: { select: { id: true } },
      visibility: { select: { visitId: true } },
      capability: { select: { visitId: true } },
      _count: {
        select: {
          stock: true,
          pricing: true,
          competitive: true,
          risks: true,
          photos: true,
          tasks: true,
          templateResponses: true,
        },
      },
    },
    // The same keyset the tenant-wide list uses, and for the same reason: a
    // day's offline visits sync in a burst, so equal `checkinTs` values are
    // ordinary and `id` is the tiebreaker that keeps a page boundary stable.
    orderBy: [{ checkinTs: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  const page = buildPage(rows, input.limit);
  return {
    data: page.data.map((row) => {
      const captured = [
        row._count.stock > 0,
        row.visibility !== null,
        row._count.pricing > 0,
        row._count.competitive > 0,
        row._count.risks > 0,
        row.capability !== null,
        row._count.templateResponses > 0,
      ].filter(Boolean).length;

      const card = row.scorecard;
      return {
        id: row.id,
        outletId: row.outletId,
        outletName: row.outlet.name,
        outletCode: row.outlet.code,
        checkinTs: row.checkinTs,
        checkinDistanceM: row.checkinDistanceM,
        geofencePass: row.geofencePass,
        status: row.status,
        dwellMinutes:
          row.submittedAtClient === null
            ? null
            : Math.max(
                0,
                Math.round(
                  (row.submittedAtClient.getTime() - row.checkinTs.getTime()) / 60_000,
                ),
              ),
        sectionsCaptured: captured,
        sectionsTotal: MY_VISIT_SECTION_TOTAL,
        photos: row._count.photos,
        tasksRaised: row._count.tasks,
        score:
          card === null
            ? null
            : {
                weightedTotal: card.weightedTotal,
                ratingBand: card.ratingBand,
                scoredAt: card.scoredAt,
                // Both halves or neither, exactly as `toScorecardResponse`
                // folds them: a total without a band is not a score anyone saw.
                seen:
                  card.provisionalTotal !== null && card.provisionalBand !== null
                    ? {
                        weightedTotal: card.provisionalTotal,
                        ratingBand: card.provisionalBand,
                        seenAt: card.provisionalAt,
                      }
                    : null,
              },
        reviewedVerdict: row.fraudVerdict?.verdict ?? null,
        pinReported: row.pinDispute !== null,
      };
    }),
    nextCursor: page.nextCursor,
  };
}
