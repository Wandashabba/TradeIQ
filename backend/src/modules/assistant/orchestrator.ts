import { SYSTEM_PROMPT } from './prompt';
import type { LlmProvider, Message, ToolCallRecord, Usage } from './providers/types';
import { quarantineFreeText } from './quarantine';
import { pillarOf, type ToolName } from './roster';
import { sanitizeToolResult } from './sanitize';
import { tracer as processTracer, type AssistantTracer, type ToolSpan } from './tracing';
import { ToolFacingError, type AnyAssistantTool } from './types';
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
 * a hang. Four is comfortably above what a real question needs — the exit demo
 * is one round — and low enough that a runaway costs a rounding error.
 */
export const MAX_TOOL_ROUNDS = 4;

/** What the route writes to the wire. Mirrors the SSE table in the design spec. */
export type WireEvent =
  | { event: 'token'; data: { text: string } }
  | { event: 'tool_start'; data: { name: string; pillar: string } }
  | { event: 'tool_end'; data: { name: string; ok: boolean } }
  | { event: 'artifact'; data: { id: string; type: string; params: unknown; data: unknown } }
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
          provider: provider.name,
          model: provider.models.orchestrator,
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
    const lastRound = round === maxRounds;
    const calls: ToolCallRecord[] = [];
    let assistantText = '';
    let failed = false;

    for await (const event of provider.runTurn(
      {
        system,
        tools,
        messages,
        ...(lastRound ? { toolChoice: 'none' as const } : {}),
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
    if (calls.length === 0) {
      emitTrace();
      yield { event: 'usage', data: totalUsage };
      yield { event: 'done', data: {} };
      return;
    }

    messages.push({ role: 'assistant', content: assistantText, toolCalls: calls });

    for (const call of calls) {
      if (signal.aborted) {
        errorCode = 'aborted';
        emitTrace();
        yield { event: 'error', data: { code: 'aborted', message: 'Request cancelled.' } };
        return;
      }

      const tool = byName.get(call.name);

      // A tool the caller's roster does not carry. Not an error the user should
      // see — it is the security boundary doing its job, and the model recovers
      // better from "that is unavailable" than from a dead turn.
      if (!tool) {
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

      yield { event: 'tool_start', data: { name: tool.name, pillar: tool.pillar } };
      const toolStartedAt = Date.now();
      const span = (ok: boolean): void => {
        toolSpans.push({
          name: tool.name,
          pillar: tool.pillar,
          ok,
          durationMs: Date.now() - toolStartedAt,
        });
      };

      const parsed = tool.args.safeParse(call.args);
      if (!parsed.success) {
        span(false);
        yield { event: 'tool_end', data: { name: tool.name, ok: false } };
        messages.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          ok: false,
          // Naming the bad field lets the model retry correctly instead of
          // guessing, which is the difference between one wasted round and four.
          content: `Invalid arguments: ${parsed.error.issues
            .map((i) => `${i.path.join('.') || '<root>'} ${i.message}`)
            .join('; ')}`,
        });
        continue;
      }

      let result: unknown;
      try {
        result = await tool.run(parsed.data);
      } catch (err) {
        // A tool that throws is ordinary — a stale id, an empty period.
        //
        // The message is ours, never the exception's: a Prisma error carries
        // table and column names straight into the model's context. The one
        // exception is `ToolFacingError`, which a tool throws to say "I wrote
        // this string for the model deliberately" — that is how a tool asks a
        // clarifying question ("which Sipho?") instead of failing opaquely.
        const forModel =
          err instanceof ToolFacingError
            ? err.message
            : 'That lookup failed. Tell the user you could not retrieve it.';

        // Logged at different levels because they are different events: an
        // ambiguous name is the system working, and a Prisma failure is not.
        if (err instanceof ToolFacingError) {
          console.warn(`[assistant] tool ${tool.name} declined: ${err.message}`);
        } else {
          console.error(`[assistant] tool ${tool.name} failed`, err);
        }

        span(false);
        yield { event: 'tool_end', data: { name: tool.name, ok: false } };
        messages.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          ok: false,
          content: forModel,
        });
        continue;
      }

      span(true);
      yield { event: 'tool_end', data: { name: tool.name, ok: true } };

      // The artifact carries the RAW result, and the model gets the sanitized
      // one. They are different on purpose: the client renders through a
      // validated spec into widgets that draw data, so fencing would put
      // "«untrusted» …" inside a chart label. The model's copy is the one that
      // needs spotlighting, because the model is the thing an injection targets.
      const spec = safeViewSpec(tool, parsed.data, result);
      if (spec) {
        yield {
          event: 'artifact',
          data: {
            // Deterministic within a turn so a repeated call patches the card
            // in place instead of appending a near-identical one. Phase 2
            // replaces this with a persisted id.
            id: `${tool.name}-${artifactIndex}`,
            type: spec.type,
            params: spec.params,
            data: result,
          },
        };
        artifactIndex += 1;
      }

      const quarantined = await quarantineFreeText(result, { provider, signal });
      const { value } = sanitizeToolResult(quarantined.value);

      messages.push({
        role: 'tool',
        callId: call.id,
        name: call.name,
        ok: true,
        content: truncate(JSON.stringify(value)),
      });
    }
  }

  // Unreachable: the final round runs with tools withdrawn, so it cannot
  // produce calls and must exit through the `calls.length === 0` branch. Kept
  // because "unreachable" is a claim about code that changes.
  emitTrace();
  yield { event: 'usage', data: totalUsage };
  yield { event: 'done', data: {} };
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
 * Bound one tool result's contribution to context.
 *
 * A tool that returns thousands of rows would otherwise push the turn past the
 * window — and it is billed by the token either way. Truncation is announced
 * inside the payload so the model reports a partial answer rather than
 * confidently summarising the half it happened to receive.
 */
const MAX_TOOL_RESULT_CHARS = 24_000;

function truncate(json: string): string {
  if (json.length <= MAX_TOOL_RESULT_CHARS) return json;
  return (
    json.slice(0, MAX_TOOL_RESULT_CHARS) +
    '\n[truncated: this result was too large to include in full. Say so, and suggest narrowing the question.]'
  );
}

export function pillarFor(name: string): string {
  try {
    return pillarOf(name as ToolName);
  } catch {
    return 'unknown';
  }
}
