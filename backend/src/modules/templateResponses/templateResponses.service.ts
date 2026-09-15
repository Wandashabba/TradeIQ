import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';

export interface RecordTemplateResponseInput {
  visitId: string;
  templateId: string;
  clientId: string;
  agentId: string;
  // Free-form answers keyed by the template schema's field ids. Stored as-is,
  // mirroring how AuditTemplate.schema itself is stored.
  answers: Prisma.InputJsonValue;
  // The template version the answers were given against, as the agent's
  // device rendered it. Omitted = the template's current version.
  templateVersion?: number;
}

export interface ListTemplateResponsesInput {
  visitId: string;
  clientId: string;
  templateId?: string;
  limit: number;
  cursor?: string;
}

export async function listTemplateResponsesForVisit(input: ListTemplateResponsesInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const rows = await prisma.visitTemplateResponse.findMany({
    where: {
      visitId: input.visitId,
      ...(input.templateId !== undefined ? { templateId: input.templateId } : {}),
    },
    // Tiebreaker direction matches the primary sort — see alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });

  return buildPage(rows, input.limit);
}

export async function recordTemplateResponse(input: RecordTemplateResponseInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId, agentId: input.agentId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  const template = await prisma.auditTemplate.findFirst({
    where: { id: input.templateId, clientId: input.clientId },
  });
  if (!template) {
    throw new NotFoundError('Template not found');
  }
  // A device cannot have rendered a version that does not exist yet.
  if (input.templateVersion !== undefined && input.templateVersion > template.version) {
    throw new ValidationError('templateVersion is newer than the template');
  }
  const templateVersion = input.templateVersion ?? template.version;

  // One response per (visit, template) — upsert so re-submitting a section is
  // idempotent. templateVersion snapshots the version answered against: the
  // one the agent's device rendered when it says so (an offline answer can
  // sync after a schema edit), otherwise the template's current version.
  return prisma.visitTemplateResponse.upsert({
    where: { visitId_templateId: { visitId: input.visitId, templateId: input.templateId } },
    create: {
      visitId: input.visitId,
      templateId: input.templateId,
      templateVersion,
      answers: input.answers,
    },
    update: { templateVersion, answers: input.answers },
  });
}
