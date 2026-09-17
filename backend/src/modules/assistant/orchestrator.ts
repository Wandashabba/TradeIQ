import { validateFigure, type FigureArtifact } from './figures';
import { SYSTEM_PROMPT } from './prompt';
import type { LlmProvider, Message, RawWebSource, ToolCallRecord, Usage } from './providers/types';
import { quarantineFreeText } from './quarantine';
import { pillarOf, type ToolName } from './roster';
import { neutraliseAnswerMarkup, sanitizeToolResult } from './sanitize';
import { shrinkToolResult } from './shrink';
import { normaliseSources, type WebSource } from './sources';
import { tracer as processTracer, type AssistantTracer, type ToolSpan } from './tracing';
import { ToolFacingError, type AnyAssistantTool, type ToolArgs } from './types';
import { validateViewSpec, type ViewSpec } from './viewspec';

/**
 * The turn loop.
 *
 * **Deliberately logic-free.** The named failure mode of building this by hand
 * is that the loop accretes branches until it is an unmaintainable while-loop,
 * and that is the thing that would re-open the LangGraph decision. So the rules
 * here are: call the model, run whatever tools it asked for, hand the results
 * back, repeat until it stops asking. No business logic, no per-tool special
 * cases, no "if the tool is X then Y". If a branch on a specific tool name ever
 * appears in this file, it belongs in the tool.
 *
 * **Tripwire — re-open the orchestration decision if any of these become true:**
 * durable multi-day resume is required; the loop needs more than three
 * branches; or a turn needs to fan out to more than one orchestrator. Until
 * then the SDK-loop shape is the right one and a graph framework buys nothing.
 */

/**
 * How many times the model may call tools before we stop it.
 *
 * Every round is a paid request, so an unbounded loop is a spend incident, not
 * a hang. Ten leaves room for a real investigation — a headline figure, the
 * territory behind it, the outlets behind that, and a comparison — which four
 * cut off halfway. What makes ten safe is not the number but the guards around
 * it: an identical repeated call ends the loop at once, and the time and cost
 * budgets below end it whichever limit is reached first.
 */
export const MAX_TOOL_ROUNDS = 10;

/**
 * How many of one round's tool calls run at once.
 *
 * The model often asks for several independent figures in one round (stock and
 * share of shelf, this month and last). Running them one after another made a
 * round as slow as the sum of its tools; four at a time keeps it near the
 * slowest one without letting a single turn take a large share of the database
 * pool that is also serving the console. Results are still emitted in the order
 * the model asked for them.
 */
export const MAX_PARALLEL_TOOLS = 4;

/**
 * Soft per-turn budgets, checked between rounds.
 *
 * Neither existed while a turn was capped at four rounds; at ten, a slow or
 * expensive turn needs its own ceiling. Reaching one does not cut the turn off:
 * the next round runs with tools withdrawn, so the model still answers from
 * what it retrieved, and the user is told the answer may be incomplete. Both
 * are overridable per call.
 */
export const TURN_TIME_BUDGET_MS = 120_000;
export const TURN_COST_BUDGET_CENTS = 100;

/**
 * What the user sees appended to an answer the tool budget cut short. Plain
 * text: it follows whatever the model wrote, `followups` block included.
 */
export const BUDGET_NOTICE =
  '\n\nI reached the limit on how many lookups I can make for one question, so this answer ' +
  'may be incomplete. Ask a narrower follow-up to go further.';

/** What the model is told on the last round, inside the final tool results. */
const FINAL_ROUND_NOTE: Record<FinalReason, string> = {
  rounds:
    'Tool budget reached: no more tool calls are possible in this turn. Answer now from the ' +
    'results you already have, and say plainly if anything the user asked is not covered.',
  time:
    'Time budget reached: no more tool calls are possible in this turn. Answer now from the ' +
    'results you already have, and say plainly if anything the user asked is not covered.',
  cost:
    'Cost budget reached: no more tool calls are possible in this turn. Answer now from the ' +
    'results you already have, and say plainly if anything the user asked is not covered.',
  repeat:
    'You repeated a tool call with identical arguments; its result is already above. No more ' +
    'tool calls are possible in this turn. Answer now from the results you already have.',
};

type FinalReason = 'rounds' | 'time' | 'cost' | 'repeat';

/** The working-step name a vendor-run web search is announced under. */
export const WEB_SEARCH_STEP = 'webSearch';

/** What the route writes to the wire. Mirrors the SSE table in the design spec. */
export type WireEvent =
  /**
   * Which conversation this turn belongs to — sent first, and by the route
   * rather than the orchestrator, which has no notion of a conversation.
   * The client echoes it on the next turn so artifacts stay findable.
   */
  | { event: 'conversation'; data: { id: string } }
  | { event: 'token'; data: { text: string } }
  | { event: 'tool_start'; data: { name: string; pillar: string } }
  | { event: 'tool_end'; data: { name: string; ok: boolean } }
  | { event: 'artifact'; data: { id: string; type: string; params: unknown; data: unknown } }
  /**
   * Web pages the answer cited, validated by `sources.ts`. At most once per
   * turn, after the last token and before `usage`. Clients that predate it
   * ignore it, as they must any unknown event.
   */
  | { event: 'sources'; data: { sources: WebSource[] } }
  | { event: 'usage'; data: Usage }
  | { event: 'error'; data: { code: string; message: string } }
  | { event: 'done'; data: Record<string, never> };

export interface OrchestratorInput {
  provider: LlmProvider;
  tools: readonly AnyAssistantTool[];
  /** Prior turns. The current user message is the last entry. */
  messages: readonly Message[];
  signal: AbortSignal;
  /** Overridden in tests. */
  system?: string;
  maxToolRounds?: number;
  /** Overrides {@link TURN_TIME_BUDGET_MS} and {@link TURN_COST_BUDGET_CENTS}. */
  budget?: { maxMs?: number; maxCostCents?: number };
  /**
   * Offer the provider's live web search this turn. Off unless the caller says
   * so — the route reads it from the tenant's switch — so every existing caller,
   * including the eval sweep, keeps scoring internal tool choice alone.
   */
  webSearch?: boolean;
  /**
   * Who is asking, for tracing only.
   *
   * Optional so the orchestrator stays testable without inventing a user, and
   * so a caller that has no tracing story still works. When absent, nothing is
   * traced — rather than a trace attributed to nobody, which is worse than no
   * trace because it pollutes the per-tenant cost figures.
   */
  trace?: { traceId: string; userId: string; clientId: string };
  /** Injected by tests. Defaults to the process tracer. */
  tracer?: AssistantTracer;
  /**
   * Persist an artifact this turn produced and return the id to publish.
   *
   * A callback rather than a database import: the orchestrator has no tenant,
   * no request and no Prisma client, and giving it one would make every test
   * that runs a turn need a database. Callers that omit it — every unit test —
   * keep the turn-local ids, which is why adding persistence changed no
   * existing assertion.
   *
   * Returning `null` means "could not persist"; the turn falls back to a
   * turn-local id and carries on. A chart the user can see but not refine is a
   * degraded artifact; a failed turn is no artifact at all.
   */
  saveArtifact?: (input: {
    type: string;
    toolName: string;
    params: ToolArgs;
  }) => Promise<string | null>;
}

function zeroUsage(): Usage {
  return { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, costCents: 0 };
}

function addUsage(a: Usage, b: Usage): Usage {
  return {
    inputTokens: a.inputTokens + b.inputTokens,
    outputTokens: a.outputTokens + b.outputTokens,
    cacheReadTokens: a.cacheReadTokens + b.cacheReadTokens,
    costCents: Math.round((a.costCents + b.costCents) * 10_000) / 10_000,
  };
}

export async function* runTurn(input: OrchestratorInput): AsyncGenerator<WireEvent> {
  const { provider, tools, signal } = input;
  const maxRounds = input.maxToolRounds ?? MAX_TOOL_ROUNDS;
  const byName = new Map(tools.map((tool) => [tool.name, tool]));

  // The prompt prefix is `[tools][system]` and both are frozen. Everything
  // volatile — history, the user's message, tool results — accumulates after
  // it. Caching is a prefix match, so this ordering is load-bearing rather
  // than stylistic.
  const system = input.system ?? SYSTEM_PROMPT;
  const messages: Message[] = [...input.messages];

  // Summed across every round, not taken from the last one. A turn that called
  // three tools made four paid requests, and reporting only the final one
  // under-reports the expensive turns by the most.
  let totalUsage = zeroUsage();
  let artifactIndex = 0;
  // Collected across rounds and published once, at the end, deduplicated.
  const rawSources: RawWebSource[] = [];

  // Tracing state. Collected as the turn runs and emitted once at the end —
  // a trace per event would multiply the request count by the number of tools
  // for no extra signal.
  const startedAt = Date.now();
  const toolSpans: ToolSpan[] = [];
  let roundsUsed = 0;
  let errorCode: string | undefined;

  const emitTrace = (): void => {
    const trace = input.trace;
    if (!trace) return;
    // Guarded here as well as inside the tracer. `AssistantTracer` documents
    // that `recordTurn` must not throw, but a contract every implementation is
    // trusted to honour is one that breaks on the first implementation that
    // does not — and the cost of being wrong is a manager's question dying
    // because a metrics client had a bad day. Observability is never worth a
    // turn.
    try {
      (input.tracer ?? processTracer()).recordTurn(
        {
          ...trace,
          // Read at emit time, not at the start: a fallback wrapper reports
          // whichever vendor actually answered.
          provider: provider.name,
          model: provider.models.orchestrator,
          ...(provider.fallbackFrom ? { fallbackFrom: provider.fallbackFrom } : {}),
        },
        {
          usage: totalUsage,
          durationMs: Date.now() - startedAt,
          rounds: roundsUsed,
          tools: toolSpans,
          ...(errorCode ? { errorCode } : {}),
        },
      );
    } catch (err) {
      console.error('[assistant] tracer threw while recording a turn', err);
    }
  };

  // Why the next round is the last, once something has decided it is. Set by
  // the round budget, the time and cost budgets, or the repeated-call guard.
  let finalReason: FinalReason | null = null;
  // Every call already made this turn, by name and canonical args. A model
  // asking for the same thing twice is looping, not investigating.
  const executed = new Set<string>();
  const maxMs = input.budget?.maxMs ?? TURN_TIME_BUDGET_MS;
  const maxCostCents = input.budget?.maxCostCents ?? TURN_COST_BUDGET_CENTS;

  for (let round = 0; round <= maxRounds; round += 1) {
    roundsUsed = round + 1;
    if (signal.aborted) {
      errorCode = 'aborted';
      // An abandoned turn is traced too. It still cost whatever it had already
      // spent, and a cost dashboard that only sees completed turns
      // under-reports exactly the ones worth investigating.
      emitTrace();
      yield { event: 'error', data: { code: 'aborted', message: 'Request cancelled.' } };
      return;
    }

    // On the final permitted round, tools are withdrawn rather than the turn
    // being cut off. The model still gets to answer from what it already
    // retrieved, which is a useful answer; stopping dead would waste every
    // paid call the turn had already made.
    const lastRound = round === maxRounds || finalReason !== null;
    const calls: ToolCallRecord[] = [];
    let assistantText = '';
    let replay: unknown;
    let failed = false;

    for await (const event of provider.runTurn(
      {
        system,
        tools,
        messages,
        ...(lastRound ? { toolChoice: 'none' as const } : {}),
        ...(input.webSearch ? { webSearch: true } : {}),
      },
      signal,
    )) {
      switch (event.type) {
        case 'token':
          assistantText += event.text;
          yield { event: 'token', data: { text: event.text } };
          break;

        case 'tool_call':
          calls.push({
            id: event.id,
            name: event.name,
            args: event.args,
            // Opaque here. It only has to survive the round trip back into
            // history — see ToolCallRecord.providerSignature.
            ...(event.signature ? { providerSignature: event.signature } : {}),
          });
          break;

        case 'usage':
          totalUsage = addUsage(totalUsage, event.usage);
          break;

        // The vendor ran its own search. It is shown as a working step like
        // any tool, but there is nothing for us to execute.
        case 'web_search':
          yield { event: 'tool_start', data: { name: WEB_SEARCH_STEP, pillar: 'web' } };
          yield { event: 'tool_end', data: { name: WEB_SEARCH_STEP, ok: true } };
          toolSpans.push({ name: WEB_SEARCH_STEP, pillar: 'web', ok: true, durationMs: 0 });
          break;

        case 'sources':
          rawSources.push(...event.sources);
          break;

        // Opaque. Only carried back into history — see TextMessage.providerReplay.
        case 'replay':
          replay = event.content;
          break;

        case 'error':
          // The adapter has already made this message user-safe.
          errorCode = event.code;
          yield { event: 'error', data: { code: event.code, message: event.message } };
          failed = true;
          break;

        case 'done':
          break;
      }
      if (failed) break;
    }

    if (failed) {
      emitTrace();
      return;
    }

    // No tool calls means the model has answered. This is the only exit that
    // is not an error or a bound — everything else is a failure of some kind.
    //
    // A turn a budget cut short says so after the answer, so the user is not
    // left to assume the reading is complete. A repeated call is not a budget:
    // the model already had what it asked for twice.
    if (calls.length === 0 || lastRound) {
      if (finalReason !== null && finalReason !== 'repeat') {
        yield { event: 'token', data: { text: BUDGET_NOTICE } };
      } else if (calls.length > 0) {
        // The provider ignored `toolChoice: 'none'`. Its calls are not run —
        // that would spend past every bound — and the user hears why.
        yield { event: 'token', data: { text: BUDGET_NOTICE } };
      }
      emitTrace();
      const sources = normaliseSources(rawSources, new Date());
      if (sources.length > 0) yield { event: 'sources', data: { sources } };
      yield { event: 'usage', data: totalUsage };
      yield { event: 'done', data: {} };
      return;
    }

    messages.push({
      role: 'assistant',
      content: assistantText,
      toolCalls: calls,
      ...(replay !== undefined ? { providerReplay: { provider: provider.name, content: replay } } : {}),
    });

    // Parse and classify every call up front; the ones worth running start
    // together, bounded, and are emitted below in the order the model asked.
    const planned = calls.map((call) => planCall(call, byName, executed));
    const running = startBounded(planned, MAX_PARALLEL_TOOLS, (plan) =>
      plan.kind === 'run' ? runPlannedTool(plan, { provider, signal }) : Promise.resolve(null),
    );
    // Awaited in order below, but a turn that returns early (abort) must not
    // leave a rejected promise unobserved.
    for (const pending of running) pending.catch(() => undefined);

    let repeated = false;

    for (const [index, call] of calls.entries()) {
      if (signal.aborted) {
        errorCode = 'aborted';
        emitTrace();
        yield { event: 'error', data: { code: 'aborted', message: 'Request cancelled.' } };
        return;
      }

      const plan = planned[index];

      // A tool the caller's roster does not carry. Not an error the user should
      // see — it is the security boundary doing its job, and the model recovers
      // better from "that is unavailable" than from a dead turn.
      if (plan.kind === 'unavailable') {
        yield { event: 'tool_start', data: { name: call.name, pillar: 'unknown' } };
        yield { event: 'tool_end', data: { name: call.name, ok: false } };
        messages.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          ok: false,
          content: 'This tool is not available to you.',
        });
        continue;
      }

      // The loop guard. Not run and not shown: nothing new happens, and the
      // model is told why before its final, tool-less round.
      if (plan.kind === 'repeat') {
        repeated = true;
        messages.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          ok: false,
          content:
            'You already called this tool with these exact arguments in this turn; its result ' +
            'is above. Do not call it again.',
        });
        continue;
      }

      const { tool } = plan;
      yield { event: 'tool_start', data: { name: tool.name, pillar: tool.pillar } };

      if (plan.kind === 'invalid') {
        toolSpans.push({ name: tool.name, pillar: tool.pillar, ok: false, durationMs: 0 });
        yield { event: 'tool_end', data: { name: tool.name, ok: false } };
        messages.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          ok: false,
          // Naming the bad field lets the model retry correctly instead of
          // guessing, which is the difference between one wasted round and four.
          content: plan.content,
        });
        continue;
      }

      const outcome = (await running[index])!;
      toolSpans.push({
        name: tool.name,
        pillar: tool.pillar,
        ok: outcome.ok,
        durationMs: outcome.durationMs,
      });

      if (!outcome.ok) {
        yield { event: 'tool_end', data: { name: tool.name, ok: false } };
        messages.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          ok: false,
          content: outcome.content,
        });
        continue;
      }

      yield { event: 'tool_end', data: { name: tool.name, ok: true } };
      const { result } = outcome;
      // Outside data a tool cites (retailer pages behind collected prices) joins
      // the web sources, and goes through the same validation at the end.
      rawSources.push(...safeToolSources(tool, plan.args, result));

      // The artifact carries the RAW result, and the model gets the sanitized
      // one. They are different on purpose: the client renders through a
      // validated spec into widgets that draw data, so fencing would put
      // "«untrusted» …" inside a chart label. The model's copy is the one that
      // needs spotlighting, because the model is the thing an injection targets.
      const spec = safeViewSpec(tool, plan.args, result);
      if (spec) {
        // A persisted id is what makes the card refinable after the turn ends:
        // `/artifacts/:id/refine` has to find a row. Persistence failing must
        // not cost the user the chart, so the turn-local id remains the
        // fallback — deterministic within a turn, so a repeated call patches
        // the card in place instead of appending a near-identical one.
        let id = `${tool.name}-${artifactIndex}`;
        if (input.saveArtifact) {
          try {
            const persisted = await input.saveArtifact({
              type: spec.type,
              toolName: tool.name,
              // The tool's PARSED args, not the model's raw ones. Refine
              // re-validates through the same schema, so storing anything
              // Zod had not already accepted would put a row in the table
              // that can never be re-run.
              params: plan.args,
            });
            if (persisted) id = persisted;
          } catch (err) {
            console.error('[assistant] could not persist artifact', err);
          }
        }

        yield {
          event: 'artifact',
          data: { id, type: spec.type, params: spec.params, data: result },
        };
        artifactIndex += 1;
      }

      // Tiles and bars, after the tool's own view so the first artifact a
      // client sees for a tool is unchanged. Not persisted: they are a
      // rendering of this turn's result rather than something `refine` can
      // re-run, so their ids stay turn-local — and are namespaced by type so
      // they can never patch the view artifact above.
      for (const figure of await safeFigures(tool, plan.args, result)) {
        yield {
          event: 'artifact',
          data: {
            id: `${tool.name}-${figure.type}-${artifactIndex}`,
            type: figure.type,
            params: {},
            data: figure.data,
          },
        };
        artifactIndex += 1;
      }

      messages.push({
        role: 'tool',
        callId: call.id,
        name: call.name,
        ok: true,
        content: outcome.content,
      });
    }

    // Decide whether the next round is the last, and if so tell the model now,
    // inside this round's final tool result — the only place a note can go
    // without a synthetic user turn, which Gemini rejects next to a tool
    // response, or a change to the cached system prompt.
    finalReason = repeated
      ? 'repeat'
      : round + 1 >= maxRounds
        ? 'rounds'
        : Date.now() - startedAt >= maxMs
          ? 'time'
          : totalUsage.costCents >= maxCostCents
            ? 'cost'
            : null;
    if (finalReason !== null) {
      const last = messages[messages.length - 1];
      if (last.role === 'tool') {
        messages[messages.length - 1] = {
          ...last,
          content: JSON.stringify({ turnNote: FINAL_ROUND_NOTE[finalReason], result: parseOrText(last.content) }),
        };
      }
    }
  }

  // Unreachable: the final round runs with tools withdrawn, and exits through
  // the branch above whether or not the model obeyed. Kept because
  // "unreachable" is a claim about code that changes.
  emitTrace();
  yield { event: 'usage', data: totalUsage };
  yield { event: 'done', data: {} };
}

/** A tool result's content back as data where it is JSON, so a wrapper stays valid JSON. */
function parseOrText(content: string): unknown {
  try {
    return JSON.parse(content);
  } catch {
    return content;
  }
}

/** Object keys sorted at every depth, so `{a, b}` and `{b, a}` are the same call. */
function canonicalJson(value: unknown): string {
  const sort = (v: unknown): unknown => {
    if (Array.isArray(v)) return v.map(sort);
    if (v !== null && typeof v === 'object') {
      return Object.fromEntries(
        Object.keys(v as Record<string, unknown>)
          .sort()
          .map((k) => [k, sort((v as Record<string, unknown>)[k])]),
      );
    }
    return v;
  };
  return JSON.stringify(sort(value)) ?? 'undefined';
}

type PlannedCall =
  | { kind: 'unavailable' }
  | { kind: 'repeat' }
  | { kind: 'invalid'; tool: AnyAssistantTool; content: string }
  | { kind: 'run'; tool: AnyAssistantTool; args: ToolArgs };

/**
 * What to do with one call, decided before anything runs.
 *
 * The repeat check keys on the model's raw args, canonicalised, and counts a
 * call as made once it is planned — so the same call twice in one round is a
 * repeat too, and runs once.
 */
function planCall(
  call: ToolCallRecord,
  byName: Map<string, AnyAssistantTool>,
  executed: Set<string>,
): PlannedCall {
  const tool = byName.get(call.name);
  if (!tool) return { kind: 'unavailable' };

  const signature = `${call.name}:${canonicalJson(call.args ?? {})}`;
  if (executed.has(signature)) return { kind: 'repeat' };
  executed.add(signature);

  const parsed = tool.args.safeParse(call.args);
  if (!parsed.success) {
    return {
      kind: 'invalid',
      tool,
      content: `Invalid arguments: ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '<root>'} ${i.message}`)
        .join('; ')}`,
    };
  }
  return { kind: 'run', tool, args: parsed.data as ToolArgs };
}

type ToolOutcome =
  | { ok: true; result: unknown; content: string; durationMs: number }
  | { ok: false; content: string; durationMs: number };

/**
 * Run one tool and prepare the model's copy of its result.
 *
 * Everything that can run alongside another tool's call lives here: the query
 * itself, and the quarantine and sanitising of its free text. What must follow
 * the model's order — events, artifacts, history — stays in the loop.
 */
async function runPlannedTool(
  plan: Extract<PlannedCall, { kind: 'run' }>,
  context: { provider: LlmProvider; signal: AbortSignal },
): Promise<ToolOutcome> {
  const { tool } = plan;
  const startedAt = Date.now();

  let result: unknown;
  try {
    result = await tool.run(plan.args);
  } catch (err) {
    // A tool that throws is ordinary — a stale id, an empty period.
    //
    // The message is ours, never the exception's: a Prisma error carries
    // table and column names straight into the model's context. The one
    // exception is `ToolFacingError`, which a tool throws to say "I wrote
    // this string for the model deliberately" — that is how a tool asks a
    // clarifying question ("which Sipho?") instead of failing opaquely.
    //
    // Neutralised even so: a clarifying message can quote agent display
    // names, and those are typed by the people the injection defence is
    // about. See `neutraliseAnswerMarkup`.
    const content =
      err instanceof ToolFacingError
        ? neutraliseAnswerMarkup(err.message)
        : 'That lookup failed. Tell the user you could not retrieve it.';

    // Logged at different levels because they are different events: an
    // ambiguous name is the system working, and a Prisma failure is not.
    if (err instanceof ToolFacingError) {
      console.warn(`[assistant] tool ${tool.name} declined: ${err.message}`);
    } else {
      console.error(`[assistant] tool ${tool.name} failed`, err);
    }
    return { ok: false, content, durationMs: Date.now() - startedAt };
  }
  const durationMs = Date.now() - startedAt;

  const quarantined = await quarantineFreeText(result, context);
  const { value } = sanitizeToolResult(quarantined.value);
  return { ok: true, result, content: shrinkToolResult(value), durationMs };
}

/**
 * Start `run` over every item with at most `limit` in flight, returning one
 * promise per item in input order — so the caller can await them in order while
 * they execute concurrently.
 */
function startBounded<T, R>(items: readonly T[], limit: number, run: (item: T) => Promise<R>): Promise<R>[] {
  let active = 0;
  const waiting: (() => void)[] = [];
  const acquire = (): Promise<void> => {
    if (active < limit) {
      active += 1;
      return Promise.resolve();
    }
    return new Promise((resolve) => waiting.push(resolve));
  };
  const release = (): void => {
    const next = waiting.shift();
    // Hand the slot straight to the next waiter, or give it back.
    if (next) next();
    else active -= 1;
  };
  return items.map((item) =>
    acquire().then(async () => {
      try {
        return await run(item);
      } finally {
        release();
      }
    }),
  );
}

/**
 * A tool's view spec, validated against the closed catalog.
 *
 * Returns `null` on anything wrong. A malformed spec must degrade to a text
 * answer — never a blank card, which reads as a bug in the app rather than as a
 * question the assistant could not draw.
 */
function safeViewSpec(
  tool: AnyAssistantTool,
  args: unknown,
  result: unknown,
): ViewSpec | null {
  if (!tool.view) return null;

  let candidate: { type: string; params: unknown } | null;
  try {
    candidate = tool.view(args as never, result);
  } catch (err) {
    console.error(`[assistant] view spec for ${tool.name} threw`, err);
    return null;
  }
  if (!candidate) return null;

  const validated = validateViewSpec(candidate);
  if (!validated.ok) {
    console.error(
      `[assistant] ${tool.name} produced an invalid view spec: ${validated.reason} ` +
        validated.issues.join('; '),
    );
    return null;
  }
  return validated.spec;
}

/**
 * A tool's figure artifacts, each validated against the figure contract.
 *
 * Same degradation rule as {@link safeViewSpec}: a builder that throws or
 * produces something malformed costs the card, never the turn.
 */
async function safeFigures(
  tool: AnyAssistantTool,
  args: unknown,
  result: unknown,
): Promise<FigureArtifact[]> {
  if (!tool.figures) return [];

  let candidates: unknown;
  try {
    candidates = await tool.figures(args as never, result);
  } catch (err) {
    console.error(`[assistant] figures for ${tool.name} threw`, err);
    return [];
  }
  if (!Array.isArray(candidates)) return [];

  const valid: FigureArtifact[] = [];
  for (const candidate of candidates) {
    const checked = validateFigure(candidate);
    if (checked.ok) valid.push(checked.figure);
    else console.error(`[assistant] ${tool.name} produced an invalid figure: ${checked.reason}`);
  }
  return valid;
}

/** A tool's cited outside pages. A builder that throws costs the citations, never the turn. */
function safeToolSources(tool: AnyAssistantTool, args: unknown, result: unknown): RawWebSource[] {
  if (!tool.sources) return [];
  try {
    const candidates = tool.sources(args as never, result);
    return Array.isArray(candidates) ? candidates : [];
  } catch (err) {
    console.error(`[assistant] sources for ${tool.name} threw`, err);
    return [];
  }
}

export function pillarFor(name: string): string {
  try {
    return pillarOf(name as ToolName);
  } catch {
    return 'unknown';
  }
}
