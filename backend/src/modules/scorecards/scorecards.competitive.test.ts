import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

/**
 * #93 — the scorecard's `competitive` dimension used to be
 * `competitive.length > 0 ? 100 : 0`.
 *
 * That scored *data entry*, not the store: an agent who typed one competitor row
 * got full marks, and an outlet with genuinely no competitor on shelf scored a
 * flat zero for something nobody could have done anything about.
 */
describe('scorecard competitive dimension (#93)', () => {
  let clientId: string;
  let agentId: string;
  let agentToken: string;

  async function makeVisit(code: string) {
    const outlet = await prisma.outlet.create({
      data: {
        name: `COMP-${code}`,
        code: `COMP-${code}`,
        channelType: 'spaza',
        lat: -26.2,
        lng: 28.0,
        territoryId: 'comp-t1',
        clientId,
      },
    });
    return prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status: 'submitted',
      },
    });
  }

  /** Our facings for the visit. */
  async function ownFacings(visitId: string, total: number) {
    await prisma.visitVisibility.create({
      data: {
        visitId,
        brandingElements: {},
        planogramCompliancePct: 80,
        facingsCount: { total },
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
    });
  }

  async function score(visitId: string) {
    const res = await request(app)
      .post('/scorecards')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId });
    expect(res.status).toBe(201);
    return res.body;
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      // Equal weights across all six dimensions.
      data: {
        name: 'COMP-Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'comp-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agentId, role: 'field_agent', clientId });
  });

  it('scores the competitive dimension as our share of shelf', async () => {
    const visit = await makeVisit('SOS');
    await ownFacings(visit.id, 30);
    await prisma.visitCompetitive.create({
      data: {
        visitId: visit.id,
        competitorSku: 'Rival',
        competitorPrice: 20,
        competitorPosmType: 'shelf',
        competitorPromoterPresent: false,
        geotag: {},
        facingsCount: 10,
      },
    });

    const body = await score(visit.id);

    // 30 of ours against 10 of theirs = 75% of the shelf. Under the old rule
    // this was simply 100, because a row existed.
    expect(body.dimensionScores.competitive).toBe(75);
  });

  it('does not award full marks merely for capturing a competitor', async () => {
    const visit = await makeVisit('LOSS');
    await ownFacings(visit.id, 2);
    await prisma.visitCompetitive.create({
      data: {
        visitId: visit.id,
        competitorSku: 'Rival',
        competitorPrice: 20,
        competitorPosmType: 'shelf',
        competitorPromoterPresent: false,
        geotag: {},
        facingsCount: 18,
      },
    });

    const body = await score(visit.id);

    // We are being crushed on shelf: 2 of 20 facings. The old rule scored this
    // exactly the same as dominating it — 100.
    expect(body.dimensionScores.competitive).toBe(10);
  });

  it('treats an unmeasurable dimension as UNKNOWN, not as zero', async () => {
    const visit = await makeVisit('NONE');
    await ownFacings(visit.id, 10);
    // No competitor on shelf at all — there is nothing to take a share of.

    const body = await score(visit.id);

    // Omitted, not scored 0. A zero would drag the weighted total down for a
    // store where the agent did nothing wrong and nothing was measurable.
    expect(body.dimensionScores.competitive).toBeUndefined();
  });

  it('excludes the unknown dimension from the weighted total rather than zeroing it', async () => {
    const visit = await makeVisit('EXCL');
    await ownFacings(visit.id, 10); // visibility 80, display 80 (cleanliness 4*20)

    const body = await score(visit.id);

    // Five measurable dimensions: availability 0, visibility 80, display 80,
    // pricing 0, salesCapability 0 -> 160/5 = 32.
    //
    // Had competitive been scored 0 and included, this would be 160/6 = 26.67 —
    // the store would be punished for a dimension nobody could measure.
    expect(body.weightedTotal).toBe(32);
  });

  afterAll(async () => {
    // These suites share one live database and never truncate it, so a fixture
    // that does not clean up collides with itself on the next run (Outlet.code
    // is globally unique).
    const ids = [clientId];
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.user.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.client.deleteMany({ where: { id: { in: ids } } });
    await prisma.$disconnect();
  });
});
