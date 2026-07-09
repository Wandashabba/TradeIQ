import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  createTemplate,
  getTemplate,
  listTemplatesForClient,
  updateTemplate,
} from './templates.service';

export const templatesRouter = Router();
templatesRouter.use(requireAuth);

// The schema is a free-form dynamic-form definition; the backend only checks it
// is a plain (non-null, non-array) object and stores it verbatim.
function isSchemaObject(value: unknown): value is Prisma.InputJsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

templatesRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, schema, industry } = req.body as {
    name?: unknown;
    schema?: unknown;
    industry?: unknown;
  };

  if (typeof name !== 'string' || name.length === 0 || !isSchemaObject(schema)) {
    res.status(400).json({ error: 'name (string) and schema (non-null object) are required' });
    return;
  }
  if (industry !== undefined && typeof industry !== 'string') {
    res.status(400).json({ error: 'industry must be a string when provided' });
    return;
  }

  const template = await createTemplate({
    clientId: req.user!.clientId,
    name,
    schema,
    ...(industry !== undefined ? { industry } : {}),
  });
  res.status(201).json(template);
});

templatesRouter.get('/', async (req: AuthedRequest, res) => {
  const includeInactive = req.query.includeInactive === 'true';
  const templates = await listTemplatesForClient(req.user!.clientId, includeInactive);
  res.status(200).json(templates);
});

templatesRouter.get('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const template = await getTemplate(id, req.user!.clientId);
  res.status(200).json(template);
});

templatesRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { schema, name, industry, active } = req.body as {
    schema?: unknown;
    name?: unknown;
    industry?: unknown;
    active?: unknown;
  };

  const hasSchema = schema !== undefined;
  const hasName = name !== undefined;
  const hasIndustry = industry !== undefined;
  const hasActive = active !== undefined;

  // At least one updatable field must be present.
  if (!hasSchema && !hasName && !hasIndustry && !hasActive) {
    res.status(400).json({ error: 'a schema, name, industry, or active field is required' });
    return;
  }
  // Each present field must be well-typed; a present schema must be a non-null object.
  if (
    (hasSchema && !isSchemaObject(schema)) ||
    (hasName && (typeof name !== 'string' || name.length === 0)) ||
    (hasIndustry && typeof industry !== 'string') ||
    (hasActive && typeof active !== 'boolean')
  ) {
    res.status(400).json({ error: 'invalid schema, name, industry, or active value' });
    return;
  }

  const { id } = req.params as { id: string };
  const template = await updateTemplate({
    id,
    clientId: req.user!.clientId,
    ...(isSchemaObject(schema) ? { schema } : {}),
    ...(typeof name === 'string' ? { name } : {}),
    ...(typeof industry === 'string' ? { industry } : {}),
    ...(typeof active === 'boolean' ? { active } : {}),
  });
  res.status(200).json(template);
});
