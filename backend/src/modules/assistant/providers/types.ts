import type { AnyAssistantTool } from '../types';

/**
 * The only vendor-aware seam in the system.
 *
 * An adapter's entire job is: vendor stream → {@link TurnEvent}. Everything
 * above this file — orchestrator, routes, Flutter client — is vendor-blind.
 * The interface stays deliberately narrow (two methods) because a wider one is
 * a contract that cannot actually be held across two vendors.
 *
 * What each adapter absorbs and must not leak upward:
 *
 * | Concern       | Anthropic                      | Gemini                              |
 * |---------------|--------------------------------|-------------------------------------|
 * | Tool calls    | `tool_use` content blocks      | `function_call` steps               |
 * | System prompt | top-level `system` parameter   | handled differently — the most      |
 * |               |                                | common migration bug                |
 * | Caching       | explicit `cache_control`       | implicit; explicit `CachedContent`  |
 * | Usage field   | `cache_read_input_tokens`      | `cachedContentTokenCount`           |
 *
 * **Provider is pinned per conversation**, never per turn: history carries
 * vendor-specific artifacts that do not transfer, and switching invalidates the
 * cached prefix regardless.
 */
export interface LlmProvider {
  readonly name: ProviderName;
  readonly models: { orchestrator: string; quarantine: string };

  /**
   * Run one turn. The `signal` is not optional courtesy — a client that
   * disconnects mid-turn must abort the provider call rather than orphan a
   * request we still pay for.
   */
  runTurn(input: TurnInput, signal: AbortSignal): AsyncIterable<TurnEvent>;

  /** Vendor usage payload → our shape. Hides the cache-field naming split. */
  normaliseUsage(raw: unknown): Usage;

  /**
   * Set only on a fallback wrapper, and only once the fallback actually
   * answered: the provider the turn was meant to run on. Read by tracing so a
   * turn served by the secondary is attributable rather than invisible — see
   * `providers/fallback.ts`.
   */
  readonly fallbackFrom?: ProviderName;
}

export type ProviderName = 'anthropic' | 'gemini';

export interface TurnInput {
  /**
   * Frozen. No interpolation, ever.
   *
   * Caching is a prefix match, so a single interpolated value here — a
   * timestamp, the user's name — turns every turn into a cache miss. That is a
   * cost regression no functional test would catch, which is why CI asserts on
   * `cacheReadTokens` instead of trusting review.
   */
  system: string;
  /** Our shape; the adapter converts to the vendor's tool declaration format. */
  tools: readonly AnyAssistantTool[];
  messages: readonly Message[];
  toolChoice?: 'auto' | 'none';
  /**
   * Which of the provider's two model tiers to run on. Defaults to
   * `orchestrator`.
   *
   * The quarantine pass is the reason this exists: it is a deliberately cheap,
   * deliberately tool-less call over untrusted text, and running it on the
   * orchestrator model would multiply the cost of every turn carrying a visit
   * note. Naming a *tier* rather than a model id keeps the caller vendor-blind
   * — `providers/index.ts` is the only place a model string is chosen.
   */
  model?: 'orchestrator' | 'quarantine';
  /**
   * Offer the model the vendor's live web search for this turn.
   *
   * A request, not a guarantee: an adapter whose vendor or configured model
   * cannot combine search with function calling ignores it, and the frozen
   * prompt tells the model to say so when it has no search. Never honoured on
   * the quarantine tier — a tool-less pass must stay tool-less.
   */
  webSearch?: boolean;
}

export type Role = 'user' | 'assistant';

/**
 * What the model said, or what the user asked.
 *
 * `toolCalls` records the calls an assistant turn requested. It has to be
 * carried on the message rather than reconstructed, because both vendors
 * require the assistant's own tool-call turn to be present in history before
 * the matching results — omit it and Gemini rejects the request outright while
 * Anthropic accepts a subtly wrong conversation.
 */
export interface TextMessage {
  role: Role;
  content: string;
  toolCalls?: readonly ToolCallRecord[];
  /**
   * The vendor's own rendering of this assistant turn, replayed verbatim by the
   * adapter that produced it and ignored by every other.
   *
   * Exists because a turn that used a *server-side* tool (live web search)
   * carries blocks we never see as tool calls — encrypted search results,
   * signed thinking — and both vendors refuse a follow-up request that drops
   * them. Opaque above the adapter, exactly like
   * {@link ToolCallRecord.providerSignature}, and never persisted beyond the turn.
   */
  providerReplay?: { provider: ProviderName; content: unknown };
}

/** One tool call the model asked for, as replayed back to it in history. */
export interface ToolCallRecord {
  id: string;
  name: string;
  args: unknown;

  /**
   * Vendor-opaque token the provider attached to this call, replayed verbatim
   * when the call goes back in history. Never inspected, never logged, never
   * persisted beyond the turn — treat it as a blob the vendor handed us.
   *
   * Gemini 3.x rejects a follow-up request outright (400 INVALID_ARGUMENT) when
   * a `functionCall` comes back without the `thoughtSignature` it was issued
   * with. Since the model's tool-call turn *must* be in history before the
   * matching results, dropping the token breaks every multi-round turn — the
   * first tool runs, and the request that carries its result is refused.
   * Anthropic has no equivalent, so it leaves this unset.
   */
  providerSignature?: string;
}

/**
 * The result of running one tool, on its way back to the model.
 *
 * **`content` is a string, deliberately.** By the time a result reaches here it
 * has been through `sanitize.ts` and is spotlight-wrapped as untrusted data —
 * wrapping produces text, and re-parsing it into structured fields would undo
 * the wrapping that makes it safe to show the model.
 *
 * `ok: false` carries a failed tool run rather than aborting the turn. A tool
 * that throws is a normal event — a stale id, an empty period — and the model
 * recovers better from "that returned nothing" than from a dropped turn.
 */
export interface ToolResultMessage {
  role: 'tool';
  /** Correlates with the `id` of the {@link TurnEvent} `tool_call` that asked for it. */
  callId: string;
  name: string;
  ok: boolean;
  content: string;
}

/**
 * Amended from `{ role, content }` when the first adapter landed.
 *
 * A `tool_runner` loop cannot be expressed without a way to send results back:
 * `TurnEvent`'s `tool_call.id` exists specifically to "correlate the later
 * result", and there was no message shape carrying one. The union is additive —
 * `TextMessage` is the original shape — so it widens the contract rather than
 * changing it, and `content: string` stays universal across all variants.
 */
export type Message = TextMessage | ToolResultMessage;

export function isToolResult(message: Message): message is ToolResultMessage {
  return message.role === 'tool';
}

export interface Usage {
  inputTokens: number;
  outputTokens: number;
  /** Normalised across `cache_read_input_tokens` / `cachedContentTokenCount`. */
  cacheReadTokens: number;
  costCents: number;
}

/**
 * What a provider adapter may emit.
 *
 * **This is deliberately narrower than the SSE wire vocabulary**, and the
 * difference is not an omission. `artifact` and `confirm` are ours: an artifact
 * is a validated view spec drawn from our closed catalog, and a confirm is our
 * risk gate. No model stream can produce either, so putting them in this union
 * would oblige every adapter to declare cases it can never emit.
 *
 * The orchestrator maps this vocabulary onto the wire:
 *
 * | TurnEvent    | Becomes on the wire                                        |
 * |--------------|------------------------------------------------------------|
 * | `token`      | `token`                                                    |
 * | `tool_call`  | `tool_start` before `run()`, `tool_end` after              |
 * | —            | `artifact` — orchestrator, from the validated view spec     |
 * | —            | `confirm` — orchestrator, from the risk tier               |
 * | `usage`      | `usage`                                                    |
 * | `error`      | `error`                                                    |
 * | `done`       | `done`                                                     |
 *
 * The design spec calls the SSE table "the normalisation boundary". It is —
 * for the client. This union is the same boundary one layer lower, where the
 * vendor differences actually live. Worth confirming against the spec before
 * the first adapter is written.
 */
export type TurnEvent =
  | { type: 'token'; text: string }
  /**
   * The model wants a tool run. `id` correlates the later result.
   *
   * `signature` is the vendor-opaque token that must travel back with this call
   * in history — see {@link ToolCallRecord.providerSignature}. Absent for
   * providers that do not issue one.
   */
  | { type: 'tool_call'; id: string; name: string; args: unknown; signature?: string }
  | { type: 'usage'; usage: Usage }
  /**
   * The model ran the vendor's server-side web search. No arguments and no
   * result: the vendor executed it, and the only thing above the adapter needs
   * is that it happened (a working step, a trace span).
   */
  | { type: 'web_search' }
  /**
   * Web pages the answer cited, un-validated. The orchestrator owns turning
   * these into something safe to publish — see `sources.ts`.
   */
  | { type: 'sources'; sources: RawWebSource[] }
  /**
   * The vendor's rendering of this round's assistant turn, for
   * {@link TextMessage.providerReplay}. Emitted only by a round that asked for
   * tools, since only those rounds are replayed.
   */
  | { type: 'replay'; content: unknown }
  /** Terminal. `message` must be user-safe — never a stack trace or a raw vendor error. */
  | { type: 'error'; code: string; message: string }
  | { type: 'done' };

/**
 * One cited web page as a vendor reported it — before any validation.
 *
 * Everything here is untrusted: the title and snippet are written by whoever
 * owns the page, and the url is whatever the search index holds.
 */
export interface RawWebSource {
  url: string;
  title?: string | null;
  /** The cited passage, when the vendor exposes one. */
  snippet?: string | null;
  /** Free text from the vendor ("3 days ago", "April 30, 2025"), when known. */
  pageAge?: string | null;
  /**
   * When the page was actually read, ISO-8601, when that was BEFORE this turn —
   * a tool citing data it collected earlier (getCompetitorShelfPrices). Omitted
   * for a live web search, which was retrieved this turn.
   */
  retrievedAt?: string | null;
}
