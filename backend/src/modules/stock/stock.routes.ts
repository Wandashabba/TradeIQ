import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';
import { recordStock } from './stock.service';

export const stockRouter = Router();
stockRouter.use(requireAuth);

stockRouter.post('/', async (req: AuthedRequest, res) => {
  const {
    visitId,
    skuId,
    unitsAvailable,
    lastStockinDate,
    daysOutOfStock,
    velocityAvg,
    salesActual,
    salesTarget,
  } = req.body as {
    visitId?: string;
    skuId?: string;
    unitsAvailable?: number;
    lastStockinDate?: string;
    daysOutOfStock?: number;
    velocityAvg?: number;
    salesActual?: number;
    salesTarget?: number;
  };

  if (
    !visitId ||
    !skuId ||
    unitsAvailable === undefined ||
    !lastStockinDate ||
    daysOutOfStock === undefined ||
    velocityAvg === undefined ||
    salesActual === undefined ||
    salesTarget === undefined
  ) {
    res.status(400).json({
      error:
        'visitId, skuId, unitsAvailable, lastStockinDate, daysOutOfStock, velocityAvg, salesActual, and salesTarget are required',
    });
    return;
  }

  const stock = await recordStock({
    visitId,
    skuId,
    unitsAvailable,
    lastStockinDate: new Date(lastStockinDate),
    daysOutOfStock,
    velocityAvg,
    salesActual,
    salesTarget,
    clientId: req.user!.clientId,
  });
  res.status(201).json(stock);
});

stockRouter.get('/', () => {
  throw new NotImplementedError('Stock listing is not implemented yet');
});
