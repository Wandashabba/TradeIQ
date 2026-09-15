import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { runCsvForClient } from './reportschedules.service';
import { reportLinkSecret, verifyReportLinkToken } from './reportschedules.links';

/**
 * Signed CSV downloads (#66): `GET /report-downloads/:token`.
 *
 * Deliberately **outside** the report-schedules router, which requires a
 * manager/admin bearer token on every path. Here the token IS the credential:
 * an HMAC over one tenant, one schedule and one run, with an expiry
 * (reportschedules.links.ts). The run is still looked up by all three ids, so
 * a token whose claims do not name a real run of that tenant is a 404.
 */
export const reportDownloadsRouter = Router();

/**
 * Per IP. The HMAC already makes guessing hopeless; this bounds the cost of a
 * valid link being hammered, since every download regenerates the whole
 * report. Generous for a person or a nightly job, tight for a loop.
 */
export function createReportDownloadRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return rateLimit({
    windowMs: options?.windowMs ?? 15 * 60 * 1000,
    limit: options?.limit ?? 60,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many downloads, please try again later' },
  });
}

reportDownloadsRouter.use(createReportDownloadRateLimiter());

const INVALID = 'Invalid download link';

reportDownloadsRouter.get('/:token', async (req, res) => {
  // A download link is a bearer credential: never cache the response anywhere.
  res.setHeader('Cache-Control', 'private, no-store');

  const { token } = req.params as { token: string };
  const secret = reportLinkSecret();
  if (!secret.ok) {
    // Links are off on this deployment, so no token can be valid.
    res.status(401).json({ error: INVALID });
    return;
  }
  const verified = verifyReportLinkToken(secret.secret, token);
  if (!verified.ok) {
    if (verified.reason === 'expired') {
      res.status(410).json({ error: 'This download link has expired' });
    } else {
      res.status(401).json({ error: INVALID });
    }
    return;
  }

  const { clientId, scheduleId, runId } = verified.claims;
  const { run, csv } = await runCsvForClient(scheduleId, runId, clientId);
  res.setHeader('Content-Disposition', `attachment; filename="report-${run.id}.csv"`);
  res.status(200).type('text/csv').send(csv);
});
