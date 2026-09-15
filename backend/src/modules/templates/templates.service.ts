import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';
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
    //
    // COPYING THIS PATTERN: the tiebreaker's direction MUST match the primary
    // sort's direction (both `asc` here).
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

  if (input.active === false) {
    // A paused template is not in use, so it stops being the client's audit
    // template in the same write — agents must not keep answering it, and the
    // console must not show a paused template as the one in audits.
    const [, updated] = await prisma.$transaction([
      prisma.client.updateMany({
        where: { id: input.clientId, auditTemplateId: input.id },
        data: { auditTemplateId: null },
      }),
      prisma.auditTemplate.update({ where: { id: input.id }, data }),
    ]);
    return updated;
  }

  return prisma.auditTemplate.update({ where: { id: input.id }, data });
}

// ── The client's audit template (#122) ────────────────────────────────────
//
// A client picks at most one template whose questions its field agents answer
// on every visit, as an extra "client questions" section after the fixed
// S1–S10. It supplements those sections; it never replaces them and never
// feeds the perfect-store score.

/** The template this client uses in audits, or null when it uses none. */
export async function getAuditTemplateForClient(clientId: string) {
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: { auditTemplate: true },
  });
  const template = client?.auditTemplate ?? null;
  // Selection is validated on write; this is the read-side guarantee that a
  // paused or foreign template can never reach an agent, however it got there.
  if (!template || !template.active || template.clientId !== clientId) {
    return null;
  }
  return template;
}

/**
 * Sets (or, with null, clears) the template this client uses in audits.
 * Only one of the client's own, active templates can be chosen: another
 * tenant's template is a 404, exactly as reading it would be.
 */
export async function setAuditTemplateForClient(clientId: string, templateId: string | null) {
  if (templateId !== null) {
    const template = await prisma.auditTemplate.findFirst({ where: { id: templateId, clientId } });
    if (!template) {
      throw new NotFoundError('Template not found');
    }
    if (!template.active) {
      throw new ValidationError('A paused template cannot be used in audits');
    }
  }
  await prisma.client.update({
    where: { id: clientId },
    data: { auditTemplateId: templateId },
  });
  return getAuditTemplateForClient(clientId);
}
