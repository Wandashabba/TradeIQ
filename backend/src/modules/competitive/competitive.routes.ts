import { Router } from 'express';
import { parsePagination } from '../../lib/pagination';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { listCompetitiveForVisit, recordCompetitive, CompetitiveItemInput } from './competitive.service';

export const competitiveRouter = Router();
competitiveRouter.use(requireAuth);

function isValidItem(item: unknown): item is CompetitiveItemInput {
  if (typeof item !== 'object' || item === null) return false;
  const i = item as Record<string, unknown>;
  return (
    typeof i.competitorSku === 'string' &&
    typeof i.competitorPrice === 'number' &&
    typeof i.competitorPosmType === 'string' &&
    typeof i.competitorPromoterPresent === 'boolean' &&
    typeof i.geotag === 'object' &&
    i.geotag !== null
  );
}

competitiveRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, items } = req.body as { visitId?: string; items?: unknown[] };

  if (!visitId || !Array.isArray(items) || items.length === 0 || !items.every(isValidItem)) {
    res.status(400).json({ error: 'visitId and a non-empty items[] with all required fields are required' });
    return;
  }

  const rows = await recordCompetitive({ visitId, clientId: req.user!.clientId, agentId: req.user!.userId, items });
  res.status(201).json(rows);
});

competitiveRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId } = req.query;
  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId query param is required' });
    return;
  }

  const rows = await listCompetitiveForVisit(visitId, req.user!.clientId, parsePagination(req));
  res.status(200).json(rows);
});
