import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { parsePagination } from '../../lib/pagination';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  listTemplateResponsesForVisit,
  recordTemplateResponse,
} from './templateResponses.service';

export const templateResponsesRouter = Router();
templateResponsesRouter.use(requireAuth);

// Answers are keyed by field id from the template schema; like the schema
// itself, the backend only checks for a plain (non-null, non-array) object.
function isAnswersObject(value: unknown): value is Prisma.InputJsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

templateResponsesRouter.post(
  '/',
  requireRole('field_agent'),
  async (req: AuthedRequest, res) => {
    const { visitId, templateId, answers } = req.body as {
      visitId?: unknown;
      templateId?: unknown;
      answers?: unknown;
    };

    if (
      typeof visitId !== 'string' ||
      visitId.length === 0 ||
      typeof templateId !== 'string' ||
      templateId.length === 0 ||
      !isAnswersObject(answers)
    ) {
      res.status(400).json({
        error: 'visitId (string), templateId (string), and answers (non-null object) are required',
      });
      return;
    }

    const response = await recordTemplateResponse({
      visitId,
      templateId,
      clientId: req.user!.clientId,
      agentId: req.user!.userId,
      answers,
    });
    res.status(201).json(response);
  }
);

templateResponsesRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId, templateId } = req.query as { visitId?: unknown; templateId?: unknown };

  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId query param is required' });
    return;
  }
  if (templateId !== undefined && typeof templateId !== 'string') {
    res.status(400).json({ error: 'templateId must be a string' });
    return;
  }

  const { limit, cursor } = parsePagination(req);
  const rows = await listTemplateResponsesForVisit({
    visitId,
    clientId: req.user!.clientId,
    ...(templateId !== undefined ? { templateId } : {}),
    limit,
    cursor,
  });
  res.status(200).json(rows);
});
