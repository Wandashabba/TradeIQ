import { Task, VisitRisk } from '@prisma/client';
import { prisma } from '../../lib/prisma';
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

export async function listRisksForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitRisk.findMany({
    where: { visitId },
    orderBy: { createdAt: 'desc' },
  });
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
