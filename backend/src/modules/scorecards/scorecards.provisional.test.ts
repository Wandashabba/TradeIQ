import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';

/**
 * #390 / #399: "scored 71, you saw 84".
 *
 * The app scores a visit on the device from the outbox so the agent sees a
 * number before leaving the store, using a simpler formula than the server's.
 * The two legitimately disagree — and until now the device's number was thrown
 * away on sync, so an agent who watched 84 on the walk out and later opened 71
 * had no way to learn that both were honest. It simply looked as though the app
 * had lied to them.
 *
 * The properties pinned here:
 *
 *   1. The device's score is recorded and reported back, and **never read as an
 *      input**: the server's own total is identical whatever the device sent.
 *   2. A regenerate that carries no provisional does NOT wipe one. The server
 *      recomputing its number has learned nothing new about what the agent saw.
 *   3. "We do not know what they saw" is **null**, never 0.
 */
const OUTLET = { lat: -26.2041, lng: 28.0473 };

type ScorecardBody = {
  weightedTotal: number;
  ratingBand: string;
  createdAt: string;
  scoredAt: string;
  provisional: { weightedTotal: number; ratingBand: string; seenAt: string | null } | null;
};

describe('server-stamped provisional score (#390, #399)', () => {
  let clientId: string;
  let agent: TestUser;
  let manager: TestUser;
  let foreign: TestUser & { cleanup: () => Promise<void> };
  let outletId: string;
  let skuId: string;

  const score = (visitId: string, body: Record<string, unknown> = {}, token = agent.token) =>
    request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${token}`)
      .send({ visitId, ...body });

  /** A submitted visit with one in-stock SKU, so the server has a real score. */
  const createVisit = async () => {
    const visit = await prisma.visit.create({
      data: {
        outletId,
        agentId: agent.userId,
        clientId,
        checkinTs: new Date(),
        checkinLat: OUTLET.lat,
        checkinLng: OUTLET.lng,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visit.id,
        skuId,
        unitsAvailable: 12,
        lastStockinDate: new Date(),
        daysOutOfStock: 0,
        velocityAvg: 1.5,
        coverageDaysPredicted: 8,
      },
    });
    return visit.id;
  };

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'PROVISIONAL-Client',
        industry: 'FMCG',
        scorecardWeights: { availability: 1 },
        kpiThresholds: { green: 80, amber: 60 },
      },
    });
    clientId = client.id;

    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    foreign = await foreignTenant('field_agent');

    const outlet = await prisma.outlet.create({
      data: {
        name: 'PROVISIONAL-Outlet',
        code: 'PROV-OUT',
        channelType: 'spaza',
        ...OUTLET,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;

    const sku = await prisma.sku.create({
      data: { clientId, name: 'PROV-SKU', category: 'beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;
  });

  afterAll(async () => {
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  it('records what the device showed and hands it straight back', async () => {
    const visitId = await createVisit();
    const seenAt = '2026-09-01T08:30:00.000Z';

    const res = await score(visitId, {
      provisional: { weightedTotal: 84, ratingBand: 'green', computedAt: seenAt },
    });

    expect(res.status).toBe(201);
    const body = res.body as ScorecardBody;
    expect(body.provisional).toEqual({ weightedTotal: 84, ratingBand: 'green', seenAt });
    // The server's own number is unaffected: one in-stock SKU is 100% availability.
    expect(body.weightedTotal).toBe(100);
    expect(body.ratingBand).toBe('green');
    expect(Number.isNaN(Date.parse(body.scoredAt))).toBe(false);
  });

  it('never reads the provisional as an input to any score', async () => {
    // Two identical visits, one told the device scored 84 and the other 3. If
    // anything downstream read the column, these would differ.
    const [honest, absurd] = await Promise.all([createVisit(), createVisit()]);
    const [a, b] = await Promise.all([
      score(honest, { provisional: { weightedTotal: 84, ratingBand: 'green' } }),
      score(absurd, { provisional: { weightedTotal: 3, ratingBand: 'red' } }),
    ]);

    expect(a.body.weightedTotal).toBe(b.body.weightedTotal);
    expect(a.body.dimensionScores).toEqual(b.body.dimensionScores);
    expect(a.body.ratingBand).toBe(b.body.ratingBand);
  });

  it('does NOT wipe a stored provisional when a regenerate carries none', async () => {
    const visitId = await createVisit();
    await score(visitId, { provisional: { weightedTotal: 71.5, ratingBand: 'amber' } });

    // A re-sync, a rescore, the submit hook firing twice: the server recomputing
    // its own number has learned nothing new about what the agent was shown.
    const again = await score(visitId);

    expect(again.status).toBe(201);
    expect((again.body as ScorecardBody).provisional).toEqual({
      weightedTotal: 71.5,
      ratingBand: 'amber',
      seenAt: null,
    });
  });

  it('overwrites the provisional only when a new one is supplied', async () => {
    const visitId = await createVisit();
    await score(visitId, { provisional: { weightedTotal: 40, ratingBand: 'red' } });

    const again = await score(visitId, { provisional: { weightedTotal: 90, ratingBand: 'green' } });

    expect((again.body as ScorecardBody).provisional).toMatchObject({
      weightedTotal: 90,
      ratingBand: 'green',
    });
  });

  it('reports null — never 0 — when no client ever sent a provisional', async () => {
    const visitId = await createVisit();

    const res = await score(visitId);

    // An older app build sends `{ visitId }` alone. That is not a device that
    // scored the visit at zero; it is a device whose number we never learned.
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('provisional', null);
  });

  it('reports seenAt: null when the score arrived without a device clock', async () => {
    const visitId = await createVisit();

    const res = await score(visitId, { provisional: { weightedTotal: 55, ratingBand: 'red' } });

    // We know what they saw, not when. Stamping the server clock here would be
    // inventing a device time.
    expect((res.body as ScorecardBody).provisional).toEqual({
      weightedTotal: 55,
      ratingBand: 'red',
      seenAt: null,
    });
  });

  it('moves scoredAt on a regenerate while createdAt stays put', async () => {
    const visitId = await createVisit();
    const first = (await score(visitId)).body as ScorecardBody;
    await new Promise((resolve) => setTimeout(resolve, 5));

    const second = (await score(visitId)).body as ScorecardBody;

    expect(second.createdAt).toBe(first.createdAt);
    // createdAt survives the upsert, so it names when the FIRST score was
    // written. A client rendering "scored 71" needs to say when 71 was decided.
    expect(Date.parse(second.scoredAt)).toBeGreaterThan(Date.parse(first.scoredAt));
  });

  it('serves the same shape from GET /scorecards/:visitId', async () => {
    const visitId = await createVisit();
    await score(visitId, {
      provisional: { weightedTotal: 62, ratingBand: 'amber', computedAt: '2026-09-02T06:00:00.000Z' },
    });

    const res = await request(app)
      .get(`/scorecards/${visitId}`)
      .set('Authorization', `Bearer ${agent.token}`);

    expect(res.status).toBe(200);
    expect((res.body as ScorecardBody).provisional).toEqual({
      weightedTotal: 62,
      ratingBand: 'amber',
      seenAt: '2026-09-02T06:00:00.000Z',
    });
    expect(res.body).toHaveProperty('scoredAt');
  });

  it("surfaces both on the manager's visit detail", async () => {
    const visitId = await createVisit();
    await score(visitId, {
      provisional: { weightedTotal: 84, ratingBand: 'green', computedAt: '2026-09-03T07:15:00.000Z' },
    });

    const res = await request(app)
      .get(`/visits/${visitId}`)
      .set('Authorization', `Bearer ${manager.token}`);

    expect(res.status).toBe(200);
    expect(res.body.score.provisional).toEqual({
      weightedTotal: 84,
      ratingBand: 'green',
      seenAt: '2026-09-03T07:15:00.000Z',
    });
    expect(Number.isNaN(Date.parse(res.body.score.scoredAt))).toBe(false);
  });

  it('shows provisional: null on a visit detail whose score has no device number', async () => {
    const visitId = await createVisit();
    await score(visitId);

    const res = await request(app)
      .get(`/visits/${visitId}`)
      .set('Authorization', `Bearer ${manager.token}`);

    expect(res.body.score).toHaveProperty('provisional', null);
  });

  it('rejects a malformed provisional with 400 and stores no scorecard', async () => {
    const visitId = await createVisit();
    const bad: Array<Record<string, unknown>> = [
      { weightedTotal: 84 }, // a total with no band is not a score anyone saw
      { weightedTotal: 150, ratingBand: 'green' },
      { weightedTotal: 84, ratingBand: 'blue' },
      { weightedTotal: 84, ratingBand: 'green', ratingBnd: 'green' },
      { weightedTotal: 84, ratingBand: 'green', computedAt: 'yesterday' },
    ];
    for (const provisional of bad) {
      const res = await score(visitId, { provisional });
      expect(res.status).toBe(400);
      expect(Array.isArray(res.body.issues)).toBe(true);
    }
    expect(await prisma.scorecard.count({ where: { visitId } })).toBe(0);
  });

  it('still accepts the older body an unchanged app build sends', async () => {
    const visitId = await createVisit();

    const res = await score(visitId, {});

    expect(res.status).toBe(201);
    expect(res.body.weightedTotal).toBe(100);
  });

  it("returns 404 to a foreign tenant scoring this client's visit", async () => {
    const visitId = await createVisit();

    const res = await score(
      visitId,
      { provisional: { weightedTotal: 99, ratingBand: 'green' } },
      foreign.token,
    );

    // Authenticated, and THEN denied: a 401 would mean the scoping was never
    // reached. And nothing was written under their name.
    expect(res.status).toBe(404);
    expect(await prisma.scorecard.count({ where: { visitId } })).toBe(0);
  });
});
