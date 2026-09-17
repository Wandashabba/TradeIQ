import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parseIsoInstant } from '../../lib/parseIsoInstant';
import { isConsentKind } from './locationPolicy';
import {
  LocationConsentRequiredError,
  getLocationSettings,
  ingestPings,
  parsePingBatch,
  recordConsent,
} from './locations.service';

/**
 * Location sharing, field agent side: the foreground heartbeat (#153 T1) and
 * background tracking between stores (#153 T2).
 *
 * The agent id and tenant come from the token on every route here — never from
 * the body — so an agent can only ever write their own location into their own
 * tenant.
 */
export const locationsRouter = Router();
locationsRouter.use(requireAuth);

/**
 * Interval, notice versions and the agent's answers — foreground and
 * background reported independently, plus the working window as instants.
 */
locationsRouter.get('/settings', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const settings = await getLocationSettings(req.user!.clientId, req.user!.userId);
  res.status(200).json(settings);
});

/** Records the agent's answer to one of the location notices. */
locationsRouter.post('/consent', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { decision, noticeVersion, decidedAt, kind } = (req.body ?? {}) as {
    decision?: unknown;
    noticeVersion?: unknown;
    decidedAt?: unknown;
    kind?: unknown;
  };
  if (decision !== 'acknowledged' && decision !== 'declined') {
    res.status(400).json({ error: "decision must be 'acknowledged' or 'declined'" });
    return;
  }
  // Absent means the foreground notice, so an app build that predates T2 keeps
  // recording its answers against the notice it actually showed.
  if (kind !== undefined && !isConsentKind(kind)) {
    res.status(400).json({ error: "kind must be 'foreground' or 'background'" });
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
    kind: kind === undefined ? undefined : kind,
    decidedAt: decidedAtDate,
  });
  res.status(201).json(consent);
});

/**
 * A batch of pings, possibly late and out of order. `source` says which capture
 * produced them (`foreground` by default, `background` for T2) and decides
 * which notice must have been accepted and whether the working-hours window
 * applies.
 */
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
      source: parsed.source,
    });
    res.status(200).json(result);
  } catch (err) {
    if (err instanceof LocationConsentRequiredError) {
      // A code the app can act on (stop that capture, ask again), not just
      // words — and specific to the notice, so a missing background
      // acknowledgement never stops the foreground heartbeat as well.
      res.status(403).json({ error: err.message, code: err.code });
      return;
    }
    throw err;
  }
});
