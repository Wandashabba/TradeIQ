import { Prisma, Territory, User, Outlet } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

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

export function listTerritoriesForClient(clientId: string) {
  return prisma.territory.findMany({ where: { clientId }, orderBy: { name: 'asc' } });
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
  outlets: Outlet[];
  agents: User[];
  coverage: { outletsVisited: number; outletsTotal: number; coverageRate: number };
}> {
  const territory = await findTerritoryForClient(territoryId, clientId);

  // Outlets link to a territory by the free-text Outlet.territoryId equalling
  // Territory.code, still scoped to the caller's client.
  const outlets = await prisma.outlet.findMany({
    where: { territoryId: territory.code, clientId },
  });

  const assignments = await prisma.userTerritory.findMany({
    where: { territoryId: territory.id },
    include: { user: true },
  });
  const agents = assignments.map((assignment) => assignment.user);

  const outletIds = outlets.map((outlet) => outlet.id);
  const visitWhere: Prisma.VisitWhereInput = { clientId, outletId: { in: outletIds } };
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

  return { territory, outlets, agents, coverage: { outletsVisited, outletsTotal, coverageRate } };
}
