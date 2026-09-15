interface Coordinates {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_METERS = 6371000;

/**
 * The check-in fence around every outlet, in metres. POST /visits/checkin
 * rejects anything further out; the fraud engine reasons in the same fence
 * (stock_outside_outlet, #248), so both read it from here.
 */
export const GEOFENCE_RADIUS_M = 50;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

export function haversineDistanceMeters(a: Coordinates, b: Coordinates): number {
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(h));
}

export function isWithinGeofence(
  outlet: Coordinates,
  checkin: Coordinates,
  radiusMeters = GEOFENCE_RADIUS_M,
): boolean {
  return haversineDistanceMeters(outlet, checkin) <= radiusMeters;
}
