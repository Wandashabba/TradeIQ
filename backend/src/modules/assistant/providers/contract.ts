import { z } from 'zod';
import type { AnyAssistantTool } from '../types';
import type { LlmProvider, TurnEvent, TurnInput } from './types';

/**
 * The provider contract suite.
 *
 * Every adapter runs the **same scripted turn** and must emit the **same
 * normalised `TurnEvent` stream**. This is the test that stops the second
 * adapter from silently diverging — passing its own tests while behaving
 * differently in production, which the plan names as a top risk.
 *
 * The shape matters. The suite does not test Gemini or Anthropic; it tests
 * *the contract*, and each adapter supplies only the translation of an abstract
 * script into its own wire format. That translation is the one thing an adapter
 * is allowed to do differently — so it is the one thing the subject provides,
 * and everything else is asserted identically.
 *
 * Deliberately **no key and no network**. A contract test that needs a live
 * provider runs on one developer's machine and nowhere else, which is how a
 * contract stops being enforced. Live behaviour is the eval suite's job.
 *
 * This file is not named `*.test.ts` on purpose: it is a suite *definition*
 * that adapters import, not a suite that runs on its own.
 */

/** A vendor-neutral description of one turn coming back from a model. */
export interface ScriptedTurn {
  /** Narrative text, already split into the chunks the vendor would stream. */
  textChunks?: string[];
  /** Tool calls the model asks for, in order. */
  toolCalls?: { name: string; args: Record<string, unknown> }[];
  /** Raw token counts. Each adapter maps these onto its vendor's usage field names. */
  usage?: { promptTokens: number; outputTokens: number; cachedTokens: number };
  /** When set, the vendor call rejects with this instead of streaming. */
  failWith?: Error;
}

export interface ContractSubject {
  /** Adapter name, used in the test titles. */
  readonly name: string;
  /**
   * Build a provider whose next `runTurn` replays `script` in this vendor's
   * wire shape. No key, no network.
   */
  providerFor(script: ScriptedTurn): LlmProvider;
}

export const CONTRACT_TOOL: AnyAssistantTool = {
  name: 'getAgentScorecard',
  pillar: 'execution',
  description: 'Call this when the user asks how a named field agent has been performing.',
  args: z.object({ agentId: z.string() }) as unknown as AnyAssistantTool['args'],
  run: async () => ({ ok: true }),
};

export function contractInput(overrides: Partial<TurnInput> = {}): TurnInput {
  return {
    system: 'You are TradeIQ.',
    tools: [CONTRACT_TOOL],
    messages: [{ role: 'user', content: 'How has Tumo been performing this month?' }],
    ...overrides,
  };
}

export async function collect(events: AsyncIterable<TurnEvent>): Promise<TurnEvent[]> {
  const out: TurnEvent[] = [];
  for await (const event of events) out.push(event);
  return out;
}

/**
 * Assert the contract against one adapter.
 *
 * Call from that adapter's own `*.test.ts`:
 * `runProviderContract({ name: 'gemini', providerFor })`.
 */
export function runProviderContract(subject: ContractSubject): void {
  describe(`LlmProvider contract — ${subject.name}`, () => {
    it('streams text as token events, then usage, then done', async () => {
      const provider = subject.providerFor({
        textChunks: ['Tumo ', 'is up 6 points.'],
        usage: { promptTokens: 1200, outputTokens: 40, cachedTokens: 0 },
      });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      expect(events.map((e) => e.type)).toEqual(['token', 'token', 'usage', 'done']);
      expect(events[0]).toEqual({ type: 'token', text: 'Tumo ' });
      expect(events[1]).toEqual({ type: 'token', text: 'is up 6 points.' });
    });

    it('emits done exactly once, and last', async () => {
      const provider = subject.providerFor({
        textChunks: ['hello'],
        usage: { promptTokens: 10, outputTokens: 2, cachedTokens: 0 },
      });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const doneCount = events.filter((e) => e.type === 'done').length;
      expect(doneCount).toBe(1);
      expect(events[events.length - 1]).toEqual({ type: 'done' });
    });

    it('emits a usage event even when the vendor reports none', async () => {
      // A missing usage event reads downstream as a free turn, so the adapter
      // must synthesise a zeroed one rather than staying silent.
      const provider = subject.providerFor({ textChunks: ['hi'] });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const usage = events.find((e) => e.type === 'usage');
      expect(usage).toBeDefined();
    });

    it('surfaces a tool call with a correlation id, name and args', async () => {
      const provider = subject.providerFor({
        toolCalls: [{ name: 'getAgentScorecard', args: { agentId: 'agent-1' } }],
        usage: { promptTokens: 900, outputTokens: 12, cachedTokens: 0 },
      });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const call = events.find((e) => e.type === 'tool_call');
      expect(call).toMatchObject({
        type: 'tool_call',
        name: 'getAgentScorecard',
        args: { agentId: 'agent-1' },
      });
      // The id is what the later result correlates against, so it must exist
      // and be a non-empty string whether or not the vendor supplied one.
      expect(typeof (call as { id: string }).id).toBe('string');
      expect((call as { id: string }).id.length).toBeGreaterThan(0);
    });

    it('gives parallel tool calls distinct correlation ids', async () => {
      // Two calls sharing an id is the bug that makes a parallel turn return
      // the same tool's result twice — and it looks correct in a single-call test.
      const provider = subject.providerFor({
        toolCalls: [
          { name: 'getAgentScorecard', args: { agentId: 'a' } },
          { name: 'getAgentScorecard', args: { agentId: 'b' } },
        ],
      });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const ids = events.filter((e) => e.type === 'tool_call').map((e) => (e as { id: string }).id);
      expect(ids).toHaveLength(2);
      expect(new Set(ids).size).toBe(2);
    });

    it('normalises cache hits onto cacheReadTokens', async () => {
      // The vendors name this field differently; the CI cost assertion reads
      // ours. This is the whole reason normaliseUsage is on the interface.
      const provider = subject.providerFor({
        textChunks: ['cached'],
        usage: { promptTokens: 5000, outputTokens: 20, cachedTokens: 4800 },
      });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const usage = events.find((e) => e.type === 'usage') as { usage: { cacheReadTokens: number } };
      expect(usage.usage.cacheReadTokens).toBe(4800);
    });

    it('prices a cached turn below an uncached one of the same size', async () => {
      // The economic claim behind the frozen prompt prefix. If an adapter
      // double-counts cached tokens this inverts, and nothing else would notice.
      const cached = subject.providerFor({
        usage: { promptTokens: 5000, outputTokens: 20, cachedTokens: 4800 },
      });
      const uncached = subject.providerFor({
        usage: { promptTokens: 5000, outputTokens: 20, cachedTokens: 0 },
      });

      const cost = async (p: LlmProvider) => {
        const events = await collect(p.runTurn(contractInput(), new AbortController().signal));
        return (events.find((e) => e.type === 'usage') as { usage: { costCents: number } }).usage
          .costCents;
      };

      expect(await cost(cached)).toBeLessThan(await cost(uncached));
    });

    it('reports a vendor failure as a terminal error event, not a throw', async () => {
      // A throw escapes the SSE stream and the client sees a dead connection
      // with no reason. Every adapter must end the stream by yielding.
      const provider = subject.providerFor({ failWith: new Error('kaboom: internal detail') });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const error = events.find((e) => e.type === 'error') as { code: string; message: string };
      expect(error).toBeDefined();
      expect(typeof error.code).toBe('string');
      expect(error.message.length).toBeGreaterThan(0);
    });

    it('never leaks the vendor error text to the user-facing message', async () => {
      const provider = subject.providerFor({
        failWith: new Error('project 12345 quota for model gemini-x exceeded; trace abc-def'),
      });

      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      const error = events.find((e) => e.type === 'error') as { message: string };
      expect(error.message).not.toMatch(/12345|trace|abc-def/);
    });

    it('aborts before opening a request when the signal is already aborted', async () => {
      // A client that disconnected while queued should not open a paid request
      // at all. Checking only inside the loop is one round trip too late.
      const controller = new AbortController();
      controller.abort();
      const provider = subject.providerFor({ textChunks: ['should not be sent'] });

      const events = await collect(provider.runTurn(contractInput(), controller.signal));

      expect(events).toEqual([
        { type: 'error', code: 'aborted', message: expect.any(String) },
      ]);
    });

    it('exposes an orchestrator and a quarantine model', async () => {
      // The dual-LLM quarantine pattern needs a cheaper tier on every provider.
      // An adapter offering only one model cannot support it.
      const provider = subject.providerFor({});
      expect(provider.models.orchestrator).toBeTruthy();
      expect(provider.models.quarantine).toBeTruthy();
      expect(provider.models.orchestrator).not.toBe(provider.models.quarantine);
    });
  });
}
