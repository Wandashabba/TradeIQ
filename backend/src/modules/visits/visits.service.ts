import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { haversineDistanceMeters, isWithinGeofence } from '../../lib/geofence';
import { GeofenceRejectedError, NotFoundError } from '../../middleware/errorHandler';
import { Prisma } from '@prisma/client';
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
import { markRouteStopsVisited } from '../beatplans/beatplans.service';
import { recordPointsBestEffort, recordVisitSubmitted } from '../gamification/pointsLedger';

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
}

export async function checkIn(input: CheckInInput) {
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

  return prisma.visit.create({
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
  /** Null until the visit has been scored. */
  score: {
    weightedTotal: number;
    ratingBand: string;
    /** The client's current green line — the standard the total is read against. */
    target: number;
    /** Every dimension, in the fixed order; `score` null means not measurable. */
    dimensions: Array<{ key: ScorecardDimension; score: number | null }>;
    scoredAt: Date;
  } | null;
  sections: VisitSectionSummary[];
  photos: {
    total: number;
    items: Array<{ id: string; section: string; timestamp: Date; thumbnailUrl: string }>;
  };
  fraud: Pick<FraudResult, 'riskScore' | 'signals'>;
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
      geofencePass: true,
      checkinDistanceM: true,
      outlet: { select: { id: true, name: true, code: true, channelType: true } },
      agent: { select: { id: true, email: true } },
      scorecard: {
        select: { weightedTotal: true, ratingBand: true, dimensionScores: true, createdAt: true },
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
    prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } }),
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
  );

  let score: VisitDetail['score'] = null;
  if (visit.scorecard) {
    const stored = asDimensionRecord(visit.scorecard.dimensionScores);
    score = {
      weightedTotal: visit.scorecard.weightedTotal,
      ratingBand: visit.scorecard.ratingBand,
      target: kpiThreshold(client?.kpiThresholds, 'green', DEFAULT_GREEN_THRESHOLD),
      dimensions: SCORECARD_DIMENSIONS.map((key) => ({ key, score: stored[key] ?? null })),
      scoredAt: visit.scorecard.createdAt,
    };
  }

  return {
    id: visit.id,
    status: visit.status,
    outlet: visit.outlet,
    agent: visit.agent,
    checkinTs: visit.checkinTs,
    submittedAtClient: visit.submittedAtClient,
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
  };
}

function summariseStock(
  rows: Array<{
    unitsAvailable: number;
    daysOutOfStock: number;
    coverageDaysPredicted: number;
    sku: { name: string };
  }>,
  count: number,
): VisitSectionSummary {
  const out = rows
    .filter((r) => r.unitsAvailable <= 0)
    .sort((a, b) => b.daysOutOfStock - a.daysOutOfStock);
  // Coverage uses the forecast service's own red line, not a number made up here.
  const low = rows.filter((r) => r.unitsAvailable > 0 && coverageStatus(r.coverageDaysPredicted) === 'red');
  const findings: string[] = [];
  if (count > 0) findings.push(`${out.length} of ${plural(count, 'SKU')} out of stock`);
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
