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
}

export type Role = 'user' | 'assistant';

export interface Message {
  role: Role;
  content: string;
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
  /** The model wants a tool run. `id` correlates the later result. */
  | { type: 'tool_call'; id: string; name: string; args: unknown }
  | { type: 'usage'; usage: Usage }
  /** Terminal. `message` must be user-safe — never a stack trace or a raw vendor error. */
  | { type: 'error'; code: string; message: string }
  | { type: 'done' };
