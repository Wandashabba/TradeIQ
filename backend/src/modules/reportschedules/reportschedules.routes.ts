import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  createSchedule,
  deleteSchedule,
  isCadence,
  isRecipients,
  listSchedules,
  runSchedule,
  updateSchedule,
  type Cadence,
} from './reportschedules.service';

export const reportSchedulesRouter = Router();
reportSchedulesRouter.use(requireAuth);
// Scheduled report delivery is a manager/admin surface end-to-end.
reportSchedulesRouter.use(requireRole('manager', 'admin'));

reportSchedulesRouter.post('/', async (req: AuthedRequest, res) => {
  const { reportDefinitionId, cadence, recipients } = req.body as {
    reportDefinitionId?: unknown;
    cadence?: unknown;
    recipients?: unknown;
  };

  if (typeof reportDefinitionId !== 'string' || reportDefinitionId.length === 0) {
    res.status(400).json({ error: 'reportDefinitionId is required' });
    return;
  }
  if (!isCadence(cadence)) {
    res.status(400).json({ error: 'cadence must be one of daily|weekly' });
    return;
  }
  if (!isRecipients(recipients)) {
    res.status(400).json({ error: 'recipients must be a non-empty array of strings' });
    return;
  }

  const schedule = await createSchedule({
    clientId: req.user!.clientId,
    reportDefinitionId,
    cadence,
    recipients,
  });
  res.status(201).json(schedule);
});

reportSchedulesRouter.get('/', async (req: AuthedRequest, res) => {
  const schedules = await listSchedules(req.user!.clientId);
  res.status(200).json(schedules);
});

reportSchedulesRouter.patch('/:id', async (req: AuthedRequest, res) => {
  const { active, cadence, recipients } = req.body as {
    active?: unknown;
    cadence?: unknown;
    recipients?: unknown;
  };

  if (
    (active !== undefined && typeof active !== 'boolean') ||
    (cadence !== undefined && !isCadence(cadence)) ||
    (recipients !== undefined && !isRecipients(recipients))
  ) {
    res.status(400).json({
      error:
        'active must be a boolean, cadence must be daily|weekly, and recipients must be a non-empty array of strings',
    });
    return;
  }
  if (active === undefined && cadence === undefined && recipients === undefined) {
    res.status(400).json({ error: 'At least one of active, cadence, or recipients is required' });
    return;
  }

  const { id } = req.params as { id: string };
  const schedule = await updateSchedule(id, req.user!.clientId, {
    active: active as boolean | undefined,
    cadence: cadence as Cadence | undefined,
    recipients: recipients as string[] | undefined,
  });
  res.status(200).json(schedule);
});

reportSchedulesRouter.delete('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  await deleteSchedule(id, req.user!.clientId);
  res.status(204).send();
});

reportSchedulesRouter.post('/:id/run', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const result = await runSchedule(id, req.user!.clientId);
  res.status(200).json(result);
});
