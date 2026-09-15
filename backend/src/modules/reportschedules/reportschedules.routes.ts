import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  createSchedule,
  deleteSchedule,
  isCadence,
  listSchedules,
  runCsvForClient,
  runSchedule,
  updateSchedule,
  type Cadence,
} from './reportschedules.service';
import { listEmailDeliveriesForRun, validateRecipients } from './reportschedules.email';
import { listRunsForSchedule } from './reportschedules.runs';
import { parsePagination } from '../../lib/pagination';

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
  const checked = validateRecipients(recipients);
  if (!checked.ok) {
    res.status(400).json({ error: checked.error });
    return;
  }

  const schedule = await createSchedule({
    clientId: req.user!.clientId,
    reportDefinitionId,
    cadence,
    recipients: checked.recipients,
  });
  res.status(201).json(schedule);
});

reportSchedulesRouter.get('/', async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const page = await listSchedules({ clientId: req.user!.clientId, limit, cursor });
  res.status(200).json(page);
});

reportSchedulesRouter.patch('/:id', async (req: AuthedRequest, res) => {
  const { active, cadence, recipients } = req.body as {
    active?: unknown;
    cadence?: unknown;
    recipients?: unknown;
  };

  if ((active !== undefined && typeof active !== 'boolean') || (cadence !== undefined && !isCadence(cadence))) {
    res.status(400).json({
      error: 'active must be a boolean, and cadence must be daily|weekly',
    });
    return;
  }
  const checked = recipients === undefined ? undefined : validateRecipients(recipients);
  if (checked && !checked.ok) {
    res.status(400).json({ error: checked.error });
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
    recipients: checked?.ok ? checked.recipients : undefined,
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

// A schedule's run history (#66), newest first: each run's status, delivery
// summary, webhook results and signed CSV link. Another client's schedule is
// a 404.
reportSchedulesRouter.get('/:id/runs', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const { limit, cursor } = parsePagination(req);
  const page = await listRunsForSchedule({ scheduleId: id, clientId: req.user!.clientId, limit, cursor });
  res.status(200).json(page);
});

// A run's CSV (#66) — what a `report.generated` webhook's `csvPath` points at.
// Manager/admin like the rest of this router; another client's run is a 404.
// Machine subscribers use the signed `csvDownloadUrl` instead
// (reportschedules.downloads.routes.ts).
reportSchedulesRouter.get('/:id/runs/:runId/csv', async (req: AuthedRequest, res) => {
  const { id, runId } = req.params as { id: string; runId: string };
  const { run, csv } = await runCsvForClient(id, runId, req.user!.clientId);
  // Force download rather than inline render (defense-in-depth for CWE-1236).
  // The filename uses the stored id, never the raw path segment.
  res.setHeader('Content-Disposition', `attachment; filename="report-${run.id}.csv"`);
  res.status(200).type('text/csv').send(csv);
});

// A run's email delivery log (#66): one row per recipient, with attempts and
// the last error. Another client's run is a 404.
reportSchedulesRouter.get('/:id/runs/:runId/email-deliveries', async (req: AuthedRequest, res) => {
  const { id, runId } = req.params as { id: string; runId: string };
  const { limit, cursor } = parsePagination(req);
  const page = await listEmailDeliveriesForRun({
    scheduleId: id,
    runId,
    clientId: req.user!.clientId,
    limit,
    cursor,
  });
  res.status(200).json(page);
});
