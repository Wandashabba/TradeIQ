import { Router } from 'express';
import { z } from 'zod';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  FRAUD_VERDICTS,
  FlaggedReviewFilter,
  getVisitFraud,
  listAttempts,
  listFlagged,
  listVerdicts,
  recordFraudVerdict,
} from './fraud.service';
import { parsePagination } from '../../lib/pagination';

const DEFAULT_MIN_SCORE = 50;

export const fraudRouter = Router();

// Fraud analytics are a supervisory concern: managers/admins only, and every
// query is scoped to the caller's own client (tenant).
fraudRouter.use(requireAuth);
fraudRouter.use(requireRole('manager', 'admin'));

// The zod issue list the 400 envelope carries, as competitorPrices.routes.ts
// spells it: `{ error, issues }`, one line per failed field path.
function issues(error: z.ZodError) {
  return error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`);
}

// GET /fraud/visits/:visitId — score a single visit. 404 if it isn't the
// caller's tenant's visit.
fraudRouter.get('/visits/:visitId', async (req: AuthedRequest, res) => {
  const { visitId } = req.params as { visitId: string };
  const result = await getVisitFraud(visitId, req.user!.clientId);
  res.status(200).json(result);
});

// The note is free text a reviewer types, so it is trimmed and bounded. An
// empty note is not a note: `.trim()` plus the service's `?? null` means a
// reviewer who typed nothing leaves null rather than '' — the wire never says
// "there is a note" about a blank string.
const MAX_VERDICT_NOTE_LENGTH = 2000;

const verdictBody = z
  .object({
    verdict: z.enum(FRAUD_VERDICTS),
    note: z.string().trim().max(MAX_VERDICT_NOTE_LENGTH).optional(),
  })
  .strict();

/**
 * POST /fraud/visits/:visitId/verdict — record the manager's ruling (#392, #395).
 *
 * **201 once, 409 ever after.** The verdict is INSERTed against a unique
 * `visit_id`, so the second ruling on one visit does not overwrite the first: it
 * loses at the database and is answered 409 with the standing verdict in the
 * body, which is how the loser learns whose decision applies instead of
 * believing theirs did. See recordFraudVerdict.
 *
 * The reviewer is taken from the token, never from the body. A body that could
 * name the reviewer is a body that lets one manager file a ruling under a
 * colleague's name, and this row is the audit trail.
 *
 * `.strict()` so a client that misspells `verdct` is told, rather than having a
 * silently-ignored field recorded as a different decision than it meant.
 */
fraudRouter.post('/visits/:visitId/verdict', async (req: AuthedRequest, res) => {
  const parsed = verdictBody.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({
      error: `verdict must be one of ${FRAUD_VERDICTS.join(', ')}; note is optional free text`,
      issues: issues(parsed.error),
    });
    return;
  }

  const { visitId } = req.params as { visitId: string };
  const result = await recordFraudVerdict({
    visitId,
    clientId: req.user!.clientId,
    reviewerId: req.user!.userId,
    verdict: parsed.data.verdict,
    // Trimmed to nothing is nothing: see MAX_VERDICT_NOTE_LENGTH above.
    note: parsed.data.note && parsed.data.note.length > 0 ? parsed.data.note : undefined,
  });

  if (!result.created) {
    res.status(409).json({
      error:
        `${result.verdict.reviewer.label} already ruled this visit ` +
        `"${result.verdict.verdict}"; a visit is ruled once`,
      verdict: result.verdict,
    });
    return;
  }
  res.status(201).json(result.verdict);
});

/**
 * GET /fraud/verdicts — the tenant's review ledger, newest first (#392).
 *
 * The standard keyset page: `{ data, nextCursor }`.
 */
fraudRouter.get('/verdicts', async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  res.status(200).json(await listVerdicts({ clientId: req.user!.clientId, limit, cursor }));
});

// GET /fraud/attempts — list check-in attempts, optional outletId/agentId/passed.
fraudRouter.get('/attempts', async (req: AuthedRequest, res) => {
  const { outletId, agentId, passed } = req.query as {
    outletId?: unknown;
    agentId?: unknown;
    passed?: unknown;
  };

  if (outletId !== undefined && typeof outletId !== 'string') {
    res.status(400).json({ error: 'outletId must be a string' });
    return;
  }
  if (agentId !== undefined && typeof agentId !== 'string') {
    res.status(400).json({ error: 'agentId must be a string' });
    return;
  }

  let passedFilter: boolean | undefined;
  if (passed !== undefined) {
    if (passed === 'true') {
      passedFilter = true;
    } else if (passed === 'false') {
      passedFilter = false;
    } else {
      res.status(400).json({ error: "passed must be 'true' or 'false'" });
      return;
    }
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listAttempts({
    clientId: req.user!.clientId,
    outletId,
    agentId,
    passed: passedFilter,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

// GET /fraud/flagged — submitted visits whose stored score is >= minScore
// (default 50), highest risk first, as a standard keyset page:
// { data, nextCursor, unscored, from, to }. See listFlagged (#236).
//
// ── BY DEFAULT THIS IS NOW THE *OPEN* QUEUE (#392) ────────────────────────
//
// A visit a manager has ruled on leaves this list. That is a deliberate change
// to what an unchanged request returns, and the reason is in listFlagged: a
// queue that never shortens is a queue people stop opening, so the flagged
// visit that mattered went unread among the ones already cleared.
//
// `?reviewed=true` is the decided list and `?reviewed=all` is exactly the old
// behaviour, so nothing is unreachable — and every row carries its `verdict`
// (null = nobody has ruled) whichever side you ask for.
fraudRouter.get('/flagged', async (req: AuthedRequest, res) => {
  const { minScore, reviewed } = req.query as { minScore?: unknown; reviewed?: unknown };

  // Rejected rather than coerced, like the window below: a silently ignored
  // `reviewed=yes` would hand back the open queue while the caller believed
  // they were reading the decided one.
  let reviewFilter: FlaggedReviewFilter = 'unreviewed';
  if (reviewed !== undefined) {
    if (reviewed === 'true') {
      reviewFilter = 'reviewed';
    } else if (reviewed === 'all') {
      reviewFilter = 'all';
    } else if (reviewed !== 'false') {
      res.status(400).json({ error: "reviewed must be 'true', 'false' or 'all'" });
      return;
    }
  }

  let min = DEFAULT_MIN_SCORE;
  if (minScore !== undefined) {
    if (typeof minScore !== 'string' || minScore.trim() === '' || !Number.isFinite(Number(minScore))) {
      res.status(400).json({ error: 'minScore must be a number' });
      return;
    }
    min = Number(minScore);
  }

  // The review window. Rejected rather than coerced when malformed: a silently
  // ignored `from` would quietly answer a different question than the one asked.
  const window: { from?: Date; to?: Date } = {};
  for (const key of ['from', 'to'] as const) {
    const raw = (req.query as Record<string, unknown>)[key];
    if (raw === undefined) continue;
    if (typeof raw !== 'string' || Number.isNaN(Date.parse(raw))) {
      res.status(400).json({ error: `${key} must be an ISO-8601 date` });
      return;
    }
    window[key] = new Date(raw);
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listFlagged({
    clientId: req.user!.clientId,
    minScore: min,
    reviewed: reviewFilter,
    ...window,
    limit,
    cursor,
  });
  res.status(200).json(page);
});
