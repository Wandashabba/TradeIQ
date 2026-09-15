import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { LOCATION_NOTICE_VERSION, MAX_PINGS_PER_BATCH } from './locationPolicy';

/**
 * #153 T1 — foreground location pings, agent side: consent gates ingest, a
 * batch is validated and bounded, and late or shuffled pings never move an
 * agent backwards.
 */
describe('locations routes (#153 T1)', () => {
  const MIN = 60 * 1000;
  const ago = (ms: number) => new Date(Date.now() - ms);

  let clientId: string;
  let agent: TestUser;
  let manager: TestUser;

  const settings = (user: TestUser) =>
    request(app).get('/locations/settings').set('Authorization', `Bearer ${user.token}`);

  const consent = (user: TestUser, body: object) =>
    request(app).post('/locations/consent').set('Authorization', `Bearer ${user.token}`).send(body);

  const post = (user: TestUser, body: unknown) =>
    request(app).post('/locations').set('Authorization', `Bearer ${user.token}`).send(body as object);

  const ping = (at: Date, lat = -26.1, lng = 28.05, accuracyM: number | null = 12) => ({
    lat,
    lng,
    accuracyM,
    recordedAt: at.toISOString(),
  });

  /** A fresh agent who has acknowledged the notice, as of `decidedAt`. */
  const consentingAgent = async (decidedAt = ago(3 * 24 * 60 * MIN)) => {
    const user = await userIn(clientId, 'field_agent');
    const res = await consent(user, {
      decision: 'acknowledged',
      noticeVersion: LOCATION_NOTICE_VERSION,
      decidedAt: decidedAt.toISOString(),
    });
    expect(res.status).toBe(201);
    return user;
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'LOC-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
  });

  describe('GET /locations/settings', () => {
    it('reports the default interval and no consent for a new agent', async () => {
      const res = await settings(agent);
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        intervalSeconds: 120,
        noticeVersion: LOCATION_NOTICE_VERSION,
        consent: null,
        sharingEnabled: false,
      });
    });

    it('reads the interval from kpiThresholds and clamps it', async () => {
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { locationPingIntervalSeconds: 5 } },
      });
      expect((await settings(agent)).body.intervalSeconds).toBe(60);

      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { locationPingIntervalSeconds: 99999 } },
      });
      expect((await settings(agent)).body.intervalSeconds).toBe(900);

      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { locationPingIntervalSeconds: 300 } },
      });
      expect((await settings(agent)).body.intervalSeconds).toBe(300);

      await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
    });

    it('is for field agents only', async () => {
      expect((await settings(manager)).status).toBe(403);
    });
  });

  describe('POST /locations/consent', () => {
    it('rejects an unknown decision and a missing notice version', async () => {
      expect((await consent(agent, { decision: 'maybe', noticeVersion: LOCATION_NOTICE_VERSION })).status).toBe(400);
      expect((await consent(agent, { decision: 'acknowledged' })).status).toBe(400);
      expect(
        (await consent(agent, { decision: 'acknowledged', noticeVersion: LOCATION_NOTICE_VERSION, decidedAt: 'soon' }))
          .status,
      ).toBe(400);
    });

    it('refuses an answer to an older notice rather than recording it against the current one', async () => {
      const res = await consent(agent, { decision: 'acknowledged', noticeVersion: '2020-01-01' });
      expect(res.status).toBe(409);
      expect(await prisma.locationConsent.count({ where: { agentId: agent.userId } })).toBe(0);
    });

    it('records an acknowledgement with its timestamp, and a retried one only once', async () => {
      const user = await userIn(clientId, 'field_agent');
      const decidedAt = ago(5 * MIN).toISOString();
      const body = { decision: 'acknowledged', noticeVersion: LOCATION_NOTICE_VERSION, decidedAt };

      const first = await consent(user, body);
      expect(first.status).toBe(201);
      expect(first.body).toEqual({ decision: 'acknowledged', noticeVersion: LOCATION_NOTICE_VERSION, decidedAt });
      expect((await consent(user, body)).status).toBe(201);

      const rows = await prisma.locationConsent.findMany({ where: { agentId: user.userId } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ clientId, decision: 'acknowledged', noticeVersion: LOCATION_NOTICE_VERSION });
      expect(rows[0].decidedAt.toISOString()).toBe(decidedAt);

      const s = await settings(user);
      expect(s.body.sharingEnabled).toBe(true);
      expect(s.body.consent.decidedAt).toBe(decidedAt);
    });

    it('never dates an answer in the future', async () => {
      const user = await userIn(clientId, 'field_agent');
      const res = await consent(user, {
        decision: 'declined',
        noticeVersion: LOCATION_NOTICE_VERSION,
        decidedAt: new Date(Date.now() + 60 * MIN).toISOString(),
      });
      expect(res.status).toBe(201);
      expect(new Date(res.body.decidedAt).getTime()).toBeLessThanOrEqual(Date.now());
    });
  });

  describe('POST /locations', () => {
    it('refuses pings from an agent who has not acknowledged the notice', async () => {
      const res = await post(agent, { pings: [ping(ago(MIN))] });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('location_consent_required');
      expect(await prisma.agentLocationPing.count({ where: { agentId: agent.userId } })).toBe(0);
    });

    it('refuses pings once the agent declines, even after acknowledging', async () => {
      const user = await consentingAgent();
      expect((await post(user, { pings: [ping(ago(2 * MIN))] })).status).toBe(200);
      await consent(user, { decision: 'declined', noticeVersion: LOCATION_NOTICE_VERSION });
      const res = await post(user, { pings: [ping(ago(MIN))] });
      expect(res.status).toBe(403);
      expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(1);
    });

    it('is for field agents only', async () => {
      expect((await post(manager, { pings: [ping(ago(MIN))] })).status).toBe(403);
    });

    describe('validation', () => {
      let user: TestUser;
      beforeAll(async () => {
        user = await consentingAgent();
      });

      it.each([
        ['no body', {}],
        ['an empty batch', { pings: [] }],
        ['a non-array', { pings: 'lots' }],
        ['a non-object ping', { pings: [42] }],
        ['latitude out of range', { pings: [{ ...ping(ago(MIN)), lat: 91 }] }],
        ['longitude out of range', { pings: [{ ...ping(ago(MIN)), lng: -181 }] }],
        ['a string latitude', { pings: [{ ...ping(ago(MIN)), lat: '-26.1' }] }],
        ['the 0,0 null fix', { pings: [{ ...ping(ago(MIN)), lat: 0, lng: 0 }] }],
        ['negative accuracy', { pings: [{ ...ping(ago(MIN)), accuracyM: -1 }] }],
        ['an instant with no offset', { pings: [{ ...ping(ago(MIN)), recordedAt: '2026-09-15T10:00:00' }] }],
        ['a missing recordedAt', { pings: [{ lat: -26.1, lng: 28.05 }] }],
      ])('rejects %s with a 400 and stores nothing', async (_label, body) => {
        const res = await post(user, body);
        expect(res.status).toBe(400);
        expect(typeof res.body.error).toBe('string');
        expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(0);
      });

      it(`bounds a batch at ${MAX_PINGS_PER_BATCH} pings`, async () => {
        const tooMany = Array.from({ length: MAX_PINGS_PER_BATCH + 1 }, (_, i) => ping(ago((i + 1) * 1000)));
        expect((await post(user, { pings: tooMany })).status).toBe(400);

        const justRight = tooMany.slice(0, MAX_PINGS_PER_BATCH);
        const res = await post(user, { pings: justRight });
        expect(res.status).toBe(200);
        expect(res.body).toEqual({ accepted: MAX_PINGS_PER_BATCH, duplicates: 0, ignored: 0 });
      });
    });

    it('stores a batch under the token identity, whatever the body claims', async () => {
      const user = await consentingAgent();
      const foreign = await foreignTenant('field_agent');
      try {
        const res = await post(user, {
          pings: [{ ...ping(ago(2 * MIN)), agentId: foreign.userId, clientId: foreign.clientId }, ping(ago(MIN), -26.2, 28.1, null)],
        });
        expect(res.status).toBe(200);
        expect(res.body).toEqual({ accepted: 2, duplicates: 0, ignored: 0 });

        const rows = await prisma.agentLocationPing.findMany({
          where: { agentId: user.userId },
          orderBy: { recordedAt: 'asc' },
        });
        expect(rows).toHaveLength(2);
        expect(rows.every((r) => r.clientId === clientId && r.source === 'foreground')).toBe(true);
        expect(rows[1].accuracyM).toBeNull();
        expect(await prisma.agentLocationPing.count({ where: { agentId: foreign.userId } })).toBe(0);
      } finally {
        await foreign.cleanup();
      }
    });

    it('treats a re-sent batch as duplicates, not new rows', async () => {
      const user = await consentingAgent();
      const batch = { pings: [ping(ago(3 * MIN)), ping(ago(2 * MIN))] };
      expect((await post(user, batch)).body).toEqual({ accepted: 2, duplicates: 0, ignored: 0 });
      expect((await post(user, batch)).body).toEqual({ accepted: 0, duplicates: 2, ignored: 0 });
      expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(2);
    });

    it('ignores pings past retention, from a fast clock, or from before the acknowledgement', async () => {
      const user = await consentingAgent(ago(60 * MIN));
      const res = await post(user, {
        pings: [
          ping(ago(91 * 24 * 60 * MIN)),
          ping(new Date(Date.now() + 30 * MIN)),
          ping(ago(2 * 60 * MIN)),
          ping(ago(MIN)),
        ],
      });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ accepted: 1, duplicates: 0, ignored: 3 });
    });

    describe('ordering by recordedAt, never arrival (risk 2)', () => {
      it('a late batch of older pings does not overwrite the newer position', async () => {
        const user = await consentingAgent();
        const newest = ago(MIN);
        expect((await post(user, { pings: [ping(newest, -26.1, 28.05)] })).status).toBe(200);

        // An hour of pings from somewhere else, queued offline, lands afterwards.
        const late = await post(user, {
          pings: [ping(ago(60 * MIN), -33.9, 18.4), ping(ago(40 * MIN), -33.91, 18.41)],
        });
        expect(late.body.accepted).toBe(2);

        const row = await prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
        expect(row.lastLat).toBe(-26.1);
        expect(row.lastLng).toBe(28.05);
        expect(row.lastSeenAt?.toISOString()).toBe(newest.toISOString());
      });

      it('takes the newest ping of a shuffled batch, and lastSeen only moves forward', async () => {
        const user = await consentingAgent();
        const t1 = ago(30 * MIN);
        const t2 = ago(20 * MIN);
        const t3 = ago(10 * MIN);
        await post(user, { pings: [ping(t2, -26.2, 28.2), ping(t3, -26.3, 28.3), ping(t1, -26.1, 28.1)] });
        let row = await prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
        expect([row.lastLat, row.lastLng, row.lastSeenAt?.toISOString()]).toEqual([-26.3, 28.3, t3.toISOString()]);

        const t4 = ago(MIN);
        await post(user, { pings: [ping(t4, -26.4, 28.4)] });
        row = await prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
        expect([row.lastLat, row.lastLng, row.lastSeenAt?.toISOString()]).toEqual([-26.4, 28.4, t4.toISOString()]);
      });

      it('two batches racing each other still leave the newest position', async () => {
        const user = await consentingAgent();
        const newer = ago(MIN);
        await Promise.all([
          post(user, { pings: [ping(ago(50 * MIN), -33.9, 18.4)] }),
          post(user, { pings: [ping(newer, -26.1, 28.05)] }),
          post(user, { pings: [ping(ago(30 * MIN), -29.8, 31.0)] }),
        ]);
        const row = await prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
        expect(row.lastSeenAt?.toISOString()).toBe(newer.toISOString());
        expect(row.lastLat).toBe(-26.1);
      });

      it('does not move lastSeen back past a newer check-in', async () => {
        const user = await consentingAgent();
        const checkIn = ago(MIN);
        await prisma.user.update({
          where: { id: user.userId },
          data: { lastLat: -25.7, lastLng: 28.2, lastSeenAt: checkIn },
        });
        await post(user, { pings: [ping(ago(15 * MIN))] });
        const row = await prisma.user.findUniqueOrThrow({ where: { id: user.userId } });
        expect(row.lastSeenAt?.toISOString()).toBe(checkIn.toISOString());
        expect(row.lastLat).toBe(-25.7);
      });
    });
  });
});
