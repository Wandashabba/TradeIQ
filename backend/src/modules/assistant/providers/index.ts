import { createGeminiProvider } from './gemini';
import type { LlmProvider, ProviderName } from './types';

export * from './types';
export { createGeminiProvider } from './gemini';

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
  // Gemini is the default because its key is the one that exists. When the
  // Anthropic adapter lands this stays as-is: the default is a deployment
  // choice, not a preference expressed in code.
  return 'gemini';
}

/**
 * Build the adapter for a provider name.
 *
 * `anthropic` is declared and throws rather than being absent from the union.
 * A conversation pinned to a provider whose adapter has not shipped is a real
 * state once the flag can be set, and "no such provider" is a clearer failure
 * than a `undefined is not a function` three frames into the orchestrator.
 */
export function providerFor(name: ProviderName = defaultProviderName()): LlmProvider {
  switch (name) {
    case 'gemini':
      return createGeminiProvider();
    case 'anthropic':
      throw new Error(
        'The Anthropic adapter has not been written yet — it is waiting on ANTHROPIC_API_KEY. ' +
          'Set LLM_PROVIDER=gemini, or add providers/anthropic.ts and run the contract suite ' +
          'against it (see providers/contract.ts).',
      );
    default: {
      // Exhaustiveness: adding a ProviderName without an adapter fails the build
      // here rather than at runtime on a customer's turn.
      const unreachable: never = name;
      throw new Error(`Unknown provider: ${String(unreachable)}`);
    }
  }
}
