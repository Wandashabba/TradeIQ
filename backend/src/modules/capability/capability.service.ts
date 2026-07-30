import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';

export interface RecordCapabilityInput {
  visitId: string;
  clientId: string;
  agentId: string;
  staffHeadcountConfirmed: number;
  repTrainingStatus: Prisma.InputJsonValue;
  quizScore: number;
}

  // Bounded by one visit's children rather than a whole tenant, so this is
  // consistency work, not an OOM fix — but a caller should not have to know
  // which lists carry an envelope and which do not.
export async function listCapabilityForVisit(
  visitId: string,
  clientId: string,
  page: { limit: number; cursor?: string },
) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const rows = await prisma.visitCapability.findMany({
    where: { visitId },
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: page.limit + 1,
    ...(page.cursor ? { cursor: { id: page.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, page.limit);
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
