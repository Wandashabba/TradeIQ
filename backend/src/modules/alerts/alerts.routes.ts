import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  acknowledgeAlert,
  createAlertRule,
  evaluateVisit,
  isAlertMetric,
  listAlertRules,
  listAlerts,
  updateAlertRule,
} from './alerts.service';

export const alertsRouter = Router();
alertsRouter.use(requireAuth);

alertsRouter.post('/rules', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, metric, threshold, severity } = req.body as {
    name?: unknown;
    metric?: unknown;
    threshold?: unknown;
    severity?: unknown;
  };

  if (
    typeof name !== 'string' ||
    name.length === 0 ||
    !isAlertMetric(metric) ||
    (threshold !== undefined && typeof threshold !== 'number') ||
    (severity !== undefined && typeof severity !== 'string')
  ) {
    res.status(400).json({
      error:
        'name and metric (out_of_stock|price_deviation|low_scorecard) are required; threshold must be a number and severity a string when given',
    });
    return;
  }

  const rule = await createAlertRule({
    clientId: req.user!.clientId,
    name,
    metric,
    threshold,
    severity,
  });
  res.status(201).json(rule);
});

alertsRouter.get('/rules', async (req: AuthedRequest, res) => {
  const rules = await listAlertRules(req.user!.clientId);
  res.status(200).json(rules);
});

alertsRouter.patch('/rules/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { active, threshold, severity } = req.body as {
    active?: unknown;
    threshold?: unknown;
    severity?: unknown;
  };

  if (
    (active !== undefined && typeof active !== 'boolean') ||
    (threshold !== undefined && typeof threshold !== 'number') ||
    (severity !== undefined && typeof severity !== 'string')
  ) {
    res.status(400).json({
      error: 'active must be a boolean, threshold a number, and severity a string when given',
    });
    return;
  }
  if (active === undefined && threshold === undefined && severity === undefined) {
    res.status(400).json({ error: 'At least one of active, threshold, or severity is required' });
    return;
  }

  const { id } = req.params as { id: string };
  const rule = await updateAlertRule(id, req.user!.clientId, { active, threshold, severity });
  res.status(200).json(rule);
});

alertsRouter.post('/evaluate', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { visitId } = req.body as { visitId?: unknown };
  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId is required' });
    return;
  }

  const created = await evaluateVisit({ clientId: req.user!.clientId, visitId });
  res.status(201).json({ created });
});

alertsRouter.get('/', async (req: AuthedRequest, res) => {
  const { acknowledged, severity } = req.query as {
    acknowledged?: unknown;
    severity?: unknown;
  };

  if (
    (acknowledged !== undefined &&
      acknowledged !== 'true' &&
      acknowledged !== 'false') ||
    (severity !== undefined && typeof severity !== 'string')
  ) {
    res.status(400).json({
      error: "acknowledged must be 'true' or 'false' and severity a string when given",
    });
    return;
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listAlerts({
    clientId: req.user!.clientId,
    acknowledged: acknowledged === undefined ? undefined : acknowledged === 'true',
    severity: severity as string | undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

alertsRouter.patch('/:id/ack', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const alert = await acknowledgeAlert(id, req.user!.clientId);
  res.status(200).json(alert);
});
