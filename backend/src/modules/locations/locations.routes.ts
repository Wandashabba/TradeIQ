import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parseIsoInstant } from '../../lib/parseIsoInstant';
import {
  LocationConsentRequiredError,
  getLocationSettings,
  ingestPings,
  parsePingBatch,
  recordConsent,
} from './locations.service';

/**
 * Foreground location sharing, field agent side (#153 T1).
 *
 * The agent id and tenant come from the token on every route here — never from
 * the body — so an agent can only ever write their own location into their own
 * tenant.
 */
export const locationsRouter = Router();
locationsRouter.use(requireAuth);

/** Interval, notice version and the agent's current answer. */
locationsRouter.get('/settings', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const settings = await getLocationSettings(req.user!.clientId, req.user!.userId);
  res.status(200).json(settings);
});

/** Records the agent's answer to the location notice. */
locationsRouter.post('/consent', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { decision, noticeVersion, decidedAt } = (req.body ?? {}) as {
    decision?: unknown;
    noticeVersion?: unknown;
    decidedAt?: unknown;
  };
  if (decision !== 'acknowledged' && decision !== 'declined') {
    res.status(400).json({ error: "decision must be 'acknowledged' or 'declined'" });
    return;
  }
  if (typeof noticeVersion !== 'string' || noticeVersion.length === 0) {
    res.status(400).json({ error: 'noticeVersion is required' });
    return;
  }
  let decidedAtDate: Date | undefined;
  if (decidedAt !== undefined) {
    decidedAtDate = typeof decidedAt === 'string' ? parseIsoInstant(decidedAt) : undefined;
    if (decidedAtDate === undefined) {
      res.status(400).json({ error: 'decidedAt must be a full ISO-8601 instant' });
      return;
    }
  }
  const consent = await recordConsent({
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    decision,
    noticeVersion,
    decidedAt: decidedAtDate,
  });
  res.status(201).json(consent);
});

/** A batch of foreground pings, possibly late and out of order. */
locationsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const parsed = parsePingBatch(req.body);
  if (!parsed.ok) {
    res.status(400).json({ error: parsed.error });
    return;
  }
  try {
    const result = await ingestPings({
      clientId: req.user!.clientId,
      agentId: req.user!.userId,
      pings: parsed.pings,
    });
    res.status(200).json(result);
  } catch (err) {
    if (err instanceof LocationConsentRequiredError) {
      // A code the app can act on (stop the heartbeat, ask again), not just words.
      res.status(403).json({ error: err.message, code: 'location_consent_required' });
      return;
    }
    throw err;
  }
});
