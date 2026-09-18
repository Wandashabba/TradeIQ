import { FunctionCallingConfigMode, type GenerateContentParameters } from '@google/genai';
import { z } from 'zod';
import type { AnyAssistantTool } from '../types';
import {
  GROUNDED_TOOL_CONFIG,
  classifyGeminiError,
  createGeminiProvider,
  geminiSupportsSearchWithTools,
  sourcesFromGrounding,
  normaliseGeminiUsage,
  thinkingConfigFor,
  toFunctionDeclarations,
  toGeminiContents,
  type GeminiClient,
} from './gemini';
import { collect, contractInput, runProviderContract, type ScriptedTurn } from './contract';
import type { Message } from './types';

/**
 * Replay a {@link ScriptedTurn} in Gemini's wire shape.
 *
 * This is the adapter's half of the provider contract: the suite describes a
 * turn abstractly, and each vendor renders it into the chunks its SDK would
 * actually produce. Everything after that is asserted identically across
 * adapters.
 */
function geminiClientFor(script: ScriptedTurn, capture?: (p: GenerateContentParameters) => void) {
  const client: GeminiClient = {
    models: {
      async generateContentStream(params) {
        capture?.(params);
        if (script.failWith) throw script.failWith;

        async function* stream() {
          for (const text of script.textChunks ?? []) {
            yield { candidates: [{ content: { parts: [{ text }] } }] } as never;
          }
          for (const call of script.toolCalls ?? []) {
            // `id` deliberately omitted — the real Gemini API populates it only
            // sometimes, and the adapter must synthesise one either way.
            yield {
              candidates: [{ content: { parts: [{ functionCall: { name: call.name, args: call.args } }] } }],
            } as never;
          }
          if (script.usage) {
            yield {
              candidates: [{ content: { parts: [] } }],
              usageMetadata: {
                promptTokenCount: script.usage.promptTokens,
                candidatesTokenCount: script.usage.outputTokens,
                cachedContentTokenCount: script.usage.cachedTokens,
              },
            } as never;
          }
        }
        return stream();
      },
    },
  };
  return client;
}

runProviderContract({
  name: 'gemini',
  providerFor: (script) => createGeminiProvider({ client: geminiClientFor(script) }),
});

describe('gemini adapter — vendor specifics', () => {
  function providerCapturing(script: ScriptedTurn = {}) {
    let captured: GenerateContentParameters | undefined;
    const provider = createGeminiProvider({
      client: geminiClientFor(script, (p) => {
        captured = p;
      }),
    });
    return { provider, params: () => captured as GenerateContentParameters };
  }

  it('sends the system prompt as systemInstruction, never as a message turn', async () => {
    // The plan names prepending it as a user turn "the most common migration
    // bug": it works, and it destroys the cache prefix and the instruction
    // hierarchy at the same time — with no functional symptom.
    const { provider, params } = providerCapturing({ textChunks: ['ok'] });

    await collect(provider.runTurn(contractInput({ system: 'FROZEN' }), new AbortController().signal));

    expect(params().config?.systemInstruction).toBe('FROZEN');
    const texts = JSON.stringify(params().contents);
    expect(texts).not.toContain('FROZEN');
  });

  it('maps the assistant role onto Gemini\'s "model"', () => {
    const contents = toGeminiContents([
      { role: 'user', content: 'hi' },
      { role: 'assistant', content: 'hello' },
    ]);

    expect(contents).toEqual([
      { role: 'user', parts: [{ text: 'hi' }] },
      { role: 'model', parts: [{ text: 'hello' }] },
    ]);
  });

  it('replays an assistant tool-call turn before its result', () => {
    // Gemini rejects a functionResponse whose functionCall is absent from
    // history. Anthropic accepts it and quietly reasons from a broken thread.
    const messages: Message[] = [
      { role: 'user', content: 'how is Tumo doing' },
      { role: 'assistant', content: '', toolCalls: [{ id: 'c0', name: 'getAgentScorecard', args: { agentId: 'a' } }] },
      { role: 'tool', callId: 'c0', name: 'getAgentScorecard', ok: true, content: '{"score":82}' },
    ];

    const contents = toGeminiContents(messages);

    expect(contents[1]).toEqual({
      role: 'model',
      parts: [{ functionCall: { id: 'c0', name: 'getAgentScorecard', args: { agentId: 'a' } } }],
    });
    expect(contents[2].parts?.[0].functionResponse).toMatchObject({
      id: 'c0',
      name: 'getAgentScorecard',
      response: { ok: true, content: '{"score":82}' },
    });
  });

  it('replays the thought signature the call was issued with', () => {
    // Gemini 3.x answers a follow-up request with 400 INVALID_ARGUMENT
    // ("Function call is missing a thought_signature in functionCall parts")
    // when a functionCall returns without it. Because the model's tool-call
    // turn must be in history before the matching result, dropping the token
    // killed every turn that called a tool: the tool ran, and the request
    // carrying its result was refused. The signature rides on the Part, beside
    // functionCall rather than inside it.
    const contents = toGeminiContents([
      {
        role: 'assistant',
        content: '',
        toolCalls: [
          { id: 'c0', name: 'getStockLevels', args: {}, providerSignature: 'sig-abc' },
        ],
      },
    ]);

    expect(contents[0].parts?.[0].thoughtSignature).toBe('sig-abc');
  });

  it('omits the signature entirely for a provider that issues none', () => {
    // Anthropic has no equivalent. The key must be absent rather than
    // undefined — Gemini validates the shape it is sent.
    const contents = toGeminiContents([
      { role: 'assistant', content: '', toolCalls: [{ id: 'c0', name: 'getStockLevels', args: {} }] },
    ]);

    expect(contents[0].parts?.[0]).not.toHaveProperty('thoughtSignature');
  });

  it('merges parallel tool results into one turn', () => {
    // Two adjacent turns of the same role is a 400 from Gemini, and it only
    // happens once the model starts calling two tools at once.
    const contents = toGeminiContents([
      { role: 'tool', callId: 'c0', name: 'a', ok: true, content: '1' },
      { role: 'tool', callId: 'c1', name: 'b', ok: true, content: '2' },
    ]);

    expect(contents).toHaveLength(1);
    expect(contents[0].parts).toHaveLength(2);
  });

  it('drops an assistant turn that would serialise to empty parts', () => {
    // Gemini rejects `parts: []`. A text-less, call-less assistant turn is
    // meaningless anyway, so it is dropped rather than sent malformed.
    expect(toGeminiContents([{ role: 'assistant', content: '' }])).toEqual([]);
  });

  it('carries a failed tool result through rather than dropping it', () => {
    const contents = toGeminiContents([
      { role: 'tool', callId: 'c0', name: 'getStockLevels', ok: false, content: 'no rows' },
    ]);

    expect(contents[0].parts?.[0].functionResponse?.response).toEqual({
      ok: false,
      content: 'no rows',
    });
  });

  it('converts tool args into a Gemini schema, not raw JSON Schema', () => {
    const tool: AnyAssistantTool = {
      name: 'getStockLevels',
      pillar: 'stock',
      description: 'Call this when the user asks about stock on hand.',
      args: z.object({ outletId: z.string(), limit: z.number().int() }) as never,
      run: async () => null,
    };

    const [declaration] = toFunctionDeclarations([tool]);

    expect(declaration.name).toBe('getStockLevels');
    // Uppercase Type enum, and no `$schema` key — both are 400s otherwise.
    expect(declaration.parameters?.type).toBe('OBJECT');
    expect(declaration.parameters?.properties?.outletId.type).toBe('STRING');
    expect(declaration.parameters?.properties?.limit.type).toBe('INTEGER');
    expect(JSON.stringify(declaration.parameters)).not.toContain('$schema');
  });

  it('declares tool config as AUTO, and as NONE when tools are suppressed', async () => {
    // `toolChoice: 'none'` is what the quarantine pass relies on: a tool-less
    // model call is the entire dual-LLM defence. If this mapping is wrong the
    // defence is off and nothing fails visibly.
    const auto = providerCapturing({ textChunks: ['x'] });
    await collect(auto.provider.runTurn(contractInput(), new AbortController().signal));
    expect(auto.params().config?.toolConfig?.functionCallingConfig?.mode).toBe(
      FunctionCallingConfigMode.AUTO,
    );

    const none = providerCapturing({ textChunks: ['x'] });
    await collect(
      none.provider.runTurn(contractInput({ toolChoice: 'none' }), new AbortController().signal),
    );
    expect(none.params().config?.toolConfig?.functionCallingConfig?.mode).toBe(
      FunctionCallingConfigMode.NONE,
    );
  });

  it('spends full thinking on the opening round and less on every round after', async () => {
    // The largest single line on the bill. The opening round is the one the
    // eval gate scores and the cheapest in the turn whatever the level, so it
    // keeps the vendor default; the rounds after it reason over a context that
    // has been growing all turn, which is what makes them expensive.
    const first = providerCapturing({ textChunks: ['x'] });
    await collect(first.provider.runTurn(contractInput({ round: 0 }), new AbortController().signal));
    expect(first.params().config?.thinkingConfig).toBeUndefined();

    const later = providerCapturing({ textChunks: ['x'] });
    await collect(later.provider.runTurn(contractInput({ round: 2 }), new AbortController().signal));
    expect(later.params().config?.thinkingConfig).toEqual({ thinkingLevel: 'low' });

    const answer = providerCapturing({ textChunks: ['x'] });
    await collect(
      answer.provider.runTurn(
        contractInput({ toolChoice: 'none', round: 3 }),
        new AbortController().signal,
      ),
    );
    expect(answer.params().config?.thinkingConfig).toEqual({ thinkingLevel: 'low' });
  });

  it('treats a caller that sends no round as the opening round', async () => {
    // "Unknown round" must read as the setting that changes nothing about tool
    // selection, or adding a field to the contract quietly re-tunes every
    // caller written before it.
    const { provider, params } = providerCapturing({ textChunks: ['x'] });
    await collect(provider.runTurn(contractInput(), new AbortController().signal));
    expect(params().config?.thinkingConfig).toBeUndefined();
  });

  it('caps one round\'s generation', async () => {
    const { provider, params } = providerCapturing({ textChunks: ['x'] });
    await collect(provider.runTurn(contractInput(), new AbortController().signal));
    expect(params().config?.maxOutputTokens).toBeGreaterThan(0);
  });

  it('forwards the abort signal to the SDK', async () => {
    const controller = new AbortController();
    const { provider, params } = providerCapturing({ textChunks: ['x'] });

    await collect(provider.runTurn(contractInput(), controller.signal));

    expect(params().config?.abortSignal).toBe(controller.signal);
  });

  it('stops streaming once the signal aborts mid-turn', async () => {
    const controller = new AbortController();
    const client: GeminiClient = {
      models: {
        async generateContentStream() {
          async function* stream() {
            yield { candidates: [{ content: { parts: [{ text: 'first' }] } }] } as never;
            controller.abort();
            yield { candidates: [{ content: { parts: [{ text: 'second' }] } }] } as never;
          }
          return stream();
        },
      },
    };

    const events = await collect(
      createGeminiProvider({ client }).runTurn(contractInput(), controller.signal),
    );

    expect(events.map((e) => e.type)).toEqual(['token', 'error']);
    expect(events.some((e) => e.type === 'token' && e.text === 'second')).toBe(false);
  });

  it('does not stream thinking text as narrative', async () => {
    const client: GeminiClient = {
      models: {
        async generateContentStream() {
          async function* stream() {
            yield {
              candidates: [{ content: { parts: [{ text: 'let me check…', thought: true }] } }],
            } as never;
            yield { candidates: [{ content: { parts: [{ text: 'Tumo is up 6.' }] } }] } as never;
          }
          return stream();
        },
      },
    };

    const events = await collect(
      createGeminiProvider({ client }).runTurn(contractInput(), new AbortController().signal),
    );

    const text = events
      .filter((e) => e.type === 'token')
      .map((e) => (e as { text: string }).text)
      .join('');
    expect(text).toBe('Tumo is up 6.');
  });

  it('takes the last usage block rather than summing every chunk', async () => {
    // Gemini reports usage cumulatively. Summing it multiplies the reported
    // cost by the number of chunks — a cost dashboard that reads high forever.
    const client: GeminiClient = {
      models: {
        async generateContentStream() {
          async function* stream() {
            yield {
              candidates: [{ content: { parts: [{ text: 'a' }] } }],
              usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 1 },
            } as never;
            yield {
              candidates: [{ content: { parts: [{ text: 'b' }] } }],
              usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 2 },
            } as never;
          }
          return stream();
        },
      },
    };

    const events = await collect(
      createGeminiProvider({ client }).runTurn(contractInput(), new AbortController().signal),
    );

    const usage = events.find((e) => e.type === 'usage') as { usage: { inputTokens: number } };
    expect(usage.usage.inputTokens).toBe(100);
  });
});

describe('thinkingConfigFor', () => {
  it('protects the opening round and turns the rest down', () => {
    // Measured on twenty golden questions: first-tool choice was 20/20 at the
    // vendor default and 19/20 at `low`. The gate needs 90%, so 95% would pass
    // — and is one sample from not passing, for a saving the measurement says
    // is not there anyway (round zero thinks ~200 tokens at either level).
    expect(thinkingConfigFor('gemini-3.1-pro-preview', 'first')).toBeUndefined();
    expect(thinkingConfigFor('gemini-3.1-pro-preview', 'tool')).toEqual({ thinkingLevel: 'low' });
    expect(thinkingConfigFor('gemini-3.1-pro-preview', 'answer')).toEqual({ thinkingLevel: 'low' });
  });

  it('never configures the quarantine tier', () => {
    // It summarises one string with no tools. There is nothing to reason about,
    // and it is a different model whose levels nobody has measured.
    expect(thinkingConfigFor('gemini-3.6-flash', 'quarantine')).toBeUndefined();
  });

  it('says nothing to a model that does not take the setting', () => {
    // Sending `thinkingLevel` to a model that does not understand it is a 400,
    // and a 400 on every turn is a worse outcome than a turn that thinks hard.
    expect(thinkingConfigFor('gemini-2.5-flash', 'answer')).toBeUndefined();
    expect(thinkingConfigFor('models/gemini-3.1-pro-preview', 'answer')).toEqual({
      thinkingLevel: 'low',
    });
  });
});

describe('normaliseGeminiUsage', () => {
  it('reads cache hits from cachedContentTokenCount', () => {
    expect(normaliseGeminiUsage({ cachedContentTokenCount: 900 }).cacheReadTokens).toBe(900);
  });

  it('does not bill cached tokens twice', () => {
    // promptTokenCount INCLUDES the cached tokens. Adding them as a third
    // bucket makes a cache hit cost more than a miss — the exact inversion the
    // CI cost assertion exists to catch.
    const hit = normaliseGeminiUsage({
      promptTokenCount: 10_000,
      candidatesTokenCount: 100,
      cachedContentTokenCount: 9_000,
    });
    const miss = normaliseGeminiUsage({ promptTokenCount: 10_000, candidatesTokenCount: 100 });

    expect(hit.costCents).toBeLessThan(miss.costCents);
    expect(hit.inputTokens).toBe(10_000);
  });

  it('counts thinking tokens as output', () => {
    // They are billed as output and are not in candidatesTokenCount, so leaving
    // them out under-reports every reasoning turn.
    const withThinking = normaliseGeminiUsage({ candidatesTokenCount: 10, thoughtsTokenCount: 500 });
    expect(withThinking.outputTokens).toBe(510);
  });

  it('returns zeros rather than NaN for an empty payload', () => {
    // A NaN cost silently poisons every downstream sum.
    const usage = normaliseGeminiUsage(undefined);
    expect(usage).toEqual({ inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, costCents: 0 });
  });
});

describe('classifyGeminiError', () => {
  it.each([
    ['rate limit', Object.assign(new Error('RESOURCE_EXHAUSTED'), { status: 429 }), 'rate_limited'],
    ['bad key', Object.assign(new Error('API key not valid'), { status: 401 }), 'provider_unavailable'],
    ['bad request', Object.assign(new Error('INVALID_ARGUMENT'), { status: 400 }), 'bad_request'],
    ['abort', Object.assign(new Error('aborted'), { name: 'AbortError' }), 'aborted'],
    ['unknown', new Error('who knows'), 'provider_error'],
  ])('classifies %s', (_label, err, code) => {
    expect(classifyGeminiError(err).code).toBe(code);
  });

  it('never returns the vendor message verbatim', () => {
    // Vendor errors carry request ids, quota details, and sometimes prompt
    // fragments. This message is rendered in the chat.
    const raw = 'project 99 quota exceeded for gemini-x, trace zz-11';
    expect(classifyGeminiError(new Error(raw)).message).not.toContain(raw);
  });
});

describe('createGeminiProvider — construction', () => {
  it('does not require a key until a turn actually runs', () => {
    // Importing this module must not throw in CI, where no key exists.
    const previous = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;
    try {
      expect(() => createGeminiProvider()).not.toThrow();
    } finally {
      if (previous !== undefined) process.env.GEMINI_API_KEY = previous;
    }
  });

  it('reports a missing key as not_configured, not as a generic failure', async () => {
    // "Something went wrong, please try again" is the wrong answer to the one
    // error that has an obvious fix — an operator watching error codes would
    // retry forever against a config that cannot work. The stream still ends
    // with an event rather than a throw, because a throw kills the SSE
    // connection with no reason on it.
    const previous = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;
    const logged = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const provider = createGeminiProvider();
      const events = await collect(
        provider.runTurn(contractInput(), new AbortController().signal),
      );

      expect(events).toEqual([
        { type: 'error', code: 'not_configured', message: 'The assistant is not configured yet.' },
      ]);
      // The actionable detail exists — in the log, where it is useful and not
      // rendered into a manager's chat window.
      expect(String(logged.mock.calls[0]?.[1])).toMatch(/GEMINI_API_KEY.*backend\/\.env/s);
    } finally {
      logged.mockRestore();
      if (previous !== undefined) process.env.GEMINI_API_KEY = previous;
    }
  });
});

describe('gemini adapter — Google Search grounding', () => {
  function grounded(model: string, chunks: unknown[], capture?: (p: GenerateContentParameters) => void) {
    const client: GeminiClient = {
      models: {
        async generateContentStream(params) {
          capture?.(params);
          async function* stream() {
            for (const chunk of chunks) yield chunk as never;
          }
          return stream();
        },
      },
    };
    return createGeminiProvider({ client, models: { orchestrator: model, quarantine: 'gemini-3.6-flash' } });
  }

  it.each([
    ['gemini-3.1-pro-preview', true],
    ['models/gemini-3.6-flash', true],
    ['gemini-2.5-flash', false],
  ])('%s can combine search with function calling: %s', (model, ok) => {
    expect(geminiSupportsSearchWithTools(model)).toBe(ok);
  });

  it('adds googleSearch beside the declarations, with server-side invocations and VALIDATED mode', async () => {
    let params: GenerateContentParameters | undefined;
    const provider = grounded('gemini-3.1-pro-preview', [{ candidates: [{ content: { parts: [{ text: 'ok' }] } }] }], (p) => {
      params = p;
    });

    await collect(provider.runTurn(contractInput({ webSearch: true }), new AbortController().signal));

    expect(params?.config?.tools).toEqual([
      { functionDeclarations: expect.any(Array) },
      { googleSearch: {} },
    ]);
    expect(params?.config?.toolConfig).toEqual(GROUNDED_TOOL_CONFIG);
    expect(GROUNDED_TOOL_CONFIG).toEqual({
      functionCallingConfig: { mode: FunctionCallingConfigMode.VALIDATED },
      includeServerSideToolInvocations: true,
    });
  });

  it('degrades to no search on a model that cannot combine it with tools', async () => {
    let params: GenerateContentParameters | undefined;
    const provider = grounded('gemini-2.5-flash', [{ candidates: [{ content: { parts: [{ text: 'ok' }] } }] }], (p) => {
      params = p;
    });

    await collect(provider.runTurn(contractInput({ webSearch: true }), new AbortController().signal));

    expect(JSON.stringify(params?.config?.tools)).not.toContain('googleSearch');
    expect(params?.config?.toolConfig?.functionCallingConfig?.mode).toBe(FunctionCallingConfigMode.AUTO);
  });

  it('never grounds a quarantine or tool-suppressed turn', async () => {
    let params: GenerateContentParameters | undefined;
    const provider = grounded('gemini-3.1-pro-preview', [{ candidates: [{ content: { parts: [{ text: 'ok' }] } }] }], (p) => {
      params = p;
    });

    await collect(
      provider.runTurn(contractInput({ webSearch: true, toolChoice: 'none' }), new AbortController().signal),
    );

    expect(JSON.stringify(params?.config)).not.toContain('googleSearch');
  });

  it('announces the search, replays signed server-side parts, and reports cited sources', async () => {
    const provider = grounded('gemini-3.1-pro-preview', [
      {
        candidates: [
          {
            content: {
              parts: [
                { toolCall: { id: 's1', toolType: 'GOOGLE_SEARCH_WEB', args: { queries: ['shoprite'] } }, thoughtSignature: 'sig-call' },
                { toolResponse: { id: 's1', toolType: 'GOOGLE_SEARCH_WEB', response: {} }, thoughtSignature: 'sig-resp' },
              ],
            },
          },
        ],
      },
      {
        candidates: [
          {
            content: {
              parts: [{ functionCall: { id: 'f1', name: 'getAgentScorecard', args: { agentId: 'a' } }, thoughtSignature: 'sig-fn' }],
            },
            groundingMetadata: {
              groundingChunks: [{ web: { uri: 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/abc', title: 'news24.com' } }],
              groundingSupports: [{ segment: { text: 'Shoprite is running a promotion.' }, groundingChunkIndices: [0] }],
            },
          },
        ],
      },
    ]);

    const events = await collect(
      provider.runTurn(contractInput({ webSearch: true }), new AbortController().signal),
    );

    expect(events.map((e) => e.type)).toEqual(['web_search', 'tool_call', 'replay', 'sources', 'usage', 'done']);
    const replay = events.find((e) => e.type === 'replay') as { content: unknown[] };
    expect(replay.content).toHaveLength(3);
    expect(events.find((e) => e.type === 'sources')).toEqual({
      type: 'sources',
      sources: [
        {
          url: 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/abc',
          title: 'news24.com',
          snippet: 'Shoprite is running a promotion.',
        },
      ],
    });
  });

  it('replays a grounded assistant turn verbatim in history', () => {
    const parts = [{ toolCall: { id: 's1' }, thoughtSignature: 'sig' }, { functionCall: { id: 'f1', name: 'x', args: {} } }];
    const contents = toGeminiContents([
      {
        role: 'assistant',
        content: 'rebuilt text would lose the signatures',
        toolCalls: [{ id: 'f1', name: 'x', args: {} }],
        providerReplay: { provider: 'gemini', content: parts },
      },
    ]);
    expect(contents).toEqual([{ role: 'model', parts }]);
  });

  it("ignores another vendor's replay and rebuilds the turn", () => {
    const contents = toGeminiContents([
      {
        role: 'assistant',
        content: 'hi',
        providerReplay: { provider: 'anthropic', content: [{ type: 'thinking' }] },
      },
    ]);
    expect(contents).toEqual([{ role: 'model', parts: [{ text: 'hi' }] }]);
  });

  it('extracts no sources from metadata without web chunks', () => {
    expect(sourcesFromGrounding(undefined)).toEqual([]);
    expect(sourcesFromGrounding({ groundingChunks: [{}] })).toEqual([]);
  });
});
