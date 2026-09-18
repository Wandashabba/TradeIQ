import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';

/**
 * #392 / #395 end to end: the manager's ruling on a flagged visit, the lock
 * that makes it a ruling rather than a note, and what the open queue does once
 * a visit has been ruled on.
 *
 * The two properties this suite exists to hold:
 *
 *   1. **A visit is ruled once.** The second POST does not overwrite the first
 *      manager's decision — it loses at the unique index and is told whose
 *      verdict stands. An upsert would pass every other test in this file while
 *      silently destroying the thing the row exists to record.
 *   2. **A ruled visit leaves the open queue by default.** That is a change to
 *      what an unchanged `GET /fraud/flagged` returns, and it is pinned here so
 *      it cannot be reverted by accident.
 *
 * Scores are written onto the visits directly rather than computed: what the
 * engine scores is pinned by the other fraud suites, and what matters here is
 * only that a score is stored, absent, or moves afterwards.
 */
const OUTLET = { lat: -26.2041, lng: 28.0473 };
const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (n: number): Date => new Date(Date.now() - n * DAY_MS);

type VerdictBody = {
  visitId: string;
  verdict: string;
  reviewer: { id: string; label: string };
  note: string | null;
  riskScoreAtReview: number | null;
  decidedAt: string;
};

describe('fraud verdicts (#392, #395)', () => {
  let clientId: string;
  let agent: TestUser;
  /** No displayName — the personLabel fallback, which is the email (#280). */
  let manager: TestUser;
  /** Has a displayName, so the frozen `reviewerLabel` is a real name. */
  let namedManager: TestUser;
  let foreign: TestUser & { cleanup: () => Promise<void> };

  /** Score 80, ruled on by the tests below. */
  let ruledVisitId: string;
  /** Score 70, never ruled on: the visit that must stay in the open queue. */
  let openVisitId: string;
  /** No stored score: the `unscored` counter's fixture. */
  let unscoredVisitId: string;
  /** No stored score, and ruled on — riskScoreAtReview must be null, not 0. */
  let unscoredRuledVisitId: string;

  const rule = (visitId: string, token: string, body: Record<string, unknown>) =>
    request(app)
      .post(`/fraud/visits/${visitId}/verdict`)
      .set('Authorization', `Bearer ${token}`)
      .send(body);

  const flagged = (query = '', token = manager.token) =>
    request(app).get(`/fraud/flagged${query}`).set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'VERDICT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    agent = await userIn(clientId, 'field_agent');
    manager = await userIn(clientId, 'manager');
    namedManager = await userIn(clientId, 'manager', { displayName: 'Thandi Mokoena' });
    // A whole separate company. It authenticates perfectly well and must still
    // be told nothing about this tenant's visits.
    foreign = await foreignTenant('manager');

    const outlet = await prisma.outlet.create({
      data: {
        name: 'VERDICT-Outlet',
        code: 'VERDICT-OUT',
        channelType: 'spaza',
        ...OUTLET,
        territoryId: 'territory-1',
        clientId,
      },
    });

    const createVisit = async (days: number, riskScore: number | null) =>
      (
        await prisma.visit.create({
          data: {
            outletId: outlet.id,
            agentId: agent.userId,
            clientId,
            checkinTs: daysAgo(days),
            checkinLat: OUTLET.lat,
            checkinLng: OUTLET.lng,
            geofencePass: true,
            checkinDistanceM: 5,
            status: 'submitted',
            riskScore,
            ...(riskScore === null
              ? {}
              : { fraudSignals: [{ code: 'seeded', detail: 'seeded', weight: riskScore }], fraudScoredAt: new Date() }),
          },
        })
      ).id;

    ruledVisitId = await createVisit(2, 80);
    openVisitId = await createVisit(3, 70);
    unscoredVisitId = await createVisit(4, null);
    unscoredRuledVisitId = await createVisit(5, null);
  });

  afterAll(async () => {
    // Verdicts first: they hold a foreign key onto the visits below.
    await prisma.fraudVerdict.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  describe('POST /fraud/visits/:visitId/verdict', () => {
    it('rejects an unknown verdict with 400 and says which field failed', async () => {
      const res = await rule(openVisitId, manager.token, { verdict: 'maybe' });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('confirmed');
      expect(res.body.issues.join(' ')).toContain('verdict');
      expect(await prisma.fraudVerdict.count({ where: { visitId: openVisitId } })).toBe(0);
    });

    it('rejects an unrecognised field with 400 rather than ignoring it', async () => {
      // A body that could name the reviewer is a body that lets one manager file
      // a ruling under a colleague's name. `.strict()` says so out loud instead
      // of recording a decision the caller did not mean.
      const res = await rule(openVisitId, manager.token, {
        verdict: 'dismissed',
        reviewerId: namedManager.userId,
      });

      expect(res.status).toBe(400);
      expect(res.body.issues.join(' ')).toContain('reviewerId');
      expect(await prisma.fraudVerdict.count({ where: { visitId: openVisitId } })).toBe(0);
    });

    it("returns 404 for another tenant's visit, after authenticating that tenant", async () => {
      const res = await rule(ruledVisitId, foreign.token, { verdict: 'confirmed' });

      // 404, not 403 and emphatically not 401: a 401 would mean the scoping
      // logic was never reached, and a 403 would confirm the id exists.
      expect(res.status).toBe(404);
      expect(await prisma.fraudVerdict.count({ where: { visitId: ruledVisitId } })).toBe(0);

      // And the foreign manager's own token works elsewhere, so the 404 above
      // really was the tenant scope and not a broken session.
      const own = await request(app)
        .get('/fraud/verdicts')
        .set('Authorization', `Bearer ${foreign.token}`);
      expect(own.status).toBe(200);
    });

    it('returns 404 for a visit id that does not exist', async () => {
      const res = await rule('00000000-0000-4000-8000-000000000000', manager.token, {
        verdict: 'confirmed',
      });

      expect(res.status).toBe(404);
    });

    it('forbids a field agent with 403', async () => {
      const res = await rule(openVisitId, agent.token, { verdict: 'dismissed' });

      expect(res.status).toBe(403);
    });

    it('rejects an unauthenticated request with 401', async () => {
      const res = await request(app)
        .post(`/fraud/visits/${openVisitId}/verdict`)
        .send({ verdict: 'dismissed' });

      expect(res.status).toBe(401);
    });

    it('records the ruling with the reviewer from the token and the score they saw', async () => {
      const res = await rule(ruledVisitId, namedManager.token, {
        verdict: 'confirmed',
        note: '  Agent admitted the visit was not made  ',
      });

      expect(res.status).toBe(201);
      const body = res.body as VerdictBody;
      expect(body.visitId).toBe(ruledVisitId);
      expect(body.verdict).toBe('confirmed');
      // The reviewer is the caller, never anything the body could have said.
      expect(body.reviewer).toEqual({ id: namedManager.userId, label: 'Thandi Mokoena' });
      expect(body.note).toBe('Agent admitted the visit was not made');
      expect(body.riskScoreAtReview).toBe(80);
      expect(Number.isNaN(Date.parse(body.decidedAt))).toBe(false);
    });

    it('freezes the score the reviewer saw, even after a rescore moves it', async () => {
      // Visit.riskScore is a snapshot a rescore can move. Without the frozen
      // copy, a ruling read later looks as though it was made against a number
      // nobody ever saw.
      await prisma.visit.update({ where: { id: ruledVisitId }, data: { riskScore: 5 } });
      try {
        const stored = await prisma.fraudVerdict.findUniqueOrThrow({
          where: { visitId: ruledVisitId },
        });
        expect(stored.riskScoreAtReview).toBe(80);
      } finally {
        await prisma.visit.update({ where: { id: ruledVisitId }, data: { riskScore: 80 } });
      }
    });

    it('refuses a second ruling with 409 and hands back the verdict that stands', async () => {
      const res = await rule(ruledVisitId, manager.token, {
        verdict: 'dismissed',
        note: 'Looks fine to me',
      });

      expect(res.status).toBe(409);
      // The loser is told WHOSE ruling applies, so they cannot walk away
      // believing theirs took effect.
      expect(res.body.error).toContain('Thandi Mokoena');
      expect(res.body.verdict.verdict).toBe('confirmed');
      expect(res.body.verdict.reviewer.id).toBe(namedManager.userId);
    });

    it('leaves the first ruling untouched after the second is refused', async () => {
      // The row, not the response. An upsert would have passed the 409 test
      // above by answering from the second write; this is what it could not do.
      const rows = await prisma.fraudVerdict.findMany({ where: { visitId: ruledVisitId } });

      expect(rows).toHaveLength(1);
      expect(rows[0].verdict).toBe('confirmed');
      expect(rows[0].reviewerId).toBe(namedManager.userId);
      expect(rows[0].note).toBe('Agent admitted the visit was not made');
    });

    it('lets exactly one of two simultaneous rulings win, and tells the other', async () => {
      // Both requests miss the lookup; the unique index decides. A
      // SELECT-then-INSERT would let both through.
      const [a, b] = await Promise.all([
        rule(openVisitId, manager.token, { verdict: 'dismissed' }),
        rule(openVisitId, namedManager.token, { verdict: 'confirmed' }),
      ]);

      expect([a.status, b.status].sort()).toEqual([201, 409]);
      expect(await prisma.fraudVerdict.count({ where: { visitId: openVisitId } })).toBe(1);
      const loser = a.status === 409 ? a : b;
      const winner = a.status === 201 ? a : b;
      expect(loser.body.verdict).toEqual(winner.body);

      // openVisitId is the open queue's fixture below; put it back.
      await prisma.fraudVerdict.deleteMany({ where: { visitId: openVisitId } });
    });

    it('stores a blank note as null, never as an empty string', async () => {
      const res = await rule(unscoredRuledVisitId, manager.token, {
        verdict: 'inconclusive',
        note: '   ',
      });

      expect(res.status).toBe(201);
      expect(res.body.note).toBeNull();
    });

    it('records a null riskScoreAtReview for an unscored visit, never 0', async () => {
      // The visit ruled in the test above had no stored score. Zero would claim
      // the reviewer cleared a visit the engine had rated harmless.
      const stored = await prisma.fraudVerdict.findUniqueOrThrow({
        where: { visitId: unscoredRuledVisitId },
      });

      expect(stored.riskScoreAtReview).toBeNull();
    });

    it('falls back to the email when the reviewer has no display name', async () => {
      const stored = await prisma.fraudVerdict.findUniqueOrThrow({
        where: { visitId: unscoredRuledVisitId },
      });

      expect(stored.reviewerLabel).toBe(manager.email);
    });
  });

  describe('GET /fraud/flagged — the open queue (#392)', () => {
    const idsOf = (body: { data: Array<{ visitId: string }> }) => body.data.map((v) => v.visitId);

    it('excludes a ruled visit by default: a ruled case leaves the open queue', async () => {
      const res = await flagged('?minScore=0');

      expect(res.status).toBe(200);
      expect(idsOf(res.body)).toContain(openVisitId);
      expect(idsOf(res.body)).not.toContain(ruledVisitId);
    });

    it('carries verdict: null on every unreviewed row', async () => {
      const res = await flagged('?minScore=0');

      const row = res.body.data.find((v: { visitId: string }) => v.visitId === openVisitId);
      // Null, not an omitted field a client would read as "cleared".
      expect(row).toHaveProperty('verdict', null);
    });

    it('returns only ruled visits, with their verdicts, for reviewed=true', async () => {
      const res = await flagged('?minScore=0&reviewed=true');

      expect(res.status).toBe(200);
      expect(idsOf(res.body)).toEqual([ruledVisitId]);
      const row = res.body.data[0];
      expect(row.verdict.verdict).toBe('confirmed');
      expect(row.verdict.reviewer.label).toBe('Thandi Mokoena');
      expect(row.verdict.riskScoreAtReview).toBe(80);
    });

    it('returns both for reviewed=all — exactly what this endpoint used to return', async () => {
      const res = await flagged('?minScore=0&reviewed=all');

      expect(res.status).toBe(200);
      expect(idsOf(res.body).sort()).toEqual([ruledVisitId, openVisitId].sort());
    });

    it('treats reviewed=false as the default rather than a third meaning', async () => {
      const [explicit, implied] = await Promise.all([
        flagged('?minScore=0&reviewed=false'),
        flagged('?minScore=0'),
      ]);

      expect(idsOf(explicit.body)).toEqual(idsOf(implied.body));
    });

    it('filters `unscored` the same way, so the page and its counter agree', async () => {
      // Two unscored visits exist; one of them has been ruled on.
      const [open, decided, all] = await Promise.all([
        flagged('?minScore=0'),
        flagged('?minScore=0&reviewed=true'),
        flagged('?minScore=0&reviewed=all'),
      ]);

      expect(open.body.unscored).toBe(1);
      expect(decided.body.unscored).toBe(1);
      expect(all.body.unscored).toBe(2);
      expect(idsOf(open.body)).not.toContain(unscoredVisitId);
    });

    it('rejects an unrecognised reviewed value with 400 rather than silently answering', async () => {
      const res = await flagged('?minScore=0&reviewed=yes');

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('reviewed');
    });

    it("never shows another tenant's queue", async () => {
      const res = await flagged('?minScore=0&reviewed=all', foreign.token);

      expect(res.status).toBe(200);
      expect(idsOf(res.body)).toEqual([]);
    });
  });

  describe('GET /fraud/verdicts', () => {
    it('lists this tenant ledger, newest decision first', async () => {
      const res = await request(app)
        .get('/fraud/verdicts')
        .set('Authorization', `Bearer ${manager.token}`);

      expect(res.status).toBe(200);
      expect(Object.keys(res.body).sort()).toEqual(['data', 'nextCursor']);
      const visitIds = (res.body.data as Array<{ visitId: string }>).map((v) => v.visitId);
      expect(visitIds.sort()).toEqual([ruledVisitId, unscoredRuledVisitId].sort());
      const times = (res.body.data as VerdictBody[]).map((v) => Date.parse(v.decidedAt));
      expect(times).toEqual([...times].sort((x, y) => y - x));
      expect(res.body.nextCursor).toBeNull();
    });

    it('pages on the cursor without repeating or dropping a ruling', async () => {
      const whole = await request(app)
        .get('/fraud/verdicts')
        .set('Authorization', `Bearer ${manager.token}`);
      const paged: string[] = [];
      let cursor: string | null = null;
      for (let page = 0; page < 5; page += 1) {
        const res: request.Response = await request(app)
          .get(`/fraud/verdicts?limit=1${cursor ? `&cursor=${cursor}` : ''}`)
          .set('Authorization', `Bearer ${manager.token}`);
        expect(res.status).toBe(200);
        expect(res.body.data.length).toBeLessThanOrEqual(1);
        paged.push(...(res.body.data as VerdictBody[]).map((v) => v.visitId));
        cursor = res.body.nextCursor;
        if (!cursor) break;
      }
      expect(cursor).toBeNull();
      expect(paged).toEqual((whole.body.data as VerdictBody[]).map((v) => v.visitId));
    });

    it("does not leak another tenant's rulings", async () => {
      const res = await request(app)
        .get('/fraud/verdicts')
        .set('Authorization', `Bearer ${foreign.token}`);

      // Authenticated, and then told nothing: an empty ledger of their own.
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
    });

    it('forbids a field agent with 403', async () => {
      const res = await request(app)
        .get('/fraud/verdicts')
        .set('Authorization', `Bearer ${agent.token}`);

      expect(res.status).toBe(403);
    });

    it('rejects an unauthenticated request with 401', async () => {
      const res = await request(app).get('/fraud/verdicts');

      expect(res.status).toBe(401);
    });
  });
});
