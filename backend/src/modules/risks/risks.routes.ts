import { Router } from 'express';
import { parsePagination } from '../../lib/pagination';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { listRisksForVisit, recordRisks, RiskInput } from './risks.service';

const SEVERITIES: readonly string[] = ['critical', 'high', 'normal'];

function isValidRisk(risk: unknown): risk is RiskInput {
  if (typeof risk !== 'object' || risk === null) return false;
  const r = risk as Record<string, unknown>;
  return (
    typeof r.flagType === 'string' &&
    typeof r.note === 'string' &&
    typeof r.severity === 'string' &&
    SEVERITIES.includes(r.severity)
  );
}

export const risksRouter = Router();
risksRouter.use(requireAuth);

risksRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, risks } = req.body as { visitId?: string; risks?: unknown[] };

  if (!visitId || !Array.isArray(risks) || risks.length === 0 || !risks.every(isValidRisk)) {
    res.status(400).json({
      error:
        'visitId and a non-empty risks[] with flagType, severity (critical|high|normal), and note are required',
    });
    return;
  }

  const result = await recordRisks({ visitId, clientId: req.user!.clientId, risks });
  res.status(201).json(result);
});

risksRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId } = req.query;
  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId query param is required' });
    return;
  }

  const rows = await listRisksForVisit(visitId, req.user!.clientId, parsePagination(req));
  res.status(200).json(rows);
});
