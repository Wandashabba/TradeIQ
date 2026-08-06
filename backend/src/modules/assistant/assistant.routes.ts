import { Router, type Response } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../../middleware/auth';
import {
  assistantTenantRateLimiter,
  assistantUserRateLimiter,
} from '../../middleware/rateLimit';
import { requireAssistantEnabled } from './featureFlag';
import { runTurn, type WireEvent } from './orchestrator';
import { providerFor } from './providers';
import type { Message } from './providers/types';
import { buildTools } from './tools';

export const assistantRouter = Router();

/**
 * Bounded so a client cannot push an unbounded history back at us and turn one
 * request into an arbitrarily expensive provider call. History is replayed on
 * every turn, so its size is a direct multiplier on cost.
 */
const MAX_HISTORY_MESSAGES = 40;
const MAX_MESSAGE_CHARS = 4_000;

const chatBody = z.object({
  message: z.string().trim().min(1).max(MAX_MESSAGE_CHARS),
  history: z
    .array(
      z.object({
        role: z.enum(['user', 'assistant']),
        content: z.string().max(MAX_MESSAGE_CHARS),
      }),
    )
    .max(MAX_HISTORY_MESSAGES)
    .optional(),
});

/**
 * Write one SSE frame.
 *
 * The event name is on its own line and the payload is always JSON, so the
 * client can `JSON.parse` unconditionally. **Unknown event types must be
 * ignored by the client rather than erroring** — that is what lets the server
 * add events without a lockstep app release, and it is a contract the app has
 * to hold up its end of.
 */
function writeEvent(res: Response, frame: WireEvent): void {
  res.write(`event: ${frame.event}\ndata: ${JSON.stringify(frame.data)}\n\n`);
}

/**
 * `POST /assistant/chat` — one turn, streamed.
 *
 * Middleware order is load-bearing and is asserted by the route test:
 *
 * 1. `requireAuth` — everything below reads `req.user`.
 * 2. `requireAssistantEnabled` — 404s a tenant outside the rollout. Must come
 *    after auth, so an unauthenticated request fails as unauthenticated rather
 *    than leaking whether a flag exists.
 * 3. The two rate limiters — keyed on the JWT, so they need `req.user` too.
 *    Per-user bounds one manager; per-tenant bounds the bill.
 *
 * POST rather than GET, despite SSE conventionally being a GET: the request
 * carries a message and history that do not belong in a URL, where they would
 * land in access logs and browser history. `EventSource` cannot POST, so the
 * client reads the stream with a fetch reader — which it must do anyway to send
 * an Authorization header.
 */
assistantRouter.post(
  '/chat',
  requireAuth,
  requireAssistantEnabled,
  assistantUserRateLimiter,
  assistantTenantRateLimiter,
  async (req: AuthedRequest, res: Response) => {
    const user = req.user!;

    const parsed = chatBody.safeParse(req.body);
    if (!parsed.success) {
      // Before the stream opens, so this is an ordinary JSON error rather than
      // an SSE error frame. Once headers are flushed the status is fixed at 200
      // and every failure has to travel as an event.
      res.status(400).json({
        error: 'Invalid request',
        issues: parsed.error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`),
      });
      return;
    }

    const controller = new AbortController();
    // A client that navigates away must not leave a paid provider call running.
    // Note the ceiling this does NOT provide: aborting stops us reading, and on
    // Gemini it does not stop generation being billed. The account-level cap
    // lives in the provider console and is tracked separately.
    res.on('close', () => controller.abort());

    res.status(200).set({
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      // Nginx buffers proxied responses by default, which holds every token
      // until the turn ends — the stream still "works" and feels broken.
      'X-Accel-Buffering': 'no',
    });
    res.flushHeaders?.();

    // Identity is bound once, here. Nothing below takes a tenant argument.
    const now = new Date();
    const tools = buildTools({ user, now });

    const messages: Message[] = [
      ...(parsed.data.history ?? []).map((m) => ({ role: m.role, content: m.content })),
      { role: 'user' as const, content: parsed.data.message },
    ];

    try {
      for await (const frame of runTurn({
        provider: providerFor(),
        tools,
        messages,
        signal: controller.signal,
      })) {
        writeEvent(res, frame);
      }
    } catch (err) {
      // The orchestrator is written to yield errors rather than throw, so
      // reaching here is a bug in it — but a bug must not leave the client on
      // an open socket with no explanation.
      console.error('[assistant] turn threw out of the orchestrator', err);
      if (!res.writableEnded) {
        writeEvent(res, {
          event: 'error',
          data: { code: 'internal', message: 'Something went wrong. Please try again.' },
        });
      }
    } finally {
      // Not `next(err)`: the error handler would try to send JSON onto a
      // response whose headers are long gone, and express would log a
      // "headers already sent" that hides the real failure.
      if (!res.writableEnded) res.end();
    }
  },
);
