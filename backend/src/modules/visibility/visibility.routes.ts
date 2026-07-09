import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { NotImplementedError } from '../../middleware/errorHandler';
import { recordVisibility } from './visibility.service';

export const visibilityRouter = Router();
visibilityRouter.use(requireAuth);

visibilityRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const {
    visitId,
    brandingElements,
    planogramCompliancePct,
    facingsCount,
    highTrafficPass,
    cleanlinessScore,
  } = req.body as {
    visitId?: string;
    brandingElements?: unknown;
    planogramCompliancePct?: unknown;
    facingsCount?: unknown;
    highTrafficPass?: unknown;
    cleanlinessScore?: unknown;
  };

  if (
    !visitId ||
    typeof planogramCompliancePct !== 'number' ||
    typeof cleanlinessScore !== 'number' ||
    typeof highTrafficPass !== 'boolean' ||
    typeof brandingElements !== 'object' ||
    brandingElements === null ||
    typeof facingsCount !== 'object' ||
    facingsCount === null
  ) {
    res.status(400).json({
      error:
        'visitId, brandingElements, planogramCompliancePct, facingsCount, highTrafficPass, and cleanlinessScore are required',
    });
    return;
  }

  const visibility = await recordVisibility({
    visitId,
    clientId: req.user!.clientId,
    brandingElements: brandingElements as Prisma.InputJsonValue,
    planogramCompliancePct,
    facingsCount: facingsCount as Prisma.InputJsonValue,
    highTrafficPass,
    cleanlinessScore,
  });
  res.status(201).json(visibility);
});

visibilityRouter.get('/', () => {
  throw new NotImplementedError('Visibility listing is not implemented yet');
});
