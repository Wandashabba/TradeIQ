import { prisma } from '../lib/prisma';
import { fetchStockHistoryForOutlet } from './stock-derived.service';

describe('fetchStockHistoryForOutlet', () => {
  let clientId: string;
  let agentId: string;
  let outletId: string;
  let otherOutletId: string;
  let skuAId: string;
  let skuBId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Stock History Fetch Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'stock-history-fetch-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Stock History Fetch Outlet',
        code: 'SHF-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'Stock History Fetch Other Outlet',
        code: 'SHF-002',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    otherOutletId = otherOutlet.id;

    const skuA = await prisma.sku.create({
      data: { clientId, name: 'History Fetch SKU A', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuAId = skuA.id;

    const skuB = await prisma.sku.create({
      data: { clientId, name: 'History Fetch SKU B', category: 'Beverages', minFacingsStandard: 4, rrp: 9.99 },
    });
    skuBId = skuB.id;

    const now = new Date();
    const daysAgo = (n: number) => new Date(now.getTime() - n * 24 * 60 * 60 * 1000);

    // 7 Visit+VisitStock pairs for SKU A at outletId, staggered 1 day apart.
    // unitsAvailable set to (7 - daysAgoIndex) so the newest (1 day ago) has
    // the highest value and is unambiguously identifiable.
    for (let i = 7; i >= 1; i -= 1) {
      const visit = await prisma.visit.create({
        data: {
          outletId,
          agentId,
          clientId,
          checkinTs: daysAgo(i),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
      });
      await prisma.visitStock.create({
        data: {
          visitId: visit.id,
          skuId: skuAId,
          unitsAvailable: 100 - i,
          lastStockinDate: daysAgo(i),
          daysOutOfStock: 0,
          velocityAvg: 0,
          coverageDaysPredicted: 0,
        },
      });
    }

    // 1 Visit+VisitStock pair for SKU B at outletId.
    const visitB = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: daysAgo(2),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visitB.id,
        skuId: skuBId,
        unitsAvailable: 50,
        lastStockinDate: daysAgo(2),
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });

    // 1 Visit+VisitStock pair for SKU A at a DIFFERENT outlet (same client),
    // with an extreme unitsAvailable value to prove outlet-scoping.
    const foreignVisit = await prisma.visit.create({
      data: {
        outletId: otherOutletId,
        agentId,
        clientId,
        checkinTs: daysAgo(1),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: foreignVisit.id,
        skuId: skuAId,
        unitsAvailable: 999,
        lastStockinDate: daysAgo(1),
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });
  });

  afterAll(async () => {
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('caps history at 5 rows per SKU, orders newest-first, and scopes to the outlet', async () => {
    const history = await fetchStockHistoryForOutlet(outletId, clientId);

    expect(history.size).toBe(2);

    const skuAHistory = history.get(skuAId);
    expect(skuAHistory).toBeDefined();
    expect(skuAHistory).toHaveLength(5);

    // Newest-first: visitCheckinTs strictly descending.
    for (let i = 0; i < skuAHistory!.length - 1; i += 1) {
      expect(skuAHistory![i].visitCheckinTs.getTime()).toBeGreaterThan(skuAHistory![i + 1].visitCheckinTs.getTime());
    }

    // Newest row (1 day ago) is the 7th seeded row: unitsAvailable = 100 - 1 = 99.
    expect(skuAHistory![0].unitsAvailable).toBe(99);

    // The foreign-outlet row's 999 value never appears in SKU A's array.
    expect(skuAHistory!.some((row) => row.unitsAvailable === 999)).toBe(false);

    const skuBHistory = history.get(skuBId);
    expect(skuBHistory).toBeDefined();
    expect(skuBHistory).toHaveLength(1);
    expect(skuBHistory![0].unitsAvailable).toBe(50);
  });

  it('breaks a checkin_ts tie using created_at DESC', async () => {
    const skuC = await prisma.sku.create({
      data: { clientId, name: 'History Fetch SKU C', category: 'Beverages', minFacingsStandard: 4, rrp: 12.99 },
    });

    const sameCheckinTs = new Date();

    // Two Visit+VisitStock pairs sharing the exact same checkinTs, created in
    // sequence (each a real DB round trip apart) so created_at naturally
    // differs by at least a millisecond -- Postgres timestamp resolution is
    // finer than that, so no explicit sleep is needed.
    const visit1 = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: sameCheckinTs,
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    const stock1 = await prisma.visitStock.create({
      data: {
        visitId: visit1.id,
        skuId: skuC.id,
        unitsAvailable: 10,
        lastStockinDate: sameCheckinTs,
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });

    const visit2 = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: sameCheckinTs,
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    const stock2 = await prisma.visitStock.create({
      data: {
        visitId: visit2.id,
        skuId: skuC.id,
        unitsAvailable: 20,
        lastStockinDate: sameCheckinTs,
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });

    // Sanity check the premise: same checkinTs, but created_at genuinely
    // differs (stock2 created after stock1).
    expect(stock2.createdAt.getTime()).toBeGreaterThan(stock1.createdAt.getTime());

    const history = await fetchStockHistoryForOutlet(outletId, clientId);
    const skuCHistory = history.get(skuC.id);
    expect(skuCHistory).toBeDefined();
    expect(skuCHistory).toHaveLength(2);

    // Same checkinTs for both rows -- the tiebreaker (created_at DESC) must
    // put the later-created row (stock2, unitsAvailable 20) first.
    expect(skuCHistory![0].visitCheckinTs.getTime()).toBe(skuCHistory![1].visitCheckinTs.getTime());
    expect(skuCHistory![0].unitsAvailable).toBe(20);
    expect(skuCHistory![1].unitsAvailable).toBe(10);
  });
});
