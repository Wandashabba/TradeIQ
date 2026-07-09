import { prisma } from '../../lib/prisma';
import { haversineDistanceMeters, isWithinGeofence } from '../../lib/geofence';
import { GeofenceRejectedError, NotFoundError } from '../../middleware/errorHandler';
import { Prisma } from '@prisma/client';
import type { AuthTokenPayload } from '../auth/auth.service';

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
}

export async function submitVisit(input: SubmitVisitInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  return prisma.visit.update({
    where: { id: input.visitId },
    data: { status: 'submitted' },
  });
}

export interface ListVisitsInput {
  clientId: string;
  role: AuthTokenPayload['role'];
  // Required in practice for a field_agent (they only see their own visits);
  // ignored for managers/admins, who see the whole client's visits.
  agentId?: string;
  outletId?: string;
  status?: 'in_progress' | 'submitted';
}

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

  return prisma.visit.findMany({
    where,
    orderBy: { checkinTs: 'desc' },
  });
}
