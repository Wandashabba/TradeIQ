import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { reencodedCopy, shelfJpeg, toDataUrl } from '../../test-utils/shelfImage';
import { TestUser, userIn } from '../../test-utils/tenants';
import { perceptualHashBands } from '../photos/photoHash';

/**
 * #244 end to end: photos go in through POST /photos (which hashes them), and
 * come out as duplicate_photo on GET /fraud/visits/:id and GET /fraud/flagged.
 * The pure weighting is pinned in fraud.duplicate.test.ts; this suite pins what
 * only the database can: the hash lookup, its tenant scope, its exclusions, and
 * that the flagged scan does it in one query.
 */
const OUTLET_LAT = -26.2041;
const OUTLET_LNG = 28.0473;
const DAY_MS = 24 * 60 * 60 * 1000;
// Relative to the run day, inside the flagged scan's default 30-day window.
const daysAgo = (n: number): Date => new Date(Date.now() - n * DAY_MS);

type Signal = { code: string; detail: string; weight: number };

describe('duplicate_photo routes (#244)', () => {
  let clientId: string;
  let otherClientId: string;
  let agent: TestUser;
  let manager: TestUser;
  let otherAgent: TestUser;
  let otherManager: TestUser;
  const visits: Record<string, string> = {};

  const createOutlet = async (cid: string, code: string) =>
    (
      await prisma.outlet.create({
        data: {
          name: `DUP-${code}`,
          code: `DUP-${code}`,
          channelType: 'spaza',
          lat: OUTLET_LAT,
          lng: OUTLET_LNG,
          territoryId: 'territory-1',
          clientId: cid,
        },
      })
    ).id;

  // Clean on every other signal: inside the fence, no device submit time, no
  // stock, and one captured section so no_capture stays quiet.
  const createVisit = async (who: TestUser, outletId: string, days: number) => {
    const visit = await prisma.visit.create({
      data: {
        outletId,
        agentId: who.userId,
        clientId: who.clientId,
        checkinTs: daysAgo(days),
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 5,
        status: 'submitted',
      },
    });
    await prisma.visitCapability.create({
      data: { visitId: visit.id, staffHeadcountConfirmed: 2, repTrainingStatus: {}, quizScore: 80 },
    });
    return visit.id;
  };

  const upload = async (who: TestUser, visitId: string, bytes: Buffer, section = 'visibility') => {
    const res = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${who.token}`)
      .send({
        visitId,
        section,
        dataUrl: toDataUrl(bytes),
        gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
        timestamp: new Date().toISOString(),
      });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };

  // A pre-#244 row: written straight to the table, never hashed.
  const insertUnhashed = (visitId: string, bytes: Buffer) =>
    prisma.photo.create({
      data: {
        visitId,
        section: 'visibility',
        url: toDataUrl(bytes),
        gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
        timestamp: new Date(),
      },
    });

  const fraudFor = async (visitId: string, who: TestUser = manager) => {
    const res = await request(app).get(`/fraud/visits/${visitId}`).set('Authorization', `Bearer ${who.token}`);
    expect(res.status).toBe(200);
    return res.body as { riskScore: number; signals: Signal[] };
  };
  const duplicateOf = async (visitId: string, who?: TestUser) =>
    (await fraudFor(visitId, who)).signals.find((s) => s.code === 'duplicate_photo');

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DUP-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const otherClient = await prisma.client.create({
      data: { name: 'DUP-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    otherAgent = await userIn(otherClientId, 'field_agent');
    otherManager = await userIn(otherClientId, 'manager');

    const o1 = await createOutlet(clientId, 'O1');
    const o2 = await createOutlet(clientId, 'O2');
    const o3 = await createOutlet(clientId, 'O3');
    const otherOutlet = await createOutlet(otherClientId, 'OTHER');

    const [imageA, imageB, imageC, imageD, imageE, imageF, unrelated] = await Promise.all(
      [31, 32, 33, 34, 35, 36, 37].map((seed) => shelfJpeg(seed)),
    );

    // Same file, another outlet → strong, and only on the later use.
    visits.aFirst = await createVisit(agent, o1, 10);
    await upload(agent, visits.aFirst, imageA);
    visits.aCross = await createVisit(agent, o2, 5);
    await upload(agent, visits.aCross, imageA);

    // Same file, an earlier visit to the same outlet → weak.
    visits.bFirst = await createVisit(agent, o1, 12);
    await upload(agent, visits.bFirst, imageB);
    visits.bSame = await createVisit(agent, o1, 6);
    await upload(agent, visits.bSame, imageB);

    // A re-encoded, resized copy at another outlet → near-duplicate.
    visits.cFirst = await createVisit(agent, o1, 11);
    await upload(agent, visits.cFirst, imageC);
    visits.cReencoded = await createVisit(agent, o3, 4);
    await upload(agent, visits.cReencoded, await reencodedCopy(imageC));

    // An unrelated frame → silent.
    visits.unrelated = await createVisit(agent, o2, 3);
    await upload(agent, visits.unrelated, unrelated);

    // Task closure on this side: image A again, but as closure evidence → silent.
    visits.closureOnly = await createVisit(agent, o3, 2);
    await upload(agent, visits.closureOnly, imageA, 'task_closure');
    // Task closure on the other side: the earlier copy of D is closure evidence.
    visits.dClosure = await createVisit(agent, o2, 9);
    await upload(agent, visits.dClosure, imageD, 'task_closure');
    visits.dLater = await createVisit(agent, o3, 8);
    await upload(agent, visits.dLater, imageD);

    // No hash on the earlier copy (not backfilled) → the later upload is silent.
    visits.eUnhashedFirst = await createVisit(agent, o1, 13);
    await insertUnhashed(visits.eUnhashedFirst, imageE);
    visits.eLater = await createVisit(agent, o2, 7);
    await upload(agent, visits.eLater, imageE);
    // No hash on this side: an unhashed copy of A → silent.
    visits.aUnhashedLater = await createVisit(agent, o3, 1);
    await insertUnhashed(visits.aUnhashedLater, imageA);

    // Tenant isolation, both directions: F exists only in the other tenant
    // before this tenant uploads it, and the other tenant later uploads A.
    visits.otherTenantF = await createVisit(otherAgent, otherOutlet, 20);
    await upload(otherAgent, visits.otherTenantF, imageF);
    visits.fHere = await createVisit(agent, o2, 3.5);
    await upload(agent, visits.fHere, imageF);
    visits.otherTenantA = await createVisit(otherAgent, otherOutlet, 1.5);
    await upload(otherAgent, visits.otherTenantA, imageA);

    // Hand-set hashes exactly 5 dHash bits apart, and not byte-identical. A real
    // re-encoded copy can hash identically (0 bits), which gives a per-tenant
    // threshold nothing to cut; this pair pins the SQL distance to the bit.
    // Bands differ by 1, 1, 2 and 1 bits, so the one-bit-neighbour probe finds it.
    const nearBase = '00ff00ff00ff00ff';
    const nearFiveBits = '00fe00fe00fc00fe';
    for (const g of [
      { key: 'gFirst', outletId: o1, days: 14, contentHash: 'g-first-content', perceptualHash: nearBase },
      { key: 'gNear', outletId: o2, days: 0.5, contentHash: 'g-near-content', perceptualHash: nearFiveBits },
    ]) {
      visits[g.key] = await createVisit(agent, g.outletId, g.days);
      await prisma.photo.create({
        data: {
          visitId: visits[g.key],
          section: 'visibility',
          url: 'https://example.test/near.jpg',
          gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
          timestamp: new Date(),
          contentHash: g.contentHash,
          perceptualHash: g.perceptualHash,
          perceptualHashBands: perceptualHashBands(g.perceptualHash),
        },
      });
    }
  });

  afterAll(async () => {
    for (const cid of [clientId, otherClientId]) {
      await prisma.photo.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visitCapability.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visit.deleteMany({ where: { clientId: cid } });
      await prisma.outlet.deleteMany({ where: { clientId: cid } });
      await prisma.user.deleteMany({ where: { clientId: cid } });
      await prisma.client.delete({ where: { id: cid } });
    }
    await prisma.$disconnect();
  });

  describe('GET /fraud/visits/:visitId', () => {
    it('scores the same image at another outlet as the strong signal, and leaves its first use alone', async () => {
      const result = await fraudFor(visits.aCross);
      expect(result.signals).toEqual([
        expect.objectContaining({ code: 'duplicate_photo', weight: 35 }),
      ]);
      expect(result.riskScore).toBe(35);
      expect(result.signals[0].detail).toContain('byte-identical to a photo from a visit to a different outlet');
      expect(result.signals[0].detail).toContain(daysAgo(10).toISOString().slice(0, 10));

      expect((await fraudFor(visits.aFirst)).signals).toEqual([]);
    });

    it('scores the same image from an earlier visit to the same outlet as the weaker signal', async () => {
      const signal = await duplicateOf(visits.bSame);
      expect(signal).toEqual(expect.objectContaining({ weight: 15 }));
      expect(signal!.detail).toContain('byte-identical to a photo from a visit to this outlet');
      expect(await duplicateOf(visits.bFirst)).toBeUndefined();
    });

    it('detects a re-encoded, resized copy as a near-duplicate', async () => {
      const signal = await duplicateOf(visits.cReencoded);
      expect(signal).toEqual(expect.objectContaining({ weight: 25 }));
      expect(signal!.detail).toMatch(/near-duplicate \(\d of 64 bits differ, threshold 6\)/);

      // It was never byte-identical: only the perceptual hash could see it.
      const [original, copy] = await Promise.all(
        [visits.cFirst, visits.cReencoded].map((visitId) =>
          prisma.photo.findFirstOrThrow({ where: { visitId }, select: { contentHash: true } }),
        ),
      );
      expect(copy.contentHash).not.toBe(original.contentHash);
    });

    it('is silent for an unrelated image', async () => {
      expect((await fraudFor(visits.unrelated)).signals).toEqual([]);
    });

    it('excludes task-closure photos, on either side of the match', async () => {
      expect((await fraudFor(visits.closureOnly)).signals).toEqual([]);
      expect((await fraudFor(visits.dLater)).signals).toEqual([]);
    });

    it('ignores photos without a hash, on either side of the match', async () => {
      expect((await fraudFor(visits.eLater)).signals).toEqual([]);
      expect((await fraudFor(visits.aUnhashedLater)).signals).toEqual([]);
    });

    it("never matches another tenant's identical photo", async () => {
      expect((await fraudFor(visits.fHere)).signals).toEqual([]);
      expect((await fraudFor(visits.otherTenantA, otherManager)).signals).toEqual([]);
      const crossTenant = await request(app)
        .get(`/fraud/visits/${visits.otherTenantA}`)
        .set('Authorization', `Bearer ${manager.token}`);
      expect(crossTenant.status).toBe(404);
    });

    it("applies the tenant's own near-duplicate threshold, read from the database", async () => {
      // Default 6: five bits apart is a near-duplicate, and the distance measured
      // in SQL is the exact bit count.
      const byDefault = await duplicateOf(visits.gNear);
      expect(byDefault).toEqual(expect.objectContaining({ weight: 25 }));
      expect(byDefault!.detail).toContain('near-duplicate (5 of 64 bits differ, threshold 6)');
      expect(await duplicateOf(visits.gFirst)).toBeUndefined();

      const setThreshold = (bits: number) =>
        prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: { duplicatePhotoMaxDistance: bits } } });
      try {
        await setThreshold(4);
        expect(await duplicateOf(visits.gNear)).toBeUndefined();
        await setThreshold(5);
        expect(await duplicateOf(visits.gNear)).toEqual(expect.objectContaining({ weight: 25 }));
        // Byte-identical reuse is untouched by even the tightest threshold.
        await setThreshold(0);
        expect(await duplicateOf(visits.aCross)).toEqual(expect.objectContaining({ weight: 35 }));
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
      }
    });
  });

  describe('GET /fraud/flagged', () => {
    it('never flags reuse alone, but lists it with the same signals as the visit endpoint', async () => {
      const byDefault = await request(app).get('/fraud/flagged').set('Authorization', `Bearer ${manager.token}`);
      expect(byDefault.status).toBe(200);
      expect(byDefault.body.data).toEqual([]);

      const listed = await request(app).get('/fraud/flagged?minScore=1').set('Authorization', `Bearer ${manager.token}`);
      expect(listed.status).toBe(200);
      const rows = listed.body.data as Array<{ visitId: string; riskScore: number; signals: Signal[] }>;
      expect(rows.map((r) => r.visitId).sort()).toEqual(
        [visits.aCross, visits.bSame, visits.cReencoded, visits.gNear].sort(),
      );
      expect(rows.map((r) => r.riskScore)).toEqual([35, 25, 25, 15]);
      for (const row of rows) {
        expect(row.signals).toEqual((await fraudFor(row.visitId)).signals);
      }
    });

    it('looks every scanned photo up in one query, however many visits and outlets (no N+1)', async () => {
      const queryRaw = jest.spyOn(prisma, '$queryRaw');
      const photoFindMany = jest.spyOn(prisma.photo, 'findMany');
      const photoFindFirst = jest.spyOn(prisma.photo, 'findFirst');
      try {
        const res = await request(app)
          .get('/fraud/flagged?minScore=1')
          .set('Authorization', `Bearer ${manager.token}`);
        expect(res.status).toBe(200);
        expect(res.body.scanned).toBe(16);
        expect(res.body.data).toHaveLength(4);

        const sqlOf = (call: unknown[]) => (call[0] as { sql: string }).sql;
        const photoLookups = queryRaw.mock.calls.filter((call) => sqlOf(call).includes('perceptual_hash_bands'));
        // One photo lookup for 16 visits across 3 outlets, plus #245's one stock
        // history read, and no per-photo or per-visit query of any kind.
        expect(photoLookups).toHaveLength(1);
        expect(queryRaw).toHaveBeenCalledTimes(2);
        expect(photoFindMany).not.toHaveBeenCalled();
        expect(photoFindFirst).not.toHaveBeenCalled();
      } finally {
        queryRaw.mockRestore();
        photoFindMany.mockRestore();
        photoFindFirst.mockRestore();
      }
    });
  });
});
