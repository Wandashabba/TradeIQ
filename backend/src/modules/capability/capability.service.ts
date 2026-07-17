import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

export interface RecordCapabilityInput {
  visitId: string;
  clientId: string;
  agentId: string;
  staffHeadcountConfirmed: number;
  repTrainingStatus: Prisma.InputJsonValue;
  quizScore: number;
}

export async function listCapabilityForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitCapability.findMany({
    where: { visitId },
    orderBy: { createdAt: 'desc' },
  });
}

export async function recordCapability(input: RecordCapabilityInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const fields = {
    staffHeadcountConfirmed: input.staffHeadcountConfirmed,
    repTrainingStatus: input.repTrainingStatus,
    quizScore: input.quizScore,
  };

  // One VisitCapability per visit (unique visitId) — upsert so re-submitting
  // the section is idempotent.
  return prisma.visitCapability.upsert({
    where: { visitId: input.visitId },
    create: { visitId: input.visitId, ...fields },
    update: fields,
  });
}
