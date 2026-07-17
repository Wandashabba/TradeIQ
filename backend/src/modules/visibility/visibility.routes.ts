import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { isVisionEnabled } from '../../lib/featureFlags';
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

  // A photo only switches the section to vision-assisted capture when CV is
  // actually enabled (#92). While it is disabled — the default, because the
  // implementation is still a random stub — a photo is just evidence, and the
  // agent's own measurements are still required and still stand.
  const hasPhoto = typeof photoUrl === 'string' && photoUrl.length > 0;
  const visionWillRun = hasPhoto && isVisionEnabled();

  // visitId and highTrafficPass (a manual field) are required in both paths.
  if (!visitId || typeof highTrafficPass !== 'boolean') {
    res.status(400).json({ error: 'visitId and highTrafficPass are required' });
    return;
  }

  if (!visionWillRun) {
    // Manual-entry path — validate the client-provided vision fields. This now
    // covers "a photo was sent but CV is off": without it the service would
    // write undefined into the vision columns.
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

  // Forward everything we were given and let the service decide which path to
  // take. The route used to drop the manual fields whenever a photo was present,
  // which meant a photo sent with CV disabled wrote undefined into the vision
  // columns — the route was making a decision that is the service's to make.
  const visibility = await recordVisibility({
    visitId,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    highTrafficPass,
    photoUrl: hasPhoto ? (photoUrl as string) : undefined,
    templateId: typeof templateId === 'string' ? templateId : undefined,
    skuId: typeof skuId === 'string' ? skuId : undefined,
    // Manual brandingElements stand on their own, and are merged with the model's
    // verdict when vision runs.
    brandingElements:
      typeof brandingElements === 'object' && brandingElements !== null
        ? (brandingElements as Prisma.InputJsonValue)
        : undefined,
    planogramCompliancePct:
      typeof planogramCompliancePct === 'number' ? planogramCompliancePct : undefined,
    facingsCount:
      typeof facingsCount === 'object' && facingsCount !== null
        ? (facingsCount as Prisma.InputJsonValue)
        : undefined,
    cleanlinessScore: typeof cleanlinessScore === 'number' ? cleanlinessScore : undefined,
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
