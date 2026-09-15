import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, userIn } from '../../test-utils/tenants';
import { rescoreFraudScores } from './fraudRescore';

/**
 * #248 end to end: stock_outside_outlet on GET /fraud/visits/:id and
 * GET /fraud/flagged. The weighting is pinned in fraud.outside.test.ts; this
 * suite pins what only the database can: the outlet lookup (own outlet plus
 * same-client outlets near each capture position), its tenant scope, the
 * per-client tolerance read from the column, and one lookup per flagged scan.
 */
const A = { lat: -26.2041, lng: 28.0473 };
const M_PER_DEG_LAT = 111_195;
const offset = (from: { lat: number; lng: number }, northM: number, eastM = 0) => ({
  lat: from.lat + northM / M_PER_DEG_LAT,
  lng: from.lng + eastM / (M_PER_DEG_LAT * Math.cos((from.lat * Math.PI) / 180)),
});
// 120m north of A: clear of A's fence + tolerance, under the divergence line.
const NEAR = offset(A, 120);
// ~1.1km south of A: a photo here also trips photo_gps_divergence.
const FAR = offset(A, -1100);
// 120m east of A: where the OTHER tenant's outlet stands.
const OTHER_TENANT_SPOT = offset(A, 0, 120);

const DAY_MS = 24 * 60 * 60 * 1000;
const MINUTE_MS = 60_000;
const daysAgo = (n: number): Date => new Date(Date.now() - n * DAY_MS);

type Signal = { code: string; detail: string; weight: number };

describe('stock_outside_outlet routes (#248)', () => {
  let clientId: string;
  let otherClientId: string;
  let agent: TestUser;
  let manager: TestUser;
  let otherAgent: TestUser;
  let otherManager: TestUser;
  let outletA: string;
  const visits: Record<string, string> = {};

  const createOutlet = async (cid: string, code: string, at: { lat: number; lng: number }) =>
    (
      await prisma.outlet.create({
        data: {
          name: `OUTSIDE-${code}`,
          code: `OUTSIDE-${code}`,
          channelType: 'spaza',
          ...at,
          territoryId: 'territory-1',
          clientId: cid,
        },
      })
    ).id;

  // A 20-minute visit checked in at the outlet itself; one stock row with a
  // count of its own (never a repeating run) and one photo mid-visit wherever
  // the test places it.
  const createVisit = async (
    who: TestUser,
    outletId: string,
    days: number,
    photo: { lat: number; lng: number } | null,
    options: { status?: 'submitted' | 'in_progress'; stock?: boolean; checkinAt?: { lat: number; lng: number } } = {},
  ) => {
    const checkinTs = daysAgo(days);
    const checkinAt = options.checkinAt ?? A;
    const visit = await prisma.visit.create({
      data: {
        outletId,
        agentId: who.userId,
        clientId: who.clientId,
        checkinTs,
        checkinLat: checkinAt.lat,
        checkinLng: checkinAt.lng,
        geofencePass: true,
        checkinDistanceM: 5,
        status: options.status ?? 'submitted',
        submittedAtClient: new Date(checkinTs.getTime() + 20 * MINUTE_MS),
      },
    });
    if (options.stock ?? true) {
      const sku = await prisma.sku.create({
        data: { clientId: who.clientId, name: `OUTSIDE-SKU-${visit.id}`, category: 'beverages', minFacingsStandard: 1, rrp: 1 },
      });
      await prisma.visitStock.create({
        data: {
          visitId: visit.id,
          skuId: sku.id,
          unitsAvailable: 8,
          lastStockinDate: checkinTs,
          daysOutOfStock: 0,
          velocityAvg: 0,
          coverageDaysPredicted: 8,
        },
      });
    } else {
      // Something captured, so no_capture stays quiet: only the missing stock is under test.
      await prisma.visitCapability.create({
        data: { visitId: visit.id, staffHeadcountConfirmed: 2, repTrainingStatus: {}, quizScore: 80 },
      });
    }
    await prisma.photo.create({
      data: {
        visitId: visit.id,
        section: 'visibility',
        url: 'https://example.test/outside.jpg',
        gpsTag: photo ?? {},
        timestamp: new Date(checkinTs.getTime() + 10 * MINUTE_MS),
      },
    });
    return { id: visit.id, checkinTs };
  };

  const fraudFor = async (visitId: string, who: TestUser = manager) => {
    const res = await request(app).get(`/fraud/visits/${visitId}`).set('Authorization', `Bearer ${who.token}`);
    expect(res.status).toBe(200);
    return res.body as { riskScore: number; signals: Signal[] };
  };
  const outsideOf = async (visitId: string, who?: TestUser) =>
    (await fraudFor(visitId, who)).signals.find((s) => s.code === 'stock_outside_outlet');

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'OUTSIDE-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const otherClient = await prisma.client.create({
      data: { name: 'OUTSIDE-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    otherAgent = await userIn(otherClientId, 'field_agent');
    otherManager = await userIn(otherClientId, 'manager');

    outletA = await createOutlet(clientId, 'A', A);
    await createOutlet(clientId, 'NEAR', NEAR);
    await createOutlet(clientId, 'FAR', FAR);
    // The other tenant has ONE outlet, 120m east of A.
    const otherOutlet = await createOutlet(otherClientId, 'X', OTHER_TENANT_SPOT);

    // Strong: a photo from the sitting, inside outlet NEAR → 30 alone.
    visits.near = (await createVisit(agent, outletA, 10, NEAR)).id;
    // At the visit's own outlet → silent.
    visits.own = (await createVisit(agent, outletA, 9, A)).id;
    // No coordinates on the photo → silent.
    visits.noCoords = (await createVisit(agent, outletA, 8, null)).id;
    // Inside ANOTHER tenant's outlet, and none of this client's → silent.
    visits.otherTenantSpot = (await createVisit(agent, outletA, 7, OTHER_TENANT_SPOT)).id;
    // Far outlet: photo_gps_divergence 25 + a top-up of 20.
    visits.far = (await createVisit(agent, outletA, 6, FAR)).id;
    // Far outlet, and a rejected check-in to A from inside FAR 30 minutes
    // earlier → failed_attempts 10 + 25 + 30 = 65, the one that flags.
    const corroborated = await createVisit(agent, outletA, 5, FAR);
    visits.farCorroborated = corroborated.id;
    await prisma.checkInAttempt.create({
      data: {
        clientId,
        outletId: outletA,
        agentId: agent.userId,
        ...offset(FAR, 15),
        distanceM: 1085,
        passed: false,
        createdAt: new Date(corroborated.checkinTs.getTime() - 30 * MINUTE_MS),
      },
    });
    // A draft, and a visit without stock, each with a photo inside NEAR → silent.
    visits.draft = (await createVisit(agent, outletA, 4, NEAR, { status: 'in_progress' })).id;
    visits.noStock = (await createVisit(agent, outletA, 3, NEAR, { stock: false })).id;

    // The other tenant, single-outlet: its visit's photo stands in THIS client's
    // outlet A (120m from its own, under the divergence line), which it must
    // never see.
    visits.singleOutletTenant = (
      await createVisit(otherAgent, otherOutlet, 2, A, { checkinAt: OTHER_TENANT_SPOT })
    ).id;
  });

  afterAll(async () => {
    for (const cid of [clientId, otherClientId]) {
      await prisma.checkInAttempt.deleteMany({ where: { clientId: cid } });
      await prisma.photo.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visitStock.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visitCapability.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visit.deleteMany({ where: { clientId: cid } });
      await prisma.sku.deleteMany({ where: { clientId: cid } });
      await prisma.outlet.deleteMany({ where: { clientId: cid } });
      await prisma.user.deleteMany({ where: { clientId: cid } });
      await prisma.client.delete({ where: { id: cid } });
    }
    await prisma.$disconnect();
  });

  describe('GET /fraud/visits/:visitId', () => {
    it("scores a photo from the counting sitting inside another of the client's outlets", async () => {
      const result = await fraudFor(visits.near);
      expect(result.signals).toEqual([expect.objectContaining({ code: 'stock_outside_outlet', weight: 30 })]);
      expect(result.riskScore).toBe(30);
      expect(result.signals[0].detail).toContain('from outlet OUTSIDE-NEAR (inside its 50m fence)');
      expect(result.signals[0].detail).toMatch(/and 12\dm from this visit's outlet/);
    });

    it("is silent at the visit's own outlet, and without coordinates", async () => {
      expect((await fraudFor(visits.own)).signals).toEqual([]);
      expect((await fraudFor(visits.noCoords)).signals).toEqual([]);
    });

    it("never counts another tenant's outlet at the capture position, in either direction", async () => {
      expect((await fraudFor(visits.otherTenantSpot)).signals).toEqual([]);
      // A single-outlet tenant, photographing inside this client's outlet.
      expect((await fraudFor(visits.singleOutletTenant, otherManager)).signals).toEqual([]);
      const crossTenant = await request(app)
        .get(`/fraud/visits/${visits.singleOutletTenant}`)
        .set('Authorization', `Bearer ${manager.token}`);
      expect(crossTenant.status).toBe(404);
    });

    it('only tops up photo_gps_divergence for the same far photo, unless a rejected attempt corroborates it', async () => {
      const far = await fraudFor(visits.far);
      expect(far.signals.map((s) => [s.code, s.weight])).toEqual([
        ['photo_gps_divergence', 25],
        ['stock_outside_outlet', 20],
      ]);
      expect(far.riskScore).toBe(45);

      const corroborated = await fraudFor(visits.farCorroborated);
      expect(corroborated.signals.map((s) => [s.code, s.weight])).toEqual([
        ['failed_attempts', 10],
        ['photo_gps_divergence', 25],
        ['stock_outside_outlet', 30],
      ]);
      expect(corroborated.riskScore).toBe(65);
      expect(corroborated.signals[2].detail).toContain(
        'a rejected check-in attempt for this outlet was also made from inside OUTSIDE-FAR',
      );
    });

    it('is silent for a draft and for a visit without stock', async () => {
      expect((await fraudFor(visits.draft)).signals).toEqual([]);
      expect((await fraudFor(visits.noStock)).signals).toEqual([]);
    });

    it("applies the tenant's own tolerance, read from the database under the pinned key", async () => {
      const setTolerance = (metres: number) =>
        prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: { stockOutsideOutletToleranceMeters: metres } } });
      try {
        // 120m from A: needs more than 50 + 100 = 150m once widened.
        await setTolerance(100);
        expect(await outsideOf(visits.near)).toBeUndefined();
        await setTolerance(60);
        expect(await outsideOf(visits.near)).toEqual(expect.objectContaining({ weight: 30 }));
        expect((await outsideOf(visits.near))!.detail).toContain('plus the 60m tolerance');
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
      }
    });
  });

  describe('GET /fraud/flagged', () => {
    // The list reads the stored score (#236); fixtures were written directly.
    beforeAll(async () => {
      await rescoreFraudScores({ clientId });
    });

    it('flags only the corroborated visit by default, and lists the rest with the same signals as the visit endpoint', async () => {
      const byDefault = await request(app).get('/fraud/flagged').set('Authorization', `Bearer ${manager.token}`);
      expect(byDefault.status).toBe(200);
      expect(byDefault.body.data.map((r: { visitId: string }) => r.visitId)).toEqual([visits.farCorroborated]);

      const listed = await request(app).get('/fraud/flagged?minScore=1').set('Authorization', `Bearer ${manager.token}`);
      expect(listed.status).toBe(200);
      const rows = listed.body.data as Array<{ visitId: string; riskScore: number; signals: Signal[] }>;
      expect(rows.map((r) => r.visitId)).toEqual([visits.farCorroborated, visits.far, visits.near]);
      expect(rows.map((r) => r.riskScore)).toEqual([65, 45, 30]);
      for (const row of rows) {
        expect(row.signals).toEqual((await fraudFor(row.visitId)).signals);
      }
    });

    it('looks the outlets near every capture position up in one query per scoring batch (no N+1)', async () => {
      const queryRaw = jest.spyOn(prisma, '$queryRaw');
      const outletFindMany = jest.spyOn(prisma.outlet, 'findMany');
      const outletFindFirst = jest.spyOn(prisma.outlet, 'findFirst');
      const outletFindUnique = jest.spyOn(prisma.outlet, 'findUnique');
      try {
        const result = await rescoreFraudScores({ clientId, all: true });
        // Seven submitted visits of this client scored in one batch (the draft is not).
        expect(result.scanned).toBe(7);
        const res = await request(app).get('/fraud/flagged?minScore=1').set('Authorization', `Bearer ${manager.token}`);
        expect(res.status).toBe(200);
        expect(res.body.data).toHaveLength(3);

        const sqlOf = (call: unknown[]) => (call[0] as { sql: string }).sql;
        const outletLookups = queryRaw.mock.calls.filter((call) => sqlOf(call).includes('lat_min'));
        // One outlet lookup for five geotagged visits with stock, next to #245's one stock
        // history read (no photo here has a hash, so #244's lookup skips itself).
        expect(outletLookups).toHaveLength(1);
        expect(queryRaw).toHaveBeenCalledTimes(2);
        expect(outletFindMany).not.toHaveBeenCalled();
        expect(outletFindFirst).not.toHaveBeenCalled();
        expect(outletFindUnique).not.toHaveBeenCalled();
      } finally {
        queryRaw.mockRestore();
        outletFindMany.mockRestore();
        outletFindFirst.mockRestore();
        outletFindUnique.mockRestore();
      }
    });
  });
});
