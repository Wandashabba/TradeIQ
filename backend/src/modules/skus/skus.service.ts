import { prisma } from '../../lib/prisma';

export function listSkusForClient(clientId: string) {
  return prisma.sku.findMany({ where: { clientId } });
}
