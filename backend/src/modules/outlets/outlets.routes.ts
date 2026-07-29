import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import { createOutlet, listOutletsForClient } from './outlets.service';

export const outletsRouter = Router();

// All authenticated roles can read outlets (field agents pick one to visit),
// but provisioning an outlet is a management action.
outletsRouter.use(requireAuth);

outletsRouter.get('/', async (req: AuthedRequest, res) => {
  // `?mine=true` narrows to the caller's assigned territories. Opt-in on
  // purpose: the app asks for it as a default view, but any client can still
  // see every outlet in the tenant, because being unable to check in at a
  // store you are standing in is a worse failure than a long list.
  const mine = req.query.mine === 'true';
  const { limit, cursor } = parsePagination(req);
  const page = await listOutletsForClient({
    clientId: req.user!.clientId,
    assignedTo: mine ? req.user!.userId : undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

outletsRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
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
