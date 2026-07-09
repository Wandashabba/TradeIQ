import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { getVisibility, recordVisibility } from './visibility.service';

export const visibilityRouter = Router();
visibilityRouter.use(requireAuth);

visibilityRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const {
    visitId,
    photoUrl,
    templateId,
    skuId,
    brandingElements,
    planogramCompliancePct,
    facingsCount,
    highTrafficPass,
    cleanlinessScore,
  } = req.body as {
    visitId?: string;
    photoUrl?: unknown;
    templateId?: unknown;
    skuId?: unknown;
    brandingElements?: unknown;
    planogramCompliancePct?: unknown;
    facingsCount?: unknown;
    highTrafficPass?: unknown;
    cleanlinessScore?: unknown;
  };

  // A non-empty photoUrl switches the section to vision-assisted capture; the
  // vision fields are then derived from the CV stub in the service layer.
  const hasPhoto = typeof photoUrl === 'string' && photoUrl.length > 0;

  // visitId and highTrafficPass (a manual field) are required in both paths.
  if (!visitId || typeof highTrafficPass !== 'boolean') {
    res.status(400).json({ error: 'visitId and highTrafficPass are required' });
    return;
  }

  if (!hasPhoto) {
    // Manual-entry path — validate the client-provided vision fields exactly as
    // before.
    if (
      typeof planogramCompliancePct !== 'number' ||
      typeof cleanlinessScore !== 'number' ||
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
  }

  const visibility = await recordVisibility({
    visitId,
    clientId: req.user!.clientId,
    highTrafficPass,
    ...(hasPhoto
      ? {
          photoUrl: photoUrl as string,
          templateId: typeof templateId === 'string' ? templateId : undefined,
          skuId: typeof skuId === 'string' ? skuId : undefined,
          // Optional manual brandingElements are merged with the stub result.
          brandingElements:
            typeof brandingElements === 'object' && brandingElements !== null
              ? (brandingElements as Prisma.InputJsonValue)
              : undefined,
        }
      : {
          brandingElements: brandingElements as Prisma.InputJsonValue,
          planogramCompliancePct: planogramCompliancePct as number,
          facingsCount: facingsCount as Prisma.InputJsonValue,
          cleanlinessScore: cleanlinessScore as number,
        }),
  });
  res.status(201).json(visibility);
});

visibilityRouter.get('/', async (req: AuthedRequest, res) => {
  const visitId = typeof req.query.visitId === 'string' ? req.query.visitId : undefined;
  if (!visitId) {
    res.status(400).json({ error: 'visitId is required' });
    return;
  }

  const visibility = await getVisibility({ visitId, clientId: req.user!.clientId });
  res.status(200).json(visibility);
});
