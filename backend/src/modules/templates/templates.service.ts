import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';

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

export interface ListTemplatesForClientInput {
  clientId: string;
  includeInactive: boolean;
  limit: number;
  cursor?: string;
}

export async function listTemplatesForClient(input: ListTemplatesForClientInput) {
  const rows = await prisma.auditTemplate.findMany({
    where: {
      clientId: input.clientId,
      ...(input.includeInactive ? {} : { active: true }),
    },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two templates share a name — same reasoning as alerts.service.ts.
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
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
