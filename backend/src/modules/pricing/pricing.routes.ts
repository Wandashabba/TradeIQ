import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { NotImplementedError } from '../../middleware/errorHandler';
import { recordPricing, PricingItemInput } from './pricing.service';

export const pricingRouter = Router();
pricingRouter.use(requireAuth);

function isValidItem(item: unknown): item is PricingItemInput {
  if (typeof item !== 'object' || item === null) return false;
  const i = item as Record<string, unknown>;
  return (
    typeof i.skuId === 'string' &&
    typeof i.priceActual === 'number' &&
    typeof i.promoActive === 'boolean' &&
    typeof i.promoMaterialsDetected === 'object' &&
    i.promoMaterialsDetected !== null &&
    typeof i.commsRating === 'number'
  );
}

pricingRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, items } = req.body as { visitId?: string; items?: unknown[] };

  if (!visitId || !Array.isArray(items) || items.length === 0 || !items.every(isValidItem)) {
    res.status(400).json({ error: 'visitId and a non-empty items[] with all required fields are required' });
    return;
  }

  const rows = await recordPricing({ visitId, clientId: req.user!.clientId, items });
  res.status(201).json(rows);
});

pricingRouter.get('/', () => {
  throw new NotImplementedError('Pricing listing is not implemented yet');
});
