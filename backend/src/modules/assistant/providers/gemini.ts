import {
  FunctionCallingConfigMode,
  GoogleGenAI,
  type Content,
  type FunctionDeclaration,
  type GenerateContentParameters,
  type GenerateContentResponse,
  type Part,
} from '@google/genai';
import { z } from 'zod';
import type { AnyAssistantTool } from '../types';
import { toGeminiSchema } from './geminiSchema';
import {
  isToolResult,
  type LlmProvider,
  type Message,
  type TurnEvent,
  type TurnInput,
  type Usage,
} from './types';

/**
 * The Gemini adapter — built first, because its key is the one that exists.
 *
 * Its entire job is vendor stream → {@link TurnEvent}. Nothing above it knows
 * that Gemini calls a system prompt `systemInstruction`, that its size bounds
 * are strings, or that it reports cache hits under a different name.
 *
 * The three things this file exists to absorb, in the order they bite:
 *
 * 1. **The system prompt is not a message.** Gemini takes it as
 *    `config.systemInstruction`. The plan calls prepending it as a `user` turn
 *    "the most common migration bug" — it works, and it quietly destroys the
 *    cache prefix and the instruction hierarchy at once.
 * 2. **Tool-call ids are optional on the wire.** `FunctionCall.id` is populated
 *    "if populated". The orchestrator needs one to correlate a result, so this
 *    file synthesises a deterministic one when Gemini omits it.
 * 3. **Cache hits are reported as `cachedContentTokenCount`.** The CI cost
 *    assertion reads `Usage.cacheReadTokens`, so the rename lives here.
 */

/**
 * The orchestrator default is `-preview` because that is the model's actual
 * name. `gemini-3.1-pro` — what the plan's table says, and what this line said
 * until the first sweep tried to use it — is a 404 on `v1beta`: there is no GA
 * 3.1 Pro to fall back to. Nothing caught it because every measured run so far
 * set `GEMINI_ORCHESTRATOR_MODEL` to a Flash tier, and CI skips the live sweep
 * for want of a key, so this default had never once been called.
 *
 * A preview name will eventually stop resolving too. That is a property of the
 * model, not a mistake here: the failure is loud (404 → `provider_error` →
 * every question excluded → `passed: false`), and the override exists so a
 * rename is an env change rather than a deploy.
 */
export const GEMINI_ORCHESTRATOR_MODEL =
  process.env.GEMINI_ORCHESTRATOR_MODEL ?? 'gemini-3.1-pro-preview';
export const GEMINI_QUARANTINE_MODEL = process.env.GEMINI_QUARANTINE_MODEL ?? 'gemini-3.6-flash';

/**
 * Dollars per million tokens.
 *
 * ⚠️ **Placeholders. Confirm against Google's published pricing before any
 * spend dashboard is trusted.**
 *
 * Seeded from the plan's cost-model table (`$2 / $12` for Gemini 3.1 Pro, with
 * cached reads at roughly a 90% discount) rather than from a second guess, so
 * there is **one** set of numbers to correct rather than two that can quietly
 * disagree — the plan says its own figures are "orders of magnitude, not a
 * forecast", and that caveat travels with them to here.
 *
 * Declared at all, rather than left out, because `Usage.costCents` is part of
 * the provider contract and returning `0` would make a cost regression look
 * like a cost saving. A wrong-but-visible number gets corrected; a zero does
 * not.
 *
 * Cached input is billed at a discount on every provider that offers it, which
 * is the entire economic argument for the frozen prompt prefix.
 */
const RATES = {
  inputPerMTok: Number(process.env.GEMINI_INPUT_USD_PER_MTOK ?? 2),
  outputPerMTok: Number(process.env.GEMINI_OUTPUT_USD_PER_MTOK ?? 12),
  cachedInputPerMTok: Number(process.env.GEMINI_CACHED_INPUT_USD_PER_MTOK ?? 0.2),
} as const;

/**
 * The slice of the SDK this adapter actually uses.
 *
 * Narrowed to one method so tests can drive the adapter with a scripted stream
 * and no key, no network, and no `GoogleGenAI` construction. The provider
 * contract test depends on being able to do exactly that for every adapter.
 */
export interface GeminiClient {
  models: {
    generateContentStream(
      params: GenerateContentParameters,
    ): Promise<AsyncGenerator<GenerateContentResponse>>;
  };
}

export interface GeminiProviderOptions {
  /** Injected by tests. Omitted in production, where the real SDK is built from the key. */
  client?: GeminiClient;
  apiKey?: string;
  models?: { orchestrator?: string; quarantine?: string };
}

/** Gemini names the assistant role `model`; ours is `assistant`. */
function toGeminiRole(role: 'user' | 'assistant'): 'user' | 'model' {
  return role === 'assistant' ? 'model' : 'user';
}

/**
 * Our history → Gemini `Content[]`.
 *
 * Consecutive tool results are merged into a single `user` turn. Gemini rejects
 * a conversation with two adjacent turns of the same role, and a parallel tool
 * call produces exactly that if each result becomes its own turn — a failure
 * that only appears once the model starts calling two tools at once, which is
 * long after the code looks correct.
 */
export function toGeminiContents(messages: readonly Message[]): Content[] {
  const contents: Content[] = [];

  for (const message of messages) {
    if (isToolResult(message)) {
      const part: Part = {
        functionResponse: {
          id: message.callId,
          name: message.name,
          // Gemini requires an object here, never a bare string. The `ok` flag
          // travels with it so a failed tool reads as a result the model can
          // reason about rather than as a missing answer.
          response: { ok: message.ok, content: message.content },
        },
      };
      const previous = contents[contents.length - 1];
      if (previous?.role === 'user' && previous.parts?.[0]?.functionResponse) {
        previous.parts.push(part);
      } else {
        contents.push({ role: 'user', parts: [part] });
      }
      continue;
    }

    const parts: Part[] = [];
    if (message.content.length > 0) parts.push({ text: message.content });
    for (const call of message.toolCalls ?? []) {
      parts.push({
        functionCall: {
          id: call.id,
          name: call.name,
          args: (call.args ?? {}) as Record<string, unknown>,
        },
      });
    }
    // An assistant turn that was pure tool calls has no text. Gemini rejects an
    // empty `parts` array, so a turn that ended up with nothing is dropped
    // rather than sent as a malformed one.
    if (parts.length === 0) continue;
    contents.push({ role: toGeminiRole(message.role), parts });
  }

  return contents;
}

/**
 * Our tools → Gemini function declarations.
 *
 * Order is preserved from the roster, and the roster's order is stable, because
 * the declarations sit inside the cached prefix — reordering them is a cache
 * miss with no functional symptom.
 */
export function toFunctionDeclarations(tools: readonly AnyAssistantTool[]): FunctionDeclaration[] {
  return tools.map((tool) => ({
    name: tool.name,
    description: tool.description,
    // `parametersJsonSchema` would accept the Zod output directly, but it
    // forfeits the deterministic key ordering `toGeminiSchema` guarantees —
    // and the cache prefix is a byte comparison.
    parameters: toGeminiSchema(z.toJSONSchema(tool.args, { io: 'input' })),
  }));
}

/**
 * Vendor usage payload → ours.
 *
 * `promptTokenCount` **includes** the cached tokens, which is why the billable
 * input below subtracts them rather than adding a third bucket. Counting them
 * twice would make a cache hit look more expensive than a miss — the exact
 * inversion the cost assertion exists to catch.
 */
export function normaliseGeminiUsage(raw: unknown): Usage {
  const meta = (raw ?? {}) as {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    cachedContentTokenCount?: number;
    thoughtsTokenCount?: number;
  };

  const promptTokens = meta.promptTokenCount ?? 0;
  const cacheReadTokens = meta.cachedContentTokenCount ?? 0;
  // Thinking tokens are billed as output and are not included in
  // `candidatesTokenCount`. Omitting them under-reports every reasoning turn.
  const outputTokens = (meta.candidatesTokenCount ?? 0) + (meta.thoughtsTokenCount ?? 0);
  const freshInputTokens = Math.max(0, promptTokens - cacheReadTokens);

  const usd =
    (freshInputTokens / 1_000_000) * RATES.inputPerMTok +
    (cacheReadTokens / 1_000_000) * RATES.cachedInputPerMTok +
    (outputTokens / 1_000_000) * RATES.outputPerMTok;

  return {
    inputTokens: promptTokens,
    outputTokens,
    cacheReadTokens,
    costCents: Math.round(usd * 100 * 10_000) / 10_000,
  };
}

/**
 * A user-safe message for a vendor failure.
 *
 * Vendor errors carry request ids, model names, quota details and occasionally
 * fragments of the prompt. `TurnEvent.error.message` is rendered in the chat, so
 * nothing from the vendor reaches it verbatim — the real error goes to the log,
 * where it is useful and not visible.
 */
/**
 * The key is missing or the adapter is otherwise unusable before any request.
 *
 * Distinct from a vendor failure on purpose. A misconfiguration is the one
 * error with an obvious fix, and folding it into `provider_error` — "something
 * went wrong, please try again" — hides that from the operator watching the
 * error codes, who will retry forever against a config that cannot work.
 */
export class ProviderNotConfiguredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ProviderNotConfiguredError';
  }
}

export function classifyGeminiError(err: unknown): { code: string; message: string } {
  const status = (err as { status?: number })?.status;
  const raw = err instanceof Error ? err.message : String(err);

  if (err instanceof ProviderNotConfiguredError) {
    // The actionable detail goes to the log, not to a manager's chat window.
    return { code: 'not_configured', message: 'The assistant is not configured yet.' };
  }
  if ((err as { name?: string })?.name === 'AbortError') {
    return { code: 'aborted', message: 'Request cancelled.' };
  }
  if (status === 429 || /quota|rate.?limit|RESOURCE_EXHAUSTED/i.test(raw)) {
    return { code: 'rate_limited', message: 'The assistant is busy right now. Try again shortly.' };
  }
  if (status === 401 || status === 403 || /API key|PERMISSION_DENIED|UNAUTHENTICATED/i.test(raw)) {
    // Deliberately vague to the user; a misconfigured key is an operator
    // problem and naming it invites probing.
    return { code: 'provider_unavailable', message: 'The assistant is unavailable right now.' };
  }
  if (status === 400 || /INVALID_ARGUMENT/i.test(raw)) {
    return { code: 'bad_request', message: 'The assistant could not process that request.' };
  }
  if (/SAFETY|blocked/i.test(raw)) {
    return { code: 'blocked', message: 'The assistant could not answer that.' };
  }
  return { code: 'provider_error', message: 'Something went wrong. Please try again.' };
}

export function createGeminiProvider(options: GeminiProviderOptions = {}): LlmProvider {
  const orchestratorModel = options.models?.orchestrator ?? GEMINI_ORCHESTRATOR_MODEL;
  const quarantineModel = options.models?.quarantine ?? GEMINI_QUARANTINE_MODEL;

  // Built lazily. Constructing `GoogleGenAI` eagerly would make importing this
  // module throw in any environment without a key — including every test run
  // and CI, neither of which should need one to typecheck the orchestrator.
  let client: GeminiClient | undefined = options.client;
  function getClient(): GeminiClient {
    if (client) return client;
    const apiKey = options.apiKey ?? process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new ProviderNotConfiguredError(
        'GEMINI_API_KEY is not set. It is declared in backend/.env.example; ' +
          'copy it into backend/.env before running an assistant turn.',
      );
    }
    client = new GoogleGenAI({ apiKey }) as unknown as GeminiClient;
    return client;
  }

  return {
    name: 'gemini',
    models: { orchestrator: orchestratorModel, quarantine: quarantineModel },
    normaliseUsage: normaliseGeminiUsage,

    async *runTurn(input: TurnInput, signal: AbortSignal): AsyncIterable<TurnEvent> {
      // Checked before the call, not only inside the loop: a client that
      // disconnected while we were queued should not open a paid request at all.
      if (signal.aborted) {
        yield { type: 'error', code: 'aborted', message: 'Request cancelled.' };
        return;
      }

      // A quarantine turn must reach the model with no tool declarations at
      // all. `toolChoice: 'none'` alone is a policy the request carries; an
      // empty declaration list is the absence of anything to call. The dual-LLM
      // defence rests on the second, so the two are enforced together here
      // rather than trusted to every caller.
      const suppressTools = input.toolChoice === 'none' || input.model === 'quarantine';
      const declarations = suppressTools ? [] : toFunctionDeclarations(input.tools);

      const params: GenerateContentParameters = {
        model: input.model === 'quarantine' ? quarantineModel : orchestratorModel,
        contents: toGeminiContents(input.messages),
        config: {
          // NOT a prepended user turn. See the file header.
          systemInstruction: input.system,
          ...(declarations.length > 0 ? { tools: [{ functionDeclarations: declarations }] } : {}),
          toolConfig: {
            functionCallingConfig: {
              mode: suppressTools ? FunctionCallingConfigMode.NONE : FunctionCallingConfigMode.AUTO,
            },
          },
          // ⚠️ Client-side only, per the SDK's own note: aborting stops us
          // reading the stream, it does not stop Google generating or billing
          // it. The plan's "client disconnect must not orphan a paid request"
          // is therefore only *partly* satisfiable from here — the rest is the
          // console spend cap, which is tracked as its own task.
          abortSignal: signal,
        },
      };

      let usage: Usage | undefined;
      // Deterministic, not random: the contract test compares event streams,
      // and a uuid would make every run differ. Correlation only has to hold
      // within one turn, which an index does.
      let callIndex = 0;

      try {
        const stream = await getClient().models.generateContentStream(params);

        for await (const chunk of stream) {
          if (signal.aborted) {
            yield { type: 'error', code: 'aborted', message: 'Request cancelled.' };
            return;
          }

          for (const part of chunk.candidates?.[0]?.content?.parts ?? []) {
            // Thinking text is not narrative and must not be streamed to the
            // user as though it were the answer.
            if (part.thought) continue;
            if (typeof part.text === 'string' && part.text.length > 0) {
              yield { type: 'token', text: part.text };
            }
            if (part.functionCall) {
              yield {
                type: 'tool_call',
                id: part.functionCall.id ?? `call_${callIndex}`,
                name: part.functionCall.name ?? '',
                args: part.functionCall.args ?? {},
              };
              callIndex += 1;
            }
          }

          // Usage arrives cumulatively across chunks; the last one wins rather
          // than being summed, or a long stream reports several times its cost.
          if (chunk.usageMetadata) usage = normaliseGeminiUsage(chunk.usageMetadata);
        }
      } catch (err) {
        const { code, message } = classifyGeminiError(err);
        // The vendor error is logged, never streamed. See classifyGeminiError.
        console.error('[assistant] gemini turn failed', err);
        yield { type: 'error', code, message };
        return;
      }

      // Always emitted, even when the vendor sent no usage block, so the cost
      // path has no silent hole — a missing `usage` event would read downstream
      // as a free turn.
      yield {
        type: 'usage',
        usage: usage ?? { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, costCents: 0 },
      };
      yield { type: 'done' };
    },
  };
}
