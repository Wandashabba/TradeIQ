import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

export interface RecordVisibilityInput {
  visitId: string;
  clientId: string;
  brandingElements: Prisma.InputJsonValue;
  planogramCompliancePct: number;
  facingsCount: Prisma.InputJsonValue;
  highTrafficPass: boolean;
  cleanlinessScore: number;
}

export async function recordVisibility(input: RecordVisibilityInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const fields = {
    brandingElements: input.brandingElements,
    planogramCompliancePct: input.planogramCompliancePct,
    facingsCount: input.facingsCount,
    highTrafficPass: input.highTrafficPass,
    cleanlinessScore: input.cleanlinessScore,
  };

  // One VisitVisibility per visit (unique visitId) — upsert so re-submitting
  // the section is idempotent.
  return prisma.visitVisibility.upsert({
    where: { visitId: input.visitId },
    create: { visitId: input.visitId, ...fields },
    update: fields,
  });
}
