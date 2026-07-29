import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { ValidationError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';

export interface CreateOutletInput {
  name: string;
  code: string;
  channelType: string;
  lat: number;
  lng: number;
  territoryId: string;
  teamProfile?: Prisma.InputJsonValue;
  clientId: string;
}

/**
 * Outlets for a tenant, optionally narrowed to the ones in a user's assigned
 * territories.
 *
 * The narrowing is a *filter the caller asks for*, never something imposed.
 * Territory assignment should shorten an agent's list, not decide what work is
 * possible: an agent covering a colleague's patch, or standing in a store
 * filed under the wrong territory, must still be able to check in. In
 * offline-first field software, "I am here and the app will not let me work"
 * is a worse failure than a longer list.
 *
 * An agent with no assignments gets everything rather than nothing — an empty
 * roster is far more likely to mean nobody has set assignments up yet than to
 * mean this agent is meant to visit no outlets at all.
 */
export interface ListOutletsForClientInput {
  clientId: string;
  assignedTo?: string;
  limit: number;
  cursor?: string;
}

export async function listOutletsForClient(input: ListOutletsForClientInput) {
  const { clientId, assignedTo, limit, cursor } = input;
  // `id` is the unique tiebreaker that makes the cursor deterministic when
  // two outlets share a name — same reasoning as alerts.service.ts.
  //
  // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
  // sort's direction (both `asc` here).
  const paging = {
    orderBy: [{ name: 'asc' as const }, { id: 'asc' as const }],
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  };

  if (!assignedTo) {
    const rows = await prisma.outlet.findMany({ where: { clientId }, ...paging });
    return buildPage(rows, limit);
  }

  const assignments = await prisma.userTerritory.findMany({
    where: { userId: assignedTo, territory: { clientId } },
    // NOTE: `Outlet.territoryId` stores a Territory *code*, not its id (see the
    // comment on the Territory model). Matching on id here would silently
    // return nothing — the exact bug #97 shipped once, where a territory
    // filter degraded to all-zero KPIs rather than erroring.
    select: { territory: { select: { code: true } } },
  });

  const codes = assignments.map((a) => a.territory.code);
  if (codes.length === 0) {
    const rows = await prisma.outlet.findMany({ where: { clientId }, ...paging });
    return buildPage(rows, limit);
  }

  const rows = await prisma.outlet.findMany({
    where: { clientId, territoryId: { in: codes } },
    ...paging,
  });
  return buildPage(rows, limit);
}

export async function createOutlet(input: CreateOutletInput) {
  // `Outlet.territoryId` is free text mirroring `Territory.code` — there is no
  // foreign key to enforce it (see the note on the Territory model). Without a
  // check here, any string is accepted and the outlet is silently orphaned:
  // absent from coverage counts, territory filters and every territory-scoped
  // view, with no error to explain why.
  //
  // Observed in production data: an outlet was created with territoryId
  // "Hurlingham" — the territory's *name* — while its code was "2773u". It
  // looked correct to a human and matched nothing.
  const territory = await prisma.territory.findUnique({
    where: {
      clientId_code: { clientId: input.clientId, code: input.territoryId },
    },
    select: { id: true },
  });

  if (!territory) {
    // Names the distinction the caller almost certainly got wrong, rather than
    // a bare "invalid territory" that leaves them retrying the same string.
    throw new ValidationError(
      `Unknown territory "${input.territoryId}". territoryId must be a territory's code, not its name — see GET /territories.`,
    );
  }

  return prisma.outlet.create({ data: input });
}
