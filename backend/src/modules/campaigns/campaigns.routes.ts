import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  CAMPAIGN_STATUSES,
  CampaignStatus,
  createCampaign,
  getCampaign,
  getCampaignCompliance,
  listCampaigns,
  updateCampaign,
} from './campaigns.service';

export const campaignsRouter = Router();
campaignsRouter.use(requireAuth);

function isValidDate(value: unknown): value is string {
  return typeof value === 'string' && !Number.isNaN(new Date(value).getTime());
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((v) => typeof v === 'string');
}

campaignsRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, startDate, endDate, objective, budget, outletIds } = req.body as {
    name?: unknown;
    startDate?: unknown;
    endDate?: unknown;
    objective?: unknown;
    budget?: unknown;
    outletIds?: unknown;
  };

  if (typeof name !== 'string' || name.trim().length === 0) {
    res.status(400).json({ error: 'name is required' });
    return;
  }
  if (!isValidDate(startDate) || !isValidDate(endDate)) {
    res.status(400).json({ error: 'startDate and endDate must be valid ISO dates' });
    return;
  }
  if (objective !== undefined && typeof objective !== 'string') {
    res.status(400).json({ error: 'objective must be a string' });
    return;
  }
  if (budget !== undefined && typeof budget !== 'number') {
    res.status(400).json({ error: 'budget must be a number' });
    return;
  }
  if (outletIds !== undefined && !isStringArray(outletIds)) {
    res.status(400).json({ error: 'outletIds must be an array of strings' });
    return;
  }

  const campaign = await createCampaign({
    clientId: req.user!.clientId,
    name,
    startDate,
    endDate,
    objective,
    budget,
    outletIds,
  });
  res.status(201).json(campaign);
});

campaignsRouter.get('/', async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const page = await listCampaigns({ clientId: req.user!.clientId, limit, cursor });
  res.status(200).json(page);
});

campaignsRouter.get('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const campaign = await getCampaign(id, req.user!.clientId);
  res.status(200).json(campaign);
});

campaignsRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { status, name, objective, budget } = req.body as {
    status?: unknown;
    name?: unknown;
    objective?: unknown;
    budget?: unknown;
  };

  if (status !== undefined && !CAMPAIGN_STATUSES.includes(status as CampaignStatus)) {
    res.status(400).json({ error: 'status must be one of draft, active, completed' });
    return;
  }
  if (name !== undefined && (typeof name !== 'string' || name.trim().length === 0)) {
    res.status(400).json({ error: 'name must be a non-empty string' });
    return;
  }
  if (objective !== undefined && typeof objective !== 'string') {
    res.status(400).json({ error: 'objective must be a string' });
    return;
  }
  if (budget !== undefined && typeof budget !== 'number') {
    res.status(400).json({ error: 'budget must be a number' });
    return;
  }

  if (status === undefined && name === undefined && objective === undefined && budget === undefined) {
    res.status(400).json({ error: 'at least one updatable field is required' });
    return;
  }

  const { id } = req.params as { id: string };
  const campaign = await updateCampaign(id, req.user!.clientId, {
    status: status as CampaignStatus | undefined,
    name: name as string | undefined,
    objective: objective as string | undefined,
    budget: budget as number | undefined,
  });
  res.status(200).json(campaign);
});

campaignsRouter.get('/:id/compliance', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const compliance = await getCampaignCompliance(id, req.user!.clientId);
  res.status(200).json(compliance);
});
