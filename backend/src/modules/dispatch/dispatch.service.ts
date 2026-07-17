import { prisma } from '../../lib/prisma';
import { haversineDistanceMeters } from '../../lib/geofence';
import { NotFoundError } from '../../middleware/errorHandler';

// A single ranked field-agent candidate for an outlet. `distanceM` is the
// straight-line distance from the agent's last-known location to the outlet
// (rounded to 1dp), or null when the agent has never reported a location.
export interface DispatchCandidate {
  agentId: string;
  email: string;
  distanceM: number | null;
  inTerritory: boolean;
  lastSeenAt: Date | null;
}

// Ranks the client's field agents for an outlet: agents covering the outlet's
// territory come first, then nearest-by-distance, with unlocated agents last.
// Throws NotFoundError when the outlet does not exist or belongs to another
// tenant (keeping cross-tenant outlet ids indistinguishable from missing ones).
export async function rankAgentsForOutlet(
  outletId: string,
  clientId: string,
): Promise<DispatchCandidate[]> {
  const outlet = await prisma.outlet.findFirst({
    where: { id: outletId, clientId },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  // Select only the fields DispatchCandidate projects — matching the hand-picked
  // selects in dashboard/gamification rather than fetching every User column.
  const agents = await prisma.user.findMany({
    where: { clientId, role: 'field_agent' },
    select: { id: true, email: true, lastLat: true, lastLng: true, lastSeenAt: true },
  });

  // The outlet links to a Territory by free-text code equalling Outlet.territoryId
  // (same client). Agents assigned to that territory are considered in-territory.
  const territory = await prisma.territory.findFirst({
    where: { clientId, code: outlet.territoryId },
    select: { id: true },
  });

  const inTerritoryAgentIds = new Set<string>();
  if (territory) {
    const assignments = await prisma.userTerritory.findMany({
      where: { territoryId: territory.id },
      select: { userId: true },
    });
    for (const assignment of assignments) {
      inTerritoryAgentIds.add(assignment.userId);
    }
  }

  const candidates: DispatchCandidate[] = agents.map((agent) => {
    const hasLocation = agent.lastLat !== null && agent.lastLng !== null;
    const distanceM = hasLocation
      ? Math.round(
          haversineDistanceMeters(
            { lat: agent.lastLat as number, lng: agent.lastLng as number },
            { lat: outlet.lat, lng: outlet.lng },
          ) * 10,
        ) / 10
      : null;

    return {
      agentId: agent.id,
      email: agent.email,
      distanceM,
      inTerritory: inTerritoryAgentIds.has(agent.id),
      lastSeenAt: agent.lastSeenAt,
    };
  });

  // In-territory first, then nearest first, with unlocated agents (null distance) last.
  candidates.sort((a, b) => {
    if (a.inTerritory !== b.inTerritory) {
      return a.inTerritory ? -1 : 1;
    }
    if (a.distanceM === null && b.distanceM === null) {
      return 0;
    }
    if (a.distanceM === null) {
      return 1;
    }
    if (b.distanceM === null) {
      return -1;
    }
    return a.distanceM - b.distanceM;
  });

  return candidates;
}
