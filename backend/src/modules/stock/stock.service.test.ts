import { prisma } from '../../lib/prisma';
import { ValidationError } from '../../middleware/errorHandler';
import { recordStock } from './stock.service';

// stock.routes.test.ts already proves POST /stock rejects duplicate skuId
// with a 400 -- but that only shows the route's own fast-fail check works.
// This file proves the invariant holds in recordStock itself, independent of
// any caller: bypass the route entirely (no requireAuth/requireRole, no
// isValidItem shape guard) and call the service directly, the way a script,
// admin tool, or future bulk-import path might (#121).
describe('stock service: recordStock', () => {
  let clientId: string;
  let agentId: string;
  let visitId: string;
  let skuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Stock Service Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'stock-service-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Stock Service Outlet',
        code: 'STOCK-SVC-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;

    const sku = await prisma.sku.create({
      data: { clientId, name: 'Stock Service Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;
  });

  afterAll(async () => {
    await prisma.task.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validItem = () => ({
    skuId,
    unitsAvailable: 20,
    lastStockinDate: '2026-07-01T00:00:00.000Z',
  });

  it('rejects duplicate skuId within items[] even when called directly, bypassing the route guard (#121)', async () => {
    const before = await prisma.visitStock.count({ where: { visitId, skuId } });

    await expect(
      recordStock({
        visitId,
        clientId,
        agentId,
        items: [validItem(), { ...validItem(), unitsAvailable: 5 }],
      }),
    ).rejects.toThrow(ValidationError);

    // No transaction, no rows -- the guard runs before any write is
    // attempted.
    const after = await prisma.visitStock.count({ where: { visitId, skuId } });
    expect(after).toBe(before);
  });
});
