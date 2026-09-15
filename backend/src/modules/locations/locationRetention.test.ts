import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, userIn } from '../../test-utils/tenants';
import {
  StopSummary,
  foldStops,
  parsePruneArgs,
  pruneLocationPings,
  purgeAgentLocationPings,
  utcDayStart,
} from './locationRetention';

/**
 * #178 — raw pings kept 90 days, then folded into day summaries and deleted;
 * a deactivated agent's raw pings deleted at once. It deletes rows, so most of
 * this is about what must survive.
 */
describe('location ping retention (#178)', () => {
  const DAY = 24 * 60 * 60 * 1000;
  const now = new Date('2026-09-15T12:00:00.000Z');
  /** Midnight UTC `n` days before `now`'s day, plus `hours`. */
  const dayAt = (daysAgo: number, hours: number) =>
    new Date(utcDayStart(now).getTime() - daysAgo * DAY + hours * 60 * 60 * 1000);

  // Two stores ~1km apart, and a point between them outside both fences.
  const storeA = { lat: -26.1, lng: 28.05 };
  const storeB = { lat: -26.109, lng: 28.05 };
  const street = { lat: -26.1045, lng: 28.05 };

  let clientId: string;
  let otherClientId: string;
  let outletA: string;
  let outletB: string;
  let admin: TestUser;

  const newClient = async (name: string) =>
    (await prisma.client.create({ data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} } })).id;

  const addPing = (agent: TestUser, at: Date, where: { lat: number; lng: number }) =>
    prisma.agentLocationPing.create({
      data: { clientId: agent.clientId, agentId: agent.userId, ...where, recordedAt: at, source: 'foreground' },
    });

  const summary = (agent: TestUser, day: Date) =>
    prisma.agentDaySummary.findUnique({ where: { agentId_day: { agentId: agent.userId, day } } });

  const rawCount = (agent: TestUser) => prisma.agentLocationPing.count({ where: { agentId: agent.userId } });

  beforeAll(async () => {
    clientId = await newClient('RET-Client');
    otherClientId = await newClient('RET-Other');
    outletA = (
      await prisma.outlet.create({
        data: { clientId, name: 'Store A', code: 'RET-A', channelType: 'grocery', territoryId: 'T', ...storeA },
      })
    ).id;
    outletB = (
      await prisma.outlet.create({
        data: { clientId, name: 'Store B', code: 'RET-B', channelType: 'grocery', territoryId: 'T', ...storeB },
      })
    ).id;
    admin = await userIn(clientId, 'admin');
  });

  afterEach(async () => {
    await prisma.agentLocationPing.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.agentDaySummary.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
  });

  afterAll(async () => {
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
  });

  describe('foldStops', () => {
    const outlets = [
      { id: 'a', name: 'Store A', ...storeA },
      { id: 'b', name: 'Store B', ...storeB },
    ];
    const at = (minute: number) => new Date(Date.UTC(2026, 8, 1, 8, minute));

    it('folds consecutive in-fence pings into ordered stops, whatever order they arrive in', () => {
      const stops = foldStops(
        [
          { ...storeB, recordedAt: at(30) },
          { ...storeA, recordedAt: at(2) },
          { ...street, recordedAt: at(15) },
          { ...storeA, recordedAt: at(0) },
          { ...storeB, recordedAt: at(34) },
          { ...storeA, recordedAt: at(4) },
        ],
        outlets,
      );
      expect(stops).toEqual<StopSummary[]>([
        { outletId: 'a', outletName: 'Store A', arrivedAt: at(0).toISOString(), leftAt: at(4).toISOString(), pingCount: 3 },
        { outletId: 'b', outletName: 'Store B', arrivedAt: at(30).toISOString(), leftAt: at(34).toISOString(), pingCount: 2 },
      ]);
    });

    it('treats leaving and returning to the same store as two stops', () => {
      const stops = foldStops(
        [
          { ...storeA, recordedAt: at(0) },
          { ...street, recordedAt: at(10) },
          { ...storeA, recordedAt: at(20) },
        ],
        outlets,
      );
      expect(stops.map((s) => [s.outletId, s.pingCount])).toEqual([
        ['a', 1],
        ['a', 1],
      ]);
    });

    it('has no stops for a day spent outside every fence', () => {
      expect(foldStops([{ ...street, recordedAt: at(0) }], outlets)).toEqual([]);
    });
  });

  describe('parsePruneArgs', () => {
    it('parses every flag', () => {
      expect(parsePruneArgs(['--dry-run', '--client', 'c1', '--max-agent-days', '25'])).toEqual({
        dryRun: true,
        clientId: 'c1',
        maxAgentDays: 25,
      });
      expect(parsePruneArgs([])).toEqual({});
    });

    it.each([
      [['--older-than', '5']],
      [['--client']],
      [['--client', '--dry-run']],
      [['--max-agent-days', '0']],
      [['--max-agent-days', 'lots']],
    ])('refuses %j', (argv) => {
      expect(() => parsePruneArgs(argv)).toThrow();
    });
  });

  it('utcDayStart is midnight UTC', () => {
    expect(utcDayStart(new Date('2026-09-15T23:59:59.999Z')).toISOString()).toBe('2026-09-15T00:00:00.000Z');
    expect(utcDayStart(new Date('2026-09-15T00:00:00.000Z')).toISOString()).toBe('2026-09-15T00:00:00.000Z');
  });

  describe('pruneLocationPings', () => {
    it('writes the day summary, then deletes only raw pings past the 90-day cutoff', async () => {
      const agent = await userIn(clientId, 'field_agent');
      const oldDay = dayAt(100, 0);
      // Day 100: store A x3, the street, store B x2 — inserted out of order.
      await addPing(agent, dayAt(100, 9.5), storeB);
      await addPing(agent, dayAt(100, 8), storeA);
      await addPing(agent, dayAt(100, 8.1), storeA);
      await addPing(agent, dayAt(100, 9), street);
      await addPing(agent, dayAt(100, 8.2), storeA);
      await addPing(agent, dayAt(100, 9.6), storeB);
      // Day 95: one ping.
      await addPing(agent, dayAt(95, 10), street);
      // Day 89: inside retention.
      await addPing(agent, dayAt(89, 10), storeA);

      const result = await pruneLocationPings({ now });

      expect(result.cutoff.toISOString()).toBe(utcDayStart(new Date(now.getTime() - 90 * DAY)).toISOString());
      expect(result).toMatchObject({ agentDaysSummarised: 2, pingsDeleted: 7, dryRun: false, stoppedEarly: false });
      expect(await rawCount(agent)).toBe(1);

      const day100 = await summary(agent, oldDay);
      expect(day100).toMatchObject({
        clientId,
        pingCount: 6,
        firstPingAt: dayAt(100, 8),
        lastPingAt: dayAt(100, 9.6),
      });
      expect(day100!.stops).toEqual([
        { outletId: outletA, outletName: 'Store A', arrivedAt: dayAt(100, 8).toISOString(), leftAt: dayAt(100, 8.2).toISOString(), pingCount: 3 },
        { outletId: outletB, outletName: 'Store B', arrivedAt: dayAt(100, 9.5).toISOString(), leftAt: dayAt(100, 9.6).toISOString(), pingCount: 2 },
      ]);
      expect(await summary(agent, dayAt(95, 0))).toMatchObject({ pingCount: 1, stops: [] });
      expect(await summary(agent, dayAt(89, 0))).toBeNull();
    });

    it('holds the cutoff exactly: the last instant before it goes, the cutoff itself stays', async () => {
      const agent = await userIn(clientId, 'field_agent');
      const cutoff = utcDayStart(new Date(now.getTime() - 90 * DAY));
      await addPing(agent, new Date(cutoff.getTime() - 1), storeA);
      const kept = await addPing(agent, cutoff, storeA);

      await pruneLocationPings({ now });

      const left = await prisma.agentLocationPing.findMany({ where: { agentId: agent.userId } });
      expect(left.map((p) => p.id)).toEqual([kept.id]);
    });

    it('is idempotent: a second run finds nothing and does not double-count', async () => {
      const agent = await userIn(clientId, 'field_agent');
      await addPing(agent, dayAt(120, 8), storeA);
      await addPing(agent, dayAt(120, 9), storeA);

      expect((await pruneLocationPings({ now })).agentDaysSummarised).toBe(1);
      const again = await pruneLocationPings({ now });
      expect(again).toMatchObject({ agentDaysSummarised: 0, pingsDeleted: 0 });
      expect((await summary(agent, dayAt(120, 0)))!.pingCount).toBe(2);
    });

    it('is resumable: a run stopped early finishes on the next one with the same result', async () => {
      const agent = await userIn(clientId, 'field_agent');
      for (const daysAgo of [130, 125, 120]) {
        await addPing(agent, dayAt(daysAgo, 8), storeA);
        await addPing(agent, dayAt(daysAgo, 8.5), storeA);
      }

      const first = await pruneLocationPings({ now, maxAgentDays: 1 });
      expect(first).toMatchObject({ agentDaysSummarised: 1, pingsDeleted: 2, stoppedEarly: true });
      expect(await summary(agent, dayAt(130, 0))).not.toBeNull();
      expect(await summary(agent, dayAt(125, 0))).toBeNull();

      const rest = await pruneLocationPings({ now });
      expect(rest).toMatchObject({ agentDaysSummarised: 2, pingsDeleted: 4, stoppedEarly: false });
      for (const daysAgo of [130, 125, 120]) {
        expect((await summary(agent, dayAt(daysAgo, 0)))!.pingCount).toBe(2);
      }
      expect(await rawCount(agent)).toBe(0);
    });

    it('merges into a summary that already exists for that day', async () => {
      const agent = await userIn(clientId, 'field_agent');
      await addPing(agent, dayAt(100, 8), storeA);
      await pruneLocationPings({ now });
      // A later ping for the same day (e.g. folded by a deactivation purge before).
      await addPing(agent, dayAt(100, 15), storeB);
      await addPing(agent, dayAt(100, 7), street);
      await pruneLocationPings({ now });

      const merged = await summary(agent, dayAt(100, 0));
      expect(merged).toMatchObject({ pingCount: 3, firstPingAt: dayAt(100, 7), lastPingAt: dayAt(100, 15) });
      expect((merged!.stops as unknown as StopSummary[]).map((s) => s.outletId)).toEqual([outletA, outletB]);
    });

    it('sweeps every raw ping of a deactivated agent, recent ones included', async () => {
      const gone = await userIn(clientId, 'field_agent');
      const staying = await userIn(clientId, 'field_agent');
      await addPing(gone, dayAt(1, 8), storeA);
      await addPing(gone, dayAt(0, 9), storeB);
      await addPing(staying, dayAt(1, 8), storeA);
      await prisma.user.update({ where: { id: gone.userId }, data: { active: false } });

      const result = await pruneLocationPings({ now });
      expect(result).toMatchObject({ deactivatedAgentsPurged: 1, agentDaysSummarised: 2, pingsDeleted: 2 });
      expect(await rawCount(gone)).toBe(0);
      expect(await rawCount(staying)).toBe(1);
      expect((await summary(gone, dayAt(1, 0)))!.pingCount).toBe(1);
      expect((await summary(gone, dayAt(0, 0)))!.pingCount).toBe(1);
    });

    it('a dry run counts and deletes nothing', async () => {
      const gone = await userIn(clientId, 'field_agent');
      const agent = await userIn(clientId, 'field_agent');
      await addPing(agent, dayAt(100, 8), storeA);
      await addPing(agent, dayAt(10, 8), storeA);
      await addPing(gone, dayAt(1, 8), storeA);
      await prisma.user.update({ where: { id: gone.userId }, data: { active: false } });

      const result = await pruneLocationPings({ now, dryRun: true });
      expect(result).toMatchObject({ dryRun: true, expiredPings: 1, deactivatedAgentPings: 1, pingsDeleted: 0 });
      expect(await rawCount(agent)).toBe(2);
      expect(await rawCount(gone)).toBe(1);
      expect(await prisma.agentDaySummary.count({ where: { clientId } })).toBe(0);
    });

    it('--client leaves every other tenant alone', async () => {
      const ours = await userIn(clientId, 'field_agent');
      const theirs = await userIn(otherClientId, 'field_agent');
      await addPing(ours, dayAt(100, 8), storeA);
      await addPing(theirs, dayAt(100, 8), storeA);

      await pruneLocationPings({ now, clientId });
      expect(await rawCount(ours)).toBe(0);
      expect(await rawCount(theirs)).toBe(1);
    });
  });

  describe('deactivation', () => {
    it('purgeAgentLocationPings folds and deletes all of one agent, nobody else', async () => {
      const agent = await userIn(clientId, 'field_agent');
      const other = await userIn(clientId, 'field_agent');
      await addPing(agent, dayAt(3, 8), storeA);
      await addPing(agent, dayAt(0, 8), storeA);
      await addPing(other, dayAt(0, 8), storeA);

      expect(await purgeAgentLocationPings({ clientId, agentId: agent.userId })).toEqual({ agentDays: 2, pingsDeleted: 2 });
      expect(await rawCount(agent)).toBe(0);
      expect(await rawCount(other)).toBe(1);
    });

    it('PATCH /users/:id active=false deletes the agent’s raw pings and keeps the summaries', async () => {
      const agent = await userIn(clientId, 'field_agent');
      await addPing(agent, dayAt(2, 8), storeA);
      await addPing(agent, dayAt(2, 8.1), storeA);

      const res = await request(app)
        .patch(`/users/${agent.userId}`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ active: false });
      expect(res.status).toBe(200);
      expect(res.body.active).toBe(false);

      expect(await rawCount(agent)).toBe(0);
      expect(await summary(agent, dayAt(2, 0))).toMatchObject({ pingCount: 2 });
    });

    it('other PATCH /users/:id updates leave pings alone', async () => {
      const agent = await userIn(clientId, 'field_agent');
      await addPing(agent, dayAt(2, 8), storeA);
      const res = await request(app)
        .patch(`/users/${agent.userId}`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ displayName: 'Thabo' });
      expect(res.status).toBe(200);
      expect(await rawCount(agent)).toBe(1);
    });
  });
});
