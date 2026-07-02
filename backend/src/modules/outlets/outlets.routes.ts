import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { createOutlet, listOutletsForClient } from './outlets.service';

export const outletsRouter = Router();

// No requireRole restriction yet — outlet read/write role rules aren't
// specified in the design spec; add requireRole(...) here once they are.
outletsRouter.use(requireAuth);

outletsRouter.get('/', async (req: AuthedRequest, res) => {
  const outlets = await listOutletsForClient(req.user!.clientId);
  res.status(200).json(outlets);
});

outletsRouter.post('/', async (req: AuthedRequest, res) => {
  const { name, code, channelType, lat, lng, territoryId, teamProfile } = req.body as {
    name?: string;
    code?: string;
    channelType?: string;
    lat?: number;
    lng?: number;
    territoryId?: string;
    teamProfile?: unknown;
  };

  if (!name || !code || !channelType || lat === undefined || lng === undefined || !territoryId) {
    res.status(400).json({ error: 'name, code, channelType, lat, lng, and territoryId are required' });
    return;
  }

  try {
    const outlet = await createOutlet({
      name,
      code,
      channelType,
      lat,
      lng,
      territoryId,
      teamProfile: teamProfile as Prisma.InputJsonValue,
      clientId: req.user!.clientId,
    });
    res.status(201).json(outlet);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'An outlet with this code already exists' });
      return;
    }
    throw err;
  }
});
