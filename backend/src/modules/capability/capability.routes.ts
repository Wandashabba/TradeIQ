import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { NotImplementedError } from '../../middleware/errorHandler';
import { recordCapability } from './capability.service';

export const capabilityRouter = Router();
capabilityRouter.use(requireAuth);

capabilityRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, staffHeadcountConfirmed, repTrainingStatus, quizScore } = req.body as {
    visitId?: string;
    staffHeadcountConfirmed?: unknown;
    repTrainingStatus?: unknown;
    quizScore?: unknown;
  };

  if (
    !visitId ||
    typeof staffHeadcountConfirmed !== 'number' ||
    typeof quizScore !== 'number' ||
    typeof repTrainingStatus !== 'object' ||
    repTrainingStatus === null
  ) {
    res.status(400).json({
      error: 'visitId, staffHeadcountConfirmed, repTrainingStatus, and quizScore are required',
    });
    return;
  }

  const capability = await recordCapability({
    visitId,
    clientId: req.user!.clientId,
    staffHeadcountConfirmed,
    repTrainingStatus: repTrainingStatus as Prisma.InputJsonValue,
    quizScore,
  });
  res.status(201).json(capability);
});

capabilityRouter.get('/', () => {
  throw new NotImplementedError('Capability listing is not implemented yet');
});
