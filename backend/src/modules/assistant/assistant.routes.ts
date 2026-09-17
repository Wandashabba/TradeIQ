import { randomUUID } from 'crypto';
import { Router, type Response } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../../middleware/auth';
import {
  assistantTenantRateLimiter,
  assistantUserRateLimiter,
} from '../../middleware/rateLimit';
import {
  isAssistantExternalContextEnabled,
  isAssistantWebSearchEnabled,
  requireAssistantEnabled,
} from './featureFlag';
import { runTurn, type WireEvent } from './orchestrator';
import { providerFor } from './providers';
import type { Message } from './providers/types';
import { buildTools, type ToolContext } from './tools';
import {
  ArtifactNotFoundError,
  InvalidParamsError,
  ToolUnavailableError,
  artifactManifest,
  createArtifact,
  readArtifact,
  refineArtifact,
  takeParamsChanges,
  undoArtifact,
} from './artifacts.service';
import { paramsChangeNote } from './paramsNote';

export const assistantRouter = Router();

/**
 * Bounded so a client cannot push an unbounded history back at us and turn one
 * request into an arbitrarily expensive provider call. History is replayed on
 * every turn, so its size is a direct multiplier on cost.
 */
const MAX_HISTORY_MESSAGES = 40;
const MAX_MESSAGE_CHARS = 4_000;

const chatBody = z.object({
  /**
   * Which conversation this turn belongs to, so artifacts it produces can be
   * found again. Optional: the first turn has no id yet, so the server mints
   * one and announces it on the stream. A client that ignores the announcement
   * still works — it just gets a fresh conversation each turn, which is exactly
   * today's behaviour.
   *
   * Not trusted as a lookup key on its own. Every artifact query is additionally
   * scoped by the caller's user and tenant, so guessing someone else's
   * conversation id reveals nothing.
   */
  conversationId: z.string().uuid().optional(),
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
    // The tenant's switch for outside context. Off leaves the calendar, weather
    // and economy tools out of the roster, so they are never declared.
    const externalContext = await isAssistantExternalContextEnabled(user.clientId);
    const tools = buildTools({ user, now, externalContext });
    const owner = { userId: user.userId, clientId: user.clientId };
    const conversationId = parsed.data.conversationId ?? randomUUID();

    // Announced before anything can fail, so a client always learns the id it
    // needs to send back — including on a turn that errors halfway.
    writeEvent(res, { event: 'conversation', data: { id: conversationId } });

    // What is already on screen, so the model refines an existing view instead
    // of emitting a near-duplicate beside it.
    //
    // Deliberately NOT part of the system prompt. The cached prefix is
    // `[tools][system]` and caching is a prefix match — folding a list that
    // changes whenever an artifact is created into that prefix would miss the
    // cache on most turns and, with explicit caching, bill for a new entry each
    // time. Volatile context belongs after the prefix, with the history.
    let manifestNote = '';
    try {
      const live = await artifactManifest(conversationId, owner);
      if (live.length > 0) {
        manifestNote =
          'Views already open (refine one by name rather than creating another):\n' +
          live.map((a) => `- ${a.id} — ${a.type} ${JSON.stringify(a.params)}`).join('\n') +
          '\n\n';
      }
    } catch (err) {
      // Context, not correctness. A turn without the manifest may duplicate a
      // card; a turn that 500s because a read failed helps nobody.
      console.error('[assistant] could not load artifact manifest', err);
    }

    // …and what the user changed with their own hands since the last answer.
    //
    // The manifest says what is open; this says what *moved*, and that the user
    // moved it. Without it, "now break that down by territory" is answered
    // against the params the model last saw rather than the ones on screen —
    // confidently, which is the worst way to be wrong. Same placement rule as
    // the manifest, for the same cache reason.
    let changeNote = '';
    try {
      changeNote = paramsChangeNote(await takeParamsChanges(conversationId, owner));
    } catch (err) {
      console.error('[assistant] could not load artifact params changes', err);
    }

    const messages: Message[] = [
      ...(parsed.data.history ?? []).map((m) => ({ role: m.role, content: m.content })),
      // Prepended to the user's own turn rather than sent as its own message:
      // Gemini rejects two adjacent turns of the same role, and a synthetic
      // `user` turn immediately before the real one is exactly that.
      { role: 'user' as const, content: manifestNote + changeNote + parsed.data.message },
    ];

    // The tenant's switch for live web search. Off means the search tool is not
    // declared at all — absence, not an instruction the model could ignore.
    const webSearch = await isAssistantWebSearchEnabled(user.clientId);

    try {
      for await (const frame of runTurn({
        provider: providerFor(),
        tools,
        messages,
        signal: controller.signal,
        webSearch,
        // Identity for tracing only — it never reaches a tool, which closes
        // over `req.user` instead. `randomUUID` rather than a counter so ids
        // stay unique across processes and restarts.
        trace: {
          traceId: randomUUID(),
          userId: user.userId,
          clientId: user.clientId,
        },
        // Returns null rather than throwing: a chart the user can see but not
        // refine beats losing the turn to a write failure.
        saveArtifact: async ({ type, toolName, params }) => {
          try {
            const saved = await createArtifact({
              owner,
              conversationId,
              type,
              toolName,
              params,
            });
            return saved.id;
          } catch (err) {
            console.error('[assistant] could not persist artifact', err);
            return null;
          }
        },
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

/**
 * Artifact routes — steering a view by its own controls rather than by talking.
 *
 * **None of these call the model.** A filter change is a re-query: routing it
 * through the orchestrator would spend a paid turn, add latency no control can
 * hide, and hand the model a chance to overrule a choice the user already made.
 * That is also why the rate limiters below are the *user* one only — these are
 * database reads bounded by the tool's own scoping, not spend against a vendor.
 *
 * `requireAssistantEnabled` still applies: an artifact is part of the assistant,
 * and a tenant switched off must not keep a back door open to its endpoints.
 */
function artifactContext(req: AuthedRequest): ToolContext {
  // A fresh roster per request, bound to whoever is asking now. See
  // artifacts.service.ts — this is the entire authorisation story.
  return { user: req.user!, now: new Date() };
}

/**
 * Map a service error onto a status.
 *
 * `ArtifactNotFoundError` is 404 for both "no such id" and "not yours", which
 * is deliberate — see the error's own comment.
 */
function sendArtifactError(res: Response, err: unknown): void {
  if (err instanceof ArtifactNotFoundError) {
    res.status(404).json({ error: err.message });
    return;
  }
  if (err instanceof ToolUnavailableError) {
    res.status(403).json({ error: err.message });
    return;
  }
  if (err instanceof InvalidParamsError) {
    res.status(400).json({ error: err.message, issues: err.issues });
    return;
  }
  console.error('[assistant] artifact request failed', err);
  res.status(500).json({ error: 'Something went wrong. Please try again.' });
}

assistantRouter.get(
  '/artifacts/:id',
  requireAuth,
  requireAssistantEnabled,
  assistantUserRateLimiter,
  async (req: AuthedRequest, res: Response) => {
    try {
      const { id } = req.params as { id: string };
      res.json(await readArtifact(id, artifactContext(req)));
    } catch (err) {
      sendArtifactError(res, err);
    }
  },
);

assistantRouter.post(
  '/artifacts/:id/refine',
  requireAuth,
  requireAssistantEnabled,
  assistantUserRateLimiter,
  async (req: AuthedRequest, res: Response) => {
    // No schema here on purpose. The tool's own `args` schema validates this
    // body, so there is exactly one contract the model and the UI both write
    // through — a second one here would be the one that drifts.
    const params = (req.body as { params?: unknown } | undefined)?.params;
    try {
      const { id } = req.params as { id: string };
      res.json(await refineArtifact(id, params, artifactContext(req)));
    } catch (err) {
      sendArtifactError(res, err);
    }
  },
);

assistantRouter.post(
  '/artifacts/:id/undo',
  requireAuth,
  requireAssistantEnabled,
  assistantUserRateLimiter,
  async (req: AuthedRequest, res: Response) => {
    try {
      const { id } = req.params as { id: string };
      res.json(await undoArtifact(id, artifactContext(req)));
    } catch (err) {
      sendArtifactError(res, err);
    }
  },
);
