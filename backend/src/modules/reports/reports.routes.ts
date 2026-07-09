import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  createReport,
  deleteReport,
  generateReport,
  isReportType,
  listReports,
  rowsToCsv,
} from './reports.service';

export const reportsRouter = Router();
reportsRouter.use(requireAuth);
// Reporting is a manager/admin surface end-to-end.
reportsRouter.use(requireRole('manager', 'admin'));

reportsRouter.post('/', async (req: AuthedRequest, res) => {
  const { name, type, filters } = req.body as {
    name?: unknown;
    type?: unknown;
    filters?: unknown;
  };

  if (typeof name !== 'string' || name.length === 0) {
    res.status(400).json({ error: 'name is required' });
    return;
  }
  if (!isReportType(type)) {
    res.status(400).json({ error: 'type must be one of visits|scorecards|tasks|orders' });
    return;
  }
  if (typeof filters !== 'object' || filters === null || Array.isArray(filters)) {
    res.status(400).json({ error: 'filters must be a non-null object' });
    return;
  }

  const report = await createReport({
    clientId: req.user!.clientId,
    name,
    type,
    filters: filters as Prisma.InputJsonValue,
  });
  res.status(201).json(report);
});

reportsRouter.get('/', async (req: AuthedRequest, res) => {
  const reports = await listReports(req.user!.clientId);
  res.status(200).json(reports);
});

reportsRouter.delete('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  await deleteReport(id, req.user!.clientId);
  res.status(204).send();
});

reportsRouter.get('/:id/generate', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const result = await generateReport(id, req.user!.clientId);

  if (req.query.format === 'csv') {
    res.status(200).type('text/csv').send(rowsToCsv(result.rows));
    return;
  }
  res.status(200).json(result);
});
