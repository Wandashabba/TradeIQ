import Anthropic from '@anthropic-ai/sdk';
import type {
  MessageCreateParamsStreaming,
  RawMessageStreamEvent,
} from '@anthropic-ai/sdk/resources/messages/messages';
import {
  ANTHROPIC_WEB_SEARCH_TOOL,
  classifyAnthropicError,
  createAnthropicProvider,
  normaliseAnthropicUsage,
  toAnthropicMessages,
  toAnthropicTools,
  type AnthropicClient,
} from './anthropic';
import { collect, CONTRACT_TOOL, contractInput, runProviderContract, type ScriptedTurn } from './contract';
import type { Message, TurnEvent } from './types';

/** A raw stream event, typed loosely — the fixtures are the vendor's wire shape. */
const ev = (event: unknown) => event as RawMessageStreamEvent;

/**
 * Replay a {@link ScriptedTurn} in Anthropic's streaming wire shape.
 *
 * The adapter's half of the provider contract: the suite describes a turn
 * abstractly and this renders it into the raw SSE events the SDK yields.
 */
function streamFor(script: ScriptedTurn): RawMessageStreamEvent[] {
  const events: RawMessageStreamEvent[] = [];
  const usage = script.usage;
  events.push(
    ev({
      type: 'message_start',
      message: {
        id: 'msg_1',
        type: 'message',
        role: 'assistant',
        content: [],
        model: 'claude-sonnet-5',
        stop_reason: null,
        usage: usage
          ? {
              // Anthropic's input_tokens EXCLUDES cache reads.
              input_tokens: usage.promptTokens - usage.cachedTokens,
              cache_read_input_tokens: usage.cachedTokens,
              cache_creation_input_tokens: 0,
              output_tokens: 1,
            }
          : {},
      },
    }),
  );

  let index = 0;
  if (script.textChunks?.length) {
    events.push(ev({ type: 'content_block_start', index, content_block: { type: 'text', text: '', citations: null } }));
    for (const text of script.textChunks) {
      events.push(ev({ type: 'content_block_delta', index, delta: { type: 'text_delta', text } }));
    }
    events.push(ev({ type: 'content_block_stop', index }));
    index += 1;
  }
  for (const [i, call] of (script.toolCalls ?? []).entries()) {
    events.push(
      ev({
        type: 'content_block_start',
        index,
        content_block: { type: 'tool_use', id: `toolu_${i}`, name: call.name, input: {} },
      }),
    );
    const json = JSON.stringify(call.args);
    // Split the arguments across deltas, as the API does.
    events.push(ev({ type: 'content_block_delta', index, delta: { type: 'input_json_delta', partial_json: json.slice(0, 5) } }));
    events.push(ev({ type: 'content_block_delta', index, delta: { type: 'input_json_delta', partial_json: json.slice(5) } }));
    events.push(ev({ type: 'content_block_stop', index }));
    index += 1;
  }
  events.push(
    ev({
      type: 'message_delta',
      delta: { stop_reason: script.toolCalls?.length ? 'tool_use' : 'end_turn' },
      usage: usage ? { output_tokens: usage.outputTokens } : {},
    }),
  );
  events.push(ev({ type: 'message_stop' }));
  return events;
}

async function* iterate(events: RawMessageStreamEvent[]): AsyncGenerator<RawMessageStreamEvent> {
  for (const event of events) yield event;
}

/** A client that answers each request with the next scripted stream. */
function clientFor(
  streams: (RawMessageStreamEvent[] | Error)[],
  capture?: (params: MessageCreateParamsStreaming, options?: { signal?: AbortSignal }) => void,
): AnthropicClient {
  let call = 0;
  return {
    messages: {
      async create(params, options) {
        // Snapshot, so later mutation of the adapter's arrays cannot rewrite
        // what the test asserts was sent.
        capture?.(JSON.parse(JSON.stringify(params)) as MessageCreateParamsStreaming, options);
        const next = streams[Math.min(call, streams.length - 1)];
        call += 1;
        if (next instanceof Error) throw next;
        return iterate(next);
      },
    },
  };
}

runProviderContract({
  name: 'anthropic',
  providerFor: (script) =>
    createAnthropicProvider({
      client: clientFor([script.failWith ?? streamFor(script)]),
    }),
});

function capturing(streams: (RawMessageStreamEvent[] | Error)[]) {
  const requests: MessageCreateParamsStreaming[] = [];
  const signals: (AbortSignal | undefined)[] = [];
  const provider = createAnthropicProvider({
    client: clientFor(streams, (p, o) => {
      requests.push(p);
      signals.push(o?.signal);
    }),
  });
  return { provider, requests, signals };
}

const silence = () => jest.spyOn(console, 'error').mockImplementation(() => {});

describe('anthropic adapter — vendor specifics', () => {
  it('defaults to Claude Sonnet 5 with Haiku 4.5 as the quarantine tier', () => {
    const provider = createAnthropicProvider({ client: clientFor([[]]) });
    expect(provider.name).toBe('anthropic');
    expect(provider.models.orchestrator).toBe('claude-sonnet-5');
    expect(provider.models.quarantine).toBe('claude-haiku-4-5-20251001');
  });

  it('sends the system prompt as a cached top-level block, never as a message', async () => {
    const { provider, requests } = capturing([streamFor({ textChunks: ['ok'] })]);

    await collect(provider.runTurn(contractInput({ system: 'FROZEN' }), new AbortController().signal));

    expect(requests[0].system).toEqual([
      { type: 'text', text: 'FROZEN', cache_control: { type: 'ephemeral' } },
    ]);
    expect(JSON.stringify(requests[0].messages)).not.toContain('FROZEN');
  });

  it('puts a second cache breakpoint on the newest message, for later rounds', async () => {
    const { provider, requests } = capturing([streamFor({ textChunks: ['ok'] })]);

    await collect(provider.runTurn(contractInput(), new AbortController().signal));

    const last = requests[0].messages[requests[0].messages.length - 1];
    expect(last.content).toEqual([
      {
        type: 'text',
        text: 'How has Tumo been performing this month?',
        cache_control: { type: 'ephemeral' },
      },
    ]);
  });

  it('declares tools as JSON schema objects, in roster order, with no $schema key', () => {
    const [tool] = toAnthropicTools([CONTRACT_TOOL]);
    expect(tool).toMatchObject({
      name: 'getAgentScorecard',
      description: CONTRACT_TOOL.description,
      input_schema: { type: 'object', properties: { agentId: { type: 'string' } } },
    });
    expect(JSON.stringify(tool)).not.toContain('$schema');
  });

  it('runs the orchestrator with adaptive thinking and auto tool choice', async () => {
    const { provider, requests } = capturing([streamFor({ textChunks: ['ok'] })]);

    await collect(provider.runTurn(contractInput(), new AbortController().signal));

    expect(requests[0].model).toBe('claude-sonnet-5');
    expect(requests[0].thinking).toEqual({ type: 'adaptive' });
    expect(requests[0].tool_choice).toEqual({ type: 'auto' });
    expect(requests[0].stream).toBe(true);
  });

  it('sends a quarantine turn to the cheap tier with no tools and no thinking', async () => {
    // The dual-LLM defence rests on the quarantine model having nothing to call.
    const { provider, requests } = capturing([streamFor({ textChunks: ['1: ok'] })]);

    await collect(
      provider.runTurn(
        contractInput({ model: 'quarantine', toolChoice: 'none', webSearch: true }),
        new AbortController().signal,
      ),
    );

    expect(requests[0].model).toBe('claude-haiku-4-5-20251001');
    expect(requests[0].tools).toBeUndefined();
    expect(requests[0].tool_choice).toBeUndefined();
    expect(requests[0].thinking).toBeUndefined();
  });

  it('keeps declarations on the final round but fences it with tool_choice none', async () => {
    const { provider, requests } = capturing([streamFor({ textChunks: ['ok'] })]);

    await collect(provider.runTurn(contractInput({ toolChoice: 'none' }), new AbortController().signal));

    expect(requests[0].tools).toHaveLength(1);
    expect(requests[0].tool_choice).toEqual({ type: 'none' });
  });

  it('declares web search only when asked, bounded and located in South Africa', async () => {
    const off = capturing([streamFor({ textChunks: ['ok'] })]);
    await collect(off.provider.runTurn(contractInput(), new AbortController().signal));
    expect(JSON.stringify(off.requests[0].tools)).not.toContain('web_search');

    const on = capturing([streamFor({ textChunks: ['ok'] })]);
    await collect(on.provider.runTurn(contractInput({ webSearch: true }), new AbortController().signal));
    const tools = on.requests[0].tools ?? [];
    expect(tools[tools.length - 1]).toEqual(ANTHROPIC_WEB_SEARCH_TOOL);
    expect(ANTHROPIC_WEB_SEARCH_TOOL).toMatchObject({
      type: 'web_search_20260209',
      name: 'web_search',
      max_uses: 3,
      user_location: { type: 'approximate', country: 'ZA' },
    });
  });

  it('forwards the abort signal to the SDK', async () => {
    const controller = new AbortController();
    const { provider, signals } = capturing([streamFor({ textChunks: ['x'] })]);

    await collect(provider.runTurn(contractInput(), controller.signal));

    expect(signals[0]).toBe(controller.signal);
  });

  it('does not stream thinking as narrative, but keeps it signed for replay', async () => {
    const stream = [
      ev({ type: 'message_start', message: { usage: { input_tokens: 10, output_tokens: 1 } } }),
      ev({ type: 'content_block_start', index: 0, content_block: { type: 'thinking', thinking: '', signature: '' } }),
      ev({ type: 'content_block_delta', index: 0, delta: { type: 'thinking_delta', thinking: 'let me check…' } }),
      ev({ type: 'content_block_delta', index: 0, delta: { type: 'signature_delta', signature: 'sig-1' } }),
      ev({ type: 'content_block_stop', index: 0 }),
      ev({ type: 'content_block_start', index: 1, content_block: { type: 'tool_use', id: 'toolu_1', name: 'getAgentScorecard', input: {} } }),
      ev({ type: 'content_block_delta', index: 1, delta: { type: 'input_json_delta', partial_json: '{"agentId":"a"}' } }),
      ev({ type: 'content_block_stop', index: 1 }),
      ev({ type: 'message_delta', delta: { stop_reason: 'tool_use' }, usage: { output_tokens: 20 } }),
      ev({ type: 'message_stop' }),
    ];
    const { provider } = capturing([stream]);

    const events = await collect(provider.runTurn(contractInput(), new AbortController().signal));

    expect(events.some((e) => e.type === 'token')).toBe(false);
    const replay = events.find((e) => e.type === 'replay') as { content: unknown[] };
    expect(replay.content).toEqual([
      { type: 'thinking', thinking: 'let me check…', signature: 'sig-1' },
      { type: 'tool_use', id: 'toolu_1', name: 'getAgentScorecard', input: { agentId: 'a' } },
    ]);
  });

  it('emits no replay for a text-only round', async () => {
    // The contract pins the exact event list for a plain answer.
    const { provider } = capturing([streamFor({ textChunks: ['hi'] })]);
    const events = await collect(provider.runTurn(contractInput(), new AbortController().signal));
    expect(events.some((e) => e.type === 'replay')).toBe(false);
  });

  it('replays its own assistant turns verbatim, and rebuilds foreign ones', () => {
    const replayed = [{ type: 'server_tool_use', id: 'srvtoolu_1', name: 'web_search', input: { query: 'x' } }];
    const messages: Message[] = [
      { role: 'user', content: 'news?' },
      {
        role: 'assistant',
        content: 'ignored',
        toolCalls: [{ id: 'toolu_1', name: 'getAgentScorecard', args: {} }],
        providerReplay: { provider: 'anthropic', content: replayed },
      },
      { role: 'tool', callId: 'toolu_1', name: 'getAgentScorecard', ok: true, content: '{}' },
      {
        role: 'assistant',
        content: 'from gemini',
        toolCalls: [{ id: 'c0', name: 'getAgentScorecard', args: { agentId: 'a' } }],
        providerReplay: { provider: 'gemini', content: [{ text: 'gemini parts' }] },
      },
      { role: 'tool', callId: 'c0', name: 'getAgentScorecard', ok: false, content: 'no rows' },
    ];

    const out = toAnthropicMessages(messages);

    expect(out[1]).toEqual({ role: 'assistant', content: replayed });
    expect(out[3]).toEqual({
      role: 'assistant',
      content: [
        { type: 'text', text: 'from gemini' },
        { type: 'tool_use', id: 'c0', name: 'getAgentScorecard', input: { agentId: 'a' } },
      ],
    });
    expect(out[4]).toEqual({
      role: 'user',
      content: [{ type: 'tool_result', tool_use_id: 'c0', content: 'no rows', is_error: true }],
    });
  });

  it('merges parallel tool results into one user turn', () => {
    const out = toAnthropicMessages([
      { role: 'tool', callId: 'a', name: 'x', ok: true, content: '1' },
      { role: 'tool', callId: 'b', name: 'y', ok: true, content: '2' },
    ]);
    expect(out).toHaveLength(1);
    expect(out[0].content).toHaveLength(2);
  });

  it('drops an assistant turn that would be empty', () => {
    expect(toAnthropicMessages([{ role: 'assistant', content: '' }])).toEqual([]);
  });

  it('surfaces web search as a step, and its citations as sources with page age', async () => {
    const stream = [
      ev({ type: 'message_start', message: { usage: { input_tokens: 100, output_tokens: 1 } } }),
      ev({ type: 'content_block_start', index: 0, content_block: { type: 'server_tool_use', id: 'srvtoolu_1', name: 'web_search', input: {} } }),
      ev({ type: 'content_block_delta', index: 0, delta: { type: 'input_json_delta', partial_json: '{"query":"Shoprite promotion"}' } }),
      ev({ type: 'content_block_stop', index: 0 }),
      ev({
        type: 'content_block_start',
        index: 1,
        content_block: {
          type: 'web_search_tool_result',
          tool_use_id: 'srvtoolu_1',
          content: [
            { type: 'web_search_result', url: 'https://news.example.co.za/a', title: 'A', encrypted_content: 'enc', page_age: '2 days ago' },
          ],
        },
      }),
      ev({ type: 'content_block_stop', index: 1 }),
      ev({ type: 'content_block_start', index: 2, content_block: { type: 'text', text: '', citations: null } }),
      ev({
        type: 'content_block_delta',
        index: 2,
        delta: {
          type: 'citations_delta',
          citation: {
            type: 'web_search_result_location',
            url: 'https://news.example.co.za/a',
            title: 'Shoprite runs a promotion',
            cited_text: 'Shoprite announced a two-week promotion.',
            encrypted_index: 'idx',
          },
        },
      }),
      ev({ type: 'content_block_delta', index: 2, delta: { type: 'text_delta', text: 'Public reports say Shoprite is running a promotion.' } }),
      ev({ type: 'content_block_stop', index: 2 }),
      ev({ type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 30, server_tool_use: { web_search_requests: 1 } } }),
      ev({ type: 'message_stop' }),
    ];
    const { provider } = capturing([stream]);

    const events = await collect(
      provider.runTurn(contractInput({ webSearch: true }), new AbortController().signal),
    );

    expect(events.map((e) => e.type)).toEqual(['web_search', 'token', 'sources', 'usage', 'done']);
    expect(events[2]).toEqual({
      type: 'sources',
      sources: [
        {
          url: 'https://news.example.co.za/a',
          title: 'Shoprite runs a promotion',
          snippet: 'Shoprite announced a two-week promotion.',
          pageAge: '2 days ago',
        },
      ],
    });
    // A search is billed per use, so a searched turn must cost more.
    const usage = (events[3] as Extract<TurnEvent, { type: 'usage' }>).usage;
    expect(usage.costCents).toBeGreaterThan(normaliseAnthropicUsage({ input_tokens: 100, output_tokens: 30 }).costCents);
  });

  it('continues a paused server-side turn inside the adapter', async () => {
    const paused = [
      ev({ type: 'message_start', message: { usage: { input_tokens: 50, output_tokens: 1 } } }),
      ev({ type: 'content_block_start', index: 0, content_block: { type: 'text', text: '', citations: null } }),
      ev({ type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'Searching. ' } }),
      ev({ type: 'content_block_stop', index: 0 }),
      ev({ type: 'message_delta', delta: { stop_reason: 'pause_turn' }, usage: { output_tokens: 5 } }),
      ev({ type: 'message_stop' }),
    ];
    const { provider, requests } = capturing([
      paused,
      streamFor({ textChunks: ['Done.'], usage: { promptTokens: 60, outputTokens: 3, cachedTokens: 0 } }),
    ]);

    const events = await collect(provider.runTurn(contractInput(), new AbortController().signal));

    expect(requests).toHaveLength(2);
    expect(requests[1].messages[requests[1].messages.length - 1]).toEqual({
      role: 'assistant',
      content: [{ type: 'text', text: 'Searching. ', citations: null }],
    });
    expect(events.filter((e) => e.type === 'token').map((e) => (e as { text: string }).text)).toEqual([
      'Searching. ',
      'Done.',
    ]);
    // Usage is summed across the continuation, not taken from the last request.
    const usage = events.find((e) => e.type === 'usage') as { usage: { outputTokens: number } };
    expect(usage.usage.outputTokens).toBe(5 + 3);
  });

  it('reports a refusal as a blocked error', async () => {
    const refused = [
      ev({ type: 'message_start', message: { usage: { input_tokens: 5, output_tokens: 0 } } }),
      ev({ type: 'message_delta', delta: { stop_reason: 'refusal' }, usage: { output_tokens: 0 } }),
      ev({ type: 'message_stop' }),
    ];
    const { provider } = capturing([refused]);

    const events = await collect(provider.runTurn(contractInput(), new AbortController().signal));

    expect(events).toEqual([
      { type: 'error', code: 'blocked', message: 'The assistant could not answer that.' },
    ]);
  });

  it('never logs the raw vendor error, which can echo request headers', async () => {
    const logged = silence();
    try {
      const err = new Anthropic.InternalServerError(500, { error: { message: 'x-api-key sk-ant-secret' } }, 'sk-ant-secret', new Headers());
      const { provider } = capturing([err]);
      const events = await collect(provider.runTurn(contractInput(), new AbortController().signal));

      expect(events).toEqual([
        { type: 'error', code: 'provider_error', message: 'Something went wrong. Please try again.' },
      ]);
      expect(JSON.stringify(logged.mock.calls)).not.toContain('sk-ant-secret');
    } finally {
      logged.mockRestore();
    }
  });
});

describe('normaliseAnthropicUsage', () => {
  it('adds cache reads and writes back into the prompt size', () => {
    const usage = normaliseAnthropicUsage({
      input_tokens: 200,
      cache_read_input_tokens: 4800,
      cache_creation_input_tokens: 0,
      output_tokens: 20,
    });
    expect(usage.inputTokens).toBe(5000);
    expect(usage.cacheReadTokens).toBe(4800);
  });

  it('prices a cache write above a plain read of the same size', () => {
    const write = normaliseAnthropicUsage({ cache_creation_input_tokens: 5000 });
    const plain = normaliseAnthropicUsage({ input_tokens: 5000 });
    expect(write.costCents).toBeGreaterThan(plain.costCents);
  });

  it('returns zeros rather than NaN for an empty payload', () => {
    expect(normaliseAnthropicUsage(undefined)).toEqual({
      inputTokens: 0,
      outputTokens: 0,
      cacheReadTokens: 0,
      costCents: 0,
    });
  });
});

describe('classifyAnthropicError', () => {
  const headers = new Headers();
  it.each([
    ['a 5xx', new Anthropic.InternalServerError(503, undefined, 'down', headers), 'provider_error'],
    ['overloaded (529)', Anthropic.APIError.generate(529, { type: 'error', error: { type: 'overloaded_error' } }, 'overloaded', headers), 'provider_error'],
    ['an overloaded error mid-stream', new Anthropic.APIError(undefined, {}, 'overloaded', undefined, 'overloaded_error'), 'provider_error'],
    ['a timeout', new Anthropic.APIConnectionTimeoutError(), 'provider_error'],
    ['a dropped connection', new Anthropic.APIConnectionError({ message: 'socket hang up' }), 'provider_error'],
    ['a rate limit', new Anthropic.RateLimitError(429, undefined, 'slow down', headers), 'rate_limited'],
    ['a bad key', new Anthropic.AuthenticationError(401, undefined, 'invalid x-api-key', headers), 'provider_unavailable'],
    ['a bad request', new Anthropic.BadRequestError(400, undefined, 'bad', headers), 'bad_request'],
    ['a user abort', new Anthropic.APIUserAbortError(), 'aborted'],
    ['a bug of ours', new TypeError('undefined is not a function'), 'internal_error'],
  ])('classifies %s', (_label, err, code) => {
    expect(classifyAnthropicError(err).code).toBe(code);
  });

  it('never returns the vendor message verbatim', () => {
    const raw = 'org 99 exceeded quota on claude-x, request_id req_zz11';
    const result = classifyAnthropicError(new Anthropic.InternalServerError(500, undefined, raw, headers));
    expect(result.message).not.toContain('req_zz11');
  });
});

describe('createAnthropicProvider — construction', () => {
  it('does not require a key until a turn actually runs', () => {
    const previous = process.env.ANTHROPIC_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    try {
      expect(() => createAnthropicProvider()).not.toThrow();
    } finally {
      if (previous !== undefined) process.env.ANTHROPIC_API_KEY = previous;
    }
  });

  it('reports a missing key as not_configured, with the detail only in the log', async () => {
    const previous = process.env.ANTHROPIC_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    const logged = silence();
    try {
      const events = await collect(
        createAnthropicProvider().runTurn(contractInput(), new AbortController().signal),
      );
      expect(events).toEqual([
        { type: 'error', code: 'not_configured', message: 'The assistant is not configured yet.' },
      ]);
      expect(String(logged.mock.calls[0]?.[0])).toMatch(/ANTHROPIC_API_KEY.*backend\/\.env/s);
    } finally {
      logged.mockRestore();
      if (previous !== undefined) process.env.ANTHROPIC_API_KEY = previous;
    }
  });
});
