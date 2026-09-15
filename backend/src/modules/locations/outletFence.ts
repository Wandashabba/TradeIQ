import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { GEOFENCE_RADIUS_M, haversineDistanceMeters } from '../../lib/geofence';

export interface FenceOutlet {
  id: string;
  name: string;
  lat: number;
  lng: number;
}

interface Point {
  lat: number;
  lng: number;
}

type Db = Prisma.TransactionClient | typeof prisma;

const METRES_PER_DEGREE_LAT = 111_320;

/**
 * Points are snapped to a ~110m grid (3 decimal places) before building boxes,
 * so a day of pings clustered in a handful of stores becomes a handful of
 * boxes rather than hundreds.
 */
const GRID_DECIMALS = 3;

/**
 * Three fence radii. The box only has to be a SUPERSET of the fence — the
 * haversine in `containingOutlet` makes the real decision — and it has to
 * absorb the grid snap above (up to ~55m of latitude, more longitude away from
 * the equator) on top of the 50m fence itself.
 */
const BOX_MARGIN_M = 3 * GEOFENCE_RADIUS_M;

function boxAround(point: Point): Prisma.OutletWhereInput {
  const dLat = BOX_MARGIN_M / METRES_PER_DEGREE_LAT;
  const cos = Math.max(0.01, Math.cos((point.lat * Math.PI) / 180));
  const dLng = dLat / cos;
  return {
    lat: { gte: point.lat - dLat, lte: point.lat + dLat },
    lng: { gte: point.lng - dLng, lte: point.lng + dLng },
  };
}

/**
 * The tenant's outlets near any of `points`, for fence matching.
 *
 * One query, bounded by where the points are rather than by the tenant's outlet
 * count — a tenant with 4,000 stores should not load all of them to place 20
 * agents. "Which store" is derived, not stored, with the same haversine and
 * radius as check-in (#153: no PostGIS until #63).
 */
export async function outletsNear(
  clientId: string,
  points: Point[],
  db: Db = prisma,
): Promise<FenceOutlet[]> {
  const snapped = new Map<string, Point>();
  for (const p of points) {
    const lat = Number(p.lat.toFixed(GRID_DECIMALS));
    const lng = Number(p.lng.toFixed(GRID_DECIMALS));
    snapped.set(`${lat},${lng}`, { lat, lng });
  }
  if (snapped.size === 0) return [];
  return db.outlet.findMany({
    where: { clientId, OR: [...snapped.values()].map(boxAround) },
    select: { id: true, name: true, lat: true, lng: true },
    // Deterministic tie-breaking in containingOutlet depends on stable order.
    orderBy: { id: 'asc' },
  });
}

/**
 * The nearest outlet whose check-in fence contains `point`, or null.
 * Nearest, because two stores in one mall can have overlapping fences and the
 * agent is most plausibly in the closer one.
 */
export function containingOutlet(point: Point, outlets: FenceOutlet[]): FenceOutlet | null {
  let best: FenceOutlet | null = null;
  let bestDistance = Infinity;
  for (const outlet of outlets) {
    const distance = haversineDistanceMeters(outlet, point);
    if (distance <= GEOFENCE_RADIUS_M && distance < bestDistance) {
      best = outlet;
      bestDistance = distance;
    }
  }
  return best;
}
