import Anthropic from '@anthropic-ai/sdk';
import type {
  ContentBlockParam,
  MessageCreateParamsStreaming,
  MessageParam,
  RawMessageStreamEvent,
  TextBlockParam,
  ToolResultBlockParam,
  ToolUnion,
} from '@anthropic-ai/sdk/resources/messages/messages';
import { z } from 'zod';
import type { AnyAssistantTool } from '../types';
import { ProviderNotConfiguredError } from './gemini';
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
 * The Anthropic adapter — Claude Sonnet 5 as the orchestrator.
 *
 * Same job as `gemini.ts`: vendor stream → {@link TurnEvent}, and nothing above
 * this file learns that Anthropic calls a tool call `tool_use`, reports cache
 * hits as `cache_read_input_tokens`, or runs web search on its own servers.
 *
 * What this file exists to absorb, in the order they bite:
 *
 * 1. **The system prompt is a top-level parameter**, and the cache breakpoint
 *    rides on it. Render order is `tools → system → messages`, so one
 *    `cache_control` on the system block caches the frozen `[tools][system]`
 *    prefix the orchestrator already guarantees is byte-stable. A second
 *    breakpoint on the newest message lets later rounds of the same turn read
 *    the growing history from cache too.
 * 2. **Server-side tool turns must be replayed verbatim.** A round that ran web
 *    search, or thought before calling a tool, returns blocks we never execute —
 *    encrypted search results, signed thinking — and the next request is refused
 *    if they are dropped. The whole assistant content goes back up as an opaque
 *    `replay` event and returns here untouched.
 * 3. **`pause_turn`.** A long server-side search can pause mid-response. That is
 *    continued inside this adapter, invisibly, by sending the paused content
 *    back — the orchestrator's round count is ours, not the vendor's.
 * 4. **Cache hits are `cache_read_input_tokens`**, and `input_tokens` excludes
 *    them — the opposite convention from Gemini, reconciled in
 *    {@link normaliseAnthropicUsage}.
 */

/**
 * The orchestrator runs on Claude Sonnet 5 — named by the owner, and the tier
 * whose tool selection the eval gate will be stated against. Overridable so a
 * model change is an env change rather than a deploy, like Gemini's.
 */
export const ANTHROPIC_ORCHESTRATOR_MODEL =
  process.env.ANTHROPIC_ORCHESTRATOR_MODEL ?? 'claude-sonnet-5';
/**
 * The quarantine pass: a cheap, tool-less summarisation call over free text.
 * Haiku 4.5 is the cheap tier; it is not reasoning, so it runs without thinking.
 */
export const ANTHROPIC_QUARANTINE_MODEL =
  process.env.ANTHROPIC_QUARANTINE_MODEL ?? 'claude-haiku-4-5-20251001';

/**
 * Dollars per million tokens, and per search.
 *
 * Seeded from Anthropic's published Sonnet 5 rates ($2 in / $10 out, cache
 * reads at a tenth of input, cache writes at 1.25×) and $10 per 1,000 web
 * searches. **Confirm against the pricing page before any spend dashboard is
 * trusted** — the same caveat as the Gemini table, and for the same reason: a
 * wrong-but-visible number gets corrected, a zero does not.
 *
 * One table for both tiers, like Gemini. A quarantine turn on Haiku is priced
 * at Sonnet rates, which over-reports it — the safe direction for a cost gate.
 */
const RATES = {
  inputPerMTok: Number(process.env.ANTHROPIC_INPUT_USD_PER_MTOK ?? 2),
  outputPerMTok: Number(process.env.ANTHROPIC_OUTPUT_USD_PER_MTOK ?? 10),
  cachedInputPerMTok: Number(process.env.ANTHROPIC_CACHED_INPUT_USD_PER_MTOK ?? 0.2),
  cacheWritePerMTok: Number(process.env.ANTHROPIC_CACHE_WRITE_USD_PER_MTOK ?? 2.5),
  perWebSearch: Number(process.env.ANTHROPIC_WEB_SEARCH_USD ?? 0.01),
} as const;

/**
 * Generous for a manager-sized answer, because adaptive thinking spends from
 * the same budget and a cut-off answer is worse than a long one. Streaming, so
 * a large ceiling costs nothing unless it is used.
 */
const MAX_TOKENS = Number(process.env.ANTHROPIC_MAX_TOKENS ?? 32_000);

/** How many `pause_turn` continuations one round may take before it gives up. */
const MAX_PAUSE_CONTINUATIONS = 3;

/**
 * Web search, bounded.
 *
 * - `max_uses: 3` — outside context is a supporting act here; a turn that
 *   wants ten searches is a research task this assistant is not.
 * - `user_location` South Africa — "Shoprite promotion" means the local one.
 * - `allowed_callers: ['direct']` — the 2026-02-09 version otherwise runs
 *   search from inside server-side code execution ("dynamic filtering"). Direct
 *   calls keep citations on plain text blocks and keep the replayed history free
 *   of code-execution containers we cannot verify without a live key.
 */
export const ANTHROPIC_WEB_SEARCH_TOOL: ToolUnion = {
  type: 'web_search_20260209',
  name: 'web_search',
  max_uses: 3,
  allowed_callers: ['direct'],
  user_location: {
    type: 'approximate',
    country: 'ZA',
    timezone: 'Africa/Johannesburg',
  },
};

/**
 * The slice of the SDK this adapter uses, narrowed so the contract suite can
 * drive it with a scripted stream and no key, no network, no client.
 */
export interface AnthropicClient {
  messages: {
    create(
      params: MessageCreateParamsStreaming,
      options?: { signal?: AbortSignal },
    ): PromiseLike<AsyncIterable<RawMessageStreamEvent>>;
  };
}

export interface AnthropicProviderOptions {
  /** Injected by tests. Omitted in production, where the SDK is built from the key. */
  client?: AnthropicClient;
  apiKey?: string;
  models?: { orchestrator?: string; quarantine?: string };
}

/** Our tools → Anthropic tool definitions, in roster order (it is cached prefix). */
export function toAnthropicTools(tools: readonly AnyAssistantTool[]): ToolUnion[] {
  return tools.map((tool) => {
    const schema = { ...(z.toJSONSchema(tool.args, { io: 'input' }) as Record<string, unknown>) };
    // The meta-schema key is noise to the API and bytes in the cached prefix.
    delete schema.$schema;
    return {
      name: tool.name,
      description: tool.description,
      input_schema: { ...schema, type: 'object' } as { type: 'object' },
    };
  });
}

/**
 * Our history → Anthropic `messages`.
 *
 * - Consecutive tool results become one `user` turn of `tool_result` blocks —
 *   every result for a parallel call must come back in a single message, or
 *   the model learns to stop calling tools in parallel.
 * - An assistant turn this adapter produced is replayed from `providerReplay`,
 *   so thinking signatures and encrypted search results survive. One produced
 *   by any other provider is rebuilt from text and tool calls.
 * - Empty text is dropped: the API rejects an empty text block.
 */
export function toAnthropicMessages(messages: readonly Message[]): MessageParam[] {
  const out: MessageParam[] = [];

  for (const message of messages) {
    if (isToolResult(message)) {
      const block: ToolResultBlockParam = {
        type: 'tool_result',
        tool_use_id: message.callId,
        content: message.content,
        ...(message.ok ? {} : { is_error: true }),
      };
      const previous = out[out.length - 1];
      if (
        previous?.role === 'user' &&
        Array.isArray(previous.content) &&
        previous.content.every((b) => b.type === 'tool_result')
      ) {
        previous.content.push(block);
      } else {
        out.push({ role: 'user', content: [block] });
      }
      continue;
    }

    if (
      message.role === 'assistant' &&
      message.providerReplay?.provider === 'anthropic' &&
      Array.isArray(message.providerReplay.content)
    ) {
      out.push({ role: 'assistant', content: message.providerReplay.content as ContentBlockParam[] });
      continue;
    }

    const content: ContentBlockParam[] = [];
    if (message.content.length > 0) content.push({ type: 'text', text: message.content });
    for (const call of message.toolCalls ?? []) {
      content.push({
        type: 'tool_use',
        id: call.id,
        name: call.name,
        input: (call.args ?? {}) as Record<string, unknown>,
      });
    }
    if (content.length === 0) continue;
    out.push({ role: message.role, content });
  }

  return out;
}

/**
 * Put a cache breakpoint on the newest message, so round 2 of a turn reads
 * round 1's history from cache. Only on block types that accept one; a turn
 * ending in anything else simply goes without.
 */
function withHistoryBreakpoint(messages: MessageParam[]): MessageParam[] {
  const last = messages[messages.length - 1];
  if (!last || last.role !== 'user') return messages;
  const blocks: ContentBlockParam[] =
    typeof last.content === 'string' ? [{ type: 'text', text: last.content }] : [...last.content];
  const tail = blocks[blocks.length - 1];
  if (!tail || (tail.type !== 'text' && tail.type !== 'tool_result')) return messages;
  blocks[blocks.length - 1] = { ...tail, cache_control: { type: 'ephemeral' } } as
    | TextBlockParam
    | ToolResultBlockParam;
  return [...messages.slice(0, -1), { role: 'user', content: blocks }];
}

/**
 * Vendor usage → ours.
 *
 * Anthropic's `input_tokens` **excludes** both cache reads and cache writes, so
 * the three are added back to give a prompt size comparable with Gemini's
 * `promptTokenCount`, while each bucket is priced at its own rate. Web searches
 * are billed per use on top of tokens, so they are folded into `costCents` —
 * leaving them out would make a searched turn look as cheap as an unsearched one.
 */
export function normaliseAnthropicUsage(raw: unknown): Usage {
  const usage = (raw ?? {}) as {
    input_tokens?: number | null;
    output_tokens?: number | null;
    cache_read_input_tokens?: number | null;
    cache_creation_input_tokens?: number | null;
    server_tool_use?: { web_search_requests?: number | null } | null;
  };

  const fresh = usage.input_tokens ?? 0;
  const cacheRead = usage.cache_read_input_tokens ?? 0;
  const cacheWrite = usage.cache_creation_input_tokens ?? 0;
  const output = usage.output_tokens ?? 0;
  const searches = usage.server_tool_use?.web_search_requests ?? 0;

  const usd =
    (fresh / 1_000_000) * RATES.inputPerMTok +
    (cacheRead / 1_000_000) * RATES.cachedInputPerMTok +
    (cacheWrite / 1_000_000) * RATES.cacheWritePerMTok +
    (output / 1_000_000) * RATES.outputPerMTok +
    searches * RATES.perWebSearch;

  return {
    inputTokens: fresh + cacheRead + cacheWrite,
    outputTokens: output,
    cacheReadTokens: cacheRead,
    costCents: Math.round(usd * 100 * 10_000) / 10_000,
  };
}

/**
 * A user-safe code and message for a vendor failure.
 *
 * **`provider_error` means an outage, and only an outage**: a 5xx, an
 * `overloaded_error` / `api_error` in the stream, a timeout, or a dropped
 * connection. `providers/fallback.ts` keys on exactly that code to decide
 * whether retrying on Gemini is sane, so anything that would fail identically
 * elsewhere — a 4xx, a bad key, a bug of ours — must classify as something else.
 *
 * The vendor's text never reaches `message`: it carries request ids, model
 * names and occasionally prompt fragments. It goes to the log.
 */
export function classifyAnthropicError(err: unknown): { code: string; message: string } {
  if (err instanceof ProviderNotConfiguredError) {
    return { code: 'not_configured', message: 'The assistant is not configured yet.' };
  }
  if (
    err instanceof Anthropic.APIUserAbortError ||
    (err as { name?: string } | undefined)?.name === 'AbortError'
  ) {
    return { code: 'aborted', message: 'Request cancelled.' };
  }
  // Connection and timeout errors are a subclass of APIError with no status, so
  // they are checked before the status switch.
  if (err instanceof Anthropic.APIConnectionError) {
    return { code: 'provider_error', message: 'Something went wrong. Please try again.' };
  }
  if (err instanceof Anthropic.APIError) {
    const status = err.status;
    const type = (err as { type?: string | null }).type ?? undefined;
    if (status === 429 || type === 'rate_limit_error') {
      return { code: 'rate_limited', message: 'The assistant is busy right now. Try again shortly.' };
    }
    if (status === 401 || status === 403 || type === 'authentication_error' || type === 'permission_error') {
      return { code: 'provider_unavailable', message: 'The assistant is unavailable right now.' };
    }
    if ((typeof status === 'number' && status >= 500) || type === 'overloaded_error' || type === 'api_error') {
      return { code: 'provider_error', message: 'Something went wrong. Please try again.' };
    }
    if (typeof status === 'number' && status >= 400) {
      return { code: 'bad_request', message: 'The assistant could not process that request.' };
    }
  }
  // Not an HTTP outage: a bug of ours or an unexpected throw. Retrying it on
  // another vendor would hide it, so it is deliberately not `provider_error`.
  return { code: 'internal_error', message: 'Something went wrong. Please try again.' };
}

interface RoundResult {
  /** The assistant content blocks, reassembled from the stream. */
  content: Record<string, unknown>[];
  stopReason: string | null;
  usage: Record<string, unknown>;
}

export function createAnthropicProvider(options: AnthropicProviderOptions = {}): LlmProvider {
  const orchestratorModel = options.models?.orchestrator ?? ANTHROPIC_ORCHESTRATOR_MODEL;
  const quarantineModel = options.models?.quarantine ?? ANTHROPIC_QUARANTINE_MODEL;

  // Built lazily, for the same reason as Gemini's: importing this module must
  // not throw in CI, where no key exists.
  let client: AnthropicClient | undefined = options.client;
  function getClient(): AnthropicClient {
    if (client) return client;
    const apiKey = options.apiKey ?? process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      throw new ProviderNotConfiguredError(
        'ANTHROPIC_API_KEY is not set. It is declared in backend/.env.example; ' +
          'copy it into backend/.env before running an assistant turn on LLM_PROVIDER=anthropic.',
      );
    }
    client = new Anthropic({
      apiKey,
      // One SDK retry, not the default two: an outage should reach the Gemini
      // fallback in seconds, not after three slow failures.
      maxRetries: Number(process.env.ANTHROPIC_MAX_RETRIES ?? 1),
      timeout: Number(process.env.ANTHROPIC_TIMEOUT_MS ?? 60_000),
    }) as unknown as AnthropicClient;
    return client;
  }

  return {
    name: 'anthropic',
    models: { orchestrator: orchestratorModel, quarantine: quarantineModel },
    normaliseUsage: normaliseAnthropicUsage,

    async *runTurn(input: TurnInput, signal: AbortSignal): AsyncIterable<TurnEvent> {
      if (signal.aborted) {
        yield { type: 'error', code: 'aborted', message: 'Request cancelled.' };
        return;
      }

      const quarantine = input.model === 'quarantine';
      const model = quarantine ? quarantineModel : orchestratorModel;

      // The quarantine pass reaches the model with no tools at all — the
      // dual-LLM defence rests on absence, not on a policy flag. The final
      // orchestrator round keeps its declarations (they are the cached prefix,
      // and history may hold tool_use blocks that need them) and is fenced by
      // `tool_choice: none` instead.
      const tools: ToolUnion[] = quarantine
        ? []
        : [
            ...toAnthropicTools(input.tools),
            ...(input.webSearch ? [ANTHROPIC_WEB_SEARCH_TOOL] : []),
          ];
      const toolChoiceNone = input.toolChoice === 'none';

      const baseParams: Omit<MessageCreateParamsStreaming, 'messages'> = {
        model,
        max_tokens: MAX_TOKENS,
        stream: true,
        // NOT a message. The breakpoint here caches `[tools][system]`.
        system: [{ type: 'text', text: input.system, cache_control: { type: 'ephemeral' } }],
        ...(tools.length > 0
          ? { tools, tool_choice: toolChoiceNone ? { type: 'none' } : { type: 'auto' } }
          : {}),
        // Adaptive thinking on the orchestrator: Claude decides per round how
        // much to reason, and it works with tool use. Thinking text is omitted
        // from the stream by default and is never streamed to the user here
        // either; only its signature travels, inside the replay. The quarantine
        // tier summarises — it does not need to think, and Haiku 4.5 does not
        // take the adaptive form.
        ...(quarantine ? {} : { thinking: { type: 'adaptive' as const } }),
      };

      let messages = withHistoryBreakpoint(toAnthropicMessages(input.messages));
      const replay: Record<string, unknown>[] = [];
      const sources: RawWebSource[] = [];
      const pageAges = new Map<string, string>();
      const usageTotals: Record<string, number> = {};
      let callCount = 0;

      try {
        for (let continuation = 0; ; continuation += 1) {
          let round: RoundResult | undefined;
          for await (const event of streamRound(
            getClient(),
            { ...baseParams, messages },
            signal,
            pageAges,
            sources,
          )) {
            if ('round' in event) round = event.round;
            else {
              if (event.type === 'tool_call') callCount += 1;
              yield event;
            }
          }
          if (!round) break;
          replay.push(...round.content);
          accumulateUsage(usageTotals, round.usage);

          if (round.stopReason === 'refusal') {
            yield { type: 'error', code: 'blocked', message: 'The assistant could not answer that.' };
            return;
          }
          // A paused server-side search: send what we have back and let it
          // carry on. Bounded, because every continuation is a paid request.
          if (round.stopReason !== 'pause_turn' || continuation >= MAX_PAUSE_CONTINUATIONS) break;
          messages = [
            ...messages,
            { role: 'assistant', content: round.content as unknown as ContentBlockParam[] },
          ];
        }
      } catch (err) {
        if (signal.aborted) {
          yield { type: 'error', code: 'aborted', message: 'Request cancelled.' };
          return;
        }
        const { code, message } = classifyAnthropicError(err);
        // Logged by class and status only — never the raw error object, whose
        // request echo can carry headers.
        // The configuration message is ours and names the fix, so it is logged
        // whole; nothing else from the error is.
        const detail =
          err instanceof ProviderNotConfiguredError
            ? err.message
            : `${(err as { name?: string })?.name ?? 'Error'} ${(err as { status?: number })?.status ?? ''}`.trim();
        console.error(`[assistant] anthropic turn failed: ${code} (${detail})`);
        yield { type: 'error', code, message };
        return;
      }

      // Only a round that asked for tools is replayed, so only it pays for the
      // event. A text-only round ends the turn.
      if (callCount > 0) yield { type: 'replay', content: replay };
      if (sources.length > 0) {
        yield {
          type: 'sources',
          sources: sources.map((s) => ({ ...s, pageAge: s.pageAge ?? pageAges.get(s.url) ?? null })),
        };
      }
      yield { type: 'usage', usage: normaliseAnthropicUsage(usageTotals) };
      yield { type: 'done' };
    },
  };
}

function accumulateUsage(totals: Record<string, number>, usage: Record<string, unknown>): void {
  for (const key of ['input_tokens', 'output_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens']) {
    const value = usage[key];
    if (typeof value === 'number') totals[key] = (totals[key] ?? 0) + value;
  }
  const searches = (usage.server_tool_use as { web_search_requests?: number } | null | undefined)
    ?.web_search_requests;
  if (typeof searches === 'number') {
    const existing = (totals as unknown as { server_tool_use?: { web_search_requests: number } })
      .server_tool_use;
    (totals as unknown as { server_tool_use: { web_search_requests: number } }).server_tool_use = {
      web_search_requests: (existing?.web_search_requests ?? 0) + searches,
    };
  }
}

type StreamItem = TurnEvent | { round: RoundResult };

/**
 * One request: stream it, emit tokens as they arrive, and reassemble the
 * content blocks for replay.
 *
 * Tool calls are emitted when their block closes, because the arguments arrive
 * as JSON fragments and are only parseable once complete.
 */
async function* streamRound(
  client: AnthropicClient,
  params: MessageCreateParamsStreaming,
  signal: AbortSignal,
  pageAges: Map<string, string>,
  sources: RawWebSource[],
): AsyncGenerator<StreamItem> {
  const stream = await client.messages.create(params, { signal });

  const blocks: Record<string, unknown>[] = [];
  const partialJson = new Map<number, string>();
  let stopReason: string | null = null;
  let usage: Record<string, unknown> = {};

  for await (const event of stream) {
    if (signal.aborted) {
      const abort = new Error('aborted');
      abort.name = 'AbortError';
      throw abort;
    }

    switch (event.type) {
      case 'message_start':
        usage = { ...(event.message.usage as unknown as Record<string, unknown>) };
        break;

      case 'content_block_start': {
        const block = { ...(event.content_block as unknown as Record<string, unknown>) };
        blocks[event.index] = block;
        if (block.type === 'tool_use' || block.type === 'server_tool_use') {
          partialJson.set(event.index, '');
        }
        if (block.type === 'web_search_tool_result' && Array.isArray(block.content)) {
          for (const result of block.content as { url?: string; page_age?: string | null }[]) {
            if (result.url && result.page_age) pageAges.set(result.url, result.page_age);
          }
        }
        break;
      }

      case 'content_block_delta': {
        const block = blocks[event.index];
        if (!block) break;
        const delta = event.delta;
        switch (delta.type) {
          case 'text_delta':
            block.text = `${(block.text as string | undefined) ?? ''}${delta.text}`;
            if (delta.text.length > 0) yield { type: 'token', text: delta.text };
            break;
          case 'input_json_delta':
            partialJson.set(event.index, (partialJson.get(event.index) ?? '') + delta.partial_json);
            break;
          case 'thinking_delta':
            // Kept for replay; never streamed. Thinking is not the answer.
            block.thinking = `${(block.thinking as string | undefined) ?? ''}${delta.thinking}`;
            break;
          case 'signature_delta':
            block.signature = delta.signature;
            break;
          case 'citations_delta': {
            const citations = Array.isArray(block.citations) ? (block.citations as unknown[]) : [];
            citations.push(delta.citation);
            block.citations = citations;
            if (delta.citation.type === 'web_search_result_location') {
              sources.push({
                url: delta.citation.url,
                title: delta.citation.title,
                snippet: delta.citation.cited_text,
              });
            }
            break;
          }
        }
        break;
      }

      case 'content_block_stop': {
        const block = blocks[event.index];
        if (!block) break;
        if (partialJson.has(event.index)) {
          const json = partialJson.get(event.index) ?? '';
          let input: unknown = {};
          try {
            input = json.length > 0 ? JSON.parse(json) : (block.input ?? {});
          } catch {
            // A truncated argument blob. The orchestrator's schema check turns
            // `{}` into a named validation error the model can recover from.
            input = {};
          }
          block.input = input;
          if (block.type === 'tool_use') {
            yield {
              type: 'tool_call',
              id: String(block.id),
              name: String(block.name),
              args: input,
            };
          } else if (block.name === 'web_search') {
            yield { type: 'web_search' };
          }
        }
        break;
      }

      case 'message_delta':
        stopReason = event.delta.stop_reason ?? stopReason;
        // Cumulative: later fields win, absent ones keep message_start's value.
        for (const [key, value] of Object.entries(event.usage ?? {})) {
          if (value !== null && value !== undefined) usage[key] = value;
        }
        break;

      case 'message_stop':
        break;
    }
  }

  yield { round: { content: blocks.filter(Boolean), stopReason, usage } };
}
