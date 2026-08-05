import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { errorHandler } from '../../middleware/errorHandler';
import { issueToken } from '../auth/auth.service';
import { fraudRouter } from './fraud.routes';
import { userIn } from '../../test-utils/tenants';

// The fraud router is mounted on a local app here rather than the shared
// `src/app.ts`, because wiring it into app.ts is out of this change's scope
// (parallel work owns app.ts). This mirrors exactly how app.ts will mount it.
const expressApp = express();
expressApp.use(express.json());
expressApp.use('/fraud', fraudRouter);
expressApp.use(errorHandler);
// Listening once, so supertest reuses this socket instead of binding a fresh
// ephemeral port per request — see src/testHttpServer.ts (#227).
const app = createServer(expressApp).listen(0);
app.unref();

// Outlet / check-in reference location.
const OUTLET_LAT = -26.2041;
const OUTLET_LNG = 28.0473;
// ~500m due south of the check-in — well past the 150m photo-divergence line.
const FAR_PHOTO_LAT = -26.2086;

// Anchored to the run day, NOT pinned to a calendar date.
//
// `GET /fraud/flagged` always bounds its scan, defaulting to the last
// DEFAULT_FRAUD_WINDOW_DAYS (#236). A fixture pinned to an absolute date
// therefore slides out of that window as the calendar moves, and the suite
// starts failing on a day nobody touched the code. That is exactly what
// happened: these were `2026-07-01` and `2026-07-05`, which sat inside the
// 30-day window when #236 landed on 2026-07-30 and fell outside it on
// 2026-08-04. `GET /fraud/flagged` then scanned nothing and returned [].
//
// Keep every date here relative to `now`, and keep the offsets well inside
// DEFAULT_FRAUD_WINDOW_DAYS. The demo seed anchors to its run day for the same
// reason.
const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (n: number): Date => new Date(Date.now() - n * DAY_MS);

const CLEAN_CHECKIN = daysAgo(6);
const SUS_CHECKIN = daysAgo(2);

describe('fraud routes', () => {
  let clientId: string;
  let clientBId: string;
  let agentId: string;
  let outletId: string;
  let managerToken: string;
  let agentToken: string;
  let cleanVisitId: string;
  let suspiciousVisitId: string;
  let clientBVisitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'FRAUD-Client-A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: {
        email: 'FRAUD-agent-a@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'FRAUD-Outlet-A',
        code: 'FRAUD-OUT-A',
        channelType: 'hypermarket',
        lat: OUTLET_LAT,
        lng: OUTLET_LNG,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;

    const sku = await prisma.sku.create({
      data: {
        clientId,
        name: 'FRAUD-SKU',
        category: 'beverages',
        minFacingsStandard: 4,
        rrp: 19.99,
      },
    });

    // Common stock-row payload (a "section row"); createdAt drives dwell time.
    const stockData = (visitId: string, createdAt: Date) => ({
      visitId,
      skuId: sku.id,
      unitsAvailable: 12,
      lastStockinDate: createdAt,
      daysOutOfStock: 0,
      velocityAvg: 1.5,
      coverageDaysPredicted: 8,
      salesActual: 100,
      salesTarget: 120,
      createdAt,
    });

    // ── Clean visit: near check-in, unhurried capture, photo on-site → score 0.
    const cleanVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: CLEAN_CHECKIN,
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 5,
        status: 'submitted',
      },
    });
    cleanVisitId = cleanVisit.id;
    await prisma.visitStock.create({
      // 10 minutes after check-in — a plausible dwell.
      data: stockData(cleanVisitId, new Date(CLEAN_CHECKIN.getTime() + 10 * 60 * 1000)),
    });
    await prisma.photo.create({
      data: {
        visitId: cleanVisitId,
        section: 'stock',
        url: 'https://example.test/clean.jpg',
        gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
        timestamp: CLEAN_CHECKIN,
      },
    });

    // ── Suspicious visit: fence edge, off-site photo, failed retries, 0s dwell.
    const suspiciousVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: SUS_CHECKIN,
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 45,
        status: 'submitted',
        // The DEVICE says the visit finished at the same instant it began — a
        // genuine 0s dwell, measured on one clock. Dwell used to be inferred
        // from the server's insert time, which measured the network, not the
        // agent (#101).
        submittedAtClient: SUS_CHECKIN,
      },
    });
    suspiciousVisitId = suspiciousVisit.id;
    await prisma.visitStock.create({
      // Same instant as check-in → ~0s dwell.
      data: stockData(suspiciousVisitId, SUS_CHECKIN),
    });
    await prisma.photo.create({
      data: {
        visitId: suspiciousVisitId,
        section: 'stock',
        url: 'https://example.test/suspicious.jpg',
        gpsTag: { lat: FAR_PHOTO_LAT, lng: OUTLET_LNG },
        timestamp: SUS_CHECKIN,
      },
    });

    // Two failed attempts (within 6h before the suspicious check-in) + one
    // passing attempt, all for the same (agent, outlet). Offsets are taken from
    // SUS_CHECKIN rather than restated as absolute dates, so the "within 6h"
    // relationship the failed_attempts signal keys on survives the anchor
    // moving with the run day.
    const beforeSus = (ms: number): Date => new Date(SUS_CHECKIN.getTime() - ms);
    await prisma.checkInAttempt.createMany({
      data: [
        {
          clientId,
          outletId,
          agentId,
          lat: OUTLET_LAT,
          lng: OUTLET_LNG,
          distanceM: 120,
          passed: false,
          createdAt: beforeSus(60 * 60 * 1000),
        },
        {
          clientId,
          outletId,
          agentId,
          lat: OUTLET_LAT,
          lng: OUTLET_LNG,
          distanceM: 80,
          passed: false,
          createdAt: beforeSus(30 * 60 * 1000),
        },
        {
          clientId,
          outletId,
          agentId,
          lat: OUTLET_LAT,
          lng: OUTLET_LNG,
          distanceM: 20,
          passed: true,
          createdAt: beforeSus(15 * 60 * 1000),
        },
      ],
    });

    // A second tenant whose visit must 404 for client A's manager.
    const clientB = await prisma.client.create({
      data: { name: 'FRAUD-Client-B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientBId = clientB.id;
    const agentB = await prisma.user.create({
      data: {
        email: 'FRAUD-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: clientBId,
      },
    });
    const outletB = await prisma.outlet.create({
      data: {
        name: 'FRAUD-Outlet-B',
        code: 'FRAUD-OUT-B',
        channelType: 'hypermarket',
        lat: OUTLET_LAT,
        lng: OUTLET_LNG,
        territoryId: 'territory-1',
        clientId: clientBId,
      },
    });
    const clientBVisit = await prisma.visit.create({
      data: {
        outletId: outletB.id,
        agentId: agentB.id,
        clientId: clientBId,
        checkinTs: SUS_CHECKIN,
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 5,
        status: 'submitted',
      },
    });
    clientBVisitId = clientBVisit.id;
  });

  afterAll(async () => {
    for (const cid of [clientId, clientBId]) {
      await prisma.checkInAttempt.deleteMany({ where: { clientId: cid } });
      await prisma.photo.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visitStock.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visit.deleteMany({ where: { clientId: cid } });
      await prisma.sku.deleteMany({ where: { clientId: cid } });
      await prisma.outlet.deleteMany({ where: { clientId: cid } });
      await prisma.user.deleteMany({ where: { clientId: cid } });
      await prisma.client.delete({ where: { id: cid } });
    }
    await prisma.$disconnect();
  });

  describe('GET /fraud/visits/:visitId', () => {
    it('scores a clean submitted visit at or near zero risk', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${cleanVisitId}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.visitId).toBe(cleanVisitId);
      expect(res.body.riskScore).toBe(0);
      expect(res.body.signals).toEqual([]);
    });

    it('flags a suspicious visit with multiple signals and a high risk score', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${suspiciousVisitId}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      const codes = res.body.signals.map((s: { code: string }) => s.code);
      expect(codes).toEqual(
        expect.arrayContaining([
          'geofence_distance',
          'failed_attempts',
          'photo_gps_divergence',
          'fast_completion',
        ]),
      );
      // 20 + 20 (2 failures) + 25 + 20 = 85.
      expect(res.body.riskScore).toBe(85);
      expect(res.body.riskScore).toBeGreaterThanOrEqual(50);
    });

    it('returns 404 for a visit belonging to another tenant', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${clientBVisitId}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(404);
    });

    it('forbids a field agent with 403', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${suspiciousVisitId}`)
        .set('Authorization', `Bearer ${agentToken}`);

      expect(res.status).toBe(403);
    });

    it('rejects an unauthenticated request with 401', async () => {
      const res = await request(app).get(`/fraud/visits/${suspiciousVisitId}`);
      expect(res.status).toBe(401);
    });
  });

  describe('GET /fraud/attempts', () => {
    it('returns the seeded attempts for the tenant, newest first', async () => {
      const res = await request(app)
        .get('/fraud/attempts')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(3);
      expect(res.body.data.every((a: { clientId: string }) => a.clientId === clientId)).toBe(true);
      const times = res.body.data.map((a: { createdAt: string }) => new Date(a.createdAt).getTime());
      expect(times).toEqual([...times].sort((x, y) => y - x));
    });

    it('filters by passed=false', async () => {
      const res = await request(app)
        .get('/fraud/attempts?passed=false')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(2);
      expect(res.body.data.every((a: { passed: boolean }) => a.passed === false)).toBe(true);
    });

    it('filters by passed=true', async () => {
      const res = await request(app)
        .get('/fraud/attempts?passed=true')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].passed).toBe(true);
    });

    it('returns an envelope, caps at limit and pages on without repeating', async () => {
      const first = await request(app)
        .get('/fraud/attempts?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/fraud/attempts?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((a: { id: string }) => a.id);
      const secondIds = second.body.data.map((a: { id: string }) => a.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/fraud/attempts?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(400);
    });

    it('forbids a field agent with 403', async () => {
      const res = await request(app)
        .get('/fraud/attempts')
        .set('Authorization', `Bearer ${agentToken}`);
      expect(res.status).toBe(403);
    });

    it('rejects an unauthenticated request with 401', async () => {
      const res = await request(app).get('/fraud/attempts');
      expect(res.status).toBe(401);
    });
  });

  describe('GET /fraud/flagged', () => {
    it('bounds the scan and says so, rather than silently truncating (#236)', async () => {
      // The endpoint scores visits in memory, so it cannot key a cursor on the
      // result. What it CAN do is refuse to scan without limit — and admit it
      // when the limit bit. A flagged list that quietly stops short is worse
      // than one that says it stopped: a manager who cannot see a suspicious
      // visit concludes there wasn't one.
      const res = await request(app)
        .get('/fraud/flagged')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('scanned');
      expect(res.body).toHaveProperty('truncated');
      expect(res.body.truncated).toBe(false);
    });

    it('rejects a scan window that is not a date with 400', async () => {
      const res = await request(app)
        .get('/fraud/flagged?from=not-a-date')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(400);
    });

    it('honours an explicit from/to window', async () => {
      // A window in the distant past must find nothing, proving the window is
      // applied to the scan rather than ignored.
      const res = await request(app)
        .get('/fraud/flagged?from=2020-01-01T00:00:00.000Z&to=2020-01-02T00:00:00.000Z')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(0);
      expect(res.body.scanned).toBe(0);
    });

    it('returns the suspicious visit and excludes the clean one', async () => {
      const res = await request(app)
        .get('/fraud/flagged')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      const ids = res.body.data.map((v: { visitId: string }) => v.visitId);
      expect(ids).toContain(suspiciousVisitId);
      expect(ids).not.toContain(cleanVisitId);
      const flagged = res.body.data.find((v: { visitId: string }) => v.visitId === suspiciousVisitId);
      expect(flagged.riskScore).toBe(85);
      expect(flagged.outletId).toBe(outletId);
      expect(flagged.agentId).toBe(agentId);
    });

    it('honours a custom minScore that excludes every visit', async () => {
      const res = await request(app)
        .get('/fraud/flagged?minScore=90')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      const ids = res.body.data.map((v: { visitId: string }) => v.visitId);
      expect(ids).not.toContain(suspiciousVisitId);
    });

    it('rejects a non-numeric minScore with 400', async () => {
      const res = await request(app)
        .get('/fraud/flagged?minScore=abc')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });

    it('forbids a field agent with 403', async () => {
      const res = await request(app)
        .get('/fraud/flagged')
        .set('Authorization', `Bearer ${agentToken}`);
      expect(res.status).toBe(403);
    });

    it('rejects an unauthenticated request with 401', async () => {
      const res = await request(app).get('/fraud/flagged');
      expect(res.status).toBe(401);
    });
  });
});
