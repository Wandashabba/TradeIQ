import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { LOCATION_NOTICE_VERSION } from '../locations/locationPolicy';
import { deriveLiveState } from './agentLocations.service';

/**
 * #153 T1 — GET /agents/locations: each agent's latest ping, its age, and one
 * of six states. A decline beats everything, age decides before place, GPS
 * accuracy decides at vs near a store, ordering is by recordedAt, and the page
 * is bounded.
 */
describe('deriveLiveState', () => {
  // Default interval 120s → stale after max(300, 3×120) = 360s; offline after 1800s.
  const at = (
    ageSeconds: number | null,
    insideOutlet = false,
    accuracyM: number | null = 8,
    declined = false,
  ) => deriveLiveState({ ageSeconds, insideOutlet, accuracyM, intervalSeconds: 120, declined });

  it('never shared is offline', () => expect(at(null)).toBe('offline'));
  it('fresh inside a fence is at_store', () => expect(at(0, true)).toBe('at_store'));
  it('fresh outside every fence is in_transit', () => expect(at(360)).toBe('in_transit'));
  it('past three missed pings is stale, even inside a fence', () => expect(at(361, true)).toBe('stale'));
  it('stale holds up to the offline threshold', () => expect(at(1800)).toBe('stale'));
  it('past thirty minutes is offline', () => expect(at(1801, true)).toBe('offline'));

  it('never calls a ping stale sooner than five minutes, however short the interval', () => {
    const base = { insideOutlet: false, accuracyM: 8, declined: false };
    expect(deriveLiveState({ ...base, ageSeconds: 299, intervalSeconds: 60 })).toBe('in_transit');
    expect(deriveLiveState({ ...base, ageSeconds: 301, intervalSeconds: 60 })).toBe('stale');
  });

  it('stretches stale with a longer tenant interval', () => {
    expect(
      deriveLiveState({ ageSeconds: 800, insideOutlet: true, accuracyM: 8, intervalSeconds: 300, declined: false }),
    ).toBe('at_store');
  });

  describe('GPS accuracy gates at_store', () => {
    it('accuracy of exactly 100m is at_store', () => expect(at(30, true, 100)).toBe('at_store'));
    it('accuracy of 101m is near_store', () => expect(at(30, true, 101)).toBe('near_store'));
    it('no accuracy estimate is near_store', () => expect(at(30, true, null)).toBe('near_store'));
    it('accuracy never matters outside every fence', () => expect(at(30, false, null)).toBe('in_transit'));
    it('age still beats place: a stale low-accuracy ping in a fence is stale', () => {
      expect(at(361, true, null)).toBe('stale');
      expect(at(1801, true, 500)).toBe('offline');
    });
  });

  describe('a decline beats every other state', () => {
    it.each<[string, number | null, boolean, number | null]>([
      ['a fresh at-store ping', 10, true, 8],
      ['a fresh near-store ping', 10, true, null],
      ['a fresh in-transit ping', 10, false, 8],
      ['a stale ping', 600, true, 8],
      ['an old ping', 7200, false, 8],
      ['no ping at all', null, false, null],
    ])('%s reads not_sharing', (_, ageSeconds, inside, accuracyM) => {
      expect(at(ageSeconds, inside, accuracyM, true)).toBe('not_sharing');
    });
  });
});

describe('GET /agents/locations — consent and accuracy (#153)', () => {
  const SEC = 1000;
  const MIN = 60 * SEC;
  const store = { lat: -26.2, lng: 28.1 };
  // ~10m north of the store: inside its 50m fence.
  const inStore = { lat: store.lat + 0.00009, lng: store.lng };
  // ~1.1km north: outside the fence.
  const road = { lat: -26.19, lng: 28.1 };

  let clientId: string;
  let outletId: string;
  let manager: TestUser;
  const agents = {} as Record<
    | 'declinedFresh'
    | 'declinedOld'
    | 'reacknowledged'
    | 'oldNoticeDeclined'
    | 'neverAnswered'
    | 'accuracy100'
    | 'accuracy101'
    | 'accuracyNull'
    | 'staleLowAccuracy',
    TestUser
  >;

  const ping = (agent: TestUser, ageMs: number, where: { lat: number; lng: number }, accuracyM: number | null) =>
    prisma.agentLocationPing.create({
      data: {
        clientId: agent.clientId,
        agentId: agent.userId,
        ...where,
        accuracyM,
        recordedAt: new Date(Date.now() - ageMs),
        source: 'foreground',
      },
    });

  /** Answers in order, oldest first, spaced so `createdAt` ordering is unambiguous. */
  const answer = async (
    agent: TestUser,
    decisions: Array<'acknowledged' | 'declined'>,
    noticeVersion = LOCATION_NOTICE_VERSION,
  ) => {
    for (const [i, decision] of decisions.entries()) {
      const at = new Date(Date.now() - (decisions.length - i) * MIN);
      await prisma.locationConsent.create({
        data: { clientId, agentId: agent.userId, noticeVersion, decision, decidedAt: at, createdAt: at },
      });
    }
  };

  const rows = async () => {
    const res = await request(app)
      .get('/agents/locations?limit=200')
      .set('Authorization', `Bearer ${manager.token}`);
    expect(res.status).toBe(200);
    return {
      body: res.body,
      byId: new Map<string, Record<string, unknown>>(
        res.body.data.map((row: Record<string, unknown>) => [row.agentId, row]),
      ),
    };
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'ALOC-Consent', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    outletId = (
      await prisma.outlet.create({
        data: { clientId, name: 'Rosebank PnP', code: 'ALOC-C1', channelType: 'grocery', territoryId: 'GP', ...store },
      })
    ).id;
    manager = await userIn(clientId, 'manager');
    for (const key of [
      'declinedFresh',
      'declinedOld',
      'reacknowledged',
      'oldNoticeDeclined',
      'neverAnswered',
      'accuracy100',
      'accuracy101',
      'accuracyNull',
      'staleLowAccuracy',
    ] as const) {
      agents[key] = await userIn(clientId, 'field_agent');
    }

    // Declined after a fresh, accurate at-store ping: not_sharing, not at_store.
    await ping(agents.declinedFresh, 20 * SEC, inStore, 8);
    await answer(agents.declinedFresh, ['acknowledged', 'declined']);
    // Declined, with only an old ping: not_sharing, not offline.
    await ping(agents.declinedOld, 3 * 60 * MIN, road, 8);
    await answer(agents.declinedOld, ['acknowledged', 'declined']);
    await prisma.visit.create({
      data: {
        clientId,
        outletId,
        agentId: agents.declinedOld.userId,
        checkinTs: new Date(Date.now() - 4 * 60 * MIN),
        checkinLat: store.lat,
        checkinLng: store.lng,
        geofencePass: true,
        status: 'submitted',
      },
    });
    // Declined, then acknowledged again: back to reading by ping.
    await ping(agents.reacknowledged, 30 * SEC, road, 8);
    await answer(agents.reacknowledged, ['acknowledged', 'declined', 'acknowledged']);
    // Declined an OLDER notice only: that answer no longer counts.
    await ping(agents.oldNoticeDeclined, 30 * SEC, road, 8);
    await answer(agents.oldNoticeDeclined, ['declined'], '2020-01-01');
    // Never answered the notice, so never shared: offline.

    await ping(agents.accuracy100, 30 * SEC, inStore, 100);
    await ping(agents.accuracy101, 30 * SEC, inStore, 101);
    await ping(agents.accuracyNull, 30 * SEC, inStore, null);
    await ping(agents.staleLowAccuracy, 10 * MIN, inStore, null);
  });

  afterAll(async () => {
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
  });

  it('carries the accuracy limit in the thresholds envelope', async () => {
    const { body } = await rows();
    expect(body).toMatchObject({
      intervalSeconds: 120,
      staleAfterSeconds: 360,
      offlineAfterSeconds: 1800,
      maxAtStoreAccuracyM: 100,
    });
  });

  it('a declined agent with a fresh ping reads not_sharing, and their position is withheld', async () => {
    const { byId } = await rows();
    expect(byId.get(agents.declinedFresh.userId)).toMatchObject({
      state: 'not_sharing',
      lastPing: null,
      ageSeconds: null,
      currentOutlet: null,
      lastOutlet: null,
    });
  });

  it('a declined agent with only an old ping reads not_sharing, not offline, keeping the check-in', async () => {
    const { byId } = await rows();
    expect(byId.get(agents.declinedOld.userId)).toMatchObject({
      state: 'not_sharing',
      lastPing: null,
      lastOutlet: { id: outletId, name: 'Rosebank PnP', source: 'check_in' },
    });
  });

  it('declining stores nothing extra and deletes nothing: the pings are still there', async () => {
    expect(await prisma.agentLocationPing.count({ where: { agentId: agents.declinedFresh.userId } })).toBe(1);
    expect(await prisma.agentLocationPing.count({ where: { agentId: agents.declinedOld.userId } })).toBe(1);
  });

  it('a declined-then-re-acknowledged agent reads by ping', async () => {
    const { byId } = await rows();
    const row = byId.get(agents.reacknowledged.userId)!;
    expect(row).toMatchObject({ state: 'in_transit', lastPing: { accuracyM: 8 } });
    expect(row.ageSeconds).toEqual(expect.any(Number));
  });

  it('a decline of an older notice does not count', async () => {
    const { byId } = await rows();
    expect(byId.get(agents.oldNoticeDeclined.userId)).toMatchObject({ state: 'in_transit' });
  });

  it('an agent who never answered reads offline', async () => {
    const { byId } = await rows();
    expect(byId.get(agents.neverAnswered.userId)).toMatchObject({ state: 'offline', lastPing: null, ageSeconds: null });
  });

  it('accuracy 100m inside a fence is at_store; 101m and none are near_store', async () => {
    const { byId } = await rows();
    const outlet = { id: outletId, name: 'Rosebank PnP' };
    expect(byId.get(agents.accuracy100.userId)).toMatchObject({
      state: 'at_store',
      currentOutlet: outlet,
      lastOutlet: { ...outlet, source: 'ping' },
    });
    for (const agent of [agents.accuracy101, agents.accuracyNull]) {
      expect(byId.get(agent.userId)).toMatchObject({
        state: 'near_store',
        currentOutlet: null,
        lastOutlet: { ...outlet, source: 'ping' },
      });
    }
  });

  it('stale beats near_store: age before place still holds', async () => {
    const { byId } = await rows();
    expect(byId.get(agents.staleLowAccuracy.userId)).toMatchObject({ state: 'stale', currentOutlet: null });
  });
});

describe('GET /agents/locations (#153 T1)', () => {
  const SEC = 1000;
  const MIN = 60 * SEC;
  const store = { lat: -26.1, lng: 28.05 };
  // ~1.1km north of the store: outside its 50m fence.
  const road = { lat: -26.09, lng: 28.05 };

  let clientId: string;
  let outletId: string;
  let territoryId: string;
  let manager: TestUser;
  let agents: Record<'atStore' | 'transit' | 'stale' | 'offline' | 'never', TestUser>;
  let foreign: TestUser & { cleanup: () => Promise<void> };

  const get = (user: TestUser, qs = '') =>
    request(app).get(`/agents/locations${qs}`).set('Authorization', `Bearer ${user.token}`);

  const ping = (agent: TestUser, ageMs: number, where: { lat: number; lng: number }, createdAt?: Date) =>
    prisma.agentLocationPing.create({
      data: {
        clientId: agent.clientId,
        agentId: agent.userId,
        ...where,
        accuracyM: 8,
        recordedAt: new Date(Date.now() - ageMs),
        source: 'foreground',
        ...(createdAt ? { createdAt } : {}),
      },
    });

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'ALOC-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    outletId = (
      await prisma.outlet.create({
        data: { clientId, name: 'Sandton Spar', code: 'ALOC-1', channelType: 'grocery', territoryId: 'GP', ...store },
      })
    ).id;
    territoryId = (await prisma.territory.create({ data: { clientId, name: 'Gauteng', code: 'ALOC-GP' } })).id;
    manager = await userIn(clientId, 'manager');
    agents = {
      atStore: await userIn(clientId, 'field_agent', { displayName: 'At Store' }),
      transit: await userIn(clientId, 'field_agent'),
      stale: await userIn(clientId, 'field_agent'),
      offline: await userIn(clientId, 'field_agent'),
      never: await userIn(clientId, 'field_agent'),
    };

    // at_store: fresh, 10m from the store. An OLDER ping elsewhere arrived later
    // (a late outbox flush) — it must not be taken as the latest.
    await ping(agents.atStore, 30 * SEC, { lat: store.lat + 0.00009, lng: store.lng }, new Date(Date.now() - 20 * MIN));
    await ping(agents.atStore, 10 * MIN, road, new Date());
    // in_transit: fresh, on the road; checked in at the store earlier.
    await ping(agents.transit, 45 * SEC, road);
    await prisma.visit.create({
      data: {
        clientId,
        outletId,
        agentId: agents.transit.userId,
        checkinTs: new Date(Date.now() - 90 * MIN),
        checkinLat: store.lat,
        checkinLng: store.lng,
        geofencePass: true,
        status: 'submitted',
      },
    });
    // stale: ten minutes old, inside the store fence.
    await ping(agents.stale, 10 * MIN, store);
    // offline: two hours old.
    await ping(agents.offline, 2 * 60 * MIN, road);

    await prisma.userTerritory.create({ data: { userId: agents.atStore.userId, territoryId } });

    foreign = await foreignTenant('field_agent');
    await ping(foreign, 10 * SEC, store);
  });

  afterAll(async () => {
    await prisma.userTerritory.deleteMany({ where: { territoryId } });
    await prisma.territory.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  it('derives the four ping-age states, with age, outlet and the server clock', async () => {
    const before = Date.now();
    const res = await get(manager);
    expect(res.status).toBe(200);

    const serverTime = new Date(res.body.serverTime).getTime();
    expect(serverTime).toBeGreaterThanOrEqual(before - SEC);
    expect(res.body).toMatchObject({
      intervalSeconds: 120,
      staleAfterSeconds: 360,
      offlineAfterSeconds: 1800,
      maxAtStoreAccuracyM: 100,
      nextCursor: null,
    });

    const byId = new Map<string, Record<string, unknown>>(
      res.body.data.map((row: Record<string, unknown>) => [row.agentId, row]),
    );
    expect(byId.size).toBe(5);

    const atStore = byId.get(agents.atStore.userId)!;
    expect(atStore).toMatchObject({
      name: 'At Store',
      state: 'at_store',
      currentOutlet: { id: outletId, name: 'Sandton Spar' },
      lastOutlet: { id: outletId, name: 'Sandton Spar', source: 'ping' },
      lastPing: { lat: store.lat + 0.00009, lng: store.lng, accuracyM: 8 },
    });
    expect(atStore.ageSeconds).toBeGreaterThanOrEqual(29);
    expect(atStore.ageSeconds).toBeLessThan(90);

    expect(byId.get(agents.transit.userId)).toMatchObject({
      state: 'in_transit',
      currentOutlet: null,
      lastOutlet: { id: outletId, name: 'Sandton Spar', source: 'check_in' },
    });
    expect(byId.get(agents.stale.userId)).toMatchObject({
      state: 'stale',
      currentOutlet: null,
      lastOutlet: { id: outletId, source: 'ping' },
    });
    expect(byId.get(agents.offline.userId)).toMatchObject({ state: 'offline', currentOutlet: null, lastOutlet: null });
    expect(byId.get(agents.never.userId)).toMatchObject({
      state: 'offline',
      lastPing: null,
      ageSeconds: null,
      lastOutlet: null,
    });
  });

  it('measures age against serverTime', async () => {
    const res = await get(manager);
    const row = res.body.data.find((r: { agentId: string }) => r.agentId === agents.offline.userId);
    const expected = Math.floor((new Date(res.body.serverTime).getTime() - new Date(row.lastPing.recordedAt).getTime()) / 1000);
    expect(row.ageSeconds).toBe(expected);
  });

  it('never shows another tenant’s agents', async () => {
    const res = await get(manager);
    expect(res.body.data.map((r: { agentId: string }) => r.agentId)).not.toContain(foreign.userId);
    const theirs = await get(foreign);
    expect(theirs.status).toBe(403);
  });

  it('pages by agent with limit and cursor, without overlap', async () => {
    const first = await get(manager, '?limit=2');
    expect(first.status).toBe(200);
    expect(first.body.data).toHaveLength(2);
    expect(first.body.nextCursor).toEqual(expect.any(String));

    const second = await get(manager, `?limit=2&cursor=${first.body.nextCursor}`);
    const third = await get(manager, `?limit=2&cursor=${second.body.nextCursor}`);
    expect(third.body.nextCursor).toBeNull();

    const ids = [...first.body.data, ...second.body.data, ...third.body.data].map((r: { agentId: string }) => r.agentId);
    expect(new Set(ids).size).toBe(5);
    expect(ids).toHaveLength(5);
  });

  it('rejects a malformed limit', async () => {
    expect((await get(manager, '?limit=0')).status).toBe(400);
    expect((await get(manager, '?limit=abc')).status).toBe(400);
  });

  it('clamps limit at the shared maximum rather than refusing it', async () => {
    const res = await get(manager, '?limit=5000');
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(5);
  });

  it('filters by territory through UserTerritory', async () => {
    const res = await get(manager, `?territoryId=${territoryId}`);
    expect(res.body.data.map((r: { agentId: string }) => r.agentId)).toEqual([agents.atStore.userId]);
    const none = await get(manager, '?territoryId=not-a-territory');
    expect(none.body.data).toEqual([]);
  });

  it('leaves deactivated agents off the map', async () => {
    const leaver = await userIn(clientId, 'field_agent');
    await ping(leaver, 10 * SEC, road);
    await prisma.user.update({ where: { id: leaver.userId }, data: { active: false } });
    const res = await get(manager, '?limit=200');
    expect(res.body.data.map((r: { agentId: string }) => r.agentId)).not.toContain(leaver.userId);
  });

  it('refuses a field agent', async () => {
    expect((await get(agents.transit)).status).toBe(403);
  });
});

/**
 * #153 T2 — background pings on the same map.
 *
 * They feed the same six states, but a background fix is taken on a timer with
 * the phone in a pocket, so it is never allowed to say the agent is IN a store.
 */
describe('background pings never claim a store (#153 T2)', () => {
  describe('deriveLiveState', () => {
    const at = (
      ageSeconds: number | null,
      insideOutlet: boolean,
      accuracyM: number | null,
      source: 'foreground' | 'background',
    ) =>
      deriveLiveState({
        ageSeconds,
        insideOutlet,
        accuracyM,
        source,
        intervalSeconds: 120,
        declined: false,
      });

    it('a fresh, pinpoint background ping inside a fence is in_transit, not at_store', () => {
      expect(at(30, true, 5, 'background')).toBe('in_transit');
      // The same reading from the foreground heartbeat does say at_store.
      expect(at(30, true, 5, 'foreground')).toBe('at_store');
    });

    it('is never near_store either — there is no store to be near', () => {
      expect(at(30, true, 500, 'background')).toBe('in_transit');
      expect(at(30, true, null, 'background')).toBe('in_transit');
      expect(at(30, true, 500, 'foreground')).toBe('near_store');
    });

    it('outside every fence it is in_transit, like any other ping', () => {
      expect(at(30, false, 5, 'background')).toBe('in_transit');
    });

    it('ages exactly like a foreground ping', () => {
      expect(at(361, true, 5, 'background')).toBe('stale');
      expect(at(1801, true, 5, 'background')).toBe('offline');
      expect(at(null, false, null, 'background')).toBe('offline');
    });

    it('an absent source is read as foreground, so T1 callers are unchanged', () => {
      expect(
        deriveLiveState({
          ageSeconds: 30,
          insideOutlet: true,
          accuracyM: 5,
          intervalSeconds: 120,
          declined: false,
        }),
      ).toBe('at_store');
    });
  });

  describe('GET /agents/locations', () => {
    const SEC = 1000;
    const store = { lat: -26.4, lng: 28.4 };
    /** ~10m north of the store: well inside its 50m fence. */
    const inStore = { lat: store.lat + 0.00009, lng: store.lng };

    let clientId: string;
    let outletId: string;
    let manager: TestUser;
    let backgroundAgent: TestUser;
    let foregroundAgent: TestUser;

    const get = (user: TestUser) =>
      request(app).get('/agents/locations?limit=200').set('Authorization', `Bearer ${user.token}`);

    interface AgentRow {
      agentId: string;
      state: string;
      ageSeconds: number | null;
      lastPing: { lat: number; lng: number; accuracyM: number | null; source: string } | null;
      currentOutlet: { id: string; name: string } | null;
      lastOutlet: { id: string; name: string; source: string } | null;
    }

    const row = (body: { data: AgentRow[] }, agent: TestUser): AgentRow =>
      body.data.find((r) => r.agentId === agent.userId)!;

    beforeAll(async () => {
      const client = await prisma.client.create({
        data: {
          name: `BGMAP-${Date.now()}`,
          industry: 'FMCG',
          scorecardWeights: {},
          kpiThresholds: {},
        },
      });
      clientId = client.id;
      outletId = (
        await prisma.outlet.create({
          data: {
            clientId,
            name: 'Background Store',
            code: 'BGMAP-1',
            channelType: 'grocery',
            territoryId: 'T-BGMAP',
            ...store,
          },
        })
      ).id;
      manager = await userIn(clientId, 'manager');
      backgroundAgent = await userIn(clientId, 'field_agent');
      foregroundAgent = await userIn(clientId, 'field_agent');

      // Both standing in the same store, with the same pinpoint accuracy. The
      // only difference between them is what took the fix.
      const recordedAt = new Date(Date.now() - 30 * SEC);
      for (const [agent, source] of [
        [backgroundAgent, 'background'],
        [foregroundAgent, 'foreground'],
      ] as const) {
        await prisma.agentLocationPing.create({
          data: {
            clientId,
            agentId: agent.userId,
            ...inStore,
            accuracyM: 5,
            recordedAt,
            source,
          },
        });
      }
    });

    afterAll(async () => {
      await prisma.agentLocationPing.deleteMany({ where: { clientId } });
      await prisma.outlet.delete({ where: { id: outletId } });
      await prisma.user.deleteMany({ where: { clientId } });
      await prisma.client.delete({ where: { id: clientId } });
    });

    it('reads in_transit where the identical foreground ping reads at_store', async () => {
      const res = await get(manager);
      expect(res.status).toBe(200);
      expect(row(res.body, backgroundAgent).state).toBe('in_transit');
      expect(row(res.body, foregroundAgent).state).toBe('at_store');
    });

    it('names no currentOutlet', async () => {
      const res = await get(manager);
      expect(row(res.body, backgroundAgent).currentOutlet).toBeNull();
      expect(row(res.body, foregroundAgent).currentOutlet).toMatchObject({ name: 'Background Store' });
    });

    it('names no lastOutlet from its fence either — that would be the same claim by another route', async () => {
      const res = await get(manager);
      // No check-in exists for this agent, so there is nothing to fall back to.
      expect(row(res.body, backgroundAgent).lastOutlet).toBeNull();
      expect(row(res.body, foregroundAgent).lastOutlet).toMatchObject({
        name: 'Background Store',
        source: 'ping',
      });
    });

    it('still places the agent on the map, and says what took the fix', async () => {
      const res = await get(manager);
      const ping = row(res.body, backgroundAgent).lastPing;
      expect(ping).toMatchObject({ lat: inStore.lat, lng: inStore.lng, source: 'background' });
      expect(row(res.body, backgroundAgent).ageSeconds).toBeGreaterThanOrEqual(0);
      expect(row(res.body, foregroundAgent).lastPing!.source).toBe('foreground');
    });
  });
});
