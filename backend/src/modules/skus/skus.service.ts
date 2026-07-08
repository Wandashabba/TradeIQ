import { prisma } from '../../lib/prisma';

export async function listSkusForClient(clientId: string) {
  return prisma.sku.findMany({ where: { clientId }, orderBy: { name: 'asc' } });
}
