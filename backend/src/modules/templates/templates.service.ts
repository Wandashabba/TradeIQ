import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';

export interface CreateTemplateInput {
  clientId: string;
  name: string;
  // Free-form dynamic-form definition (sections/fields/conditions/scoring).
  // Stored as-is; the backend does not validate its internal shape.
  schema: Prisma.InputJsonValue;
  industry?: string;
}

export interface UpdateTemplateInput {
  id: string;
  clientId: string;
  // A schema change is a new version — supplying schema bumps `version`.
  schema?: Prisma.InputJsonValue;
  name?: string;
  industry?: string;
  active?: boolean;
}

export async function createTemplate(input: CreateTemplateInput) {
  return prisma.auditTemplate.create({
    data: {
      clientId: input.clientId,
      name: input.name,
      schema: input.schema,
      ...(input.industry !== undefined ? { industry: input.industry } : {}),
    },
  });
}

export async function listTemplatesForClient(clientId: string, includeInactive: boolean) {
  return prisma.auditTemplate.findMany({
    where: { clientId, ...(includeInactive ? {} : { active: true }) },
    orderBy: { name: 'asc' },
  });
}

export async function getTemplate(id: string, clientId: string) {
  const template = await prisma.auditTemplate.findFirst({ where: { id, clientId } });
  if (!template) {
    throw new NotFoundError('Template not found');
  }
  return template;
}

export async function updateTemplate(input: UpdateTemplateInput) {
  const existing = await prisma.auditTemplate.findFirst({
    where: { id: input.id, clientId: input.clientId },
  });
  if (!existing) {
    throw new NotFoundError('Template not found');
  }

  const data: Prisma.AuditTemplateUpdateInput = {};
  if (input.name !== undefined) {
    data.name = input.name;
  }
  if (input.industry !== undefined) {
    data.industry = input.industry;
  }
  if (input.active !== undefined) {
    data.active = input.active;
  }
  if (input.schema !== undefined) {
    // A schema change is a new version.
    data.schema = input.schema;
    data.version = { increment: 1 };
  }

  return prisma.auditTemplate.update({ where: { id: input.id }, data });
}
