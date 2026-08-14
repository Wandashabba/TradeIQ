import {
  GOLDEN_QUESTIONS,
  score,
  summarise,
  TOOL_SELECTION_THRESHOLD,
  type ScoredQuestion,
} from '../../../evals/golden-questions';
import { runTurn, type WireEvent } from './orchestrator';
import type { LlmProvider, TurnEvent, TurnInput } from './providers/types';
import { ALL_TOOL_NAMES } from './roster';
import { eraseToolTypes, type AnyAssistantTool } from './types';
import { z } from 'zod';

/**
 * The parts of the eval gate that run on **every commit**, without a key.
 *
 * The live accuracy sweep needs a provider and belongs in
 * `assistant-evals.yml`, gated behind a secret. What runs here is everything
 * that can be checked deterministically: that the dataset is well-formed, that
 * the scorer is honest, and that the cost regression assertion holds.
 *
 * The split matters. An eval suite that can only run with a key runs on one
 * machine, which is how a gate stops being a gate.
 */

describe('the golden question set', () => {
  it('has at least the 25 questions the plan calls for', () => {
    expect(GOLDEN_QUESTIONS.length).toBeGreaterThanOrEqual(25);
  });

  it('has unique ids', () => {
    const ids = GOLDEN_QUESTIONS.map((q) => q.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('only expects tools that exist in the registry', () => {
    // A question expecting a tool nobody built is a permanent, meaningless
    // miss that drags the whole rate down and teaches people to ignore it.
    const known = new Set<string>(ALL_TOOL_NAMES);
    for (const question of GOLDEN_QUESTIONS) {
      for (const name of [question.expectedTool, ...(question.acceptable ?? [])]) {
        if (name !== null && name !== undefined) expect(known).toContain(name);
      }
    }
  });

  it('covers every tool in the manager roster', () => {
    // A tool with no golden question is a tool whose selection accuracy is
    // unmeasured — so the 90% gate would pass while it was never chosen once.
    const covered = new Set(
      GOLDEN_QUESTIONS.flatMap((q) => [q.expectedTool, ...(q.acceptable ?? [])]).filter(Boolean),
    );
    for (const tool of ALL_TOOL_NAMES) {
      expect(covered).toContain(tool);
    }
  });

  it('covers all four pillars plus execution', () => {
    const prefixes = new Set(GOLDEN_QUESTIONS.map((q) => q.id.split('-')[0]));
    expect(prefixes).toEqual(new Set(['exec', 'sales', 'stock', 'vis', 'comp', 'refuse']));
  });

  it('includes refusal cases', () => {
    // A suite with no refusals rewards a model that always guesses, and
    // guessing is the failure mode the semantic layer exists to prevent.
    expect(GOLDEN_QUESTIONS.filter((q) => q.expectedTool === null).length).toBeGreaterThanOrEqual(2);
  });
});

describe('the scorer', () => {
  it('counts an exact match as a hit', () => {
    const q = { id: 'x', question: 'q', expectedTool: 'getStockLevels' };
    expect(score(q, 'getStockLevels').hit).toBe(true);
  });

  it('counts a listed alternative as a hit', () => {
    const q = { id: 'x', question: 'q', expectedTool: 'getSkuMovement', acceptable: ['getStockLevels'] };
    expect(score(q, 'getStockLevels').hit).toBe(true);
  });

  it('counts the wrong tool as a miss', () => {
    const q = { id: 'x', question: 'q', expectedTool: 'getStockLevels' };
    expect(score(q, 'getFraudFlags').hit).toBe(false);
  });

  it('treats calling nothing on a refusal question as a hit', () => {
    const q = { id: 'x', question: 'q', expectedTool: null };
    expect(score(q, null).hit).toBe(true);
  });

  it('treats calling anything on a refusal question as a miss', () => {
    // Excessive agency (OWASP LLM06). A model that reaches for a tool when the
    // honest answer is "I can't" is the failure this row exists to catch.
    const q = { id: 'x', question: 'q', expectedTool: null };
    expect(score(q, 'getStockLevels').hit).toBe(false);
  });

  it('treats calling nothing when a tool was expected as a miss', () => {
    const q = { id: 'x', question: 'q', expectedTool: 'getStockLevels' };
    expect(score(q, null).hit).toBe(false);
  });
});

describe('the gate', () => {
  const scored = (hits: number, total: number): ScoredQuestion[] =>
    Array.from({ length: total }, (_, i) => ({
      id: `q${i}`,
      question: 'q',
      expected: 'getStockLevels',
      actual: i < hits ? 'getStockLevels' : 'getFraudFlags',
      hit: i < hits,
    }));

  it('passes at exactly the threshold', () => {
    expect(summarise(scored(90, 100)).passed).toBe(true);
  });

  it('fails just below it', () => {
    expect(summarise(scored(89, 100)).passed).toBe(false);
  });

  it('reports the threshold as the plan states it', () => {
    expect(TOOL_SELECTION_THRESHOLD).toBe(0.9);
  });

  it('fails an empty run rather than passing it', () => {
    // 0/0 is NaN and `NaN >= 0.9` is false — but reporting *why* matters, or a
    // misconfigured sweep that ran nothing reads as a quality regression.
    const report = summarise([]);
    expect(report.passed).toBe(false);
    expect(report.total).toBe(0);
  });

  it('lists the misses so a failure is actionable', () => {
    const report = summarise(scored(8, 10));
    expect(report.misses).toHaveLength(2);
    expect(report.accuracy).toBe(0.8);
  });
});

/**
 * The cost regression gate.
 *
 * A cache miss has **no functional symptom** — right answers, green tests, and
 * a bill that quietly multiplies. It cannot be caught by review, so it is
 * asserted like any other regression.
 */
describe('cost regression — the cache must be hit on turn 2', () => {
  function providerWithCache(): LlmProvider & { calls: TurnInput[] } {
    const calls: TurnInput[] = [];
    let previousPrefix: string | null = null;

    return {
      calls,
      name: 'gemini',
      models: { orchestrator: 'big', quarantine: 'small' },
      normaliseUsage: () => ({ inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, costCents: 0 }),
      async *runTurn(input: TurnInput): AsyncGenerator<TurnEvent> {
        calls.push(input);
        // The prefix a provider actually hashes: system + tool declarations,
        // and nothing volatile. Modelling it as a string comparison is the
        // whole point — a real cache is a byte comparison too.
        const prefix = JSON.stringify([input.system, input.tools.map((t) => t.name)]);
        const cacheReadTokens = prefix === previousPrefix ? 4_000 : 0;
        previousPrefix = prefix;

        yield { type: 'token', text: 'ok' };
        yield {
          type: 'usage',
          usage: { inputTokens: 4_200, outputTokens: 20, cacheReadTokens, costCents: 1 },
        };
        yield { type: 'done' };
      },
    };
  }

  const tool: AnyAssistantTool = eraseToolTypes({
    name: 'getStockLevels',
    pillar: 'stock',
    description: 'Call this when the user asks about stock.',
    args: z.object({ outletId: z.string() }),
    run: async () => ({ ok: true }),
  } as never);

  async function turn(
    provider: LlmProvider,
    userMessage: string,
  ): Promise<WireEvent[]> {
    const out: WireEvent[] = [];
    for await (const event of runTurn({
      provider,
      tools: [tool],
      messages: [{ role: 'user', content: userMessage }],
      signal: new AbortController().signal,
    })) {
      out.push(event);
    }
    return out;
  }

  it('reads from cache on the second turn', async () => {
    const provider = providerWithCache();

    const first = await turn(provider, 'How is stock looking?');
    const second = await turn(provider, 'And in Gauteng?');

    const cacheReads = (events: WireEvent[]) =>
      (events.find((e) => e.event === 'usage')?.data as { cacheReadTokens: number }).cacheReadTokens;

    expect(cacheReads(first)).toBe(0);
    // The assertion the plan names explicitly: `cache_read_input_tokens > 0`
    // on turn 2.
    expect(cacheReads(second)).toBeGreaterThan(0);
  });

  it('keeps the prefix byte-identical between turns', async () => {
    const provider = providerWithCache();
    await turn(provider, 'first question');
    await turn(provider, 'a completely different second question');

    const [a, b] = provider.calls;
    expect(a.system).toBe(b.system);
    expect(a.tools.map((t) => t.name)).toEqual(b.tools.map((t) => t.name));
  });

  it('would fail if the system prompt were interpolated', async () => {
    // Proves the assertion above has teeth. A timestamp in the system prompt is
    // the realistic way this regresses, and this is what it would look like.
    const provider = providerWithCache();

    for (const stamp of ['2026-08-06T10:00:00Z', '2026-08-06T10:00:01Z']) {
      for await (const _ of runTurn({
        provider,
        tools: [tool],
        system: `You are TradeIQ. The time is ${stamp}.`,
        messages: [{ role: 'user', content: 'q' }],
        signal: new AbortController().signal,
      })) {
        void _;
      }
    }

    const usages = provider.calls;
    expect(usages[0].system).not.toBe(usages[1].system);
  });
});
