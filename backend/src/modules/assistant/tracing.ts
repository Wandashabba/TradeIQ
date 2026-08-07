import { fetch } from 'undici';
import type { Usage } from './providers/types';

/**
 * Observability for assistant turns.
 *
 * **The seam exists from the first request, not retrofitted** — that is the
 * plan's wording and the reason this file lands with the orchestrator rather
 * than after it. Retrofitting tracing means threading a context object back
 * through every call site once the shape of the code is already settled around
 * its absence.
 *
 * Three properties this has to hold, in order of how badly they bite:
 *
 * 1. **It can never fail a turn.** Every emit is fire-and-forget behind a
 *    bounded queue. Langfuse being slow, down, or misconfigured must be
 *    invisible to a manager asking about stock — observability that can take
 *    the product down is worse than none.
 * 2. **It is a no-op when unconfigured**, which is the state of this repo
 *    today. No keys, no warnings on every request, no partially-initialised
 *    client.
 * 3. **It does not send conversation content by default.** See
 *    {@link TRACE_CONTENT}.
 */

export interface TurnTrace {
  /** Stable within a turn; correlates the events of one conversation turn. */
  traceId: string;
  userId: string;
  clientId: string;
  provider: string;
  model: string;
}

export interface ToolSpan {
  name: string;
  pillar: string;
  ok: boolean;
  durationMs: number;
}

export interface TurnSummary {
  usage: Usage;
  durationMs: number;
  rounds: number;
  tools: ToolSpan[];
  /** Set when the turn ended in an error event. */
  errorCode?: string;
  /**
   * Only populated when {@link TRACE_CONTENT} is on. Absent by default, and
   * absent is the normal state.
   */
  content?: { input: string; output: string };
}

export interface AssistantTracer {
  /** Record a completed turn. Must not throw, and must not be awaited on the hot path. */
  recordTurn(trace: TurnTrace, summary: TurnSummary): void;
  /** Drain the queue. For tests and for a graceful shutdown. */
  flush(): Promise<void>;
}

/**
 * Whether conversation text is sent to the tracing backend.
 *
 * **Off by default, and that is a deliberate decision rather than an
 * oversight.** Transcripts contain outlet names, agent identities and visit
 * notes — PII by any reading — and the retention policy for them is an *open
 * question* in STATUS.md (#251 Q3), alongside an unanswered POPIA
 * data-residency question (Q4).
 *
 * Shipping full prompt-and-completion capture to a third-party cloud before
 * those are answered would quietly decide both. Metrics — which tool was
 * chosen, how long it took, what it cost — are what the Phase 0 gate actually
 * needs, and they carry no transcript.
 *
 * Turn it on per environment once the retention answer exists, not before.
 */
export const TRACE_CONTENT = process.env.LANGFUSE_TRACE_CONTENT === 'true';

/** The tracer used when Langfuse is not configured. Does nothing, says nothing. */
export const noopTracer: AssistantTracer = {
  recordTurn: () => {},
  flush: async () => {},
};

/**
 * How many un-sent events may pile up before we start dropping them.
 *
 * Bounded on purpose. An unbounded queue behind an unreachable endpoint is a
 * memory leak that presents as a slow crash hours later, with nothing in the
 * logs pointing at tracing. Dropping is the correct failure: these are metrics,
 * and a gap in metrics is not an incident.
 */
const MAX_QUEUE = 500;

/** Batched, so a busy minute is a few requests rather than a few hundred. */
const FLUSH_INTERVAL_MS = 5_000;
const MAX_BATCH = 50;

interface IngestionEvent {
  id: string;
  type: string;
  timestamp: string;
  body: Record<string, unknown>;
}

export interface LangfuseOptions {
  publicKey: string;
  secretKey: string;
  baseUrl?: string;
  /** Injected by tests. Defaults to undici's fetch. */
  post?: (url: string, init: { headers: Record<string, string>; body: string }) => Promise<{ ok: boolean; status: number }>;
  /** Injected by tests so no timer runs. */
  autoFlush?: boolean;
}

export class LangfuseTracer implements AssistantTracer {
  private queue: IngestionEvent[] = [];
  private dropped = 0;
  private timer: NodeJS.Timeout | undefined;
  /** The tail of the flush chain. See {@link flush}. */
  private pending: Promise<void> = Promise.resolve();
  private readonly baseUrl: string;
  private readonly auth: string;
  private readonly post: NonNullable<LangfuseOptions['post']>;

  constructor(private readonly options: LangfuseOptions) {
    this.baseUrl = (options.baseUrl ?? 'https://cloud.langfuse.com').replace(/\/+$/, '');
    this.auth = Buffer.from(`${options.publicKey}:${options.secretKey}`).toString('base64');
    this.post =
      options.post ??
      (async (url, init) => {
        const response = await fetch(url, { method: 'POST', ...init });
        return { ok: response.ok, status: response.status };
      });

    if (options.autoFlush !== false) {
      this.timer = setInterval(() => {
        void this.flush();
      }, FLUSH_INTERVAL_MS);
      // Without this the interval holds the event loop open and the process
      // will not exit — which turns a clean shutdown into a hang, and makes
      // every jest run that touches this file time out.
      this.timer.unref?.();
    }
  }

  recordTurn(trace: TurnTrace, summary: TurnSummary): void {
    // Wrapped whole: a bug in our own serialisation must not surface as a
    // failed chat turn. This is the "can never fail a turn" property, and it
    // has to hold for our mistakes as well as for the network's.
    try {
      this.enqueue({
        id: `${trace.traceId}-trace`,
        type: 'trace-create',
        timestamp: new Date().toISOString(),
        body: {
          id: trace.traceId,
          name: 'assistant-turn',
          userId: trace.userId,
          // The tenant, so cost and accuracy can be read per client. It is an
          // opaque id, not a name.
          metadata: { clientId: trace.clientId, provider: trace.provider },
          ...(TRACE_CONTENT && summary.content
            ? { input: summary.content.input, output: summary.content.output }
            : {}),
        },
      });

      this.enqueue({
        id: `${trace.traceId}-gen`,
        type: 'generation-create',
        timestamp: new Date().toISOString(),
        body: {
          id: `${trace.traceId}-gen`,
          traceId: trace.traceId,
          name: 'turn',
          model: trace.model,
          usage: {
            input: summary.usage.inputTokens,
            output: summary.usage.outputTokens,
            total: summary.usage.inputTokens + summary.usage.outputTokens,
            unit: 'TOKENS',
          },
          metadata: {
            // The number the cost gate is stated in. Traced because a cache
            // regression has no functional symptom — it is only ever visible
            // as a number moving.
            cacheReadTokens: summary.usage.cacheReadTokens,
            costCents: summary.usage.costCents,
            rounds: summary.rounds,
            durationMs: summary.durationMs,
            // Tool selection is the Phase 0 accuracy metric, so it is the one
            // thing worth tracing at every turn rather than only in the eval
            // sweep — the sweep measures a fixed question set; this measures
            // what people actually ask.
            tools: summary.tools.map((t) => t.name),
            ...(summary.errorCode ? { errorCode: summary.errorCode } : {}),
          },
          level: summary.errorCode ? 'ERROR' : 'DEFAULT',
        },
      });

      for (const [index, tool] of summary.tools.entries()) {
        this.enqueue({
          id: `${trace.traceId}-tool-${index}`,
          type: 'span-create',
          timestamp: new Date().toISOString(),
          body: {
            id: `${trace.traceId}-tool-${index}`,
            traceId: trace.traceId,
            name: tool.name,
            // No tool RESULT, ever — regardless of TRACE_CONTENT. Results are
            // the untrusted surface and the richest source of PII in the whole
            // system: outlet names, visit notes, agent identities.
            metadata: { pillar: tool.pillar, ok: tool.ok, durationMs: tool.durationMs },
            level: tool.ok ? 'DEFAULT' : 'WARNING',
          },
        });
      }
    } catch (err) {
      console.error('[assistant] failed to record a trace', err);
    }
  }

  private enqueue(event: IngestionEvent): void {
    if (this.queue.length >= MAX_QUEUE) {
      this.dropped += 1;
      // Logged once per batch rather than per drop: a broken endpoint would
      // otherwise produce a log line per turn, burying whatever broke it.
      return;
    }
    this.queue.push(event);
    if (this.queue.length >= MAX_BATCH) void this.flush();
  }

  /**
   * Serialised, so at most one request is in flight.
   *
   * This is what makes {@link MAX_QUEUE} mean anything. An earlier version
   * started a flush directly from `enqueue`, and because the synchronous part
   * of `flush` splices the batch off before its first `await`, the queue drained
   * on every 50th event and never reached the cap — so the bound silently did
   * nothing, and an unreachable endpoint traded an unbounded *queue* for
   * unbounded *concurrent requests*. Worse, not better: sockets instead of
   * memory. Chaining onto `pending` means the queue genuinely accumulates while
   * a request is out, and the cap genuinely bites.
   */
  flush(): Promise<void> {
    this.pending = this.pending.then(() => this.drain());
    return this.pending;
  }

  private async drain(): Promise<void> {
    const dropped = this.dropped;
    this.dropped = 0;
    if (dropped > 0) {
      // Reported once per drain rather than per drop: a dead endpoint would
      // otherwise produce a log line per event, burying whatever broke it.
      console.warn(`[assistant] tracing dropped ${dropped} event(s) — queue full`);
    }

    while (this.queue.length > 0) {
      const batch = this.queue.splice(0, MAX_BATCH);
      try {
        const response = await this.post(`${this.baseUrl}/api/public/ingestion`, {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Basic ${this.auth}`,
          },
          body: JSON.stringify({ batch }),
        });

        if (!response.ok) {
          // Not requeued. A 401 from a wrong key would retry forever and the
          // queue would fill with the same doomed events, which is how tracing
          // starts costing more than it reports.
          console.warn(`[assistant] tracing rejected with ${response.status}`);
          // Stop draining this pass too: if the endpoint is refusing us, the
          // rest of the backlog will be refused identically, and hammering it
          // once per batch is how a bad key becomes a rate-limit problem.
          return;
        }
      } catch (err) {
        console.warn('[assistant] tracing request failed', err);
        return;
      }
    }
  }

  /** Stops the timer. Without this a long-lived process keeps one per tracer. */
  close(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
  }
}

let cached: AssistantTracer | undefined;

/**
 * The tracer for this process.
 *
 * Built once and reused, so the batching window is shared rather than reset per
 * request. Falls back to {@link noopTracer} whenever either key is missing —
 * silently, because "not configured" is the normal state of a development
 * machine and a warning on every request would train people to ignore logs.
 */
export function tracer(): AssistantTracer {
  if (cached) return cached;

  const publicKey = process.env.LANGFUSE_PUBLIC_KEY;
  const secretKey = process.env.LANGFUSE_SECRET_KEY;

  if (!publicKey || !secretKey) {
    cached = noopTracer;
    return cached;
  }

  cached = new LangfuseTracer({
    publicKey,
    secretKey,
    baseUrl: process.env.LANGFUSE_BASEURL,
  });
  return cached;
}

/** Test seam — lets a suite reset the memoised tracer. */
export function resetTracer(): void {
  cached = undefined;
}
