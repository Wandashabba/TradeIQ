import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { getSkuForecast } from './forecast.service';

export const forecastRouter = Router();
forecastRouter.use(requireAuth);

function queryString(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

forecastRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const skuId = queryString(req.query.skuId);
  if (skuId === undefined) {
    res.status(400).json({ error: 'skuId is required' });
    return;
  }
  const outletId = queryString(req.query.outletId);

  const forecast = await getSkuForecast({
    clientId: req.user!.clientId,
    skuId,
    outletId,
  });
  res.status(200).json(forecast);
});
