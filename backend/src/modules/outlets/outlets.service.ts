import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';

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

export function createOutlet(input: CreateOutletInput) {
  return prisma.outlet.create({ data: input });
}
