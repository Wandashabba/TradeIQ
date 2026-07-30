import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';

import { userIn } from '../../test-utils/tenants';

/**
 * #93 — two dashboard KPIs were proxies dressed as measurements:
 *
 *  - `weightedDistribution` was literally assigned `= numericDistribution`, so
 *    the console showed two tiles, two labels, and always the same number.
 *  - `shareOfShelf` divided by the COUNT of competitive rows, so a competitor
 *    holding a whole shelf counted the same as one holding a single can — the
 *    denominator measured how much an agent typed, not what was on the shelf.
 */
describe('dashboard KPI integrity (#93)', () => {
  let clientId: string;
  let managerToken: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'DI-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager')).token;

    const agent = await prisma.user.create({
      data: { email: 'di-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });

    // A hypermarket worth 9x a kiosk, and the kiosk. Only the KIOSK gets visited.
    const hyper = await prisma.outlet.create({
      data: {
        name: 'DI-Hypermarket',
        code: 'DI-001',
        channelType: 'hypermarket',
        lat: -26.2,
        lng: 28.0,
        territoryId: 'di-t1',
        clientId,
        acvWeight: 9,
      },
    });
    const kiosk = await prisma.outlet.create({
      data: {
        name: 'DI-Kiosk',
        code: 'DI-002',
        channelType: 'kiosk',
        lat: -26.1,
        lng: 28.1,
        territoryId: 'di-t1',
        clientId,
        acvWeight: 1,
      },
    });
    void hyper;

    const visit = await prisma.visit.create({
      data: {
        outletId: kiosk.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00Z'),
        checkinLat: -26.1,
        checkinLng: 28.1,
        geofencePass: true,
        status: 'submitted',
      },
    });

    // We hold 10 facings.
    await prisma.visitVisibility.create({
      data: {
        visitId: visit.id,
        brandingElements: {},
        planogramCompliancePct: 80,
        facingsCount: { total: 10 },
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
    });

    // ONE competitor row — but it holds 30 facings. Under the old row-count
    // proxy this looked like a single facing.
    await prisma.visitCompetitive.create({
      data: {
        visitId: visit.id,
        competitorSku: 'RivalCola 500ml',
        competitorPrice: 20,
        competitorPosmType: 'end_cap',
        competitorPromoterPresent: false,
        geotag: {},
        facingsCount: 30,
      },
    });
  });

  it('weights distribution by outlet ACV — it is no longer numeric distribution', async () => {
    const res = await request(app).get('/dashboard').set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);

    // 1 of 2 outlets visited.
    expect(res.body.kpis.numericDistribution).toBe(50);

    // But the visited outlet is the kiosk: 1 of 10 ACV points. Covering half the
    // outlets is emphatically not covering half the business, and the two
    // figures must now be able to disagree.
    expect(res.body.kpis.weightedDistribution).toBe(10);
    expect(res.body.kpis.weightedDistribution).not.toBe(res.body.kpis.numericDistribution);
  });

  it('computes share of shelf from facings, not from the competitive row count', async () => {
    const res = await request(app).get('/dashboard').set('Authorization', `Bearer ${managerToken}`);

    // 10 of ours vs 30 of theirs = 25%.
    //
    // The old proxy counted the single competitive ROW as one facing and would
    // have reported 10/(10+1) = 90.91% — i.e. it would have told a manager we
    // dominate a shelf we are actually losing 3:1.
    expect(res.body.kpis.shareOfShelf).toBe(25);
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
