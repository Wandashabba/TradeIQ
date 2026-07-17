import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

export interface RecordTemplateResponseInput {
  visitId: string;
  templateId: string;
  clientId: string;
  agentId: string;
  // Free-form answers keyed by the template schema's field ids. Stored as-is,
  // mirroring how AuditTemplate.schema itself is stored.
  answers: Prisma.InputJsonValue;
}

export interface ListTemplateResponsesInput {
  visitId: string;
  clientId: string;
  templateId?: string;
}

export async function listTemplateResponsesForVisit(input: ListTemplateResponsesInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitTemplateResponse.findMany({
    where: {
      visitId: input.visitId,
      ...(input.templateId !== undefined ? { templateId: input.templateId } : {}),
    },
    orderBy: { createdAt: 'desc' },
  });
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

  // One response per (visit, template) — upsert so re-submitting a section is
  // idempotent. templateVersion snapshots the version answered against; a
  // re-submit after a schema patch records the new version.
  return prisma.visitTemplateResponse.upsert({
    where: { visitId_templateId: { visitId: input.visitId, templateId: input.templateId } },
    create: {
      visitId: input.visitId,
      templateId: input.templateId,
      templateVersion: template.version,
      answers: input.answers,
    },
    update: { templateVersion: template.version, answers: input.answers },
  });
}
