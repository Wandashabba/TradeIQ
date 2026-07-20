import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { ValidationError } from '../../middleware/errorHandler';

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

export function listOutletsForClient(clientId: string) {
  return prisma.outlet.findMany({ where: { clientId } });
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
