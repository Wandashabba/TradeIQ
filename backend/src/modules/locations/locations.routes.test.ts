import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import {
  BACKGROUND_LOCATION_NOTICE_VERSION,
  LOCATION_NOTICE_VERSION,
  MAX_PINGS_PER_BATCH,
} from './locationPolicy';

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
      // The foreground half of the payload, which is what this suite is about.
      // `background` (#153 T2) rides alongside it and has its own suite; it is
      // only checked here for its presence and its independence.
      expect(res.body).toMatchObject({
        intervalSeconds: 120,
        noticeVersion: LOCATION_NOTICE_VERSION,
        consent: null,
        sharingEnabled: false,
      });
      expect(res.body.background).toMatchObject({ enabled: false, consent: null });
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
      // `kind` names which notice was answered (#153 T2). Absent from the
      // request, so it is the foreground one — the answer this build records is
      // the answer the app showed.
      expect(first.body).toEqual({
        decision: 'acknowledged',
        kind: 'foreground',
        noticeVersion: LOCATION_NOTICE_VERSION,
        decidedAt,
      });
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

/**
 * #153 T2 — background tracking between stores.
 *
 * Two things gate it and neither may be skipped: a SEPARATE acceptance, and the
 * client's working hours read on the client's own clock. Most of what follows is
 * about what is NOT collected.
 */
describe('background location (#153 T2)', () => {
  const MIN = 60 * 1000;

  /**
   * The most recent instant already in the past at `hour`:00 UTC on ISO weekday
   * `weekday` (1 = Monday … 7 = Sunday).
   *
   * Built backwards from the real clock rather than hard-coded, so the suite is
   * deterministic whenever it runs and every instant it produces is inside the
   * 90-day retention window and behind the clock-skew bound.
   */
  const recentWeekdayAt = (weekday: number, hour: number): Date => {
    const d = new Date();
    d.setUTCHours(hour, 0, 0, 0);
    for (let i = 0; i < 9; i += 1) {
      const iso = ((d.getUTCDay() + 6) % 7) + 1;
      if (iso === weekday && d.getTime() < Date.now() - MIN) return d;
      d.setUTCDate(d.getUTCDate() - 1);
    }
    throw new Error(`no recent weekday ${weekday}`);
  };

  /** The most recent past instant at `hour`:00 UTC, whatever day that lands on. */
  const recentAt = (hour: number, forwardMin = 0): Date => {
    const d = new Date();
    d.setUTCHours(hour, 0, 0, 0);
    // forwardMin is how far a caller will push PAST this anchor. Without it a
    // test that posts anchor+90min is future-dated whenever the suite runs
    // inside that window, and the ingest clamps future pings before the
    // working-hours check ever runs - so outsideWorkingHours came back 0.
    if (d.getTime() + forwardMin * MIN >= Date.now() - MIN) d.setUTCDate(d.getUTCDate() - 1);
    return d;
  };

  const isoWeekday = (d: Date) => ((d.getUTCDay() + 6) % 7) + 1;

  const newClient = (
    name: string,
    timezone: string,
    hours: { start?: string; end?: string; days?: number[] } = {},
  ) =>
    prisma.client.create({
      data: {
        name: `${name}-${Date.now()}-${Math.random()}`,
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
        timezone,
        workHoursStart: hours.start ?? '07:00',
        workHoursEnd: hours.end ?? '17:00',
        ...(hours.days ? { workDays: hours.days } : {}),
      },
    });

  const settings = (user: TestUser) =>
    request(app).get('/locations/settings').set('Authorization', `Bearer ${user.token}`);

  const consent = (user: TestUser, body: object) =>
    request(app).post('/locations/consent').set('Authorization', `Bearer ${user.token}`).send(body);

  const post = (user: TestUser, body: unknown) =>
    request(app).post('/locations').set('Authorization', `Bearer ${user.token}`).send(body as object);

  const ping = (at: Date, accuracyM: number | null = 12) => ({
    lat: -26.1,
    lng: 28.05,
    accuracyM,
    recordedAt: at.toISOString(),
  });

  /** An agent who accepted the notice(s) named, long enough ago to cover any ping. */
  const agentWith = async (
    clientId: string,
    kinds: Array<'foreground' | 'background'>,
  ): Promise<TestUser> => {
    const user = await userIn(clientId, 'field_agent');
    // 89 days: inside the 90-day retention window, so the acceptance predates
    // every ping any test here sends without itself being out of range.
    const decidedAt = new Date(Date.now() - 89 * 24 * 60 * MIN).toISOString();
    for (const kind of kinds) {
      const res = await consent(user, {
        decision: 'acknowledged',
        kind,
        noticeVersion:
          kind === 'background' ? BACKGROUND_LOCATION_NOTICE_VERSION : LOCATION_NOTICE_VERSION,
        decidedAt,
      });
      expect(res.status).toBe(201);
    }
    return user;
  };

  const clients: string[] = [];
  const makeClient = async (...args: Parameters<typeof newClient>) => {
    const client = await newClient(...args);
    clients.push(client.id);
    return client.id;
  };

  afterAll(async () => {
    for (const clientId of clients) {
      await prisma.agentLocationPing.deleteMany({ where: { clientId } });
      await prisma.locationConsent.deleteMany({ where: { clientId } });
      await prisma.user.deleteMany({ where: { clientId } });
      await prisma.client.delete({ where: { id: clientId } });
    }
  });

  describe('GET /locations/settings reports the two notices independently', () => {
    it('offers background with the client’s window, and no answer yet', async () => {
      const clientId = await makeClient('BG-Settings', 'Africa/Johannesburg', {
        start: '08:00',
        end: '16:30',
        days: [1, 2, 3],
      });
      const user = await userIn(clientId, 'field_agent');

      const res = await settings(user);
      expect(res.status).toBe(200);
      expect(res.body.sharingEnabled).toBe(false);
      expect(res.body.consent).toBeNull();
      expect(res.body.background).toMatchObject({
        intervalSeconds: 600,
        noticeVersion: BACKGROUND_LOCATION_NOTICE_VERSION,
        consent: null,
        enabled: false,
        workingHours: {
          start: '08:00',
          end: '16:30',
          days: [1, 2, 3],
          timezone: 'Africa/Johannesburg',
        },
      });
      // Exactly one edge is ever set: a shut window knows when it opens, an
      // open one knows when it closes.
      const { withinWorkingHours, windowOpensAt, windowClosesAt } = res.body.background;
      expect(typeof withinWorkingHours).toBe('boolean');
      expect(withinWorkingHours ? windowClosesAt : windowOpensAt).toEqual(expect.any(String));
      expect(withinWorkingHours ? windowOpensAt : windowClosesAt).toBeNull();
    });

    it('accepting the foreground notice does NOT enable background', async () => {
      const clientId = await makeClient('BG-Foreground-Only', 'UTC');
      const user = await agentWith(clientId, ['foreground']);

      const res = await settings(user);
      expect(res.body.sharingEnabled).toBe(true);
      expect(res.body.background.enabled).toBe(false);
      expect(res.body.background.consent).toBeNull();
    });

    it('accepting the background notice does NOT enable foreground', async () => {
      const clientId = await makeClient('BG-Background-Only', 'UTC');
      const user = await agentWith(clientId, ['background']);

      const res = await settings(user);
      expect(res.body.sharingEnabled).toBe(false);
      expect(res.body.consent).toBeNull();
      expect(res.body.background.enabled).toBe(true);
      expect(res.body.background.consent.decision).toBe('acknowledged');
    });
  });

  describe('POST /locations/consent is per notice', () => {
    it('rejects an unknown kind', async () => {
      const clientId = await makeClient('BG-Kind', 'UTC');
      const user = await userIn(clientId, 'field_agent');
      const res = await consent(user, {
        decision: 'acknowledged',
        kind: 'sideways',
        noticeVersion: BACKGROUND_LOCATION_NOTICE_VERSION,
      });
      expect(res.status).toBe(400);
      expect(await prisma.locationConsent.count({ where: { agentId: user.userId } })).toBe(0);
    });

    it('refuses the foreground version sent against the background notice', async () => {
      const clientId = await makeClient('BG-Version', 'UTC');
      const user = await userIn(clientId, 'field_agent');
      const res = await consent(user, {
        decision: 'acknowledged',
        kind: 'background',
        noticeVersion: LOCATION_NOTICE_VERSION,
      });
      expect(res.status).toBe(409);
      expect(await prisma.locationConsent.count({ where: { agentId: user.userId } })).toBe(0);
    });

    it('records the kind on the row and reports it back', async () => {
      const clientId = await makeClient('BG-Record', 'UTC');
      const user = await userIn(clientId, 'field_agent');
      const res = await consent(user, {
        decision: 'acknowledged',
        kind: 'background',
        noticeVersion: BACKGROUND_LOCATION_NOTICE_VERSION,
      });
      expect(res.status).toBe(201);
      expect(res.body.kind).toBe('background');
      const rows = await prisma.locationConsent.findMany({ where: { agentId: user.userId } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({
        kind: 'background',
        noticeVersion: BACKGROUND_LOCATION_NOTICE_VERSION,
      });
    });

    it('defaults to foreground, so a build that predates T2 is unchanged', async () => {
      const clientId = await makeClient('BG-Default', 'UTC');
      const user = await userIn(clientId, 'field_agent');
      expect(
        (await consent(user, { decision: 'acknowledged', noticeVersion: LOCATION_NOTICE_VERSION }))
          .status,
      ).toBe(201);
      const rows = await prisma.locationConsent.findMany({ where: { agentId: user.userId } });
      expect(rows[0].kind).toBe('foreground');
    });
  });

  describe('nothing is collected without the background notice', () => {
    it('refuses a background batch from an agent who has only accepted foreground', async () => {
      const clientId = await makeClient('BG-NoConsent', 'UTC', { days: [1, 2, 3, 4, 5, 6, 7] });
      const user = await agentWith(clientId, ['foreground']);

      const res = await post(user, { source: 'background', pings: [ping(recentAt(10))] });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('background_location_consent_required');
      expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(0);
    });

    it('refuses a background batch from an agent who declined it', async () => {
      const clientId = await makeClient('BG-Declined', 'UTC', { days: [1, 2, 3, 4, 5, 6, 7] });
      const user = await agentWith(clientId, ['foreground', 'background']);
      expect((await post(user, { source: 'background', pings: [ping(recentAt(10))] })).status).toBe(200);

      await consent(user, {
        decision: 'declined',
        kind: 'background',
        noticeVersion: BACKGROUND_LOCATION_NOTICE_VERSION,
      });
      const res = await post(user, { source: 'background', pings: [ping(recentAt(9))] });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('background_location_consent_required');
      // The one already stored stays: a decline stops FUTURE pings, and what was
      // shared under an agreement follows the normal 90-day rule.
      expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(1);
    });

    it('rejects a batch whose source is not a source at all', async () => {
      const clientId = await makeClient('BG-BadSource', 'UTC');
      const user = await agentWith(clientId, ['foreground']);
      const res = await post(user, { source: 'guessing', pings: [ping(recentAt(10))] });
      expect(res.status).toBe(400);
    });
  });

  describe('revoking one notice leaves the other working', () => {
    it('declining background leaves the foreground heartbeat accepted', async () => {
      const clientId = await makeClient('BG-KeepFg', 'UTC', { days: [1, 2, 3, 4, 5, 6, 7] });
      const user = await agentWith(clientId, ['foreground', 'background']);

      await consent(user, {
        decision: 'declined',
        kind: 'background',
        noticeVersion: BACKGROUND_LOCATION_NOTICE_VERSION,
      });

      const after = await settings(user);
      expect(after.body.sharingEnabled).toBe(true);
      expect(after.body.background.enabled).toBe(false);

      // And the heartbeat still ingests.
      const res = await post(user, { pings: [ping(recentAt(10))] });
      expect(res.status).toBe(200);
      expect(res.body.accepted).toBe(1);
    });

    it('declining foreground leaves background accepted and ingesting', async () => {
      const clientId = await makeClient('BG-KeepBg', 'UTC', { days: [1, 2, 3, 4, 5, 6, 7] });
      const user = await agentWith(clientId, ['foreground', 'background']);

      await consent(user, { decision: 'declined', noticeVersion: LOCATION_NOTICE_VERSION });

      const after = await settings(user);
      expect(after.body.sharingEnabled).toBe(false);
      expect(after.body.background.enabled).toBe(true);

      expect((await post(user, { pings: [ping(recentAt(10))] })).status).toBe(403);
      const background = await post(user, { source: 'background', pings: [ping(recentAt(9))] });
      expect(background.status).toBe(200);
      expect(background.body.accepted).toBe(1);
    });
  });

  describe('working hours', () => {
    it('stores a ping inside the window with source background', async () => {
      const inside = recentAt(10, 90);
      const clientId = await makeClient('BG-Inside', 'UTC', {
        start: '09:00',
        end: '11:00',
        days: [isoWeekday(inside)],
      });
      const user = await agentWith(clientId, ['background']);

      const res = await post(user, { source: 'background', pings: [ping(inside)] });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        accepted: 1,
        duplicates: 0,
        ignored: 0,
        outsideWorkingHours: 0,
      });

      const rows = await prisma.agentLocationPing.findMany({ where: { agentId: user.userId } });
      expect(rows).toHaveLength(1);
      expect(rows[0].source).toBe('background');
    });

    it('ignores a ping before the window opens, and counts it', async () => {
      const inside = recentAt(10, 90);
      const early = new Date(inside.getTime() - 4 * 60 * MIN); // 06:00 the same day
      const clientId = await makeClient('BG-Early', 'UTC', {
        start: '09:00',
        end: '11:00',
        days: [isoWeekday(inside)],
      });
      const user = await agentWith(clientId, ['background']);

      const res = await post(user, { source: 'background', pings: [ping(early)] });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        accepted: 0,
        duplicates: 0,
        ignored: 1,
        outsideWorkingHours: 1,
      });
      expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(0);
    });

    it('keeps the inside pings of a batch that straddles the edge', async () => {
      // The case the ignore-don't-refuse decision exists for: a queue flushed
      // after the window shut, holding good pings and one late one.
      const inside = recentAt(10, 90);
      const clientId = await makeClient('BG-Straddle', 'UTC', {
        start: '09:00',
        end: '11:00',
        days: [isoWeekday(inside)],
      });
      const user = await agentWith(clientId, ['background']);

      const res = await post(user, {
        source: 'background',
        pings: [
          ping(new Date(inside.getTime() - 30 * MIN)), // 09:30 — in
          ping(inside), //                                10:00 — in
          ping(new Date(inside.getTime() + 60 * MIN)), // 11:00 — out, end is exclusive
          ping(new Date(inside.getTime() + 90 * MIN)), // 11:30 — out
        ],
      });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        accepted: 2,
        duplicates: 0,
        ignored: 2,
        outsideWorkingHours: 2,
      });
    });

    it('a weekend day collects nothing', async () => {
      const saturday = recentWeekdayAt(6, 10);
      const sunday = recentWeekdayAt(7, 10);
      const clientId = await makeClient('BG-Weekend', 'UTC', {
        start: '07:00',
        end: '17:00',
        days: [1, 2, 3, 4, 5],
      });
      const user = await agentWith(clientId, ['background']);

      const res = await post(user, {
        source: 'background',
        pings: [ping(saturday), ping(sunday)],
      });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        accepted: 0,
        duplicates: 0,
        ignored: 2,
        outsideWorkingHours: 2,
      });
      expect(await prisma.agentLocationPing.count({ where: { agentId: user.userId } })).toBe(0);
    });

    it('the window never applies to the foreground heartbeat', async () => {
      // The heartbeat runs whenever the agent has the app open, which is their
      // own choice to make; only unattended collection is bounded by hours.
      const night = recentAt(2);
      const clientId = await makeClient('BG-FgUnbounded', 'UTC', {
        start: '09:00',
        end: '11:00',
        days: [isoWeekday(night)],
      });
      const user = await agentWith(clientId, ['foreground']);

      const res = await post(user, { pings: [ping(night)] });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ accepted: 1, duplicates: 0, ignored: 0 });
      // No counter on a foreground batch: the number would mean nothing.
      expect(res.body.outsideWorkingHours).toBeUndefined();
    });

    describe('the window is read in Client.timezone', () => {
      // One pair of instants, two clients with the SAME 09:00-11:00 window. Each
      // client's verdict comes out opposite, which is only possible if the
      // window is being read on each client's own wall clock.
      const tenUtc = recentAt(10); // 12:00 in Johannesburg
      const eightUtc = new Date(tenUtc.getTime() - 2 * 60 * MIN); // 10:00 in Johannesburg

      let utcAgent: TestUser;
      let sastAgent: TestUser;

      beforeAll(async () => {
        const days = [isoWeekday(tenUtc)];
        const utcClient = await makeClient('BG-Zone-UTC', 'UTC', {
          start: '09:00',
          end: '11:00',
          days,
        });
        const sastClient = await makeClient('BG-Zone-SAST', 'Africa/Johannesburg', {
          start: '09:00',
          end: '11:00',
          days,
        });
        utcAgent = await agentWith(utcClient, ['background']);
        sastAgent = await agentWith(sastClient, ['background']);
      });

      it('10:00Z is inside the window for a UTC client', async () => {
        const res = await post(utcAgent, { source: 'background', pings: [ping(tenUtc)] });
        expect(res.body).toMatchObject({ accepted: 1, outsideWorkingHours: 0 });
      });

      it('the same instant is 12:00 in Johannesburg, so it is outside', async () => {
        const res = await post(sastAgent, { source: 'background', pings: [ping(tenUtc)] });
        expect(res.body).toMatchObject({ accepted: 0, outsideWorkingHours: 1 });
      });

      it('08:00Z is 10:00 in Johannesburg, so it is inside', async () => {
        const res = await post(sastAgent, { source: 'background', pings: [ping(eightUtc)] });
        expect(res.body).toMatchObject({ accepted: 1, outsideWorkingHours: 0 });
      });

      it('and that same instant is outside the UTC client’s window', async () => {
        const res = await post(utcAgent, { source: 'background', pings: [ping(eightUtc)] });
        expect(res.body).toMatchObject({ accepted: 0, outsideWorkingHours: 1 });
      });
    });
  });
});
