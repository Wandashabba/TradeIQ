import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';

export interface CompetitiveItemInput {
  competitorSku: string;
  competitorPrice: number;
  competitorPosmType: string;
  competitorPromoterPresent: boolean;
  geotag: Prisma.InputJsonValue;
}

export interface RecordCompetitiveInput {
  visitId: string;
  clientId: string;
  agentId: string;
  items: CompetitiveItemInput[];
}

  // Bounded by one visit's children rather than a whole tenant, so this is
  // consistency work, not an OOM fix — but a caller should not have to know
  // which lists carry an envelope and which do not.
export async function listCompetitiveForVisit(
  visitId: string,
  clientId: string,
  page: { limit: number; cursor?: string },
) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const rows = await prisma.visitCompetitive.findMany({
    where: { visitId },
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: page.limit + 1,
    ...(page.cursor ? { cursor: { id: page.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, page.limit);
}

export async function recordCompetitive(input: RecordCompetitiveInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  return prisma.$transaction(
    input.items.map((item) =>
      prisma.visitCompetitive.create({
        data: {
          visitId: input.visitId,
          competitorSku: item.competitorSku,
          competitorPrice: item.competitorPrice,
          competitorPosmType: item.competitorPosmType,
          competitorPromoterPresent: item.competitorPromoterPresent,
          geotag: item.geotag,
        },
      }),
    ),
  );
}
