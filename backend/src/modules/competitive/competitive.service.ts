import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
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

export async function listCompetitiveForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitCompetitive.findMany({
    where: { visitId },
    orderBy: { createdAt: 'desc' },
  });
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
