import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { deriveLiveState } from './agentLocations.service';

/**
 * #153 T1 — GET /agents/locations: each agent's latest ping, its age, and one
 * of four states. Age decides before place, ordering is by recordedAt, and the
 * page is bounded.
 */
describe('deriveLiveState', () => {
  // Default interval 120s → stale after max(300, 3×120) = 360s; offline after 1800s.
  const at = (ageSeconds: number | null, insideOutlet = false) =>
    deriveLiveState({ ageSeconds, insideOutlet, intervalSeconds: 120 });

  it('never shared is offline', () => expect(at(null)).toBe('offline'));
  it('fresh inside a fence is at_store', () => expect(at(0, true)).toBe('at_store'));
  it('fresh outside every fence is in_transit', () => expect(at(360)).toBe('in_transit'));
  it('past three missed pings is stale, even inside a fence', () => expect(at(361, true)).toBe('stale'));
  it('stale holds up to the offline threshold', () => expect(at(1800)).toBe('stale'));
  it('past thirty minutes is offline', () => expect(at(1801, true)).toBe('offline'));

  it('never calls a ping stale sooner than five minutes, however short the interval', () => {
    expect(deriveLiveState({ ageSeconds: 299, insideOutlet: false, intervalSeconds: 60 })).toBe('in_transit');
    expect(deriveLiveState({ ageSeconds: 301, insideOutlet: false, intervalSeconds: 60 })).toBe('stale');
  });

  it('stretches stale with a longer tenant interval', () => {
    expect(deriveLiveState({ ageSeconds: 800, insideOutlet: true, intervalSeconds: 300 })).toBe('at_store');
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

  it('derives all four states, with age, outlet and the server clock', async () => {
    const before = Date.now();
    const res = await get(manager);
    expect(res.status).toBe(200);

    const serverTime = new Date(res.body.serverTime).getTime();
    expect(serverTime).toBeGreaterThanOrEqual(before - SEC);
    expect(res.body).toMatchObject({ intervalSeconds: 120, staleAfterSeconds: 360, offlineAfterSeconds: 1800, nextCursor: null });

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
