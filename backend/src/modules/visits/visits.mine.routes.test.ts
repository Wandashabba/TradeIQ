import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { userIn } from '../../test-utils/tenants';

/**
 * GET /visits/me — the agent's own record (#383).
 *
 * The thing this suite is mostly about is the negative: an agent asking for
 * their own visits must never be able to ask for somebody else's, and must
 * never be handed the fraud engine's inputs. The rest is the arithmetic the
 * screen depends on — dwell on one clock, unknown distinct from zero, and the
 * two scores kept apart so "scored 71, you saw 84" can be said out loud.
 */
describe('GET /visits/me', () => {
  let clientId: string;
  let otherClientId: string;
  let agentAId: string;
  let agentAToken: string;
  let agentBToken: string;
  let managerToken: string;
  let outletId: string;
  let scoredVisitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'MYVISITS-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const other = await prisma.client.create({
      data: { name: 'MYVISITS-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const agentA = await prisma.user.create({
      data: {
        email: 'MYVISITS-a@example.com',
        passwordHash: 'unused',
        role: 'field_agent',
        clientId,
      },
    });
    agentAId = agentA.id;
    agentAToken = issueToken({ userId: agentA.id, role: 'field_agent', clientId });

    const agentB = await prisma.user.create({
      data: {
        email: 'MYVISITS-b@example.com',
        passwordHash: 'unused',
        role: 'field_agent',
        clientId,
      },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Kasi Corner Spaza',
        code: 'MYVISITS-KC',
        channelType: 'spaza',
        lat: -26.2,
        lng: 28.0,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;

    // A submitted, scored visit: 41 minutes of dwell, 140 m out of fence, a
    // photo, a task and two captured sections.
    const checkinTs = new Date('2026-09-17T09:00:00.000Z');
    const scored = await prisma.visit.create({
      data: {
        outletId,
        agentId: agentAId,
        clientId,
        checkinTs,
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: false,
        checkinDistanceM: 140,
        status: 'submitted',
        submittedAtClient: new Date(checkinTs.getTime() + 41 * 60_000),
        riskScore: 88,
        fraudSignals: [{ code: 'out_of_fence', detail: '140 m', weight: 40 }],
      },
    });
    scoredVisitId = scored.id;

    await prisma.scorecard.create({
      data: {
        visitId: scored.id,
        dimensionScores: { availability: 70 },
        weightedTotal: 71,
        ratingBand: 'amber',
        provisionalTotal: 84,
        provisionalBand: 'green',
        provisionalAt: new Date(checkinTs.getTime() + 41 * 60_000),
      },
    });
    // The agent started this visit by saying the pin was wrong (#386).
    await prisma.pinDispute.create({
      data: {
        clientId,
        outletId,
        agentId: agentAId,
        visitId: scored.id,
        lat: -26.2,
        lng: 28.0,
        distanceM: 140,
        outletLat: -26.2013,
        outletLng: 28.0,
      },
    });
    await prisma.visitRisk.create({
      data: {
        visitId: scored.id,
        flagType: 'expiry',
        severity: 'high',
        note: 'Two cases past date',
      },
    });
    await prisma.visitVisibility.create({
      data: {
        visitId: scored.id,
        brandingElements: {},
        planogramCompliancePct: 80,
        facingsCount: {},
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
    });
    await prisma.photo.create({
      data: {
        visitId: scored.id,
        clientId,
        section: 'shelf',
        url: 'data:,x',
        gpsTag: {},
        timestamp: checkinTs,
      },
    });
    await prisma.task.create({
      data: {
        visitId: scored.id,
        outletId,
        findingType: 'stockout',
        requiredFix: 'Refill the top shelf',
        priority: 'high',
        slaDueAt: new Date(checkinTs.getTime() + 86_400_000),
        ownerId: agentAId,
      },
    });

    // An unscored, in-progress visit with no client submit stamp and no
    // measured distance: the "unknown, not zero" case the screen has to keep
    // distinct from a real 0 m.
    await prisma.visit.create({
      data: {
        outletId,
        agentId: agentAId,
        clientId,
        checkinTs: new Date('2026-09-18T07:30:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        checkinDistanceM: null,
        status: 'in_progress',
        submittedAtClient: null,
      },
    });

    // Agent B's visit, and another tenant's: neither may ever appear.
    await prisma.visit.create({
      data: {
        outletId,
        agentId: agentB.id,
        clientId,
        checkinTs: new Date('2026-09-18T08:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status: 'submitted',
      },
    });

    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'MYVISITS-Other-Outlet',
        code: 'MYVISITS-OO',
        channelType: 'spaza',
        lat: -26.2,
        lng: 28.0,
        territoryId: 'territory-1',
        clientId: otherClientId,
      },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'MYVISITS-other@example.com',
        passwordHash: 'unused',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: otherClientId,
        checkinTs: new Date('2026-09-18T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status: 'submitted',
      },
    });
  });

  it('returns only the caller’s own visits, newest first', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data.map((v: { id: string }) => v.id)).not.toContain(undefined);
    // Newest check-in first.
    expect(new Date(res.body.data[0].checkinTs).getTime()).toBeGreaterThan(
      new Date(res.body.data[1].checkinTs).getTime(),
    );
  });

  it('gives a second agent in the same client a different list', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentBToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].id).not.toBe(scoredVisitId);
  });

  it('cannot be widened to another agent by a query parameter', async () => {
    const res = await request(app)
      .get(`/visits/me?agentId=${agentAId}`)
      .set('Authorization', `Bearer ${agentBToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].id).not.toBe(scoredVisitId);
  });

  it('is not shadowed by the manager-only GET /visits/:id guard', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    // A field agent hitting GET /visits/:id gets a 403; 'me' must not be read
    // as an id.
    expect(res.status).toBe(200);
  });

  it('gives a manager their own (empty) record rather than the tenant’s', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  it('carries the proof the agent was there, and the authoritative score', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    const visit = res.body.data.find((v: { id: string }) => v.id === scoredVisitId);
    expect(visit).toMatchObject({
      outletName: 'Kasi Corner Spaza',
      outletCode: 'MYVISITS-KC',
      checkinDistanceM: 140,
      geofencePass: false,
      status: 'submitted',
      dwellMinutes: 41,
      sectionsCaptured: 2,
      sectionsTotal: 7,
      photos: 1,
      tasksRaised: 1,
    });
    expect(visit.score.weightedTotal).toBe(71);
    expect(visit.score.ratingBand).toBe('amber');
    // The two numbers stay apart, so the app can say "scored 71, you saw 84"
    // instead of replacing one with the other.
    expect(visit.score.seen.weightedTotal).toBe(84);
  });

  it('never hands the agent the fraud engine’s inputs', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    const visit = res.body.data.find((v: { id: string }) => v.id === scoredVisitId);
    expect(visit).not.toHaveProperty('riskScore');
    expect(visit).not.toHaveProperty('fraudSignals');
    expect(visit).not.toHaveProperty('checkinLat');
    expect(visit).not.toHaveProperty('checkinLng');
    // A reviewer's ruling IS the agent's business, and it is null until one.
    expect(visit.reviewedVerdict).toBeNull();
  });

  it('says the agent reported the pin, and only on the visit they reported it on', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    const reported = res.body.data.find((v: { id: string }) => v.id === scoredVisitId);
    expect(reported.pinReported).toBe(true);
    // Their own claim, not the dispute record: no coordinates, no review note.
    expect(reported).not.toHaveProperty('pinDispute');
    const others = res.body.data.filter((v: { id: string }) => v.id !== scoredVisitId);
    expect(others.length).toBeGreaterThan(0);
    for (const v of others) expect(v.pinReported).toBe(false);
  });

  it('reports an unmeasured distance and an unknown dwell as null, not zero', async () => {
    const res = await request(app)
      .get('/visits/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    const open = res.body.data.find((v: { status: string }) => v.status === 'in_progress');
    expect(open.checkinDistanceM).toBeNull();
    expect(open.dwellMinutes).toBeNull();
    expect(open.score).toBeNull();
    expect(open.sectionsCaptured).toBe(0);
  });

  it('pages with a cursor', async () => {
    const first = await request(app)
      .get('/visits/me?limit=1')
      .set('Authorization', `Bearer ${agentAToken}`);

    expect(first.body.data).toHaveLength(1);
    expect(first.body.nextCursor).toEqual(expect.any(String));

    const second = await request(app)
      .get(`/visits/me?limit=1&cursor=${first.body.nextCursor}`)
      .set('Authorization', `Bearer ${agentAToken}`);

    expect(second.body.data).toHaveLength(1);
    expect(second.body.data[0].id).not.toBe(first.body.data[0].id);
    expect(second.body.nextCursor).toBeNull();
  });

  it('requires a token', async () => {
    const res = await request(app).get('/visits/me');
    expect(res.status).toBe(401);
  });
});
