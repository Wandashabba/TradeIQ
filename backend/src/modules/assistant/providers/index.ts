import { createAnthropicProvider } from './anthropic';
import { withFallback } from './fallback';
import { createGeminiProvider } from './gemini';
import type { LlmProvider, ProviderName } from './types';

export * from './types';
export { createAnthropicProvider } from './anthropic';
export { createGeminiProvider } from './gemini';
export { withFallback } from './fallback';

/**
 * Which provider a new conversation gets.
 *
 * **Pinned per conversation, never per turn.** History carries vendor-specific
 * artifacts — thinking blocks, tool-call shapes — that do not transfer, and
 * switching mid-thread invalidates the cached prefix regardless. So this is
 * read once, when a conversation starts, and recorded on it. Anything that
 * calls this per turn has reintroduced the bug.
 */
export function defaultProviderName(): ProviderName {
  const configured = process.env.LLM_PROVIDER?.trim().toLowerCase();
  if (configured === 'anthropic') return 'anthropic';
  if (configured === 'gemini') return 'gemini';
  if (configured) {
    // Naming the bad value beats silently running on a provider nobody chose —
    // which would show up as an unexpected line on the bill, not as an error.
    throw new Error(
      `LLM_PROVIDER is "${configured}", which is not a provider. Set it to "gemini" or "anthropic".`,
    );
  }
  // Gemini is the default because its key is the one that exists. The
  // Anthropic adapter has landed and this stays as-is: the default is a
  // deployment choice, not a preference expressed in code.
  return 'gemini';
}

/**
 * Build the adapter for a provider name.
 *
 * `anthropic` is wrapped in an outage fallback to Gemini **when a Gemini key
 * exists** — see `fallback.ts` for the narrow rules (outage only, before any
 * output, once). Without the key there is nothing to fall back to, and the
 * primary's error reaches the user as it always did. `LLM_FALLBACK=off` turns
 * the wrapper off, for a measurement that must be one vendor only.
 *
 * Gemini as primary has no fallback: it is the provider whose key exists, and
 * falling back to a provider nobody has configured would only change which
 * error the user sees.
 */
export function providerFor(name: ProviderName = defaultProviderName()): LlmProvider {
  switch (name) {
    case 'gemini':
      return createGeminiProvider();
    case 'anthropic': {
      const primary = createAnthropicProvider();
      const fallbackOff = process.env.LLM_FALLBACK?.trim().toLowerCase() === 'off';
      if (fallbackOff || !process.env.GEMINI_API_KEY) return primary;
      return withFallback(primary, createGeminiProvider());
    }
    default: {
      // Exhaustiveness: adding a ProviderName without an adapter fails the build
      // here rather than at runtime on a customer's turn.
      const unreachable: never = name;
      throw new Error(`Unknown provider: ${String(unreachable)}`);
    }
  }
}
