import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';

/**
 * #379 / #385: one store walk is one visit row.
 *
 * The app mints a local uuid at check-in and flushes the outbox later. When the
 * POST succeeded but its response was lost — a dead zone at the shop door,
 * which is the normal case — the retry used to create a SECOND visit: two rows,
 * two scorecards, two fraud scores, and a manager unable to tell which was the
 * real one.
 *
 * The properties pinned here:
 *
 *   1. A retry returns the FIRST visit, and creates nothing.
 *   2. A retry writes no second `CheckInAttempt` row and does not move the
 *      agent's last-known location. A retry is not a second attempt to check
 *      in, and the attempts table is the fraud engine's negative-signal dataset.
 *   3. An older app build, which sends no key at all, behaves exactly as it did.
 */
const OUTLET = { lat: -26.2041, lng: 28.0473 };

describe('POST /visits idempotency (#379, #385)', () => {
  let clientId: string;
  let agent: TestUser;
  let otherAgent: TestUser;
  let manager: TestUser;
  let outletId: string;
  let foreign: TestUser & { cleanup: () => Promise<void> };

  const checkIn = (token: string, body: Record<string, unknown>) =>
    request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: OUTLET.lat, lng: OUTLET.lng, ...body });

  const attemptsFor = (agentId: string) =>
    prisma.checkInAttempt.count({ where: { clientId, agentId, outletId } });

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DEDUPE-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    agent = await userIn(clientId, 'field_agent');
    otherAgent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    // A whole separate company, with a field agent who authenticates fine.
    foreign = await foreignTenant('field_agent');

    const outlet = await prisma.outlet.create({
      data: {
        name: 'DEDUPE-Outlet',
        code: 'DEDUPE-OUT',
        channelType: 'spaza',
        ...OUTLET,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;
  });

  afterAll(async () => {
    await prisma.checkInAttempt.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  it('creates the visit on the first send and echoes the device key back', async () => {
    const res = await checkIn(agent.token, { clientVisitId: 'dedupe-first-uuid' });

    expect(res.status).toBe(201);
    expect(res.body.clientVisitId).toBe('dedupe-first-uuid');
    // Not a resumed visit: a fresh check-in is what false honestly means.
    expect(res.body.resumedFromDraft).toBe(false);
    expect(res.body.deduplicated).toBe(false);
    expect(res.headers['idempotent-replayed']).toBeUndefined();
  });

  it('returns the SAME visit with 200 on a retry, and creates no second row', async () => {
    const first = await checkIn(agent.token, { clientVisitId: 'dedupe-retry-uuid' });
    expect(first.status).toBe(201);

    const retry = await checkIn(agent.token, { clientVisitId: 'dedupe-retry-uuid' });

    expect(retry.status).toBe(200);
    expect(retry.body.id).toBe(first.body.id);
    expect(retry.body.deduplicated).toBe(true);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(
      await prisma.visit.count({ where: { clientId, clientVisitId: 'dedupe-retry-uuid' } }),
    ).toBe(1);
  });

  it('writes no second CheckInAttempt row on a retry', async () => {
    // A retry is not a second attempt to check in. Letting it write one would
    // feed the fraud engine a burst of attempts for a visit that happened once.
    const before = await attemptsFor(agent.userId);
    const first = await checkIn(agent.token, { clientVisitId: 'dedupe-attempts-uuid' });
    expect(first.status).toBe(201);
    const afterCreate = await attemptsFor(agent.userId);
    expect(afterCreate).toBe(before + 1);

    await checkIn(agent.token, { clientVisitId: 'dedupe-attempts-uuid' });
    await checkIn(agent.token, { clientVisitId: 'dedupe-attempts-uuid' });

    expect(await attemptsFor(agent.userId)).toBe(afterCreate);
  });

  it("does not move the agent's last-known location on a retry", async () => {
    // lastLat/lastLng feed predictive dispatch. A retry that flushed from the
    // next town would otherwise claim the agent is standing there.
    await checkIn(agent.token, { clientVisitId: 'dedupe-location-uuid' });
    const after = await prisma.user.findUniqueOrThrow({
      where: { id: agent.userId },
      select: { lastLat: true, lastLng: true, lastSeenAt: true },
    });

    const retry = await checkIn(agent.token, {
      clientVisitId: 'dedupe-location-uuid',
      lat: OUTLET.lat + 0.0002,
      lng: OUTLET.lng + 0.0002,
    });

    expect(retry.status).toBe(200);
    const later = await prisma.user.findUniqueOrThrow({
      where: { id: agent.userId },
      select: { lastLat: true, lastLng: true, lastSeenAt: true },
    });
    expect(later).toEqual(after);
  });

  it('lets exactly one of two concurrent retries create the visit', async () => {
    // Both miss the lookup; the unique (agent_id, client_visit_id) index decides.
    // The loser must read the winner back, not answer 500 — a 500 sends the app
    // away to retry again, which is how one lost response becomes an endless one.
    const [a, b] = await Promise.all([
      checkIn(agent.token, { clientVisitId: 'dedupe-race-uuid' }),
      checkIn(agent.token, { clientVisitId: 'dedupe-race-uuid' }),
    ]);

    expect([a.status, b.status].sort()).toEqual([200, 201]);
    expect(a.body.id).toBe(b.body.id);
    expect(
      await prisma.visit.count({ where: { clientId, clientVisitId: 'dedupe-race-uuid' } }),
    ).toBe(1);
  });

  it('treats two agents using the same local uuid as two different visits', async () => {
    // The key is scoped to the agent, like Message.clientMessageId is to its
    // sender: two devices' uuid namespaces are separate, and one agent's key
    // must never resolve to a colleague's visit.
    const mine = await checkIn(agent.token, { clientVisitId: 'dedupe-shared-uuid' });
    const theirs = await checkIn(otherAgent.token, { clientVisitId: 'dedupe-shared-uuid' });

    expect(mine.status).toBe(201);
    expect(theirs.status).toBe(201);
    expect(theirs.body.id).not.toBe(mine.body.id);
    expect(theirs.body.agentId).toBe(otherAgent.userId);
  });

  it('leaves an older app build, which sends no key, exactly as it was', async () => {
    // Postgres treats NULLs as distinct, so keyless check-ins stay unconstrained:
    // two check-ins with no key are still two visits, as they have always been.
    const first = await checkIn(agent.token, {});
    const second = await checkIn(agent.token, {});

    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    expect(second.body.id).not.toBe(first.body.id);
    expect(first.body.clientVisitId).toBeNull();
    expect(first.body.resumedFromDraft).toBe(false);
    expect(first.body.deduplicated).toBe(false);
  });

  it('persists resumed: true and surfaces it on the detail and the list', async () => {
    const created = await checkIn(agent.token, {
      clientVisitId: 'dedupe-resumed-uuid',
      resumed: true,
    });
    expect(created.status).toBe(201);
    expect(created.body.resumedFromDraft).toBe(true);

    const detail = await request(app)
      .get(`/visits/${created.body.id}`)
      .set('Authorization', `Bearer ${manager.token}`);
    expect(detail.status).toBe(200);
    expect(detail.body.resumedFromDraft).toBe(true);

    const list = await request(app)
      .get('/visits?limit=200')
      .set('Authorization', `Bearer ${manager.token}`);
    const row = list.body.data.find((v: { id: string }) => v.id === created.body.id);
    expect(row.resumedFromDraft).toBe(true);
  });

  it('defaults resumedFromDraft to false when the client says nothing', async () => {
    const created = await checkIn(agent.token, { clientVisitId: 'dedupe-noresume-uuid' });

    const detail = await request(app)
      .get(`/visits/${created.body.id}`)
      .set('Authorization', `Bearer ${manager.token}`);
    // False, not null and not absent: a fresh check-in is a known thing, not an
    // unmeasured one.
    expect(detail.body).toHaveProperty('resumedFromDraft', false);
  });

  it('rejects a malformed clientVisitId with 400 and stores nothing', async () => {
    const before = await prisma.visit.count({ where: { clientId } });
    for (const clientVisitId of ['', 'has spaces', 'x'.repeat(129), 42]) {
      const res = await checkIn(agent.token, { clientVisitId });
      expect(res.status).toBe(400);
    }
    expect(await prisma.visit.count({ where: { clientId } })).toBe(before);
  });

  it('rejects a non-boolean resumed with 400', async () => {
    const res = await checkIn(agent.token, { clientVisitId: 'dedupe-badresume', resumed: 'yes' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('resumed');
  });

  it("gives a foreign tenant 404 for this client's outlet, key or no key", async () => {
    // The foreign agent authenticates successfully and is THEN denied: a 401
    // would mean the tenant scoping was never reached. Reusing a key that
    // already names one of our visits must not resolve to it either — the
    // dedupe lookup is scoped to (agent, client), so it falls through to the
    // outlet check and finds nothing.
    const res = await checkIn(foreign.token, { clientVisitId: 'dedupe-first-uuid' });

    expect(res.status).toBe(404);
    expect(await prisma.visit.count({ where: { clientId: foreign.clientId } })).toBe(0);
  });
});
