import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { haversineDistanceMeters, isWithinGeofence } from '../../lib/geofence';
import { GeofenceRejectedError, NotFoundError } from '../../middleware/errorHandler';
import { Prisma } from '@prisma/client';
import type { AuthTokenPayload } from '../auth/auth.service';
import { dispatchWebhookEvent } from '../webhooks/webhooks.service';
import { evaluateVisit } from '../alerts/alerts.service';
import { markRouteStopsVisited } from '../beatplans/beatplans.service';

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
