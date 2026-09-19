import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { foreignTenant, userIn } from '../../test-utils/tenants';
import { DEFAULT_PIN_DISPUTE_MAX_DISTANCE_M } from '../visits/visits.service';

/**
 * The repair path for a wrongly pinned outlet (#386).
 *
 * The bug: an outlet's coordinates came only from the phone's position when
 * the create form was submitted, and nothing in the product could change them
 * afterwards. A store pinned to the depot car park was un-visitable forever.
 *
 * These tests hold the two halves of the fix together — a manager who can move
 * the pin, and an agent who can say the pin is wrong — and, more importantly,
 * hold the line that the second one is an OVERRIDE and not a BYPASS.
 */

// Kwik Spar Soweto, and the depot 8.4 km away the #386 story pins it to.
const SHOP = { lat: -26.2678, lng: 27.8586 };
const DEPOT = { lat: -26.2041, lng: 27.9073 };

describe('outlet pin repair (#386)', () => {
  let clientId: string;
  let managerToken: string;
  let agent: Awaited<ReturnType<typeof userIn>>;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Pin Repair Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager', { displayName: 'Thandi Mokoena' })).token;
    agent = await userIn(clientId, 'field_agent', { displayName: 'Nomsa Dlamini' });
    await prisma.territory.create({ data: { clientId, name: 'Soweto', code: 'soweto' } });
  });

  afterAll(async () => {
    await prisma.pinDispute.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.checkInAttempt.deleteMany({ where: { clientId } });
    await prisma.outletChangeAudit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.territory.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  let outletSeq = 0;
  /** A store pinned where the manager was standing, not where the store is. */
  async function depotPinnedOutlet() {
    outletSeq += 1;
    return prisma.outlet.create({
      data: {
        name: `Kwik Spar ${outletSeq}`,
        code: `KS-${outletSeq}-${Date.now()}`,
        channelType: 'convenience',
        lat: DEPOT.lat,
        lng: DEPOT.lng,
        territoryId: 'soweto',
        clientId,
      },
    });
  }

  // ── PATCH /outlets/:id ──────────────────────────────────────────────────

  it('moves a pin and records who moved it and where it was', async () => {
    const outlet = await depotPinnedOutlet();

    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ lat: SHOP.lat, lng: SHOP.lng });

    expect(res.status).toBe(200);
    expect(res.body.lat).toBeCloseTo(SHOP.lat, 6);
    expect(res.body.lng).toBeCloseTo(SHOP.lng, 6);

    const audit = await prisma.outletChangeAudit.findMany({ where: { outletId: outlet.id } });
    expect(audit).toHaveLength(1);
    // The ledger has to answer "where was it before?" — the question a manager
    // asks when a pin turns out to have been moved to the wrong place.
    expect((audit[0].before as Record<string, number>).lat).toBeCloseTo(DEPOT.lat, 6);
    expect((audit[0].after as Record<string, number>).lat).toBeCloseTo(SHOP.lat, 6);
    expect(audit[0].pinSource).toBe('manual');
    // Frozen at the time, so deactivating or renaming the manager later cannot
    // rewrite or erase what they did.
    expect(audit[0].userLabel).toBe('Thandi Mokoena');
  });

  it('takes the new pin from the agent\'s recorded position, not from the body', async () => {
    const outlet = await depotPinnedOutlet();
    const attempt = await prisma.checkInAttempt.create({
      data: {
        clientId,
        outletId: outlet.id,
        agentId: agent.userId,
        lat: SHOP.lat,
        lng: SHOP.lng,
        distanceM: 8400,
        passed: false,
      },
    });

    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ fromAttemptId: attempt.id });

    expect(res.status).toBe(200);
    expect(res.body.lat).toBeCloseTo(SHOP.lat, 6);
    const audit = await prisma.outletChangeAudit.findFirst({ where: { outletId: outlet.id } });
    expect(audit?.pinSource).toBe('agent_position');
  });

  it('refuses lat/lng and fromAttemptId together', async () => {
    // Not a precedence rule. A body carrying both could make the ledger say
    // "moved to the agent's recorded position" beside coordinates that were
    // never any agent's position — a forgeable audit trail.
    const outlet = await depotPinnedOutlet();
    const attempt = await prisma.checkInAttempt.create({
      data: {
        clientId,
        outletId: outlet.id,
        agentId: agent.userId,
        lat: SHOP.lat,
        lng: SHOP.lng,
        distanceM: 8400,
        passed: false,
      },
    });

    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ lat: 0, lng: 0, fromAttemptId: attempt.id });

    expect(res.status).toBe(400);
    const after = await prisma.outlet.findUnique({ where: { id: outlet.id } });
    expect(after!.lat).toBeCloseTo(DEPOT.lat, 6);
  });

  it('refuses lat without lng', async () => {
    // Half a coordinate pair is a point that is neither the old pin nor the
    // new one, and is nobody's intention.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ lat: SHOP.lat });
    expect(res.status).toBe(400);
  });

  it('rejects an unknown field rather than silently ignoring it', async () => {
    // A client that misspells `lng` as `long` must be told. Silently ignoring
    // it leaves the outlet where it was behind a 200 that reads like success.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ lat: SHOP.lat, long: SHOP.lng });
    expect(res.status).toBe(400);
  });

  it.each([
    [{ lat: 91, lng: 0 }],
    [{ lat: 0, lng: 181 }],
    [{ lat: -91, lng: 0 }],
  ])('rejects an off-globe coordinate %j', async (body) => {
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send(body);
    expect(res.status).toBe(400);
  });

  it('sets status to closed and back', async () => {
    const outlet = await depotPinnedOutlet();
    const closed = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ status: 'closed' });
    expect(closed.status).toBe(200);
    expect(closed.body.status).toBe('closed');

    const reopened = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ status: 'active' });
    expect(reopened.body.status).toBe('active');
  });

  it('rejects a status that is not active or closed', async () => {
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ status: 'dormant' });
    expect(res.status).toBe(400);
  });

  it('writes no ledger row for a PATCH that changes nothing', async () => {
    // A retry of a successful PATCH — ordinary on a field connection. It
    // answers 200 rather than 400, and does not pad the ledger with
    // "changed nothing to nothing".
    const outlet = await depotPinnedOutlet();
    await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: outlet.name });

    const audit = await prisma.outletChangeAudit.count({ where: { outletId: outlet.id } });
    expect(audit).toBe(0);
  });

  it('forbids a field agent from editing an outlet', async () => {
    // The load-bearing one. An agent who could both file a pin dispute and
    // grant it could move any outlet's fence to wherever they are standing,
    // which is the entire check-in control, deleted.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ lat: SHOP.lat, lng: SHOP.lng });

    expect(res.status).toBe(403);
    const after = await prisma.outlet.findUnique({ where: { id: outlet.id } });
    expect(after!.lat).toBeCloseTo(DEPOT.lat, 6);
  });

  it('rejects an unauthenticated PATCH', async () => {
    const outlet = await depotPinnedOutlet();
    const res = await request(app).patch(`/outlets/${outlet.id}`).send({ status: 'closed' });
    expect(res.status).toBe(401);
  });

  // ── Tenant isolation ────────────────────────────────────────────────────

  it('does not let another tenant read, move or close an outlet', async () => {
    const outlet = await depotPinnedOutlet();
    const stranger = await foreignTenant('manager');

    try {
      const read = await request(app)
        .get(`/outlets/${outlet.id}`)
        .set('Authorization', `Bearer ${stranger.token}`);
      // 404, never 403: a 403 would confirm the id exists somewhere, which is
      // an existence oracle across tenants.
      expect(read.status).toBe(404);

      const patched = await request(app)
        .patch(`/outlets/${outlet.id}`)
        .set('Authorization', `Bearer ${stranger.token}`)
        .send({ lat: 0, lng: 0, status: 'closed' });
      expect(patched.status).toBe(404);

      const after = await prisma.outlet.findUnique({ where: { id: outlet.id } });
      expect(after!.lat).toBeCloseTo(DEPOT.lat, 6);
      expect(after!.status).toBe('active');
    } finally {
      await stranger.cleanup();
    }
  });

  it('does not let another tenant\'s check-in attempt move this pin', async () => {
    // fromAttemptId is scoped to the tenant AND to this outlet. Neither a
    // stranger's attempt nor one at a different store may set these
    // coordinates.
    const outlet = await depotPinnedOutlet();
    const otherOutlet = await depotPinnedOutlet();
    const sameTenantElsewhere = await prisma.checkInAttempt.create({
      data: {
        clientId,
        outletId: otherOutlet.id,
        agentId: agent.userId,
        lat: 0,
        lng: 0,
        distanceM: 1,
        passed: false,
      },
    });

    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ fromAttemptId: sameTenantElsewhere.id });

    expect(res.status).toBe(404);
    const after = await prisma.outlet.findUnique({ where: { id: outlet.id } });
    expect(after!.lat).toBeCloseTo(DEPOT.lat, 6);
  });

  it('does not leak another tenant\'s pin disputes into the queue', async () => {
    const stranger = await foreignTenant('manager');
    try {
      const res = await request(app)
        .get('/outlets/pin-disputes')
        .set('Authorization', `Bearer ${stranger.token}`)
        .query({ status: 'all' });
      expect(res.status).toBe(200);
      const outletIds = (res.body.data as Array<{ outletId: string }>).map((d) => d.outletId);
      const mine = await prisma.outlet.findMany({ where: { clientId }, select: { id: true } });
      for (const outlet of mine) {
        expect(outletIds).not.toContain(outlet.id);
      }
    } finally {
      await stranger.cleanup();
    }
  });

  it('forbids a field agent from reading the dispute queue', async () => {
    // Colleagues' recorded positions and the notes written about them are
    // supervisory data, not reference data.
    const res = await request(app)
      .get('/outlets/pin-disputes')
      .set('Authorization', `Bearer ${agent.token}`);
    expect(res.status).toBe(403);
  });

  // ── "The pin is wrong" — the override ───────────────────────────────────

  it('still rejects a too-far check-in that does not report the pin', async () => {
    // Nothing about the ordinary refusal moved. An app build that predates
    // #386 sends no pinDispute and behaves exactly as it always did.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng });

    expect(res.status).toBe(422);
    expect(await prisma.visit.count({ where: { outletId: outlet.id } })).toBe(0);
  });

  it('lets the visit proceed flagged, with the evidence, when the pin is reported', async () => {
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        outletId: outlet.id,
        lat: SHOP.lat,
        lng: SHOP.lng,
        pinDispute: { note: 'I am inside the shop; the pin is on the depot.' },
      });

    expect(res.status).toBe(201);
    // FALSE. The whole point: the value is the measurement, not a permission.
    expect(res.body.geofencePass).toBe(false);
    expect(res.body.checkinDistanceM).toBeGreaterThan(5000);

    const dispute = await prisma.pinDispute.findUnique({ where: { visitId: res.body.id } });
    expect(dispute).not.toBeNull();
    expect(dispute!.status).toBe('open');
    expect(dispute!.lat).toBeCloseTo(SHOP.lat, 6);
    // The pin frozen as it read at the time, so a dispute reviewed after the
    // correction still shows what the agent was arguing with.
    expect(dispute!.outletLat).toBeCloseTo(DEPOT.lat, 6);
    // Measured here, never accepted from the device.
    expect(dispute!.distanceM).toBeGreaterThan(5000);
    // And the rejected attempt is still recorded, as it is for any failure.
    expect(
      await prisma.checkInAttempt.count({ where: { outletId: outlet.id, passed: false } }),
    ).toBe(1);
  });

  it('never takes the distance from the device', async () => {
    // A client-supplied distance is a client-supplied verdict. The body has no
    // field for it, and the strictness of the visits route is not the guard —
    // the server measuring it is.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        outletId: outlet.id,
        lat: SHOP.lat,
        lng: SHOP.lng,
        distanceM: 3,
        checkinDistanceM: 3,
        geofencePass: true,
        pinDispute: {},
      });

    expect(res.status).toBe(201);
    expect(res.body.geofencePass).toBe(false);
    expect(res.body.checkinDistanceM).toBeGreaterThan(5000);
  });

  it('refuses the override beyond the distance cap', async () => {
    // A pin can be in the wrong part of town. At some distance "the pin is
    // wrong" stops being the likeliest explanation for where the phone is, and
    // the fraud engine should never be asked to treat it as one.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        // Cape Town, ~1270 km from Soweto.
        outletId: outlet.id,
        lat: -33.9249,
        lng: 18.4241,
        pinDispute: { note: 'trust me' },
      });

    expect(res.status).toBe(422);
    expect(res.body.error).toContain(String(DEFAULT_PIN_DISPUTE_MAX_DISTANCE_M));
    expect(await prisma.visit.count({ where: { outletId: outlet.id } })).toBe(0);
    expect(await prisma.pinDispute.count({ where: { outletId: outlet.id } })).toBe(0);
    // The attempt is still recorded, so a run of these is as visible to the
    // fraud engine as a run of ordinary retries.
    expect(
      await prisma.checkInAttempt.count({ where: { outletId: outlet.id, passed: false } }),
    ).toBe(1);
  });

  it('is ignored on a check-in that passes the fence', async () => {
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: DEPOT.lat, lng: DEPOT.lng, pinDispute: { note: 'x' } });

    expect(res.status).toBe(201);
    expect(res.body.geofencePass).toBe(true);
    expect(await prisma.pinDispute.count({ where: { visitId: res.body.id } })).toBe(0);
  });

  it('rejects a malformed pinDispute rather than answering as an ordinary refusal', async () => {
    // `pinDispute: true` meaning "yes, dispute it" must be told, not silently
    // answered with a 422 the agent will read as the app being broken.
    const outlet = await depotPinnedOutlet();
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng, pinDispute: true });
    expect(res.status).toBe(400);
  });

  // ── The loop closes ─────────────────────────────────────────────────────

  it('surfaces the claim on the outlet, and applying the correction resolves it', async () => {
    const outlet = await depotPinnedOutlet();
    const checkin = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        outletId: outlet.id,
        lat: SHOP.lat,
        lng: SHOP.lng,
        pinDispute: { note: 'Standing at the till.' },
      });
    expect(checkin.status).toBe(201);

    const detail = await request(app)
      .get(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(detail.status).toBe(200);
    expect(detail.body.disputes).toHaveLength(1);
    expect(detail.body.disputes[0].agentLabel).toBe('Nomsa Dlamini');
    expect(detail.body.failedAttempts).toHaveLength(1);
    // The manager judges the pin by where agents actually stood.
    expect(detail.body.failedAttempts[0].lat).toBeCloseTo(SHOP.lat, 6);

    const disputeId = detail.body.disputes[0].id as string;
    const attemptId = detail.body.failedAttempts[0].id as string;

    const queue = await request(app)
      .get('/outlets/pin-disputes')
      .set('Authorization', `Bearer ${managerToken}`);
    expect((queue.body.data as Array<{ id: string }>).map((d) => d.id)).toContain(disputeId);

    const fixed = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ fromAttemptId: attemptId, disputeId, resolutionNote: 'Onboarded from the depot.' });

    expect(fixed.status).toBe(200);
    expect(fixed.body.dispute.status).toBe('applied');
    expect(fixed.body.dispute.resolvedByLabel).toBe('Thandi Mokoena');

    // And the claim leaves the open queue, which is the point of having one.
    const after = await request(app)
      .get('/outlets/pin-disputes')
      .set('Authorization', `Bearer ${managerToken}`);
    expect((after.body.data as Array<{ id: string }>).map((d) => d.id)).not.toContain(disputeId);

    // The store is now visitable from inside itself — the whole issue.
    const second = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng });
    expect(second.status).toBe(201);
    expect(second.body.geofencePass).toBe(true);
  });

  it('records a dispute the manager does not believe as rejected, not as nothing', async () => {
    const outlet = await depotPinnedOutlet();
    const checkin = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng, pinDispute: {} });
    const disputeId = (await prisma.pinDispute.findUniqueOrThrow({
      where: { visitId: checkin.body.id },
    })).id;

    const ruled = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId, resolutionNote: 'Pin is right; the shop moved.' });

    expect(ruled.status).toBe(200);
    expect(ruled.body.dispute.status).toBe('rejected');
    // And the pin did not move.
    expect(ruled.body.lat).toBeCloseTo(DEPOT.lat, 6);
  });

  it('answers the second manager to rule on one dispute with 409', async () => {
    const outlet = await depotPinnedOutlet();
    const checkin = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng, pinDispute: {} });
    const disputeId = (await prisma.pinDispute.findUniqueOrThrow({
      where: { visitId: checkin.body.id },
    })).id;

    const first = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId, lat: SHOP.lat, lng: SHOP.lng });
    expect(first.status).toBe(200);

    const second = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId, lat: DEPOT.lat, lng: DEPOT.lng });
    // The loser learns whose ruling stands rather than silently overwriting it.
    expect(second.status).toBe(409);
  });

  it('scores the override as a fraud signal rather than leaving it cosmetic', async () => {
    const outlet = await depotPinnedOutlet();
    const checkin = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng, pinDispute: {} });
    expect(checkin.status).toBe(201);

    const fraud = await request(app)
      .get(`/fraud/visits/${checkin.body.id}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(fraud.status).toBe(200);
    const codes = (fraud.body.signals as Array<{ code: string }>).map((s) => s.code);
    expect(codes).toContain('geofence_override');
    // It replaces the borderline signal rather than stacking with it: a visit
    // cannot both hug the fence edge and be outside it, and charging for both
    // would put every honest override over the review threshold on geofence
    // evidence alone.
    expect(codes).not.toContain('geofence_distance');
    // Below the default review threshold on its own, on purpose. See the
    // signal's own comment.
    const overrideWeight = (fraud.body.signals as Array<{ code: string; weight: number }>)
      .find((s) => s.code === 'geofence_override')!.weight;
    expect(overrideWeight).toBeLessThan(50);
    expect(overrideWeight).toBeGreaterThan(0);
  });

  it('shows the manager the reason behind a failed fence on the visit', async () => {
    const outlet = await depotPinnedOutlet();
    const checkin = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: SHOP.lat, lng: SHOP.lng, pinDispute: { note: 'At the till' } });

    const detail = await request(app)
      .get(`/visits/${checkin.body.id}`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(detail.status).toBe(200);
    expect(detail.body.geofence.pass).toBe(false);
    // Without this a reviewer cannot tell an agent reporting a depot-pinned
    // outlet from one faking a visit, which is the whole difference.
    expect(detail.body.pinDispute.note).toBe('At the till');
    expect(detail.body.pinDispute.status).toBe('open');
  });

  it('leaves pinDispute null on an ordinary visit', async () => {
    const outlet = await depotPinnedOutlet();
    const checkin = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ outletId: outlet.id, lat: DEPOT.lat, lng: DEPOT.lng });

    const detail = await request(app)
      .get(`/visits/${checkin.body.id}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(detail.body.geofence.pass).toBe(true);
    expect(detail.body.pinDispute).toBeNull();
  });
});
