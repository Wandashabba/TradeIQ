import { prisma } from '../../lib/prisma';
import { isWithinGeofence } from '../../lib/geofence';
import { GeofenceRejectedError, NotFoundError } from '../../middleware/errorHandler';

export interface CheckInInput {
  outletId: string;
  lat: number;
  lng: number;
  clientId: string;
  agentId: string;
}

export async function checkIn(input: CheckInInput) {
  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  const geofencePass = isWithinGeofence(
    { lat: outlet.lat, lng: outlet.lng },
    { lat: input.lat, lng: input.lng },
  );
  if (!geofencePass) {
    throw new GeofenceRejectedError('Check-in location is outside the outlet geofence');
  }

  return prisma.visit.create({
    data: {
      outletId: input.outletId,
      agentId: input.agentId,
      clientId: input.clientId,
      checkinTs: new Date(),
      checkinLat: input.lat,
      checkinLng: input.lng,
      geofencePass: true,
      status: 'in_progress',
    },
  });
}
