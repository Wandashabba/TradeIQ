import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { haversineDistanceMeters, isWithinGeofence } from '../../lib/geofence';
import { GeofenceRejectedError, NotFoundError } from '../../middleware/errorHandler';
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
import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';
import { markRouteStopsVisited } from '../beatplans/beatplans.service';
import { recordPointsBestEffort, recordVisitSubmitted } from '../gamification/pointsLedger';

/** Longest accepted clientVisitId. A UUID is 36; this leaves room, not abuse.
 *  The same bound as `Message.clientMessageId` (#308), deliberately. */
export const MAX_CLIENT_VISIT_ID_LENGTH = 128;

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
    },
  });

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
