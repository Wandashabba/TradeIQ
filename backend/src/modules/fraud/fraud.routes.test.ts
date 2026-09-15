import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { errorHandler } from '../../middleware/errorHandler';
import { issueToken } from '../auth/auth.service';
import { fraudRouter } from './fraud.routes';
import { rescoreFraudScores } from './fraudRescore';
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
// `GET /fraud/flagged` defaults to a window of the last
// DEFAULT_FRAUD_WINDOW_DAYS (#236). A fixture pinned to an absolute date
// therefore slides out of that window as the calendar moves, and the suite
// starts failing on a day nobody touched the code. That is exactly what
// happened: these were `2026-07-01` and `2026-07-05`, which sat inside the
// 30-day window when the window landed on 2026-07-30 and fell outside it on
// 2026-08-04. `GET /fraud/flagged` then found nothing and returned [].
//
// Keep every date here relative to `now`, and keep the offsets well inside
// DEFAULT_FRAUD_WINDOW_DAYS. The demo seed anchors to its run day for the same
// reason.
const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (n: number): Date => new Date(Date.now() - n * DAY_MS);

const CLEAN_CHECKIN = daysAgo(6);
const SUS_CHECKIN = daysAgo(2);
const SLOW_CHECKIN = daysAgo(4);
const TIMELINE_CHECKIN = daysAgo(3);

describe('fraud routes', () => {
  let clientId: string;
  let clientBId: string;
  let agentId: string;
  let outletId: string;
  let managerToken: string;
  let agentToken: string;
  let cleanVisitId: string;
  let suspiciousVisitId: string;
  let slowVisitId: string;
  let timelineVisitId: string;
  // #245 fixtures: one outlet's repeat visit, the run-of-two before it, a draft.
  type RepeatOutlet = { outletId: string; runOfTwoId: string; repeatId: string; draftId: string };
  let repeatOutlet: RepeatOutlet;
  let repeatOutlet2: RepeatOutlet;
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

    // Common stock-row payload (a "section row"). Each outlet-A visit below
    // takes its own count: they share one outlet and SKU, so identical counts
    // across three of them would be a repeating_stock_counts run (#245) and
    // leak into scores these tests pin for other reasons.
    const stockData = (visitId: string, createdAt: Date, unitsAvailable = 12) => ({
      visitId,
      skuId: sku.id,
      unitsAvailable,
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
      data: stockData(suspiciousVisitId, SUS_CHECKIN, 4),
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

    // ── Slow visit (#247): clean on every other count, but the DEVICE says it
    // took 90 minutes from check-in to submit — over the default 48-minute band.
    const slowVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: SLOW_CHECKIN,
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 5,
        status: 'submitted',
        submittedAtClient: new Date(SLOW_CHECKIN.getTime() + 90 * 60 * 1000),
      },
    });
    slowVisitId = slowVisit.id;
    await prisma.visitStock.create({
      data: stockData(slowVisitId, new Date(SLOW_CHECKIN.getTime() + 10 * 60 * 1000), 9),
    });

    // ── Capture-timeline visit (#246): a 20-minute visit on the device clock,
    // one shelf photo taken during it, one taken 270 minutes after submit, and a
    // task-closure photo attached a day later (which must not count).
    const timelineAt = (minutes: number): Date =>
      new Date(TIMELINE_CHECKIN.getTime() + minutes * 60 * 1000);
    const timelineVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: TIMELINE_CHECKIN,
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 5,
        status: 'submitted',
        submittedAtClient: timelineAt(20),
      },
    });
    timelineVisitId = timelineVisit.id;
    await prisma.visitStock.create({
      // The server row landed hours later (an offline sync) — irrelevant here.
      data: stockData(timelineVisitId, timelineAt(6 * 60), 7),
    });
    await prisma.photo.createMany({
      data: [
        {
          visitId: timelineVisitId,
          section: 'stock',
          url: 'https://example.test/timeline-in.jpg',
          gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
          timestamp: timelineAt(10),
        },
        {
          visitId: timelineVisitId,
          section: 'visibility',
          url: 'https://example.test/timeline-late.jpg',
          gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
          timestamp: timelineAt(20 + 270),
        },
        {
          visitId: timelineVisitId,
          section: 'task_closure',
          url: 'https://example.test/timeline-closure.jpg',
          gpsTag: {},
          timestamp: timelineAt(24 * 60),
        },
      ],
    });

    // ── Repeating stock counts (#245). Two outlets with the same shape, so the
    // flagged scan has more than one outlet's history to load (the N+1 test).
    //
    // Per outlet, newest last:
    //   start-21d  A=15 B=9   no velocity yet
    //   start-14d  A=10 B=6
    //   start- 7d  A=6  B=3   first row of the run: velocity A 1.0, B 0.5/day
    //   start- 5d  (submitted, no stock — skipped, not a break)
    //   start- 3d  A=6  B=3   a run of 2: silent
    //   start      A=6  B=3   a run of 3 across 7 days: A should have sold ~7,
    //                         B ~3.5 → the whole basket, weight 15
    //   start+ 3d  A=6  B=3   a DRAFT: never history, never scored
    //
    // Stock rows are stamped with a server createdAt in REVERSE order (a week's
    // outbox flushed newest-first): the run must follow device checkinTs.
    const repeatSkuA = await prisma.sku.create({
      data: { clientId, name: 'FRAUD-REPEAT-SKU-A', category: 'beverages', minFacingsStandard: 4, rrp: 9.99 },
    });
    const repeatSkuB = await prisma.sku.create({
      data: { clientId, name: 'FRAUD-REPEAT-SKU-B', category: 'snacks', minFacingsStandard: 2, rrp: 4.99 },
    });
    const seedRepeatOutlet = async (code: string, startDaysAgo: number) => {
      const outlet = await prisma.outlet.create({
        data: {
          name: `FRAUD-${code}`,
          code: `FRAUD-${code}`,
          channelType: 'spaza',
          lat: OUTLET_LAT,
          lng: OUTLET_LNG,
          territoryId: 'territory-1',
          clientId,
        },
      });
      const at = (offsetDays: number) => daysAgo(startDaysAgo - offsetDays);
      const syncedAt = new Date();
      const plan: Array<{
        offsetDays: number;
        status: 'submitted' | 'in_progress';
        counts: Array<[string, number, number]>;
      }> = [
        { offsetDays: -21, status: 'submitted', counts: [[repeatSkuA.id, 15, 0], [repeatSkuB.id, 9, 0]] },
        { offsetDays: -14, status: 'submitted', counts: [[repeatSkuA.id, 10, 0.7], [repeatSkuB.id, 6, 0.4]] },
        { offsetDays: -7, status: 'submitted', counts: [[repeatSkuA.id, 6, 1.0], [repeatSkuB.id, 3, 0.5]] },
        { offsetDays: -5, status: 'submitted', counts: [] },
        { offsetDays: -3, status: 'submitted', counts: [[repeatSkuA.id, 6, 0.4], [repeatSkuB.id, 3, 0.2]] },
        { offsetDays: 0, status: 'submitted', counts: [[repeatSkuA.id, 6, 0.1], [repeatSkuB.id, 3, 0.1]] },
        { offsetDays: 3, status: 'in_progress', counts: [[repeatSkuA.id, 6, 0.1], [repeatSkuB.id, 3, 0.1]] },
      ];
      const ids: string[] = [];
      for (const [i, step] of plan.entries()) {
        const v = await prisma.visit.create({
          data: {
            outletId: outlet.id,
            agentId,
            clientId,
            checkinTs: at(step.offsetDays),
            checkinLat: OUTLET_LAT,
            checkinLng: OUTLET_LNG,
            geofencePass: true,
            checkinDistanceM: 5,
            status: step.status,
          },
        });
        ids.push(v.id);
        for (const [skuId, unitsAvailable, velocityAvg] of step.counts) {
          await prisma.visitStock.create({
            data: {
              visitId: v.id,
              skuId,
              unitsAvailable,
              lastStockinDate: at(step.offsetDays),
              daysOutOfStock: 0,
              velocityAvg,
              coverageDaysPredicted: 8,
              createdAt: new Date(syncedAt.getTime() - i * 60_000),
            },
          });
        }
      }
      return { outletId: outlet.id, runOfTwoId: ids[4], repeatId: ids[5], draftId: ids[6] };
    };
    repeatOutlet = await seedRepeatOutlet('REPEAT-1', 8);
    repeatOutlet2 = await seedRepeatOutlet('REPEAT-2', 9);

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

    // The fixtures are written straight to the table, never through submit, so
    // nothing has a stored score yet. GET /fraud/flagged reads only the stored
    // column (#236): score client A the way a backfill would.
    await rescoreFraudScores({ clientId });
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

    it('reports a slow visit as slow_completion, at a weight that cannot flag it alone', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${slowVisitId}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.signals.map((s: { code: string }) => s.code)).toEqual(['slow_completion']);
      expect(res.body.riskScore).toBe(10);
    });

    it("applies the tenant's own kpiThresholds dwell band, read from the database", async () => {
      // Loosen client A's band past the 90-minute visit: the signal must go
      // quiet, proving the route reads the stored column under the key the
      // engine actually reads (#97), not just the built-in default.
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { slowCompletionMinutes: 120 } },
      });
      try {
        const res = await request(app)
          .get(`/fraud/visits/${slowVisitId}`)
          .set('Authorization', `Bearer ${managerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.signals).toEqual([]);
        expect(res.body.riskScore).toBe(0);
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
      }
    });

    it('reports a photo taken outside the device visit window as capture_timeline_gap', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${timelineVisitId}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      // The route must load each photo's device timestamp and section; the
      // task-closure photo a day later is excluded, so the worst gap is 270 min.
      expect(res.body.signals).toEqual([
        {
          code: 'capture_timeline_gap',
          detail:
            '1 photo(s) taken outside the visit; the furthest was 270 min after submit ' +
            '(device clock), beyond the 15 min tolerance',
          weight: 15,
        },
      ]);
      expect(res.body.riskScore).toBe(15);
    });

    it("applies the tenant's own capture-timeline tolerance, read from the database", async () => {
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { captureTimelineToleranceMinutes: 300 } },
      });
      try {
        const res = await request(app)
          .get(`/fraud/visits/${timelineVisitId}`)
          .set('Authorization', `Bearer ${managerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.signals).toEqual([]);
        expect(res.body.riskScore).toBe(0);
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
      }
    });

    it('reports a basket copied across three visits as repeating_stock_counts (#245)', async () => {
      const res = await request(app)
        .get(`/fraud/visits/${repeatOutlet.repeatId}`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      // The route must load earlier SUBMITTED stock visits to the outlet in device
      // check-in order (the server rows were synced in reverse), skip the
      // no-stock visit, and read the run's first-row velocity.
      expect(res.body.signals).toEqual([
        {
          code: 'repeating_stock_counts',
          detail:
            'Whole basket unchanged: all 2 SKU counts identical across the last 3 submitted ' +
            'visits to this outlet, 2 of them selling fast enough by their own velocity that the ' +
            'count should have moved (longest run 3 visits, by device check-in)',
          weight: 15,
        },
      ]);
      expect(res.body.riskScore).toBe(15);
    });

    it('is silent on a run of two, and on a draft with the same counts', async () => {
      for (const id of [repeatOutlet.runOfTwoId, repeatOutlet.draftId]) {
        const res = await request(app)
          .get(`/fraud/visits/${id}`)
          .set('Authorization', `Bearer ${managerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.signals).toEqual([]);
        expect(res.body.riskScore).toBe(0);
      }
    });

    it("applies the tenant's own repeatingStockRunLength, read from the database", async () => {
      await prisma.client.update({
        where: { id: clientId },
        data: { kpiThresholds: { repeatingStockRunLength: 4 } },
      });
      try {
        const res = await request(app)
          .get(`/fraud/visits/${repeatOutlet.repeatId}`)
          .set('Authorization', `Bearer ${managerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.signals).toEqual([]);
        expect(res.body.riskScore).toBe(0);
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
      }
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
    type Row = { visitId: string; riskScore: number; signals: Array<{ code: string }>; scoredAt: string | null };
    const flagged = (query = '') =>
      request(app).get(`/fraud/flagged${query}`).set('Authorization', `Bearer ${managerToken}`);

    it('returns the standard page envelope, plus how many visits in the window are unscored (#236)', async () => {
      // The score is a stored column now, so the list pages like every other
      // one. The old {scanned, truncated} described an in-memory scan that no
      // longer happens; `nextCursor` is how a page says there is more.
      const res = await flagged();

      expect(res.status).toBe(200);
      expect(Object.keys(res.body).sort()).toEqual(['data', 'from', 'nextCursor', 'to', 'unscored']);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.nextCursor).toBeNull();
      expect(res.body.unscored).toBe(0);
    });

    it('rejects a window that is not a date with 400', async () => {
      const res = await flagged('?from=not-a-date');

      expect(res.status).toBe(400);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await flagged('?limit=0');

      expect(res.status).toBe(400);
    });

    it('honours an explicit from/to window', async () => {
      // A window in the distant past must find nothing, proving the window is
      // applied rather than ignored, and it reports the window it applied.
      const res = await flagged('?minScore=0&from=2020-01-01T00:00:00.000Z&to=2020-01-02T00:00:00.000Z');

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(0);
      expect(res.body.unscored).toBe(0);
      expect(res.body.from).toBe('2020-01-01T00:00:00.000Z');
      expect(res.body.to).toBe('2020-01-02T00:00:00.000Z');
    });

    it('returns the suspicious visit and excludes the clean one', async () => {
      const res = await request(app)
        .get('/fraud/flagged')
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      const ids = res.body.data.map((v: { visitId: string }) => v.visitId);
      expect(ids).toContain(suspiciousVisitId);
      expect(ids).not.toContain(cleanVisitId);
      // Slow on its own is corroboration, not a finding (#247).
      expect(ids).not.toContain(slowVisitId);
      // So is one photo out of the visit's window (#246).
      expect(ids).not.toContain(timelineVisitId);
      const row = res.body.data.find((v: { visitId: string }) => v.visitId === suspiciousVisitId);
      expect(row.riskScore).toBe(85);
      expect(row.outletId).toBe(outletId);
      expect(row.agentId).toBe(agentId);
      // The snapshot says when it was taken.
      expect(Number.isNaN(Date.parse(row.scoredAt))).toBe(false);
    });

    it('never flags a repeating basket alone, but lists it with the same signal as the visit endpoint', async () => {
      const byDefault = await flagged();
      expect(byDefault.status).toBe(200);
      const defaultIds = byDefault.body.data.map((v: { visitId: string }) => v.visitId);
      expect(defaultIds).not.toContain(repeatOutlet.repeatId);

      const [listed, single] = await Promise.all([
        flagged('?minScore=15'),
        request(app)
          .get(`/fraud/visits/${repeatOutlet.repeatId}`)
          .set('Authorization', `Bearer ${managerToken}`),
      ]);
      expect(listed.status).toBe(200);
      const row = listed.body.data.find((v: { visitId: string }) => v.visitId === repeatOutlet.repeatId);
      // Stored by the batched rescore, it must agree with the live per-visit route.
      expect(row).toBeDefined();
      expect(row.signals).toEqual(single.body.signals);
      expect(row.riskScore).toBe(15);
      const listedIds = listed.body.data.map((v: { visitId: string }) => v.visitId);
      expect(listedIds).not.toContain(repeatOutlet.runOfTwoId);
      expect(listedIds).not.toContain(repeatOutlet.draftId);
    });

    it('scores each visit against its own history, even when that history was in another batch', async () => {
      // One visit per batch: no repeat visit shares a batch with the copies before it.
      await rescoreFraudScores({ clientId, all: true, batchSize: 1 });

      const res = await flagged('?minScore=15');
      expect(res.status).toBe(200);
      const rows = res.body.data as Row[];
      const ids = rows.map((v) => v.visitId);
      expect(ids).toEqual(expect.arrayContaining([repeatOutlet.repeatId, repeatOutlet2.repeatId]));
      expect(ids).not.toContain(repeatOutlet.runOfTwoId);
      for (const id of [repeatOutlet.repeatId, repeatOutlet2.repeatId]) {
        const single = await request(app).get(`/fraud/visits/${id}`).set('Authorization', `Bearer ${managerToken}`);
        expect(rows.find((v) => v.visitId === id)!.signals).toEqual(single.body.signals);
      }
    });

    it('orders by stored score, highest first, and pages on the cursor without repeating or dropping a visit', async () => {
      // An explicit window: the oldest REPEAT-2 visit is checked in exactly
      // DEFAULT_FRAUD_WINDOW_DAYS ago, so the default window drops it by the
      // milliseconds between writing the fixture and reading it.
      const window = `&from=${daysAgo(60).toISOString()}`;
      const all = await flagged(`?minScore=0&limit=200${window}`);
      expect(all.status).toBe(200);
      const rows = all.body.data as Row[];
      // Every submitted visit of client A, scored: 4 + 6 per repeat outlet.
      expect(rows).toHaveLength(16);
      const scores = rows.map((v) => v.riskScore);
      expect(scores).toEqual([...scores].sort((a, b) => b - a));

      const paged: string[] = [];
      let cursor: string | null = null;
      for (let page = 0; page < 20; page += 1) {
        const res = await flagged(`?minScore=0&limit=3${window}${cursor ? `&cursor=${cursor}` : ''}`);
        expect(res.status).toBe(200);
        expect(res.body.data.length).toBeLessThanOrEqual(3);
        paged.push(...(res.body.data as Row[]).map((v) => v.visitId));
        cursor = res.body.nextCursor;
        if (!cursor) {
          break;
        }
      }
      expect(cursor).toBeNull();
      expect(paged).toEqual(rows.map((v) => v.visitId));
    });

    it('treats a fractional minScore as the next whole score', async () => {
      const res = await flagged('?minScore=84.5');

      expect(res.status).toBe(200);
      expect(res.body.data.map((v: Row) => v.visitId)).toEqual([suspiciousVisitId]);
    });

    it('excludes a visit without a stored score, and counts it as unscored in its window', async () => {
      await prisma.visit.update({
        where: { id: suspiciousVisitId },
        data: { riskScore: null, fraudSignals: Prisma.DbNull, fraudScoredAt: null },
      });
      try {
        const res = await flagged('?minScore=0&limit=200');
        expect(res.status).toBe(200);
        expect(res.body.data.map((v: Row) => v.visitId)).not.toContain(suspiciousVisitId);
        expect(res.body.unscored).toBe(1);

        // A window that does not contain it does not count it.
        const earlier = await flagged(`?minScore=0&to=${daysAgo(3).toISOString()}`);
        expect(earlier.body.unscored).toBe(0);
      } finally {
        await rescoreFraudScores({ clientId });
      }
    });

    it('reads the stored snapshot while the visit endpoint stays live, until the client rescores', async () => {
      // Loosen the slow band past the 90-minute visit: the live score drops to 0,
      // but the list still shows the score stored under the old band.
      await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: { slowCompletionMinutes: 120 } } });
      try {
        const live = await request(app).get(`/fraud/visits/${slowVisitId}`).set('Authorization', `Bearer ${managerToken}`);
        expect(live.body.riskScore).toBe(0);
        const stale = await flagged('?minScore=10');
        const staleRow = (stale.body.data as Row[]).find((v) => v.visitId === slowVisitId);
        expect(staleRow).toEqual(expect.objectContaining({ riskScore: 10 }));

        const rescored = await rescoreFraudScores({ clientId, all: true });
        expect(rescored.written).toBe(16);
        const fresh = await flagged('?minScore=10');
        expect(fresh.body.data.map((v: Row) => v.visitId)).not.toContain(slowVisitId);
        const stored = await prisma.visit.findUniqueOrThrow({
          where: { id: slowVisitId },
          select: { riskScore: true, fraudScoredAt: true },
        });
        expect(stored.riskScore).toBe(0);
        expect(stored.fraudScoredAt!.getTime()).toBeGreaterThan(Date.parse(staleRow!.scoredAt!));
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
        await rescoreFraudScores({ clientId, all: true });
      }
    });

    it('never scores on read: no history, photo, outlet or attempt lookups', async () => {
      const queryRaw = jest.spyOn(prisma, '$queryRaw');
      const attempts = jest.spyOn(prisma.checkInAttempt, 'findMany');
      try {
        const res = await flagged('?minScore=0');

        expect(res.status).toBe(200);
        expect(res.body.data.length).toBeGreaterThan(0);
        expect(queryRaw).not.toHaveBeenCalled();
        expect(attempts).not.toHaveBeenCalled();
      } finally {
        queryRaw.mockRestore();
        attempts.mockRestore();
      }
    });

    it('scores a whole batch with one stock-history query, however many outlets it covers (no N+1)', async () => {
      const queryRaw = jest.spyOn(prisma, '$queryRaw');
      try {
        const result = await rescoreFraudScores({ clientId, all: true });

        expect(result.scanned).toBe(16);
        // Three outlets and sixteen visits in one batch: exactly one history read.
        // (#248's outlet lookup also runs, once, for the geotagged photos.)
        const sqlOf = (call: unknown[]) => (call[0] as { sql: string }).sql;
        expect(queryRaw.mock.calls.filter((call) => sqlOf(call).includes('visit_stock'))).toHaveLength(1);
        expect(queryRaw.mock.calls.filter((call) => sqlOf(call).includes('lat_min'))).toHaveLength(1);
        expect(queryRaw).toHaveBeenCalledTimes(2);
      } finally {
        queryRaw.mockRestore();
      }
    });

    it('honours a custom minScore that excludes every visit', async () => {
      const res = await flagged('?minScore=90');

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
