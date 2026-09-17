import { collect, contractInput } from './contract';
import { FOREIGN_CALL_SIGNATURE, forForeignProvider, withFallback } from './fallback';
import { providerFor } from './index';
import type { LlmProvider, ProviderName, TurnEvent, TurnInput } from './types';

/** A provider that replays one scripted event list per call, and records its inputs. */
function scripted(name: ProviderName, rounds: TurnEvent[][]): LlmProvider & { inputs: TurnInput[] } {
  const inputs: TurnInput[] = [];
  return {
    inputs,
    name,
    models: { orchestrator: `${name}-big`, quarantine: `${name}-small` },
    normaliseUsage: () => ({ inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, costCents: 0 }),
    async *runTurn(input) {
      inputs.push(input);
      for (const event of rounds[inputs.length - 1] ?? rounds[rounds.length - 1]) yield event;
    },
  };
}

const usage: TurnEvent = {
  type: 'usage',
  usage: { inputTokens: 1, outputTokens: 1, cacheReadTokens: 0, costCents: 0 },
};
const answer = (text: string): TurnEvent[] => [{ type: 'token', text }, usage, { type: 'done' }];
const fail = (code: string): TurnEvent[] => [{ type: 'error', code, message: 'Something went wrong.' }];
const signal = () => new AbortController().signal;

describe('withFallback', () => {
  let warn: jest.SpyInstance;
  beforeEach(() => {
    warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });
  afterEach(() => warn.mockRestore());

  it('passes a healthy primary through untouched, and never calls the secondary', async () => {
    const primary = scripted('anthropic', [answer('Claude here.')]);
    const secondary = scripted('gemini', [answer('Gemini here.')]);
    const provider = withFallback(primary, secondary);

    const events = await collect(provider.runTurn(contractInput(), signal()));

    expect(events).toEqual(answer('Claude here.'));
    expect(secondary.inputs).toHaveLength(0);
    expect(provider.name).toBe('anthropic');
    expect(provider.fallbackFrom).toBeUndefined();
  });

  it('answers on the secondary when the primary has an outage before any output', async () => {
    const primary = scripted('anthropic', [fail('provider_error')]);
    const secondary = scripted('gemini', [answer('Gemini here.')]);
    const provider = withFallback(primary, secondary);

    const events = await collect(provider.runTurn(contractInput({ webSearch: true }), signal()));

    expect(events).toEqual(answer('Gemini here.'));
    // The same turn, not a different one.
    expect(secondary.inputs[0].system).toBe(contractInput().system);
    expect(secondary.inputs[0].webSearch).toBe(true);
    // Tracing reads these: the answering vendor, and the one it stood in for.
    expect(provider.name).toBe('gemini');
    expect(provider.models.orchestrator).toBe('gemini-big');
    expect(provider.fallbackFrom).toBe('anthropic');
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('answering this turn on gemini'));
  });

  it.each([
    'rate_limited',
    'provider_unavailable',
    'bad_request',
    'blocked',
    'not_configured',
    'internal_error',
    'aborted',
  ])('does not fall back on %s — it would fail the same way, or is not an outage', async (code) => {
    const primary = scripted('anthropic', [fail(code)]);
    const secondary = scripted('gemini', [answer('Gemini here.')]);

    const events = await collect(withFallback(primary, secondary).runTurn(contractInput(), signal()));

    expect(events).toEqual(fail(code));
    expect(secondary.inputs).toHaveLength(0);
  });

  it('never falls back mid-stream, once the user has seen output', async () => {
    const primary = scripted('anthropic', [
      [
        { type: 'token', text: 'Tumo is' },
        { type: 'error', code: 'provider_error', message: 'x' },
      ],
    ]);
    const secondary = scripted('gemini', [answer('Gemini here.')]);

    const events = await collect(withFallback(primary, secondary).runTurn(contractInput(), signal()));

    expect(events.map((e) => e.type)).toEqual(['token', 'error']);
    expect(secondary.inputs).toHaveLength(0);
  });

  it('never falls back after a tool call was issued', async () => {
    const primary = scripted('anthropic', [
      [
        { type: 'tool_call', id: 't1', name: 'getAgentScorecard', args: {} },
        { type: 'error', code: 'provider_error', message: 'x' },
      ],
    ]);
    const secondary = scripted('gemini', [answer('Gemini here.')]);

    await collect(withFallback(primary, secondary).runTurn(contractInput(), signal()));

    expect(secondary.inputs).toHaveLength(0);
  });

  it('does not fall back when the client has already gone', async () => {
    const controller = new AbortController();
    controller.abort();
    const primary = scripted('anthropic', [fail('provider_error')]);
    const secondary = scripted('gemini', [answer('Gemini here.')]);

    await collect(withFallback(primary, secondary).runTurn(contractInput(), controller.signal));

    expect(secondary.inputs).toHaveLength(0);
  });

  it('stays on the secondary for the rest of the turn once it has fallen back', async () => {
    const primary = scripted('anthropic', [fail('provider_error'), answer('Claude is back.')]);
    const secondary = scripted('gemini', [answer('round 1'), answer('round 2')]);
    const provider = withFallback(primary, secondary);

    await collect(provider.runTurn(contractInput(), signal()));
    const second = await collect(provider.runTurn(contractInput(), signal()));

    expect(second).toEqual(answer('round 2'));
    expect(primary.inputs).toHaveLength(1);
  });

  it("signs the primary's tool calls so Gemini 3 accepts them in history", async () => {
    const primary = scripted('anthropic', [fail('provider_error')]);
    const secondary = scripted('gemini', [answer('ok')]);
    const input = contractInput({
      messages: [
        { role: 'user', content: 'q' },
        {
          role: 'assistant',
          content: '',
          toolCalls: [{ id: 'toolu_1', name: 'getAgentScorecard', args: {} }],
          providerReplay: { provider: 'anthropic', content: [] },
        },
        { role: 'tool', callId: 'toolu_1', name: 'getAgentScorecard', ok: true, content: '{}' },
      ],
    });

    await collect(withFallback(primary, secondary).runTurn(input, signal()));

    type WithCalls = { toolCalls: { providerSignature?: string }[] };
    const replayed = secondary.inputs[0].messages[1] as unknown as WithCalls;
    expect(replayed.toolCalls[0].providerSignature).toBe(FOREIGN_CALL_SIGNATURE);
    // The caller's history is not mutated.
    expect((input.messages[1] as unknown as WithCalls).toolCalls[0].providerSignature).toBeUndefined();
  });

  it('keeps a signature a call already carries', () => {
    const [message] = forForeignProvider(
      [
        {
          role: 'assistant',
          content: '',
          toolCalls: [{ id: 'c', name: 'n', args: {}, providerSignature: 'real' }],
        },
      ],
      'gemini',
    );
    expect(
      (message as unknown as { toolCalls: { providerSignature?: string }[] }).toolCalls[0]
        .providerSignature,
    ).toBe('real');
  });
});

describe('providerFor — fallback wiring', () => {
  const saved = { ...process.env };
  afterEach(() => {
    process.env = { ...saved };
  });

  const isWrapper = (provider: object) =>
    Object.getOwnPropertyDescriptor(provider, 'name')?.get !== undefined;

  it('wraps anthropic in a Gemini fallback only when a Gemini key exists', () => {
    process.env.GEMINI_API_KEY = 'test-only-not-a-key';
    delete process.env.LLM_FALLBACK;
    const wrapped = providerFor('anthropic');
    expect(wrapped.name).toBe('anthropic');
    expect(isWrapper(wrapped)).toBe(true);

    delete process.env.GEMINI_API_KEY;
    expect(isWrapper(providerFor('anthropic'))).toBe(false);
  });

  it('can be switched off for single-vendor measurement', () => {
    process.env.GEMINI_API_KEY = 'test-only-not-a-key';
    process.env.LLM_FALLBACK = 'off';
    expect(isWrapper(providerFor('anthropic'))).toBe(false);
  });

  it('gives gemini no fallback', () => {
    process.env.GEMINI_API_KEY = 'test-only-not-a-key';
    const provider = providerFor('gemini');
    expect(provider.name).toBe('gemini');
    expect(isWrapper(provider)).toBe(false);
  });
});
