import { prisma } from '../lib/prisma';
import { recordStock } from '../modules/stock/stock.service';
import { fetchLastInStockForOutlet } from './stock-derived.service';

/**
 * #360 — days out of stock for a chronic stock-out.
 *
 * The derivation used to read only the outlet's last five counts, so a shelf
 * that had been empty for longer than that found no in-stock row and stored 0
 * days: the longest stock-outs vanished from every ranking built on the column.
 */
describe('days out of stock over a chronic stock-out (#360)', () => {
  const DAY = 24 * 60 * 60 * 1000;
  const now = new Date();
  const daysAgo = (n: number) => new Date(now.getTime() - n * DAY);

  let clientId: string;
  let foreignClientId: string;
  let agentId: string;
  let outletId: string;
  let skuId: string;

  async function count(checkinTs: Date, unitsAvailable: number): Promise<string> {
    const visit = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs,
        checkinLat: -29.85,
        checkinLng: 31.02,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visit.id,
        skuId,
        unitsAvailable,
        lastStockinDate: checkinTs,
        daysOutOfStock: 0,
        velocityAvg: 0,
        coverageDaysPredicted: 0,
      },
    });
    return visit.id;
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Chronic OOS Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    foreignClientId = (
      await prisma.client.create({
        data: { name: 'Chronic OOS Foreign', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      })
    ).id;
    agentId = (
      await prisma.user.create({
        data: {
          email: `chronic-oos-${Date.now()}@example.test`,
          passwordHash: 'x',
          role: 'field_agent',
          clientId,
        },
      })
    ).id;
    outletId = (
      await prisma.outlet.create({
        data: {
          clientId,
          name: 'Chronic OOS Spaza',
          code: 'COOS-1',
          channelType: 'spaza',
          lat: -29.85,
          lng: 31.02,
          territoryId: 'KZN',
        },
      })
    ).id;
    skuId = (
      await prisma.sku.create({
        data: { clientId, name: 'Kalahari Cola 2L', category: 'Beverages', minFacingsStandard: 2, rrp: 25 },
      })
    ).id;

    // In stock 32 days ago, then empty on 30 consecutive daily counts.
    await count(daysAgo(32), 24);
    for (let n = 31; n >= 2; n -= 1) await count(daysAgo(n), 0);
  });

  afterAll(async () => {
    await prisma.task.deleteMany({ where: { outletId } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, foreignClientId] } } });
  });

  it('finds the last in-stock count however far back it is', async () => {
    const lastInStock = await fetchLastInStockForOutlet(outletId, clientId);
    expect(lastInStock.get(skuId)?.getTime()).toBe(daysAgo(32).getTime());
  });

  it('is tenant-scoped: another client asking for the same outlet sees nothing', async () => {
    expect((await fetchLastInStockForOutlet(outletId, foreignClientId)).size).toBe(0);
  });

  it('stores the true duration on capture after 30 empty counts, not 0', async () => {
    const visitId = await count(daysAgo(1), 0);
    // `count` wrote a placeholder row for this visit; capture writes its own.
    await prisma.visitStock.deleteMany({ where: { visitId } });

    const rows = await recordStock({
      visitId,
      clientId,
      agentId,
      items: [{ skuId, unitsAvailable: 0, lastStockinDate: daysAgo(32).toISOString() }],
    });

    expect(rows).toHaveLength(1);
    expect(rows[0].daysOutOfStock).toBe(31);
  });
});
