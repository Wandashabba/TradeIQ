import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { errorHandler } from '../../middleware/errorHandler';
import { foreignTenant, userIn } from '../../test-utils/tenants';
import type { LlmProvider, TurnEvent, TurnInput } from './providers/types';

/**
 * The provider is stubbed for the whole file.
 *
 * A route test that reaches a real model would need a key, cost money per run,
 * and assert on prose. Tool *selection* is what these tests are about, and it
 * is deterministic — the model's choice is scripted, and what we assert is that
 * the right service ran, at the right tenant, with the right arguments.
 */
const script: { rounds: TurnEvent[][]; calls: TurnInput[] } = { rounds: [], calls: [] };

jest.mock('./providers', () => ({
  providerFor: (): LlmProvider => ({
    name: 'gemini',
    models: { orchestrator: 'big', quarantine: 'small' },
    normaliseUsage: () => ({ inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, costCents: 0 }),
    async *runTurn(input: TurnInput) {
      script.calls.push(input);
      if (input.model === 'quarantine') {
        yield { type: 'token', text: '1: summarised' };
        yield { type: 'done' };
        return;
      }
      const round = script.calls.filter((c) => c.model !== 'quarantine').length - 1;
      for (const event of script.rounds[round] ?? [{ type: 'done' as const }]) yield event;
    },
  }),
}));

// Imported after `jest.mock` above, which jest hoists — so the router picks up
// the stubbed provider rather than one built from a key this environment has
// no reason to hold.
import { assistantRouter } from './assistant.routes';

const expressApp = express();
expressApp.use(express.json());
expressApp.use('/assistant', assistantRouter);
expressApp.use(errorHandler);
// Listening once, so supertest reuses this socket rather than binding a fresh
// ephemeral port per request — see src/testHttpServer.ts (#227).
const app = createServer(expressApp).listen(0);
app.unref();

/** Parse an SSE body into `{event, data}` frames. */
function parseSse(body: string): { event: string; data: unknown }[] {
  return body
    .split('\n\n')
    .filter((block) => block.trim().length > 0)
    .map((block) => {
      const event = /^event: (.+)$/m.exec(block)?.[1] ?? '';
      const data = /^data: (.+)$/m.exec(block)?.[1] ?? '{}';
      return { event, data: JSON.parse(data) };
    });
}

describe('POST /assistant/chat', () => {
  let clientId: string;
  let manager: Awaited<ReturnType<typeof userIn>>;
  let agent: Awaited<ReturnType<typeof userIn>>;
  let outletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: `ASSISTANT-${Date.now()}`,
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        assistantEnabled: true,
      },
    });
    clientId = client.id;
    manager = await userIn(clientId, 'manager');
    agent = await userIn(clientId, 'field_agent');

    const outlet = await prisma.outlet.create({
      data: {
        clientId,
        name: 'Kasi Spaza',
        code: `OUT-${Date.now()}`,
        channelType: 'informal',
        territoryId: 'GP-01',
        lat: -26.2,
        lng: 28.04,
        acvWeight: 1,
      },
    });
    outletId = outlet.id;

    const visit = await prisma.visit.create({
      data: {
        clientId,
        outletId,
        agentId: agent.userId,
        checkinTs: new Date(),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: visit.id,
        dimensionScores: { availability: 90, pricing: 74 },
        weightedTotal: 82,
        ratingBand: 'green',
      },
    });

    // One line out of stock, so getStockLevels has an outlet to put on a map.
    const sku = await prisma.sku.create({
      data: { clientId, name: 'Cola 500ml', category: 'beverages', minFacingsStandard: 2, rrp: 12 },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visit.id,
        skuId: sku.id,
        unitsAvailable: 0,
        lastStockinDate: new Date(),
        daysOutOfStock: 3,
        velocityAvg: 1.5,
        coverageDaysPredicted: 0,
      },
    });
  });

  afterAll(async () => {
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
  });

  beforeEach(() => {
    script.rounds = [];
    script.calls = [];
  });

  describe('the gates in front of it', () => {
    it('401s without a token', async () => {
      await request(app).post('/assistant/chat').send({ message: 'hi' }).expect(401);
    });

    it('404s a tenant outside the rollout, rather than 403', async () => {
      // 403 concedes the feature exists and this tenant is not entitled, which
      // invites probing. 404 makes the kill switch indistinguishable from the
      // feature never having shipped.
      const other = await foreignTenant('manager');
      try {
        await request(app)
          .post('/assistant/chat')
          .set('Authorization', `Bearer ${other.token}`)
          .send({ message: 'hi' })
          .expect(404);
      } finally {
        await other.cleanup();
      }
    });

    it('400s an empty message before the stream opens', async () => {
      // Once headers are flushed the status is fixed at 200 and every failure
      // has to travel as an event, so validation must happen first.
      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: '   ' })
        .expect(400);

      expect(res.body.error).toBe('Invalid request');
    });

    it('400s a history longer than the cap', async () => {
      // History replays on every turn, so its size is a direct cost multiplier.
      const history = Array.from({ length: 50 }, () => ({ role: 'user', content: 'x' }));
      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'hi', history })
        .expect(400);
    });
  });

  describe('the stream', () => {
    it('answers as text/event-stream with buffering disabled', async () => {
      script.rounds = [[{ type: 'token', text: 'Hello.' }, { type: 'done' }]];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'hi' })
        .expect(200);

      expect(res.headers['content-type']).toMatch(/text\/event-stream/);
      // Nginx buffers proxied responses by default, holding every token until
      // the turn ends — the stream still "works" and feels broken.
      expect(res.headers['x-accel-buffering']).toBe('no');
    });

    it('emits token, usage and done frames', async () => {
      script.rounds = [[{ type: 'token', text: 'Hello.' }, { type: 'done' }]];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'hi' });

      const frames = parseSse(res.text);
      expect(frames.map((f) => f.event)).toEqual(['token', 'usage', 'done']);
      expect(frames[0].data).toEqual({ text: 'Hello.' });
    });

    it('every frame is parseable JSON on one data line', async () => {
      // The client parses unconditionally; a multi-line data payload would
      // break it, and a newline in a token is entirely ordinary.
      script.rounds = [[{ type: 'token', text: 'line one\nline two' }, { type: 'done' }]];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'hi' });

      expect(() => parseSse(res.text)).not.toThrow();
      expect(parseSse(res.text)[0].data).toEqual({ text: 'line one\nline two' });
    });
  });

  describe('tools, at the caller\'s scope', () => {
    it('runs the real scorecard service and streams an artifact', async () => {
      // The exit demo, end to end: scripted tool choice -> real service ->
      // validated view spec -> artifact frame.
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getAgentScorecard',
            args: { agent: agent.userId, period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'They scored 82.' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How has the agent been performing this month?' });

      const frames = parseSse(res.text);
      expect(frames.map((f) => f.event)).toEqual([
        'tool_start',
        'tool_end',
        'artifact',
        'token',
        'usage',
        'done',
      ]);
      expect(frames[0].data).toEqual({ name: 'getAgentScorecard', pillar: 'execution' });
      expect(frames[2].data).toMatchObject({
        type: 'agent_scorecard',
        params: { agentId: agent.userId },
        data: { averageScore: 82, scoredVisits: 1 },
      });
    });

    it('streams an outlet map when stockouts have somewhere to point', async () => {
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getStockLevels',
            args: { period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'One outlet is dry.' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'Which stores keep running out of stock?' });

      const artifact = parseSse(res.text).find((f) => f.event === 'artifact');
      // Ids in the params (canonical, so Phase 2 can re-run them), coordinates
      // in the data — the client draws pins without a second fetch.
      expect(artifact?.data).toMatchObject({
        type: 'outlet_map',
        params: { outletIds: [outletId] },
        data: {
          worstOutlets: [{ outletId, outletName: 'Kasi Spaza', outOfStockLines: 1, lat: -26.2, lng: 28.04 }],
        },
      });
    });

    it('streams a trend chart from the real trends service', async () => {
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            // No interval: the schema default must fill it in, and the spec
            // params must carry the defaulted value, not undefined.
            args: { metric: 'execution_score', period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Holding steady.' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How has the execution score moved this month?' });

      const artifact = parseSse(res.text).find((f) => f.event === 'artifact');
      expect(artifact?.data).toMatchObject({
        type: 'trend_chart',
        params: { metric: 'execution_score', interval: 'day' },
      });
      // The one seeded scorecard (82) lands in exactly one daily bucket.
      const data = (artifact?.data as { data: { points: { value: number }[] } }).data;
      expect(data.points).toHaveLength(1);
      expect(data.points[0].value).toBe(82);
    });

    it('resolves a NAME to the right agent in one hop', async () => {
      // The finding from the first live eval sweep. Requiring an id meant
      // "How has Tumo been performing?" had to spend a discovery round first,
      // so the exit demo routed to getVisitHistory — correctly, given the tools
      // it had. Managers say names.
      const localPart = agent.email.split('@')[0];
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getAgentScorecard',
            args: { agent: localPart, period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'They scored 82.' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: `How has ${localPart} been performing this month?` });

      const frames = parseSse(res.text);
      const artifact = frames.find((f) => f.event === 'artifact');
      // The artifact carries the CANONICAL id even though the model passed a
      // name — Phase 2's `refine` re-runs from these params, and "Tumo" is not
      // something a tool closure can be re-invoked with.
      expect(artifact?.data).toMatchObject({
        type: 'agent_scorecard',
        params: { agentId: agent.userId },
        data: { averageScore: 82 },
      });
    });

    it('asks which one when a name matches several people', async () => {
      // Picking the first would report one person's numbers under another's
      // name — the kind of wrong that gets taken into a meeting.
      const twin = await userIn(clientId, 'field_agent');
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getAgentScorecard',
            // Both seeded users share the `test-field_agent-` prefix.
            args: { agent: 'test-field_agent-', period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Which one did you mean?' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'how is the agent doing' });

      const frames = parseSse(res.text);
      expect(frames.find((f) => f.event === 'tool_end')?.data).toMatchObject({ ok: false });

      // The disambiguation must REACH the model — a generic "that lookup
      // failed" would strand the turn on an answerable question.
      const secondRound = script.calls.filter((c) => c.model !== 'quarantine')[1];
      const toolMessage = secondRound.messages.find((m) => m.role === 'tool') as {
        content: string;
      };
      expect(toolMessage.content).toMatch(/matches \d+ people/);
      expect(toolMessage.content).toContain(twin.email);
    });

    it('tells the model when nobody matches, rather than failing opaquely',
      async () => {
        script.rounds = [
          [
            {
              type: 'tool_call',
              id: 'c0',
              name: 'getAgentScorecard',
              args: { agent: 'Nobody McNoone', period: { kind: 'mtd' } },
            },
            { type: 'done' },
          ],
          [{ type: 'token', text: 'I could not find them.' }, { type: 'done' }],
        ];

        await request(app)
          .post('/assistant/chat')
          .set('Authorization', `Bearer ${manager.token}`)
          .send({ message: 'how is Nobody McNoone doing' });

        const secondRound = script.calls.filter((c) => c.model !== 'quarantine')[1];
        const toolMessage = secondRound.messages.find((m) => m.role === 'tool') as {
          content: string;
        };
        expect(toolMessage.content).toContain('Nobody McNoone');
      });

    it('cannot reach another tenant\'s agent', async () => {
      // The cross-tenant probe. The model names a real user id from another
      // client; the tool is a closure over OUR clientId, so the lookup finds
      // nothing. Zero tolerance — this is the assertion that matters most.
      const other = await foreignTenant('manager');
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getAgentScorecard',
            args: { agent: other.userId, period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'I could not find that agent.' }, { type: 'done' }],
      ];

      try {
        const res = await request(app)
          .post('/assistant/chat')
          .set('Authorization', `Bearer ${manager.token}`)
          .send({ message: 'how is that agent doing' });

        const frames = parseSse(res.text);
        expect(frames.find((f) => f.event === 'tool_end')?.data).toMatchObject({ ok: false });
        expect(frames.some((f) => f.event === 'artifact')).toBe(false);
        // Nothing about the other tenant reached the wire.
        expect(res.text).not.toContain(other.clientId);
      } finally {
        await other.cleanup();
      }
    });

    it('gives a field agent no tools at all', async () => {
      // The Phase 0 audience decision, asserted at the route rather than only
      // in the roster unit test: manager console only.
      script.rounds = [[{ type: 'token', text: 'I cannot help with that.' }, { type: 'done' }]];

      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${agent.token}`)
        .send({ message: 'how am I doing' })
        .expect(200);

      const turn = script.calls.find((c) => c.model !== 'quarantine');
      expect(turn?.tools).toEqual([]);
    });

    it('gives a manager the implemented tools, and no clientId in any schema', async () => {
      // If an args schema ever grows a tenant field, the structural guarantee
      // is gone and every other defence is doing work it should not have to.
      script.rounds = [[{ type: 'done' }]];

      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'hi' });

      const turn = script.calls.find((c) => c.model !== 'quarantine');
      expect(turn!.tools.length).toBeGreaterThan(0);
      for (const tool of turn!.tools) {
        expect(JSON.stringify(tool.args)).not.toMatch(/clientId|tenantId|userId/);
      }
    });
  });

  describe('errors travel as frames once the stream is open', () => {
    it('sends a provider failure as an error event, not a 500', async () => {
      script.rounds = [[{ type: 'error', code: 'rate_limited', message: 'Busy right now.' }]];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'hi' })
        .expect(200);

      const frames = parseSse(res.text);
      expect(frames).toEqual([
        { event: 'error', data: { code: 'rate_limited', message: 'Busy right now.' } },
      ]);
    });
  });
});
