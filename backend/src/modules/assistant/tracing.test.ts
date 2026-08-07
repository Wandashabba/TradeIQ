import {
  LangfuseTracer,
  noopTracer,
  resetTracer,
  tracer,
  type TurnSummary,
  type TurnTrace,
} from './tracing';

const TRACE: TurnTrace = {
  traceId: 't-1',
  userId: 'user-1',
  clientId: 'client-1',
  provider: 'gemini',
  model: 'gemini-3.1-pro',
};

function summary(overrides: Partial<TurnSummary> = {}): TurnSummary {
  return {
    usage: { inputTokens: 1200, outputTokens: 80, cacheReadTokens: 900, costCents: 0.4 },
    durationMs: 1500,
    rounds: 2,
    tools: [{ name: 'getStockLevels', pillar: 'stock', ok: true, durationMs: 120 }],
    ...overrides,
  };
}

/** A tracer with a recording transport and no timer. */
function tracerWithCapture(
  respond: () => Promise<{ ok: boolean; status: number }> = async () => ({
    ok: true,
    status: 207,
  }),
) {
  const calls: { url: string; headers: Record<string, string>; body: string }[] = [];
  const instance = new LangfuseTracer({
    publicKey: 'pk',
    secretKey: 'sk',
    autoFlush: false,
    post: async (url, init) => {
      calls.push({ url, ...init });
      return respond();
    },
  });
  return { instance, calls, batches: () => calls.map((c) => JSON.parse(c.body).batch) };
}

describe('LangfuseTracer', () => {
  it('posts a trace, a generation and a span per tool', async () => {
    const { instance, batches } = tracerWithCapture();

    instance.recordTurn(TRACE, summary());
    await instance.flush();

    const events = batches()[0] as { type: string }[];
    expect(events.map((e) => e.type)).toEqual([
      'trace-create',
      'generation-create',
      'span-create',
    ]);
  });

  it('sends the numbers the Phase 0 gates are stated in', async () => {
    // A cache regression has no functional symptom — it is only ever visible
    // as a number moving, which is the whole reason it is traced.
    const { instance, batches } = tracerWithCapture();

    instance.recordTurn(TRACE, summary());
    await instance.flush();

    const generation = (batches()[0] as { body: Record<string, unknown> }[])[1];
    const metadata = generation.body.metadata as Record<string, unknown>;
    expect(metadata.cacheReadTokens).toBe(900);
    expect(metadata.costCents).toBe(0.4);
    expect(metadata.tools).toEqual(['getStockLevels']);
  });

  it('authenticates with basic auth over the key pair', async () => {
    const { instance, calls } = tracerWithCapture();

    instance.recordTurn(TRACE, summary());
    await instance.flush();

    expect(calls[0].headers.Authorization).toBe(
      `Basic ${Buffer.from('pk:sk').toString('base64')}`,
    );
    expect(calls[0].url).toBe('https://cloud.langfuse.com/api/public/ingestion');
  });

  it('marks an errored turn at ERROR level with its code', async () => {
    const { instance, batches } = tracerWithCapture();

    instance.recordTurn(TRACE, summary({ errorCode: 'rate_limited' }));
    await instance.flush();

    const generation = (batches()[0] as { body: Record<string, unknown> }[])[1];
    expect(generation.body.level).toBe('ERROR');
    expect((generation.body.metadata as Record<string, unknown>).errorCode).toBe(
      'rate_limited',
    );
  });

  describe('privacy', () => {
    it('sends no conversation content by default', async () => {
      // Transcripts carry outlet and agent PII, and the retention policy for
      // them is an OPEN question (#251 Q3) alongside an unanswered POPIA
      // residency question. Shipping capture before those are answered would
      // quietly decide both.
      const { instance, calls } = tracerWithCapture();

      instance.recordTurn(
        TRACE,
        summary({
          content: {
            input: 'How is Tumo doing at Kasi Spaza?',
            output: 'Tumo scored 82 at Kasi Spaza.',
          },
        }),
      );
      await instance.flush();

      expect(calls[0].body).not.toContain('Tumo');
      expect(calls[0].body).not.toContain('Kasi Spaza');
    });

    it('never sends a tool result, at any setting', async () => {
      // Results are the untrusted surface AND the richest source of PII in the
      // system. There is no flag that turns this on.
      const { instance, calls } = tracerWithCapture();

      instance.recordTurn(TRACE, summary());
      await instance.flush();

      const span = JSON.parse(calls[0].body).batch[2];
      expect(Object.keys(span.body.metadata)).toEqual(['pillar', 'ok', 'durationMs']);
    });

    it('sends the tenant as an opaque id, not a name', async () => {
      const { instance, batches } = tracerWithCapture();

      instance.recordTurn(TRACE, summary());
      await instance.flush();

      const trace = (batches()[0] as { body: Record<string, unknown> }[])[0];
      expect((trace.body.metadata as Record<string, unknown>).clientId).toBe('client-1');
    });
  });

  describe('it can never fail a turn', () => {
    it('does not throw when the transport rejects', async () => {
      const { instance } = tracerWithCapture(async () => {
        throw new Error('ECONNREFUSED');
      });
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

      instance.recordTurn(TRACE, summary());
      await expect(instance.flush()).resolves.toBeUndefined();

      warn.mockRestore();
    });

    it('does not requeue a rejected batch', async () => {
      // A 401 from a wrong key would retry forever, and the queue would fill
      // with the same doomed events — tracing then costs more than it reports.
      const { instance, calls } = tracerWithCapture(async () => ({ ok: false, status: 401 }));
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

      instance.recordTurn(TRACE, summary());
      await instance.flush();
      await instance.flush();

      expect(calls).toHaveLength(1);
      warn.mockRestore();
    });

    it('survives a summary it cannot serialise', async () => {
      // The "never fails a turn" property has to hold for OUR bugs too, not
      // just the network's.
      const { instance } = tracerWithCapture();
      const cyclic: Record<string, unknown> = {};
      cyclic.self = cyclic;
      const error = jest.spyOn(console, 'error').mockImplementation(() => {});

      expect(() =>
        instance.recordTurn(TRACE, summary({ tools: cyclic as never })),
      ).not.toThrow();

      error.mockRestore();
    });

    it('drops rather than growing without bound when the endpoint is dead', async () => {
      // An unbounded queue behind an unreachable endpoint is a memory leak that
      // presents as a slow crash hours later, with nothing pointing at tracing.
      const { instance } = tracerWithCapture(async () => ({ ok: false, status: 500 }));
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

      for (let i = 0; i < 400; i += 1) {
        instance.recordTurn({ ...TRACE, traceId: `t-${i}` }, summary());
      }

      // Three events per turn × 400 turns is 1,200, far past the 500 cap.
      await instance.flush();
      expect(warn).toHaveBeenCalledWith(expect.stringContaining('dropped'));
      warn.mockRestore();
    });

    it('flushing an empty queue makes no request', async () => {
      const { instance, calls } = tracerWithCapture();
      await instance.flush();
      expect(calls).toEqual([]);
    });
  });

  it('honours a self-hosted base url without doubling the slash', async () => {
    const calls: string[] = [];
    const instance = new LangfuseTracer({
      publicKey: 'pk',
      secretKey: 'sk',
      baseUrl: 'https://langfuse.internal/',
      autoFlush: false,
      post: async (url) => {
        calls.push(url);
        return { ok: true, status: 207 };
      },
    });

    instance.recordTurn(TRACE, summary());
    await instance.flush();

    expect(calls[0]).toBe('https://langfuse.internal/api/public/ingestion');
  });
});

describe('tracer()', () => {
  const env = { ...process.env };

  afterEach(() => {
    process.env = { ...env };
    resetTracer();
  });

  it('is a no-op when the keys are absent', () => {
    // The state of this repo today, and of every development machine. It must
    // not warn on every request — that trains people to ignore logs.
    delete process.env.LANGFUSE_PUBLIC_KEY;
    delete process.env.LANGFUSE_SECRET_KEY;
    resetTracer();

    expect(tracer()).toBe(noopTracer);
  });

  it('is a no-op when only one key is set', () => {
    // Half-configured is a misconfiguration, and a partially-initialised client
    // is worse than none.
    process.env.LANGFUSE_PUBLIC_KEY = 'pk';
    delete process.env.LANGFUSE_SECRET_KEY;
    resetTracer();

    expect(tracer()).toBe(noopTracer);
  });

  it('builds a real tracer once both keys are present, and memoises it', () => {
    process.env.LANGFUSE_PUBLIC_KEY = 'pk';
    process.env.LANGFUSE_SECRET_KEY = 'sk';
    resetTracer();

    const first = tracer();
    expect(first).toBeInstanceOf(LangfuseTracer);
    // Memoised, so the batching window is shared rather than reset per request.
    expect(tracer()).toBe(first);
    (first as LangfuseTracer).close();
  });

  it('the no-op tracer accepts a turn and does nothing', async () => {
    expect(() => noopTracer.recordTurn(TRACE, summary())).not.toThrow();
    await expect(noopTracer.flush()).resolves.toBeUndefined();
  });
});
