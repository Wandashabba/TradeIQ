import { Task, VisitRisk } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError } from '../../middleware/errorHandler';
import { computeSlaDueAt, TaskPriority } from '../../lib/slaClock';

export interface RiskInput {
  flagType: string;
  severity: TaskPriority;
  note: string;
}

export interface RecordRisksInput {
  visitId: string;
  clientId: string;
  risks: RiskInput[];
}

  // Bounded by one visit's children rather than a whole tenant, so this is
  // consistency work, not an OOM fix — but a caller should not have to know
  // which lists carry an envelope and which do not.
export async function listRisksForVisit(
  visitId: string,
  clientId: string,
  page: { limit: number; cursor?: string },
) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const rows = await prisma.visitRisk.findMany({
    where: { visitId },
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: page.limit + 1,
    ...(page.cursor ? { cursor: { id: page.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, page.limit);
}

export async function recordRisks(input: RecordRisksInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const now = new Date();

  // Each flagged risk also auto-creates a follow-up task owned by the
  // visiting agent, with an SLA clock keyed to the risk severity (issue #13).
  // Both writes happen in one transaction so a risk is never persisted
  // without its task (or vice versa).
  return prisma.$transaction(async (tx) => {
    const risks: VisitRisk[] = [];
    const tasks: Task[] = [];
    for (const risk of input.risks) {
      risks.push(
        await tx.visitRisk.create({
          data: {
            visitId: input.visitId,
            flagType: risk.flagType,
            severity: risk.severity,
            note: risk.note,
          },
        }),
      );
      tasks.push(
        await tx.task.create({
          data: {
            visitId: input.visitId,
            findingType: risk.flagType,
            outletId: visit.outletId,
            requiredFix: risk.note,
            priority: risk.severity,
            slaDueAt: computeSlaDueAt(risk.severity, now),
            ownerId: visit.agentId,
          },
        }),
      );
    }
    return { risks, tasks };
  });
}
