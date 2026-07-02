import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { createOutlet, listOutletsForClient } from './outlets.service';

export const outletsRouter = Router();

outletsRouter.use(requireAuth);

outletsRouter.get('/', async (req: AuthedRequest, res) => {
  const outlets = await listOutletsForClient(req.user!.clientId);
  res.status(200).json(outlets);
});

outletsRouter.post('/', async (req: AuthedRequest, res) => {
  const { name, code, channelType, lat, lng, territoryId, teamProfile } = req.body;
  const outlet = await createOutlet({
    name,
    code,
    channelType,
    lat,
    lng,
    territoryId,
    teamProfile,
    clientId: req.user!.clientId,
  });
  res.status(201).json(outlet);
});
