import { Prisma, Territory, Outlet } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { safeUserSelect, SafeUser } from '../users/users.service';
import { buildPage } from '../../lib/pagination';

export interface CreateTerritoryInput {
  clientId: string;
  name: string;
  code: string;
  region?: string;
}

export function createTerritory(input: CreateTerritoryInput) {
  return prisma.territory.create({
    data: {
      clientId: input.clientId,
      name: input.name,
      code: input.code,
      region: input.region,
    },
  });
}

export interface ListTerritoriesForClientInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export async function listTerritoriesForClient(input: ListTerritoriesForClientInput) {
  const rows = await prisma.territory.findMany({
    where: { clientId: input.clientId },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two territories share a name — same reasoning as alerts.service.ts.
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

// Loads a territory scoped to the caller's client, throwing NotFoundError when
// it does not exist or belongs to another tenant.
export async function findTerritoryForClient(territoryId: string, clientId: string) {
  const territory = await prisma.territory.findFirst({
    where: { id: territoryId, clientId },
  });
  if (!territory) {
    throw new NotFoundError('Territory not found');
  }
  return territory;
}

export interface AssignAgentInput {
  territoryId: string;
  userId: string;
  clientId: string;
}

export async function assignAgentToTerritory(input: AssignAgentInput) {
  // Territory must belong to the caller's client.
  await findTerritoryForClient(input.territoryId, input.clientId);

  // The assigned user must exist and belong to the caller's client.
  const user = await prisma.user.findFirst({
    where: { id: input.userId, clientId: input.clientId },
    select: { id: true },
  });
  if (!user) {
    throw new NotFoundError('User not found');
  }

  return prisma.userTerritory.create({
    data: { territoryId: input.territoryId, userId: input.userId },
  });
}

export async function getTerritoryCoverage(
  territoryId: string,
  clientId: string,
  from?: Date,
  to?: Date,
): Promise<{
  territory: Territory;
  outlets: (Outlet & { visited: boolean })[];
  agents: SafeUser[];
  coverage: { outletsVisited: number; outletsTotal: number; coverageRate: number };
}> {
  const territory = await findTerritoryForClient(territoryId, clientId);

  // Outlets link to a territory by the free-text Outlet.territoryId equalling
  // Territory.code, still scoped to the caller's client.
  const outlets = await prisma.outlet.findMany({
    where: { territoryId: territory.code, clientId },
  });

  // Never `include: { user: true }` here — it selects every User scalar,
  // passwordHash included. /users' allowlist is the one definition of a
  // wire-safe user.
  const assignments = await prisma.userTerritory.findMany({
    where: { territoryId: territory.id },
    select: { user: { select: safeUserSelect } },
  });
  const agents = assignments.map((assignment) => assignment.user);

  const outletIds = outlets.map((outlet) => outlet.id);
  const visitWhere: Prisma.VisitWhereInput = {
    clientId,
    outletId: { in: outletIds },
    status: 'submitted',
  };
  if (from || to) {
    visitWhere.checkinTs = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
  }
  const visitedOutlets = outletIds.length
    ? await prisma.visit.findMany({ where: visitWhere, select: { outletId: true }, distinct: ['outletId'] })
    : [];

  const outletsTotal = outlets.length;
  const outletsVisited = visitedOutlets.length;
  const coverageRate = outletsTotal > 0 ? Math.round((100 * outletsVisited / outletsTotal) * 100) / 100 : 0;

  // Tag each outlet with whether it was visited, so a map view can color
  // individual pins instead of only knowing the aggregate rate above.
  const visitedOutletIds = new Set(visitedOutlets.map((visit) => visit.outletId));
  const outletsWithVisited = outlets.map((outlet) => ({
    ...outlet,
    visited: visitedOutletIds.has(outlet.id),
  }));

  return {
    territory,
    outlets: outletsWithVisited,
    agents,
    coverage: { outletsVisited, outletsTotal, coverageRate },
  };
}
