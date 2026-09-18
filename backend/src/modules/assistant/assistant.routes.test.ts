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
    // A turn that streams an artifact now persists a row referencing the
    // tenant, so this has to go before the client does.
    await prisma.assistantArtifact.deleteMany({ where: { clientId } });
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
      // `conversation` leads every turn — the client needs the id it must echo
      // back, and it is sent before anything can fail.
      expect(frames.map((f) => f.event)).toEqual(['conversation', 'token', 'usage', 'done']);
      expect(frames[0].data).toEqual({ id: expect.any(String) });
      expect(frames[1].data).toEqual({ text: 'Hello.' });
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
      expect(parseSse(res.text)[1].data).toEqual({ text: 'line one\nline two' });
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
        'conversation',
        'tool_start',
        'tool_end',
        'artifact',
        // The deterministic stat tiles, after the tool's own view (#answer design).
        'artifact',
        'token',
        'usage',
        'done',
      ]);
      expect(frames[1].data).toEqual({ name: 'getAgentScorecard', pillar: 'execution' });
      expect(frames[3].data).toMatchObject({
        type: 'agent_scorecard',
        params: { agentId: agent.userId },
        data: { averageScore: 82, scoredVisits: 1 },
      });
      // Built server-side from the same result — the model supplied no number.
      expect(frames[4].data).toMatchObject({
        id: 'getAgentScorecard-stat_tiles-1',
        type: 'stat_tiles',
        params: {},
        data: {
          tiles: [
            { label: 'Execution score', value: 82, unit: 'pts' },
            { label: 'Visits', value: 1, unit: 'count' },
            { label: 'Outlets visited', value: 1, unit: 'count' },
          ],
        },
      });
    });

    it('publishes an artifact id that is still refinable after the turn ends', async () => {
      // The point of persisting at all. A turn-local id like
      // `getAgentScorecard-0` renders once and then refers to nothing, so every
      // filter control on the card is dead the moment the stream closes.
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
        [{ type: 'token', text: 'Solid month.' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How has the agent been performing this month?' });

      const frames = parseSse(res.text);
      const conversationId = (frames[0].data as { id: string }).id;
      const artifactId = (frames.find((f) => f.event === 'artifact')!.data as { id: string }).id;

      // A persisted id, not the turn-local fallback.
      expect(artifactId).not.toMatch(/^getAgentScorecard-\d+$/);

      // And it resolves — fresh data, through the caller's own roster.
      const reopened = await request(app)
        .get(`/assistant/artifacts/${artifactId}`)
        .set('Authorization', `Bearer ${manager.token}`)
        .expect(200);

      expect(reopened.body).toMatchObject({
        id: artifactId,
        type: 'agent_scorecard',
        toolName: 'getAgentScorecard',
      });
      expect(reopened.body.data).toMatchObject({ averageScore: 82 });
      expect(conversationId).toEqual(expect.any(String));
    });

    it('tells the model which views are already open, without touching the cached prefix', async () => {
      // The manifest exists so a second question refines the open card instead
      // of stacking a near-duplicate beside it. It rides with the user's turn
      // rather than in the system prompt: the cached prefix is `[tools][system]`
      // and caching is a prefix match, so volatile context in there would miss
      // the cache — and, with explicit caching, bill for a new entry — on most
      // turns.
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
        [{ type: 'token', text: 'Solid.' }, { type: 'done' }],
      ];

      const first = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How has the agent been performing?' });

      const conversationId = (parseSse(first.text)[0].data as { id: string }).id;

      script.calls.length = 0;
      script.rounds = [[{ type: 'token', text: 'Sure.' }, { type: 'done' }]];

      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ conversationId, message: 'And last year?' });

      const turn = script.calls.find((c) => c.model !== 'quarantine')!;
      const lastMessage = turn.messages[turn.messages.length - 1];
      expect(lastMessage.content).toContain('Views already open');
      expect(lastMessage.content).toContain('agent_scorecard');
      // The user's own words survive intact beneath the note.
      expect(lastMessage.content).toContain('And last year?');
      // The frozen prefix is untouched.
      expect(turn.system).not.toContain('Views already open');
    });

    it('tells the model what the user changed with the filter controls', async () => {
      // The stale-params bug, end to end: answer, user drags a filter, user
      // asks a follow-up. Without the note the follow-up is answered against
      // the params the model last saw — which are no longer on screen.
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
        [{ type: 'token', text: 'Solid month.' }, { type: 'done' }],
      ];

      const first = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How has the agent been performing this month?' });

      const firstFrames = parseSse(first.text);
      const conversationId = (firstFrames[0].data as { id: string }).id;
      const artifactId = (firstFrames.find((f) => f.event === 'artifact')!.data as { id: string })
        .id;

      // The user moves the control themselves. No model call — that is the
      // whole point of `refine` — so this is the only way the model finds out.
      await request(app)
        .post(`/assistant/artifacts/${artifactId}/refine`)
        .set('Authorization', `Bearer ${manager.token}`)
        // The TOOL's args, not the view spec's params — `refine` re-runs the
        // tool, so the tool's own schema is the one contract it validates
        // through. See artifacts.service.ts.
        .send({ params: { agent: agent.userId, period: { kind: 'ytd' } } })
        .expect(200);

      script.calls.length = 0;
      script.rounds = [[{ type: 'token', text: 'Sure.' }, { type: 'done' }]];

      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ conversationId, message: 'Now compare that to the team.' });

      const turn = script.calls.find((c) => c.model !== 'quarantine')!;
      const lastMessage = turn.messages[turn.messages.length - 1];

      expect(lastMessage.content).toContain(`[artifact:${artifactId} params → `);
      expect(lastMessage.content).toContain('period=ytd');
      // Said to be the user's doing, not the model's own earlier work.
      expect(lastMessage.content).toContain('The user changed these views themselves');
      expect(lastMessage.content).toContain('Now compare that to the team.');
      // Same cache rule as the manifest: volatile text never enters the prefix,
      // where — since caching went explicit — it would bill a new cache entry
      // every turn rather than merely missing the old one.
      expect(turn.system).not.toContain('The user changed these views');
      expect(turn.system).not.toContain(artifactId);
    });

    it('announces a change once, not on every turn after it', async () => {
      // A note restated forever costs tokens to say what the manifest already
      // carries, and reads as a change that keeps happening.
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
        [{ type: 'token', text: 'Solid.' }, { type: 'done' }],
      ];

      const first = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How is the agent doing?' });

      const firstFrames = parseSse(first.text);
      const conversationId = (firstFrames[0].data as { id: string }).id;
      const artifactId = (firstFrames.find((f) => f.event === 'artifact')!.data as { id: string })
        .id;

      await request(app)
        .post(`/assistant/artifacts/${artifactId}/refine`)
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ params: { agent: agent.userId, period: { kind: 'ytd' } } })
        .expect(200);

      script.rounds = [[{ type: 'token', text: 'Sure.' }, { type: 'done' }]];
      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ conversationId, message: 'And the team?' });

      script.calls.length = 0;
      await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ conversationId, message: 'What about stock?' });

      const turn = script.calls.find((c) => c.model !== 'quarantine')!;
      const lastMessage = turn.messages[turn.messages.length - 1];

      expect(lastMessage.content).not.toContain('The user changed these views');
      // The manifest still carries the current params, which is what a later
      // turn actually needs — the note is about the *change*, not the state.
      expect(lastMessage.content).toContain('Views already open');
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

    it('plots a comparison as a second series, in one turn', async () => {
      // The workflow being killed is "export, save, export again, overlay the
      // two in Excel". Two lines from one question is the whole point, so the
      // second window has to come back as its own SERIES — a per-figure delta
      // is a different thing and cannot be plotted.
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            args: {
              metric: 'execution_score',
              period: { kind: 'mtd' },
              compareTo: { kind: 'previous_period' },
            },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Up on last month.' }, { type: 'done' }],
      ];

      const res = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How does execution this month compare with last month?' });

      const artifact = parseSse(res.text).find((f) => f.event === 'artifact');
      expect(artifact?.data).toMatchObject({
        type: 'trend_chart',
        // The basis rides in the params, so reopening the artifact redraws both
        // lines rather than silently dropping one.
        params: { metric: 'execution_score', compareTo: { kind: 'previous_period' } },
      });

      const data = (
        artifact?.data as {
          data: { points: unknown[]; comparison: { label: string; points: unknown[] } };
        }
      ).data;
      // The one seeded visit is TODAY, and a compared month to date is complete
      // days only on both sides (#365): today's partial figures have nothing
      // like for like to meet, so the current line leaves them out rather than
      // ending on a half-finished day. (The uncompared trend above keeps it.)
      expect(data.points).toEqual([]);
      // Nothing was seeded in the previous window, and an empty second series is
      // the honest answer — not a reason to omit the comparison and leave the
      // user wondering whether it was asked for.
      expect(data.comparison.points).toEqual([]);
      // Like for like (#365): month to date meets the same days of last month.
      expect(data.comparison.label).toBe('the same days last month');
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

    it('resolves a FULL name with a space, which no email can contain (#280)', async () => {
      // "Sipho Ndlovu" is never a substring of any address, so before display
      // names this resolved nobody on any tenant.
      const named = await userIn(clientId, 'field_agent', { displayName: 'Sipho Ndlovu' });
      try {
        script.rounds = [
          [
            {
              type: 'tool_call',
              id: 'c0',
              name: 'getAgentScorecard',
              args: { agent: 'Sipho Ndlovu', period: { kind: 'mtd' } },
            },
            { type: 'done' },
          ],
          [{ type: 'token', text: 'No visits yet this month.' }, { type: 'done' }],
        ];

        const res = await request(app)
          .post('/assistant/chat')
          .set('Authorization', `Bearer ${manager.token}`)
          .send({ message: 'How has Sipho Ndlovu been performing this month?' });

        const artifact = parseSse(res.text).find((f) => f.event === 'artifact');
        expect(artifact?.data).toMatchObject({
          type: 'agent_scorecard',
          params: { agentId: named.userId },
          // The card and the model both see the name, not the address.
          data: { agentName: 'Sipho Ndlovu', agentEmail: named.email },
        });
      } finally {
        await prisma.user.delete({ where: { id: named.userId } });
      }
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

    describe('getCompetitorShelfPrices — gated off by default', () => {
      const previous = process.env.COMPETITOR_PRICE_COLLECTION;
      afterEach(async () => {
        if (previous === undefined) delete process.env.COMPETITOR_PRICE_COLLECTION;
        else process.env.COMPETITOR_PRICE_COLLECTION = previous;
        await prisma.client.update({
          where: { id: clientId },
          data: {
            competitorPriceCollectionEnabled: false,
            competitorPriceCollectionApprovedBy: null,
            competitorPriceCollectionApprovedAt: null,
          },
        });
      });

      async function declaredNames(): Promise<string[]> {
        script.calls = [];
        script.rounds = [[{ type: 'done' }]];
        await request(app)
          .post('/assistant/chat')
          .set('Authorization', `Bearer ${manager.token}`)
          .send({ message: 'hi' });
        return script.calls.find((c) => c.model !== 'quarantine')!.tools.map((t) => t.name);
      }

      it('is not declared while the kill switch is off, even for an enabled, approved client', async () => {
        delete process.env.COMPETITOR_PRICE_COLLECTION;
        await prisma.client.update({
          where: { id: clientId },
          data: {
            competitorPriceCollectionEnabled: true,
            competitorPriceCollectionApprovedBy: 'Counsel',
            competitorPriceCollectionApprovedAt: new Date('2026-09-01'),
          },
        });
        const names = await declaredNames();
        expect(names).toContain('getPriceCompliance');
        expect(names).not.toContain('getCompetitorShelfPrices');
      });

      it('is not declared for a client that has not enabled it, with the kill switch on', async () => {
        process.env.COMPETITOR_PRICE_COLLECTION = 'on';
        expect(await declaredNames()).not.toContain('getCompetitorShelfPrices');
      });

      it('is declared once the kill switch is on and the client is enabled and approved', async () => {
        process.env.COMPETITOR_PRICE_COLLECTION = 'on';
        await prisma.client.update({
          where: { id: clientId },
          data: {
            competitorPriceCollectionEnabled: true,
            competitorPriceCollectionApprovedBy: 'Counsel',
            competitorPriceCollectionApprovedAt: new Date('2026-09-01'),
          },
        });
        expect(await declaredNames()).toContain('getCompetitorShelfPrices');
      });
    });
  });

  /**
   * The Phase 2 gate's headline item: the two control paths converge.
   *
   * An artifact can be steered two ways — by talking to the model, which calls
   * a tool with new arguments, and by moving a control, which POSTs to
   * `/refine`. The plan's bet is that these are the *same* operation reached
   * two ways, because both write through the tool's own Zod schema and both
   * store what that schema returned.
   *
   * Nothing asserted it. The machinery was built and reviewed and believed;
   * "both paths call safeParse" is a claim about two call sites in two files
   * that no test compared. These do, by driving each path to the same
   * destination and requiring the results to be indistinguishable.
   */
  describe('the two control paths converge', () => {
    /** The artifact row as stored, with the volatile fields dropped. */
    async function stateOf(artifactId: string) {
      const res = await request(app)
        .get(`/assistant/artifacts/${artifactId}`)
        .set('Authorization', `Bearer ${manager.token}`)
        .expect(200);
      // `id`, `createdAt`/`updatedAt` and `canUndo` are properties of how the
      // artifact GOT here, and the two paths get here differently on purpose.
      // What has to match is what it IS: which tool, rendered as what, against
      // which parameters, returning which figures.
      const { type, toolName, params, data } = res.body;
      return { type, toolName, params, data };
    }

    it('a prompt-driven change and a UI-driven change land on identical state', async () => {
      // Path A — the user asks, and asks again differently.
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            args: { metric: 'execution_score', period: { kind: 'mtd' }, interval: 'day' },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Here it is by day.' }, { type: 'done' }],
      ];
      const asked = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How has execution score been trending this month?' });
      const uiArtifactId = (
        parseSse(asked.text).find((f) => f.event === 'artifact')!.data as { id: string }
      ).id;

      // …then steers that same card with the controls, to weekly buckets over
      // the year.
      await request(app)
        .post(`/assistant/artifacts/${uiArtifactId}/refine`)
        .set('Authorization', `Bearer ${manager.token}`)
        .send({
          params: { metric: 'execution_score', period: { kind: 'ytd' }, interval: 'week' },
        })
        .expect(200);

      // Path B — a different conversation where the model is simply asked for
      // that destination directly, and never touches a control.
      script.calls.length = 0;
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            args: { metric: 'execution_score', period: { kind: 'ytd' }, interval: 'week' },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Weekly, year to date.' }, { type: 'done' }],
      ];
      const told = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'Show execution score weekly, year to date.' });
      const promptArtifactId = (
        parseSse(told.text).find((f) => f.event === 'artifact')!.data as { id: string }
      ).id;

      // Two different rows, reached two different ways.
      expect(promptArtifactId).not.toBe(uiArtifactId);

      // Indistinguishable in everything that describes the view: same spec
      // type, same tool, same parameter bag, same figures. If these ever
      // diverge, "ask a follow-up about the card you just filtered" is
      // answered against a state the user is not looking at.
      expect(await stateOf(uiArtifactId)).toEqual(await stateOf(promptArtifactId));
    });

    it('a schema default lands the same whether the model omits it or the UI sends it', async () => {
      // The seam where the two paths would silently diverge. `interval` is
      // `.default('day')`, so the model can omit it entirely while the UI —
      // which renders a granularity control with a value in it — always sends
      // it. If either path stored what it was HANDED rather than what Zod
      // RETURNED, the two rows would carry `{}` and `{interval:'day'}`: the
      // same chart, different stored state.
      //
      // That is not cosmetic. The manifest shows the model the stored params,
      // and `undo` restores them — so a raw-stored bag would have the model
      // reasoning about an artifact whose interval it cannot see, and an undo
      // stepping back to a bag that renders differently.
      //
      // **This is the only test here that catches it.** Verified by changing
      // the orchestrator to persist `call.args` instead of `parsed.data`: this
      // one fails, and the other two in this block still pass, because their
      // scripted calls happen to state `interval` explicitly so raw and parsed
      // coincide. Convergence at a destination and convergence of
      // normalisation are different properties, and only the second one has a
      // seam that can quietly come apart.
      script.calls.length = 0;
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            // No `interval`. Zod fills it.
            args: { metric: 'availability', period: { kind: 'mtd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Availability, by day.' }, { type: 'done' }],
      ];
      const omitted = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'How is availability trending?' });
      const omittedId = (
        parseSse(omitted.text).find((f) => f.event === 'artifact')!.data as { id: string }
      ).id;

      // The default was materialised on the way in, not left implicit.
      const omittedState = await stateOf(omittedId);
      expect(omittedState.params).toMatchObject({ interval: 'day' });

      // Now the same destination with the value stated explicitly, via the
      // control rather than the model.
      script.calls.length = 0;
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            args: { metric: 'availability', period: { kind: 'ytd' } },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Year to date.' }, { type: 'done' }],
      ];
      const other = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'And year to date?' });
      const explicitId = (
        parseSse(other.text).find((f) => f.event === 'artifact')!.data as { id: string }
      ).id;

      await request(app)
        .post(`/assistant/artifacts/${explicitId}/refine`)
        .set('Authorization', `Bearer ${manager.token}`)
        .send({
          params: { metric: 'availability', period: { kind: 'mtd' }, interval: 'day' },
        })
        .expect(200);

      expect(await stateOf(explicitId)).toEqual(omittedState);
    });

    it('an undo lands where the prompt-driven path would have put it', async () => {
      // Undo is the third writer of `params`, and the one most easily left out
      // of step: it restores a bag from history rather than composing a new
      // one. It re-validates through the same schema for exactly this reason,
      // and this is what says so.
      script.calls.length = 0;
      script.rounds = [
        [
          {
            type: 'tool_call',
            id: 'c0',
            name: 'getMetricTrend',
            args: { metric: 'perfect_store', period: { kind: 'mtd' }, interval: 'day' },
          },
          { type: 'done' },
        ],
        [{ type: 'token', text: 'Perfect store, by day.' }, { type: 'done' }],
      ];
      const asked = await request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'Perfect store this month?' });
      const artifactId = (
        parseSse(asked.text).find((f) => f.event === 'artifact')!.data as { id: string }
      ).id;

      const original = await stateOf(artifactId);

      await request(app)
        .post(`/assistant/artifacts/${artifactId}/refine`)
        .set('Authorization', `Bearer ${manager.token}`)
        .send({
          params: { metric: 'perfect_store', period: { kind: 'ytd' }, interval: 'week' },
        })
        .expect(200);
      expect(await stateOf(artifactId)).not.toEqual(original);

      await request(app)
        .post(`/assistant/artifacts/${artifactId}/undo`)
        .set('Authorization', `Bearer ${manager.token}`)
        .expect(200);

      // Back to exactly where the model's own call had left it — not merely to
      // something that renders the same.
      expect(await stateOf(artifactId)).toEqual(original);
    });
  });

  describe('outside-context switch', () => {
    const outside = ['getCalendarContext', 'getWeatherContext', 'getEconomicContext'];
    const declared = () => script.calls[0].tools.map((t: { name: string }) => t.name);
    const turn = () =>
      request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'Was there a public holiday last week?' })
        .expect(200);

    afterEach(async () => {
      await prisma.client.update({ where: { id: clientId }, data: { assistantExternalContextEnabled: true } });
    });

    it('declares the calendar, weather and economy tools by default', async () => {
      script.rounds = [[{ type: 'token', text: 'ok' }, { type: 'done' }]];
      await turn();
      expect(declared()).toEqual(expect.arrayContaining(outside));
    });

    it('does not declare them to a tenant that has switched them off', async () => {
      await prisma.client.update({ where: { id: clientId }, data: { assistantExternalContextEnabled: false } });
      script.rounds = [[{ type: 'token', text: 'ok' }, { type: 'done' }]];
      await turn();
      for (const name of outside) expect(declared()).not.toContain(name);
      expect(declared()).toContain('getRateOfSale');
    });
  });

  describe('live web search switch', () => {
    const turn = () =>
      request(app)
        .post('/assistant/chat')
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ message: 'Any Shoprite promotions this week?' })
        .expect(200);

    afterEach(async () => {
      await prisma.client.update({ where: { id: clientId }, data: { assistantWebSearchEnabled: true } });
    });

    it('offers web search by default', async () => {
      script.rounds = [[{ type: 'token', text: 'ok' }, { type: 'done' }]];
      await turn();
      expect(script.calls[0].webSearch).toBe(true);
    });

    it('does not offer it to a tenant that has switched it off', async () => {
      await prisma.client.update({ where: { id: clientId }, data: { assistantWebSearchEnabled: false } });
      script.rounds = [[{ type: 'token', text: 'ok' }, { type: 'done' }]];
      await turn();
      expect(script.calls[0].webSearch).toBeFalsy();
    });

    it('streams validated sources after the answer', async () => {
      script.rounds = [
        [
          { type: 'web_search' },
          { type: 'token', text: 'Public reports say Shoprite has a promotion.' },
          {
            type: 'sources',
            sources: [
              { url: 'https://www.news24.com/business/shoprite', title: 'Shoprite promo', snippet: 'Two weeks.' },
              { url: 'javascript:alert(1)', title: 'bad' },
            ],
          },
          { type: 'done' },
        ],
      ];
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

      const res = await turn();
      warn.mockRestore();

      const frames = parseSse(res.text);
      expect(frames.map((f) => f.event)).toEqual([
        'conversation',
        'tool_start',
        'tool_end',
        'token',
        'sources',
        'usage',
        'done',
      ]);
      expect(frames[1]).toEqual({ event: 'tool_start', data: { name: 'webSearch', pillar: 'web' } });
      expect(frames[4].data).toEqual({
        sources: [
          {
            title: 'Shoprite promo',
            url: 'https://www.news24.com/business/shoprite',
            domain: 'news24.com',
            pageAge: null,
            retrievedAt: expect.any(String),
            snippet: 'Two weeks.',
            // #406. A vendor search result declares no origin of its own, so
            // it is what it is. Neither a publisher name nor a release date is
            // available, and both say so with null rather than by absence.
            origin: 'web_search',
            publisher: null,
            publishedAt: null,
          },
        ],
      });
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
      // The conversation id still leads. A turn that fails is exactly when the
      // client most needs it — the retry belongs in the same conversation, and
      // any artifacts from earlier turns are found by that id.
      expect(frames).toEqual([
        { event: 'conversation', data: { id: expect.any(String) } },
        { event: 'error', data: { code: 'rate_limited', message: 'Busy right now.' } },
      ]);
    });
  });
});
