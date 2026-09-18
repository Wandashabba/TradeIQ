import { prisma } from '../../lib/prisma';
import { foreignTenant, userIn, type TestUser } from '../../test-utils/tenants';
import { comparisonRanges } from './compare';
import { territoryRankingFigures } from './figures';
import type { Period } from './period';
import { getTerritorySellInChange } from './pillars.service';

type Foreign = Awaited<ReturnType<typeof foreignTenant>>;

/**
 * Per-territory sell-in change — the data behind "Change by territory".
 *
 * Runs the real grouped order query, because the two things most likely to be
 * wrong here are exactly the ones a mock would hide: which local month an order
 * near midnight lands in, and whether another tenant's orders leak in through a
 * territory code both tenants use.
 */
describe('getTerritorySellInChange', () => {
  const TZ = 'Africa/Johannesburg';
  const NOW = new Date('2026-09-17T10:00:00.000Z');
  const AUGUST: Period = { kind: 'custom', from: '2026-08-01', to: '2026-08-31' };
  const windowsFor = (period: Period) => {
    const { current, comparison } = comparisonRanges(period, { kind: 'previous_period' }, NOW, TZ);
    return { current, comparison };
  };

  let clientId: string;
  let agent: TestUser;
  let foreign: Foreign;
  const outletByCode = new Map<string, string>();
  let foreignOutletId: string;
  let skuId: string;
  let foreignSkuId: string;

  async function order(
    outletId: string,
    quantity: number,
    capturedAt: string,
    options: { status?: string; clientId?: string; agentId?: string; skuId?: string } = {},
  ) {
    await prisma.order.create({
      data: {
        clientId: options.clientId ?? clientId,
        outletId,
        agentId: options.agentId ?? agent.userId,
        status: options.status ?? 'submitted',
        total: quantity,
        createdAt: new Date(capturedAt),
        capturedAt: new Date(capturedAt),
        lines: { create: [{ skuId: options.skuId ?? skuId, quantity, unitPrice: 1 }] },
      },
    });
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'TSC-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    agent = await userIn(clientId, 'field_agent');
    foreign = await foreignTenant('field_agent');

    const sku = (cid: string) =>
      prisma.sku.create({
        data: { clientId: cid, name: 'TSC-Cola', category: 'Beverages', minFacingsStandard: 2, rrp: 10 },
      });
    skuId = (await sku(clientId)).id;
    foreignSkuId = (await sku(foreign.clientId)).id;

    const territory = (cid: string, name: string, code: string, region: string | null) =>
      prisma.territory.create({ data: { clientId: cid, name, code, region } });
    const outlet = (cid: string, code: string, territoryCode: string) =>
      prisma.outlet.create({
        data: {
          clientId: cid,
          name: code,
          code,
          channelType: 'supermarket',
          lat: -26,
          lng: 28,
          territoryId: territoryCode,
        },
      });

    // Gauteng: two falling, two rising, one new, one tied with another.
    for (const [name, code, region] of [
      ['Soweto', 'TSC-SOW', 'Gauteng'],
      ['Tembisa', 'TSC-TEM', 'Gauteng'],
      ['Sandton', 'TSC-SAN', 'Gauteng'],
      ['Pretoria East', 'TSC-PTA', 'Gauteng'],
      ['Midrand', 'TSC-MID', 'Gauteng'],
      ['Alberton', 'TSC-ALB', 'Gauteng'],
      ['Durban North', 'TSC-DBN', 'KwaZulu-Natal'],
    ] as const) {
      await territory(clientId, name, code, region);
      outletByCode.set(code, (await outlet(clientId, `${code}-O1`, code)).id);
    }

    // Another tenant using the SAME territory code as Soweto, with big orders.
    await territory(foreign.clientId, 'Soweto', 'TSC-SOW', 'Gauteng');
    foreignOutletId = (await outlet(foreign.clientId, 'TSC-FX-O1', 'TSC-SOW')).id;

    const o = (code: string) => outletByCode.get(code)!;

    // July (comparison) and August (current), in SAST.
    await order(o('TSC-SOW'), 100, '2026-07-10T10:00:00Z');
    await order(o('TSC-SOW'), 69, '2026-08-10T10:00:00Z'); // −31%
    await order(o('TSC-TEM'), 200, '2026-07-11T10:00:00Z');
    await order(o('TSC-TEM'), 182, '2026-08-11T10:00:00Z'); // −9%
    await order(o('TSC-SAN'), 50, '2026-07-12T10:00:00Z');
    await order(o('TSC-SAN'), 52, '2026-08-12T10:00:00Z'); // +4%
    await order(o('TSC-PTA'), 100, '2026-07-13T10:00:00Z');
    await order(o('TSC-PTA'), 107, '2026-08-13T10:00:00Z'); // +7%
    // Alberton ties Sandton at +4%, so the tie breaks by name.
    await order(o('TSC-ALB'), 25, '2026-07-14T10:00:00Z');
    await order(o('TSC-ALB'), 26, '2026-08-14T10:00:00Z'); // +4%
    // Midrand: nothing in July, so no percentage exists.
    await order(o('TSC-MID'), 40, '2026-08-15T10:00:00Z');
    // A cancelled order is not sell-in.
    await order(o('TSC-PTA'), 999, '2026-08-16T10:00:00Z', { status: 'cancelled' });

    // Local-month boundary. 31 Jul 23:30 SAST is 21:30Z — July, not August.
    await order(o('TSC-DBN'), 10, '2026-07-31T21:30:00Z');
    // 1 Sep 00:30 SAST is 31 Aug 22:30Z — September, not August.
    await order(o('TSC-DBN'), 500, '2026-08-31T22:30:00Z');
    // 31 Aug 23:30 SAST is 21:30Z — August.
    await order(o('TSC-DBN'), 15, '2026-08-31T21:30:00Z');

    // The other tenant, on the shared code, in both months.
    await order(foreignOutletId, 5000, '2026-07-10T10:00:00Z', {
      clientId: foreign.clientId,
      agentId: foreign.userId,
      skuId: foreignSkuId,
    });
    await order(foreignOutletId, 1, '2026-08-10T10:00:00Z', {
      clientId: foreign.clientId,
      agentId: foreign.userId,
      skuId: foreignSkuId,
    });
  });

  afterAll(async () => {
    const clientIds = [clientId, foreign.clientId];
    await prisma.orderLine.deleteMany({ where: { order: { clientId: { in: clientIds } } } });
    await prisma.order.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  const run = (region?: string) =>
    getTerritorySellInChange({
      clientId,
      timeZone: TZ,
      ...windowsFor(AUGUST),
      ...(region ? { region } : {}),
    });

  it('computes signed changes and ranks worst first, ties by name', async () => {
    const result = await run('Gauteng');

    expect(result.territories.map((t) => [t.territoryName, t.changePct])).toEqual([
      ['Soweto', -31],
      ['Tembisa', -9],
      ['Alberton', 4],
      ['Sandton', 4],
      ['Pretoria East', 7],
    ]);
    expect(result.territories[0]).toMatchObject({ sellInUnits: 69, comparisonSellInUnits: 100 });
    expect(result.metric).toBe('sell_in_units');
    expect(result.basis).toMatch(/NOT consumer sell-out/);
  });

  it('excludes a territory with no comparison sell-in rather than showing ±∞ or 0', async () => {
    const result = await run('Gauteng');
    expect(result.territories.map((t) => t.territoryName)).not.toContain('Midrand');
    expect(result.excludedNoComparison).toEqual([
      expect.objectContaining({ territoryName: 'Midrand', sellInUnits: 40 }),
    ]);
  });

  it('never counts another tenant on a shared territory code', async () => {
    const result = await run('Gauteng');
    const soweto = result.territories.find((t) => t.territoryName === 'Soweto');
    // 5000 foreign units in July would make this about −99%; 1 in August +1.
    expect(soweto).toMatchObject({ sellInUnits: 69, comparisonSellInUnits: 100, changePct: -31 });
    // And the foreign territory row itself is not in this client's list.
    expect(result.territories.filter((t) => t.territoryName === 'Soweto')).toHaveLength(1);
  });

  it('dates orders by the client-local calendar month', async () => {
    const result = await run('KwaZulu-Natal');
    // July: the 23:30 SAST order on 31 Jul (10). August: only the 23:30 SAST
    // order on 31 Aug (15) — the 00:30 SAST 1 Sep order belongs to September.
    expect(result.territories).toEqual([
      expect.objectContaining({
        territoryName: 'Durban North',
        sellInUnits: 15,
        comparisonSellInUnits: 10,
        changePct: 50,
      }),
    ]);
  });

  it('sums the territories in scope, with cancelled orders excluded', async () => {
    const result = await run('Gauteng');
    expect(result.totalSellInUnits).toBe(69 + 182 + 52 + 107 + 26 + 40);
    expect(result.comparisonTotalSellInUnits).toBe(100 + 200 + 50 + 100 + 25);
  });

  it('matches the region case-insensitively, and returns every territory with none', async () => {
    expect((await run('gauteng')).territories).toHaveLength(5);
    const all = await run();
    expect(all.territories.map((t) => t.territoryName)).toContain('Durban North');
    expect(all.region).toBeNull();
  });

  it('draws diverging bars and a headline tile from the same result', async () => {
    const result = await run('Gauteng');
    const figures = territoryRankingFigures(result, {
      timeZone: TZ,
      current: windowsFor(AUGUST).current,
      comparison: { range: windowsFor(AUGUST).comparison, basis: { kind: 'previous_period' } },
    });

    expect(figures).toEqual([
      {
        type: 'stat_tiles',
        data: {
          outsideData: false,
          tiles: [
            {
              label: 'Sell-in, units',
              value: 476,
              unit: 'units',
              decimals: 0,
              // Territories in scope, both windows — a ranking over five is a
              // different claim from one over fifty.
              sampleSize: 5,
              baselineSampleSize: 5,
              delta: { value: 0.2, unit: 'pct', direction: 'up', sentiment: 'good' },
              comparedTo: "vs 475 · Jul '26",
            },
          ],
        },
      },
      {
        type: 'ranked_bars',
        data: {
          title: 'Change by territory',
          comparedTo: "vs Jul '26",
          unit: 'pct',
          decimals: 1,
          sampleSize: 5,
          baselineSampleSize: 5,
          outsideData: false,
          // Worst first, so the head of the list is the bar the answer is about.
          focusIndex: 0,
          items: [
            { label: 'Soweto', value: -31, sampleSize: null },
            { label: 'Tembisa', value: -9, sampleSize: null },
            { label: 'Alberton', value: 4, sampleSize: null },
            { label: 'Sandton', value: 4, sampleSize: null },
            { label: 'Pretoria East', value: 7, sampleSize: null },
          ],
        },
      },
    ]);
  });
});
