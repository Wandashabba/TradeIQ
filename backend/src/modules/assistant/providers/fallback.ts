import type { LlmProvider, Message, ProviderName, TurnEvent, TurnInput } from './types';

/**
 * Outage fallback: run on the primary, and when it is *down*, answer on the
 * secondary instead of showing a manager "something went wrong".
 *
 * The rules are narrow on purpose, because each relaxation is a way to be wrong
 * more expensively:
 *
 * 1. **Only an outage.** The primary must have reported `provider_error`, which
 *    the Anthropic adapter reserves for a 5xx, an overloaded/api error in the
 *    stream, a timeout, or a dropped connection. A 4xx, a bad key, a rate limit,
 *    a refusal or a bug of ours fails the same way anywhere, so retrying it just
 *    doubles the bill and hides the real fault.
 * 2. **Only before anything reached the user.** If the primary emitted a single
 *    token, tool call or source before failing, the error passes through. A
 *    second vendor restarting an answer the user is already reading produces a
 *    stitched, contradictory reply — worse than an honest error.
 * 3. **Once per round, and then sticky.** A turn that fell back stays on the
 *    secondary for its remaining rounds (this wrapper is built per request), so
 *    a flapping primary cannot alternate vendors mid-turn.
 *
 * The provider is otherwise still pinned per conversation: the wrapper *is* the
 * pinned provider, and the secondary is its contingency, not a second choice.
 */

/** The error codes that mean "the vendor is down", as adapters classify them. */
export const OUTAGE_CODES: ReadonlySet<string> = new Set(['provider_error']);

/**
 * Gemini 3's documented placeholder for a function call it did not sign.
 *
 * When a turn falls back after round 1, history holds the primary's tool calls,
 * which carry no Gemini thought signature — and Gemini 3 rejects an unsigned
 * `functionCall` outright. Google documents this value for exactly that case
 * (history transferred from another model). It is stamped only onto calls with
 * no signature at all, and only on the fallback path.
 */
export const FOREIGN_CALL_SIGNATURE = 'skip_thought_signature_validator';

/** Give a secondary provider history it can accept from another vendor. */
export function forForeignProvider(messages: readonly Message[], target: ProviderName): Message[] {
  if (target !== 'gemini') return [...messages];
  return messages.map((message) => {
    if (message.role === 'tool' || !message.toolCalls?.length) return message;
    return {
      ...message,
      toolCalls: message.toolCalls.map((call) =>
        call.providerSignature ? call : { ...call, providerSignature: FOREIGN_CALL_SIGNATURE },
      ),
    };
  });
}

export function withFallback(primary: LlmProvider, secondary: LlmProvider): LlmProvider {
  let active: LlmProvider = primary;

  const wrapper: LlmProvider = {
    get name() {
      return active.name;
    },
    get models() {
      return active.models;
    },
    get fallbackFrom() {
      return active === primary ? undefined : primary.name;
    },
    normaliseUsage: (raw) => active.normaliseUsage(raw),

    async *runTurn(input: TurnInput, signal: AbortSignal): AsyncIterable<TurnEvent> {
      if (active === secondary) {
        yield* secondary.runTurn({ ...input, messages: forForeignProvider(input.messages, secondary.name) }, signal);
        return;
      }

      let reachedUser = false;
      for await (const event of primary.runTurn(input, signal)) {
        if (
          event.type === 'error' &&
          !reachedUser &&
          !signal.aborted &&
          OUTAGE_CODES.has(event.code)
        ) {
          console.warn(
            `[assistant] ${primary.name} outage (${event.code}) before any output — ` +
              `answering this turn on ${secondary.name}`,
          );
          active = secondary;
          yield* secondary.runTurn(
            { ...input, messages: forForeignProvider(input.messages, secondary.name) },
            signal,
          );
          return;
        }
        if (event.type !== 'usage' && event.type !== 'done' && event.type !== 'error') {
          reachedUser = true;
        }
        yield event;
      }
    },
  };

  return wrapper;
}
