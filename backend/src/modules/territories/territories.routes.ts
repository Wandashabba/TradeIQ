import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  assignAgentToTerritory,
  createTerritory,
  getTerritoryCoverage,
  listTerritoriesForClient,
} from './territories.service';

export const territoriesRouter = Router();
territoriesRouter.use(requireAuth);

territoriesRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, code, region } = req.body as {
    name?: unknown;
    code?: unknown;
    region?: unknown;
  };

  if (typeof name !== 'string' || typeof code !== 'string' || (region !== undefined && typeof region !== 'string')) {
    res.status(400).json({ error: 'name and code are required; region must be a string when given' });
    return;
  }

  try {
    const territory = await createTerritory({
      clientId: req.user!.clientId,
      name,
      code,
      region,
    });
    res.status(201).json(territory);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'A territory with this code already exists' });
      return;
    }
    throw err;
  }
});

territoriesRouter.get('/', async (req: AuthedRequest, res) => {
  const territories = await listTerritoriesForClient(req.user!.clientId);
  res.status(200).json(territories);
});

territoriesRouter.post('/:id/agents', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { userId } = req.body as { userId?: unknown };

  if (typeof userId !== 'string') {
    res.status(400).json({ error: 'userId is required' });
    return;
  }

  const { id: territoryId } = req.params as { id: string };

  try {
    const assignment = await assignAgentToTerritory({
      territoryId,
      userId,
      clientId: req.user!.clientId,
    });
    res.status(201).json(assignment);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'This agent is already assigned to the territory' });
      return;
    }
    throw err;
  }
});

territoriesRouter.get('/:id/coverage', async (req: AuthedRequest, res) => {
  const { id: territoryId } = req.params as { id: string };
  const coverage = await getTerritoryCoverage(territoryId, req.user!.clientId);
  res.status(200).json(coverage);
});
