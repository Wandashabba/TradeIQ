import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { userIn } from '../../test-utils/tenants';
import { DEFAULT_PIN_DISPUTE_DAILY_CAP } from '../visits/visits.service';
import { MAX_ADOPTABLE_FIX_ACCURACY_M } from './outlets.service';

/**
 * THE ATTACK THE OVERRIDE SHIPPED WITHOUT AN ANSWER TO (#386 follow-up).
 *
 * outlets.pinRepair.test.ts holds the feature: a manager who can move a pin,
 * an agent who can say the pin is wrong, and the line that the second is an
 * override and not a bypass. Every one of those tests still passes, and none
 * of them noticed this:
 *
 *   One agent, at home, is inside the 25 km distance cap of every outlet in
 *   their metro. Ten check-ins, one per outlet, each with a wrong-pin report.
 *   Every one returned 201. Every one scored 30 — under the review threshold
 *   of 50 — because the engine scored each visit alone and nothing counted
 *   how many the agent had already made or noticed that ten claims about ten
 *   different shops came from one coordinate. /fraud/flagged stayed empty.
 *   The incentive paid ten visits. When a manager finally rejected all ten,
 *   the visits were untouched: same score, same queue, same points.
 *
 * Each test below is that attack, or one step of it, written as the failure.
 * They are deliberately not phrased as "the cap is 3" or "the weight is 55":
 * a weight may be retuned, but an agent at home claiming a morning of visits
 * must never again be invisible.
 */

// The agent's flat, and three shops at increasing distances from it. Every
// one of them is inside the 25 km the override allows, which is the point:
// nothing about any single one of these claims is refusable on distance.
const HOME = { lat: -26.1076, lng: 28.0567 };
const SHOPS = [
  { lat: -26.1345, lng: 28.0712 }, // ~3 km
  { lat: -26.1789, lng: 28.1134 }, // ~10 km
  { lat: -26.2341, lng: 28.1601 }, // ~18 km
  { lat: -26.2341, lng: 27.9601 }, // ~17 km, the other way
];

const PIXEL =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

describe('bounding the pin-dispute override (#386 follow-up)', () => {
  let clientId: string;
  let managerToken: string;
  let agent: Awaited<ReturnType<typeof userIn>>;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'Override Bounds Client',
        industry: 'FMCG',
        scorecardWeights: {},
        // Deliberately empty: every rule under test is at its DEFAULT. A suite
        // that raised the cap to make itself convenient would be testing a
        // tenant nobody has.
        kpiThresholds: {},
      },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager', { displayName: 'Thandi Mokoena' })).token;
    agent = await userIn(clientId, 'field_agent', { displayName: 'Nomsa Dlamini' });
    await prisma.territory.create({ data: { clientId, name: 'Jo\'burg', code: 'jhb' } });
  });

  afterAll(async () => {
    await prisma.photo.deleteMany({ where: { clientId } });
    await prisma.pinDispute.deleteMany({ where: { clientId } });
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.checkInAttempt.deleteMany({ where: { clientId } });
    await prisma.outletChangeAudit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.territory.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  let seq = 0;
  /** A shop pinned where it really is; the agent is the one somewhere else. */
  async function shop(at: { lat: number; lng: number }) {
    seq += 1;
    return prisma.outlet.create({
      data: {
        name: `Shop ${seq}`,
        code: `OB-${seq}-${Date.now()}`,
        channelType: 'convenience',
        lat: at.lat,
        lng: at.lng,
        territoryId: 'jhb',
        clientId,
      },
    });
  }

  /** Wipe this agent's claims so each test starts inside its own daily cap. */
  async function clearClaims() {
    await prisma.photo.deleteMany({ where: { clientId } });
    await prisma.pinDispute.deleteMany({ where: { clientId } });
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
  }

  /** "The pin is wrong", filed from HOME, as the app files it. */
  function claim(outletId: string, token = agent.token, body: object = {}) {
    return request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: HOME.lat, lng: HOME.lng, pinDispute: {}, ...body });
  }

  async function signalsFor(visitId: string) {
    const res = await request(app)
      .get(`/fraud/visits/${visitId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    return {
      riskScore: res.body.riskScore as number,
      codes: (res.body.signals as Array<{ code: string }>).map((s) => s.code),
    };
  }

  beforeEach(clearClaims);

  // ── Finding 1: nothing stopped the tenth override ────────────────────────

  it('refuses a morning of wrong-pin claims from one agent rather than scoring each one alone', async () => {
    const outlets = await Promise.all(SHOPS.map(shop));

    const statuses: number[] = [];
    for (const outlet of outlets) {
      statuses.push((await claim(outlet.id)).status);
    }

    // The attack ran to ten before; it now stops at the cap, and the refusal
    // is a refusal (429), not a 201 with a score nobody reads.
    const accepted = statuses.filter((s) => s === 201).length;
    expect(accepted).toBe(DEFAULT_PIN_DISPUTE_DAILY_CAP);
    expect(statuses.slice(DEFAULT_PIN_DISPUTE_DAILY_CAP)).toEqual(
      statuses.slice(DEFAULT_PIN_DISPUTE_DAILY_CAP).map(() => 429),
    );
    expect(await prisma.pinDispute.count({ where: { clientId, agentId: agent.userId } })).toBe(
      DEFAULT_PIN_DISPUTE_DAILY_CAP,
    );
  });

  it('the refusal names the queue rather than reading as the app being broken', async () => {
    const outlets = await Promise.all(SHOPS.map(shop));
    for (const outlet of outlets.slice(0, DEFAULT_PIN_DISPUTE_DAILY_CAP)) {
      expect((await claim(outlet.id)).status).toBe(201);
    }

    const refused = await claim(outlets[DEFAULT_PIN_DISPUTE_DAILY_CAP].id);
    expect(refused.status).toBe(429);
    expect(refused.body.error).toMatch(/limit/i);
    expect(refused.body.error).toMatch(/manager/i);
  });

  it('scores a run of claims from one agent past the review threshold', async () => {
    const outlets = await Promise.all(SHOPS.slice(0, 3).map(shop));

    const ids: string[] = [];
    for (const outlet of outlets) {
      const res = await claim(outlet.id);
      expect(res.status).toBe(201);
      ids.push(res.body.id as string);
    }

    // The first is the ordinary case the override exists for and stays under
    // the threshold; by the third the pattern itself is the evidence.
    const first = await signalsFor(ids[0]);
    const third = await signalsFor(ids[2]);
    expect(first.codes).toContain('geofence_override');
    expect(third.codes).toContain('geofence_override_rate');
    expect(third.riskScore).toBeGreaterThanOrEqual(50);
  });

  it('scores claims about different outlets made from one spot', async () => {
    const [a, b] = await Promise.all([shop(SHOPS[0]), shop(SHOPS[1])]);

    expect((await claim(a.id)).status).toBe(201);
    const second = await claim(b.id);
    expect(second.status).toBe(201);

    // One position cannot be standing in two shops. This is the home attack's
    // actual signature, and it fires on the SECOND claim, not the tenth.
    const { codes, riskScore } = await signalsFor(second.body.id);
    expect(codes).toContain('geofence_override_cluster');
    expect(riskScore).toBeGreaterThanOrEqual(50);
  });

  it('leaves an agent reporting one wrong pin alone', async () => {
    const outlet = await shop(SHOPS[0]);
    const res = await claim(outlet.id);
    expect(res.status).toBe(201);

    // The whole reason the override exists. A queue that treats every honest
    // report as suspected fraud is a queue managers stop reading.
    const { codes, riskScore } = await signalsFor(res.body.id);
    expect(codes).toContain('geofence_override');
    expect(codes).not.toContain('geofence_override_rate');
    expect(codes).not.toContain('geofence_override_cluster');
    expect(riskScore).toBeLessThan(50);
  });

  it('counts the pattern by the SERVER clock, so a backdated check-in cannot escape it', async () => {
    const [a, b] = await Promise.all([shop(SHOPS[0]), shop(SHOPS[1])]);

    expect((await claim(a.id)).status).toBe(201);
    // The device asserting it checked in a fortnight ago — outside any
    // window measured on checkinTs. The claim rows are stamped by this server.
    const second = await claim(b.id, agent.token, {
      checkinTs: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
    });
    expect(second.status).toBe(201);

    const { codes } = await signalsFor(second.body.id);
    expect(codes).toContain('geofence_override_cluster');
  });

  // ── Finding 3: one failed position replayed into many visits ─────────────

  it('refuses a second claim about the same pin on the same day instead of making a second visit', async () => {
    const outlet = await shop(SHOPS[0]);

    const first = await claim(outlet.id);
    expect(first.status).toBe(201);

    // Identical POSTs, no clientVisitId — the shape that made three visits,
    // three disputes and three submitted-visit counts out of one position.
    const second = await claim(outlet.id);
    const third = await claim(outlet.id);
    expect(second.status).toBe(409);
    expect(third.status).toBe(409);
    // The refusal names the visit that already exists, so the app can resume
    // it rather than read this as evidence lost.
    expect(second.body.error).toContain(first.body.id);

    expect(await prisma.visit.count({ where: { clientId, outletId: outlet.id } })).toBe(1);
    expect(await prisma.pinDispute.count({ where: { clientId, outletId: outlet.id } })).toBe(1);
  });

  it('still refuses a repeat claim after a manager has answered the first', async () => {
    const outlet = await shop(SHOPS[0]);
    const first = await claim(outlet.id);
    expect(first.status).toBe(201);

    const disputeId = (
      await prisma.pinDispute.findUniqueOrThrow({
        where: { visitId: first.body.id },
        select: { id: true },
      })
    ).id;
    // "I looked, and the pin stands."
    const ruling = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId, resolutionNote: 'The pin is where the shop is.' });
    expect(ruling.status).toBe(200);

    // Re-filing the same claim the moment it is rejected is how a refusal
    // becomes a retry loop, and the second visit would earn its own points.
    const again = await claim(outlet.id);
    expect(again.status).toBe(409);
    expect(await prisma.visit.count({ where: { clientId, outletId: outlet.id } })).toBe(1);
  });

  // ── Finding 2: a rejection that changed nothing about the visit ──────────

  it('puts a rejected override into the flagged queue rather than leaving the visit untouched', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    expect(checkin.status).toBe(201);
    const visitId = checkin.body.id as string;

    // One section captured, exactly as the attack did it: enough that the
    // visit is a complete-looking piece of work, so the only thing the engine
    // has to say about it is that the fence was overridden.
    await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        visitId,
        highTrafficPass: true,
        planogramCompliancePct: 90,
        brandingElements: { poster: true },
        facingsCount: { total: 12 },
        cleanlinessScore: 80,
      })
      .expect(201);
    await request(app)
      .post(`/visits/${visitId}/submit`)
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ submittedAtClient: new Date(Date.now() + 25 * 60 * 1000).toISOString() })
      .expect(200);

    // Before the ruling: an unanswered claim, deliberately under the threshold.
    const before = await signalsFor(visitId);
    expect(before.riskScore).toBeLessThan(50);
    const openQueue = await request(app)
      .get('/fraud/flagged')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(openQueue.status).toBe(200);
    expect((openQueue.body.data as Array<{ visitId: string }>).map((r) => r.visitId)).not.toContain(
      visitId,
    );

    const disputeId = (
      await prisma.pinDispute.findUniqueOrThrow({ where: { visitId }, select: { id: true } })
    ).id;
    const ruling = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId, resolutionNote: 'I looked, and the pin stands.' });
    expect(ruling.status).toBe(200);
    expect(ruling.body.dispute.status).toBe('rejected');

    // A manager saying the agent was not at the shop is the strongest thing
    // anyone says about a visit. It used to change nothing at all.
    const after = await signalsFor(visitId);
    expect(after.codes).toContain('geofence_override_rejected');
    expect(after.riskScore).toBeGreaterThanOrEqual(50);

    // And it reaches the queue WITHOUT waiting for the nightly rescore: the
    // stored score is what /fraud/flagged reads.
    const stored = await prisma.visit.findUniqueOrThrow({
      where: { id: visitId },
      select: { riskScore: true },
    });
    expect(stored.riskScore).toBeGreaterThanOrEqual(50);
    const queue = await request(app)
      .get('/fraud/flagged')
      .set('Authorization', `Bearer ${managerToken}`);
    expect((queue.body.data as Array<{ visitId: string }>).map((r) => r.visitId)).toContain(visitId);
  });

  it('leaves an APPLIED claim below the threshold — agreeing with the agent is not an accusation', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    const visitId = checkin.body.id as string;
    const disputeId = (
      await prisma.pinDispute.findUniqueOrThrow({ where: { visitId }, select: { id: true } })
    ).id;

    const ruling = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId, lat: HOME.lat, lng: HOME.lng });
    expect(ruling.status).toBe(200);
    expect(ruling.body.dispute.status).toBe('applied');

    const after = await signalsFor(visitId);
    expect(after.codes).toContain('geofence_override');
    expect(after.codes).not.toContain('geofence_override_rejected');
    expect(after.riskScore).toBeLessThan(50);
  });

  // ── Finding 4: the storefront photo could be laundered ───────────────────

  it('refuses a gallery image as storefront evidence', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    const visitId = checkin.body.id as string;

    const gallery = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        visitId,
        section: 'pin_dispute',
        dataUrl: PIXEL,
        // A screenshot picked at home: the timestamp is when it was PICKED and
        // the tag is where the phone was then, so the two agree perfectly and
        // photo_gps_divergence cannot fire.
        timestamp: new Date().toISOString(),
        gpsTag: HOME,
        source: 'gallery',
      });
    expect(gallery.status).toBe(400);
    expect(gallery.body.error).toMatch(/camera/i);

    // An older build that says nothing at all is refused for this section too:
    // unsourced evidence for the one claim that overrides the geofence is
    // evidence nobody can check.
    const unsourced = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        visitId,
        section: 'pin_dispute',
        dataUrl: PIXEL,
        timestamp: new Date().toISOString(),
        gpsTag: HOME,
      });
    expect(unsourced.status).toBe(400);

    expect(await prisma.photo.count({ where: { visitId, section: 'pin_dispute' } })).toBe(0);
  });

  it('refuses storefront evidence added after the claim was answered', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    const visitId = checkin.body.id as string;
    const disputeId = (
      await prisma.pinDispute.findUniqueOrThrow({ where: { visitId }, select: { id: true } })
    ).id;

    await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ disputeId })
      .expect(200);

    // Evidence added to a ruling already made cannot be the evidence the
    // manager read, whatever it shows.
    const late = await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        visitId,
        section: 'pin_dispute',
        dataUrl: PIXEL,
        timestamp: new Date().toISOString(),
        gpsTag: HOME,
        source: 'camera',
      });
    expect(late.status).toBe(409);
  });

  it('shows the manager the server\'s own account of the photo, not only the phone\'s', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    const visitId = checkin.body.id as string;

    // The device's account, made absurd on purpose: a timestamp from 2020.
    // The old view showed exactly this and nothing beside it.
    await request(app)
      .post('/photos')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        visitId,
        section: 'pin_dispute',
        dataUrl: PIXEL,
        timestamp: '2020-01-01T09:00:00.000Z',
        gpsTag: HOME,
        source: 'camera',
      })
      .expect(201);

    const queue = await request(app)
      .get('/outlets/pin-disputes')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(queue.status).toBe(200);
    const view = (queue.body.data as Array<{ visitId: string; photos: unknown[] }>).find(
      (d) => d.visitId === visitId,
    )!;
    const photo = view.photos[0] as { timestamp: string; createdAt: string; source: string };
    expect(photo.timestamp).toContain('2020');
    // The two the reviewer can actually lean on.
    expect(photo.source).toBe('camera');
    expect(new Date(photo.createdAt).getFullYear()).toBe(new Date().getFullYear());
  });

  // ── Finding 5: "use their position" was a decision from bare decimals ────

  it('records whose position a pin was moved to, and from which attempt', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    expect(checkin.status).toBe(201);

    const attempt = await prisma.checkInAttempt.findFirstOrThrow({
      where: { clientId, outletId: outlet.id, passed: false },
      orderBy: { createdAt: 'desc' },
    });

    await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ fromAttemptId: attempt.id })
      .expect(200);

    // An adopted position is an access boundary moved on one person's word.
    // The ledger row used to say only "agent_position".
    const row = await prisma.outletChangeAudit.findFirstOrThrow({
      where: { clientId, outletId: outlet.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(row.pinSource).toBe('agent_position');
    expect(row.fromAttemptId).toBe(attempt.id);
    expect(row.fromAgentId).toBe(agent.userId);
  });

  it('refuses to adopt a position the device itself reported as mocked', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id, agent.token, { isMocked: true, accuracyM: 8 });
    expect(checkin.status).toBe(201);

    const attempt = await prisma.checkInAttempt.findFirstOrThrow({
      where: { clientId, outletId: outlet.id, passed: false },
      orderBy: { createdAt: 'desc' },
    });
    expect(attempt.isMocked).toBe(true);

    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ fromAttemptId: attempt.id });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/mock/i);

    // The pin did not move, and nothing was written to the ledger.
    const after = await prisma.outlet.findUniqueOrThrow({ where: { id: outlet.id } });
    expect(after.lat).toBeCloseTo(SHOPS[0].lat, 6);
    expect(await prisma.outletChangeAudit.count({ where: { outletId: outlet.id } })).toBe(0);
  });

  it('refuses to adopt a fix too coarse to say where a shop door is', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id, agent.token, {
      accuracyM: MAX_ADOPTABLE_FIX_ACCURACY_M + 400,
    });
    expect(checkin.status).toBe(201);

    const attempt = await prisma.checkInAttempt.findFirstOrThrow({
      where: { clientId, outletId: outlet.id, passed: false },
      orderBy: { createdAt: 'desc' },
    });

    const res = await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ fromAttemptId: attempt.id });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/accurate/i);
  });

  it('still adopts a good fix, and one that reports nothing', async () => {
    const good = await shop(SHOPS[0]);
    const silent = await shop(SHOPS[1]);
    await claim(good.id, agent.token, { accuracyM: 12, isMocked: false });
    await claim(silent.id);

    for (const outlet of [good, silent]) {
      const attempt = await prisma.checkInAttempt.findFirstOrThrow({
        where: { clientId, outletId: outlet.id, passed: false },
        orderBy: { createdAt: 'desc' },
      });
      // An older handset that reports no accuracy must not lock a manager out
      // of fixing a pin — that is the bug this whole feature exists for.
      await request(app)
        .patch(`/outlets/${outlet.id}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ fromAttemptId: attempt.id })
        .expect(200);
    }
  });

  it('warns when the reporting agent is the only person who has ever visited the outlet', async () => {
    const outlet = await shop(SHOPS[0]);
    const checkin = await claim(outlet.id);
    expect(checkin.status).toBe(201);

    const queue = await request(app)
      .get('/outlets/pin-disputes')
      .set('Authorization', `Bearer ${managerToken}`);
    const view = (queue.body.data as Array<{ visitId: string; agentIsOnlyVisitor: boolean }>).find(
      (d) => d.visitId === checkin.body.id,
    )!;
    // Nobody else's check-ins can disagree with a pin moved onto this agent's
    // position, because nobody else has ever been here.
    expect(view.agentIsOnlyVisitor).toBe(true);

    // A second agent working the outlet removes the warning, and must: a busy
    // store with two agents is the ordinary case.
    const colleague = await userIn(clientId, 'field_agent', { displayName: 'Sipho Nkosi' });
    await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${colleague.token}`)
      .send({ outletId: outlet.id, lat: SHOPS[0].lat, lng: SHOPS[0].lng })
      .expect(201);

    const again = await request(app)
      .get('/outlets/pin-disputes')
      .set('Authorization', `Bearer ${managerToken}`);
    const view2 = (again.body.data as Array<{ visitId: string; agentIsOnlyVisitor: boolean }>).find(
      (d) => d.visitId === checkin.body.id,
    )!;
    expect(view2.agentIsOnlyVisitor).toBe(false);
  });

  // ── What must not regress ────────────────────────────────────────────────

  it('never lets the device assert its own accuracy into a geofence pass', async () => {
    const outlet = await shop(SHOPS[0]);
    // A plain check-in from home, dressed up with a perfect fix and no dispute.
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${agent.token}`)
      .send({
        outletId: outlet.id,
        lat: HOME.lat,
        lng: HOME.lng,
        accuracyM: 1,
        isMocked: false,
        geofencePass: true,
      });
    expect(res.status).toBe(422);
  });

  it('keeps an agent out of the repair entirely', async () => {
    const outlet = await shop(SHOPS[0]);
    await request(app)
      .patch(`/outlets/${outlet.id}`)
      .set('Authorization', `Bearer ${agent.token}`)
      .send({ lat: HOME.lat, lng: HOME.lng })
      .expect(403);
  });
});
