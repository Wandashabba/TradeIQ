import {
  FunctionCallingConfigMode,
  GoogleGenAI,
  type Content,
  type FunctionDeclaration,
  type GenerateContentParameters,
  type GenerateContentResponse,
  type GroundingMetadata,
  type Part,
  type ThinkingConfig,
  type Tool,
  type ToolConfig,
} from '@google/genai';
import {
  forgetCachedPrefix,
  getCachedPrefix,
  type CachesClient,
} from './promptCache';
import { z } from 'zod';
import type { AnyAssistantTool } from '../types';
import { toGeminiSchema } from './geminiSchema';
import {
  isToolResult,
  type LlmProvider,
  type Message,
  type RawWebSource,
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
 * How hard the model thinks, per kind of round.
 *
 * **The largest single line on the bill, and it was never set.** Left
 * unspecified, Gemini 3 Pro thinks at its default high level on every request.
 * Measured on one live turn: 5,644 output tokens, of which 3,539 came from the
 * one round that had tools withdrawn and nothing to do but write a 719-character
 * answer. At the output rate that round alone was 4.2 of the turn's 13.1 cents —
 * more than every cached prefix read in the turn put together.
 *
 * Three kinds of round, because they are three different jobs carrying
 * different risks:
 *
 * - The **opening round** picks the first tool from the user's words alone.
 *   That is the choice the eval gate scores at 90%, the one a turn cannot
 *   recover from, and — measured — the cheapest round in the turn at around 200
 *   thinking tokens whatever the level. There is nothing to save here and
 *   everything to lose, so it is left at the vendor default.
 * - A **later tool round** picks a follow-up with the previous results already
 *   in front of it. A narrower decision, and an expensive one: measured at
 *   1,640 output tokens on one round, because thinking scales with the context
 *   it reasons over and the context has been growing all turn.
 * - The **answer round** runs with `toolChoice: 'none'`. Every figure it may
 *   use is in front of it and no decision remains but how to phrase the
 *   reading. It was spending 3,539 output tokens on 719 characters of prose.
 *
 * Measured on twenty golden questions, first-tool choice was 20/20 at the
 * vendor default and 19/20 at `low` — which is why round zero keeps the
 * default rather than trusting a 95% that is one sample away from the gate.
 *
 * All three are overridable, and an empty string restores the vendor default
 * for that kind of round.
 */
const THINKING_LEVELS = ['minimal', 'low', 'medium', 'high'] as const;
const FIRST_THINKING_LEVEL = process.env.GEMINI_FIRST_THINKING_LEVEL ?? '';
const THINKING_LEVEL = process.env.GEMINI_THINKING_LEVEL ?? 'low';
const ANSWER_THINKING_LEVEL = process.env.GEMINI_ANSWER_THINKING_LEVEL ?? 'low';

/**
 * A ceiling on one round's generation, thinking included.
 *
 * A runaway guard rather than a cost dial — the thinking levels above are the
 * dial. Generous enough that no answer a manager would read reaches it, low
 * enough that a model looping inside its own reasoning stops costing money at
 * some point instead of at the turn budget.
 */
const MAX_OUTPUT_TOKENS = Number(process.env.GEMINI_MAX_OUTPUT_TOKENS ?? 8_192);

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
  /**
   * Optional so every existing scripted fake stays valid. A fake without it
   * takes the inline path — the behaviour those tests were written against.
   */
  caches?: CachesClient;
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

    // A turn that ran Google Search carries server-side toolCall/toolResponse
    // parts with their own signatures, and Gemini refuses the next request if
    // any of them is missing. Such a turn is replayed exactly as it streamed.
    if (
      message.role === 'assistant' &&
      message.providerReplay?.provider === 'gemini' &&
      Array.isArray(message.providerReplay.content) &&
      message.providerReplay.content.length > 0
    ) {
      contents.push({ role: 'model', parts: message.providerReplay.content as Part[] });
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
        // Replayed verbatim. Without it Gemini 3.x rejects the whole request
        // with 400 INVALID_ARGUMENT ("missing a thought_signature in
        // functionCall parts"), so every turn that calls a tool dies on the
        // follow-up request that carries the tool's result.
        ...(call.providerSignature ? { thoughtSignature: call.providerSignature } : {}),
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

/**
 * Is this the vendor telling us the cache name we sent no longer exists?
 *
 * Matched on the message rather than the status alone: a bare 403/404 also
 * covers a revoked key and a wrong model name, and retrying those inline would
 * turn one clear failure into two confusing ones.
 */
export function isMissingCacheError(err: unknown): boolean {
  const status = (err as { status?: number } | undefined)?.status;
  if (status !== 403 && status !== 404) return false;
  const message = err instanceof Error ? err.message : String(err);
  return /cachedcontent|cached_content|cache/i.test(message);
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

/**
 * Can this model combine Google Search grounding with function calling?
 *
 * Per Google's "Combine built-in tools and function calling" guide, only Gemini
 * 3 models can, in preview, and only with `includeServerSideToolInvocations` and
 * `VALIDATED` mode. Earlier models reject the combination, so for them search is
 * simply not offered and the frozen prompt has the model say it cannot search.
 */
export function geminiSupportsSearchWithTools(model: string): boolean {
  return /^(models\/)?gemini-3/i.test(model);
}

/**
 * The thinking config for one round, or nothing at all.
 *
 * Returns `undefined` — rather than a config naming the vendor's own default —
 * both when thinking is not configured for this kind of round and when the
 * model is not one that takes the setting. Sending `thinkingLevel` to a model
 * that does not understand it is a 400, and a 400 on every turn is a worse
 * outcome than a turn that thinks too hard.
 */
export function thinkingConfigFor(
  model: string,
  kind: 'first' | 'tool' | 'answer' | 'quarantine',
): ThinkingConfig | undefined {
  // The quarantine tier summarises one string with no tools. It has nothing to
  // reason about, and it is a different model whose levels we have not measured.
  if (kind === 'quarantine') return undefined;
  if (!/^(models\/)?gemini-3/i.test(model)) return undefined;
  const level = (
    kind === 'answer'
      ? ANSWER_THINKING_LEVEL
      : kind === 'first'
        ? FIRST_THINKING_LEVEL
        : THINKING_LEVEL
  ).toLowerCase();
  // An unrecognised value is treated as "unset" rather than forwarded. A typo in
  // an env var should cost the discount, not every turn — and the vendor's
  // answer to an unknown level is a 400 on every request.
  if (!THINKING_LEVELS.includes(level as (typeof THINKING_LEVELS)[number])) return undefined;
  return { thinkingLevel: level as ThinkingConfig['thinkingLevel'] };
}

/** The tool config a grounded, function-calling request needs. */
export const GROUNDED_TOOL_CONFIG: ToolConfig = {
  functionCallingConfig: { mode: FunctionCallingConfigMode.VALIDATED },
  includeServerSideToolInvocations: true,
};

/**
 * Grounding metadata → raw sources.
 *
 * Gemini names a page by `web.uri` (a Google redirect link that resolves to the
 * page) and `web.title` (usually the site's domain). The only "snippet" it
 * exposes is the answer segment a chunk supports — the model's words, not the
 * page's — so the first such segment is used, and `sources.ts` bounds it.
 */
export function sourcesFromGrounding(meta: GroundingMetadata | undefined): RawWebSource[] {
  const chunks = meta?.groundingChunks ?? [];
  const snippets = new Map<number, string>();
  for (const support of meta?.groundingSupports ?? []) {
    for (const index of support.groundingChunkIndices ?? []) {
      if (!snippets.has(index) && support.segment?.text) snippets.set(index, support.segment.text);
    }
  }
  const out: RawWebSource[] = [];
  chunks.forEach((chunk, index) => {
    if (!chunk.web?.uri) return;
    out.push({
      url: chunk.web.uri,
      title: chunk.web.title ?? chunk.web.domain ?? null,
      snippet: snippets.get(index) ?? null,
    });
  });
  return out;
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

  /**
   * Resolved through `getClient()` so a missing key still throws the same
   * configuration error, rather than caching quietly disabling itself and
   * leaving the real problem to surface one layer later.
   */
  function getCaches(): CachesClient | undefined {
    return getClient().caches;
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
      const model = input.model === 'quarantine' ? quarantineModel : orchestratorModel;
      // Tools withdrawn is precisely what "this is the answer round" means: the
      // orchestrator sets `toolChoice: 'none'` on the last round and on no
      // other. Reading it here rather than adding a flag to `TurnInput` keeps
      // the contract the same for both adapters.
      const thinking = thinkingConfigFor(
        model,
        input.model === 'quarantine'
          ? 'quarantine'
          : input.toolChoice === 'none'
            ? 'answer'
            : // No `round` at all means a caller that predates it, and the
              // safe reading of "unknown round" is the one that changes
              // nothing about tool selection.
              (input.round ?? 0) === 0
              ? 'first'
              : 'tool',
      );
      // Grounding rides beside the function declarations, never alone: a
      // search-only request would change what a tool-less round means.
      const grounded =
        Boolean(input.webSearch) && declarations.length > 0 && geminiSupportsSearchWithTools(model);
      const toolsForRequest: Tool[] =
        declarations.length > 0
          ? [{ functionDeclarations: declarations }, ...(grounded ? [{ googleSearch: {} }] : [])]
          : [];

      // Resolving the cache reaches for the client, and a missing key throws
      // from there — so this cannot sit above the try below. `runTurn` must end
      // the stream with a `not_configured` **event**; a throw kills the SSE
      // connection with no reason on it, which is the one thing the missing-key
      // test exists to prevent.
      let cachedPrefix: string | null = null;

      try {
        // The frozen prefix goes server-side when it can. Gemini's *implicit*
        // caching never engages (measured — see promptCache.ts), so the
        // discount the cost model assumes has to be requested explicitly. A
        // null handle is the ordinary case for small prefixes, and means
        // "send it inline".
        cachedPrefix = await getCachedPrefix(
          getCaches(),
          model,
          input.system,
          toolsForRequest,
          // A grounded request's tool config cannot be sent beside a cache, so
          // it lives in the cache entry — and is part of its key.
          grounded ? GROUNDED_TOOL_CONFIG : undefined,
        );
      } catch (err) {
        const { code, message } = classifyGeminiError(err);
        console.error('[assistant] gemini turn failed', err);
        yield { type: 'error', code, message };
        return;
      }

      const params: GenerateContentParameters = {
        model,
        contents: toGeminiContents(input.messages),
        config: {
          // Sent inline only when there is no cache holding them. Passing both
          // is a 400: the cached entry already carries this prefix, and the API
          // refuses to be told it twice.
          ...(cachedPrefix
            ? {
                cachedContent: cachedPrefix,
                // `toolConfig` is omitted deliberately, not forgotten. The API
                // refuses `system_instruction`, `tools` **and `tool_config`**
                // alongside a cache — "move those values to CachedContent" —
                // and a cache only exists when tools are present, which is
                // exactly when the mode would have been AUTO, the vendor
                // default. The suppressed case cannot reach here: no tools
                // means no cache, so a NONE turn always takes the inline path
                // below and keeps its explicit mode. The dual-LLM defence is
                // therefore untouched by caching.
              }
            : {
                // NOT a prepended user turn. See the file header.
                systemInstruction: input.system,
                ...(toolsForRequest.length > 0 ? { tools: toolsForRequest } : {}),
                toolConfig: grounded
                  ? GROUNDED_TOOL_CONFIG
                  : {
                      functionCallingConfig: {
                        mode: suppressTools
                          ? FunctionCallingConfigMode.NONE
                          : FunctionCallingConfigMode.AUTO,
                      },
                    },
              }),
          // Neither of these is part of the cached prefix — they are generation
          // settings, not content — so they ride alongside `cachedContent`
          // without the 400 that `tools` or `systemInstruction` would draw.
          maxOutputTokens: MAX_OUTPUT_TOKENS,
          ...(thinking ? { thinkingConfig: thinking } : {}),
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
      // Only kept when the turn used a server-side tool; see toGeminiContents.
      const replayParts: Part[] = [];
      let usedServerTool = false;
      let grounding: GroundingMetadata | undefined;

      try {
        let stream: AsyncGenerator<GenerateContentResponse>;
        try {
          stream = await getClient().models.generateContentStream(params);
        } catch (err) {
          // A cache can vanish between our refresh check and Google's read —
          // lapsed early, or deleted from the console. That must cost one
          // retry, not the turn: forget the dead name and send the prefix
          // inline. Only the opening request is retried, so nothing already
          // streamed to the user can be duplicated.
          if (!cachedPrefix || !isMissingCacheError(err)) throw err;
          forgetCachedPrefix(cachedPrefix);
          params.config = {
            ...params.config,
            cachedContent: undefined,
            systemInstruction: input.system,
            ...(toolsForRequest.length > 0 ? { tools: toolsForRequest } : {}),
            ...(grounded ? { toolConfig: GROUNDED_TOOL_CONFIG } : {}),
          };
          stream = await getClient().models.generateContentStream(params);
        }

        for await (const chunk of stream) {
          if (signal.aborted) {
            yield { type: 'error', code: 'aborted', message: 'Request cancelled.' };
            return;
          }

          for (const part of chunk.candidates?.[0]?.content?.parts ?? []) {
            if (grounded) replayParts.push(part);
            if (part.toolCall) {
              // Google ran a search. Nothing to execute; announce it once.
              if (!usedServerTool) yield { type: 'web_search' };
              usedServerTool = true;
            }
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
                // Carried, not read. Gemini 3.x refuses the next request if this
                // call returns without the signature it was issued with, and the
                // signature rides on the Part rather than inside functionCall.
                ...(part.thoughtSignature ? { signature: part.thoughtSignature } : {}),
              };
              callIndex += 1;
            }
          }

          // Usage arrives cumulatively across chunks; the last one wins rather
          // than being summed, or a long stream reports several times its cost.
          if (chunk.usageMetadata) usage = normaliseGeminiUsage(chunk.usageMetadata);
          const meta = chunk.candidates?.[0]?.groundingMetadata;
          if (meta?.groundingChunks?.length) grounding = meta;
        }
      } catch (err) {
        const { code, message } = classifyGeminiError(err);
        // The vendor error is logged, never streamed. See classifyGeminiError.
        console.error('[assistant] gemini turn failed', err);
        yield { type: 'error', code, message };
        return;
      }

      if (usedServerTool && callIndex > 0) {
        yield { type: 'replay', content: replayParts };
      }
      const sources = sourcesFromGrounding(grounding);
      if (sources.length > 0) yield { type: 'sources', sources };

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
