import { prisma } from '../../lib/prisma';
import { userIn } from '../../test-utils/tenants';
import {
  createMapping,
  getCompetitorShelfPrices,
  listMappings,
  updateMapping,
  validateProductUrl,
} from './competitorPrices.service';

const NOW = new Date('2026-09-17T10:00:00.000Z');
const DAY = 86_400_000;
const daysAgo = (n: number) => new Date(NOW.getTime() - n * DAY);

let counter = 0;
async function tenant() {
  counter += 1;
  const client = await prisma.client.create({
    data: { name: `CPSVC-${counter}-${Date.now()}`, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
  });
  const sku = await prisma.sku.create({
    data: { clientId: client.id, name: 'Our Cola 2L', category: 'beverages', minFacingsStandard: 2, rrp: 25 },
  });
  return { clientId: client.id, skuId: sku.id };
}

async function mapped(clientId: string, input: { sku: string; slug: string; ourSkuId?: string; retailer?: string }) {
  return prisma.competitorSkuMapping.create({
    data: {
      clientId,
      competitorSku: input.sku,
      retailer: input.retailer ?? 'example',
      productUrl: `https://shop.example.test/p/${input.slug}`,
      ourSkuId: input.ourSkuId ?? null,
      createdBy: 'admin',
    },
  });
}

async function observe(
  clientId: string,
  mappingId: string,
  at: Date,
  price: number,
  promo?: { price: number; endsAt?: Date },
) {
  return prisma.competitorShelfPriceObservation.create({
    data: {
      clientId,
      mappingId,
      retailer: 'example',
      productName: 'Fizzy Cola Soft Drink 2L',
      packSize: '2L',
      shelfPrice: price,
      promoPrice: promo?.price ?? null,
      promoEndsAt: promo?.endsAt ?? null,
      sourceUrl: `https://shop.example.test/p/obs-${mappingId}`,
      retrievedAt: at,
    },
  });
}

describe('getCompetitorShelfPrices', () => {
  it('returns latest, trend and gap per mapped SKU and retailer, all labelled as outside data', async () => {
    const { clientId, skuId } = await tenant();
    const m = await mapped(clientId, { sku: 'Fizzy Cola 2L', slug: 'fizzy-2l-a', ourSkuId: skuId });
    await observe(clientId, m.id, daysAgo(20), 26);
    await observe(clientId, m.id, daysAgo(10), 27);
    await observe(clientId, m.id, daysAgo(1), 28, { price: 24, endsAt: daysAgo(-5) });

    const result = await getCompetitorShelfPrices({ clientId, now: NOW, staleAfterDays: 7 });

    expect(result.dataOrigin).toBe('outside_public_retailer_website');
    expect(result.about).toMatch(/OUTSIDE, PUBLIC data/);
    expect(result.competitorSkus).toHaveLength(1);
    const group = result.competitorSkus[0];
    // No agent-captured prices for our SKU: falls back to RRP, and says so.
    expect(group.ourSku).toMatchObject({ skuId, price: 25 });
    expect(group.ourSku!.priceBasis).toMatch(/RRP/);

    const retailer = group.retailers[0];
    expect(retailer.status).toBe('current');
    expect(retailer.latest).toMatchObject({
      shelfPrice: 28,
      promoPrice: 24,
      effectivePrice: 24,
      ageDays: 1,
      stale: false,
      provenance: {
        origin: 'outside_public_retailer_website',
        retailer: 'Example Retailer (fixture)',
        domain: 'shop.example.test',
      },
    });
    expect(retailer.latest!.provenance.url).toMatch(/^https:\/\/shop\.example\.test\//);
    expect(retailer.latest!.provenance.retrievedAt).toBe(daysAgo(1).toISOString());
    expect(retailer.trend).toMatchObject({ observations: 3, firstEffectivePrice: 26, lastEffectivePrice: 24 });
    expect(retailer.trend!.changePct).toBeCloseTo(-7.69, 2);
    expect(retailer.gapVsOurPrice).toMatchObject({ ourPrice: 25, competitorPrice: 24, gap: -1, gapPct: -4 });

    expect(result.sources).toEqual([
      expect.objectContaining({ domain: 'shop.example.test', retrievedAt: daysAgo(1).toISOString(), snippet: null }),
    ]);
  });

  it('uses our agents’ captured shelf price for the gap when there is one', async () => {
    const { clientId, skuId } = await tenant();
    const agent = await userIn(clientId, 'field_agent');
    const outlet = await prisma.outlet.create({
      data: { clientId, name: 'Spaza', code: `O-${Date.now()}`, channelType: 'informal', territoryId: 'T', lat: 0, lng: 0, acvWeight: 1 },
    });
    const visit = await prisma.visit.create({
      data: { clientId, outletId: outlet.id, agentId: agent.userId, checkinTs: daysAgo(3), checkinLat: 0, checkinLng: 0, geofencePass: true },
    });
    for (const price of [29, 31]) {
      await prisma.visitPricing.create({
        data: {
          visitId: visit.id,
          skuId,
          priceActual: price,
          priceMaster: 25,
          deviationPct: 0,
          promoActive: false,
          promoMaterialsDetected: [],
          commsRating: 3,
        },
      });
    }
    const m = await mapped(clientId, { sku: 'Fizzy Cola 2L', slug: 'fizzy-2l-b', ourSkuId: skuId });
    await observe(clientId, m.id, daysAgo(2), 27);

    const result = await getCompetitorShelfPrices({ clientId, now: NOW, staleAfterDays: 7 });

    expect(result.competitorSkus[0].ourSku).toMatchObject({ price: 30 });
    expect(result.competitorSkus[0].ourSku!.priceBasis).toMatch(/captured by our agents/);
    expect(result.competitorSkus[0].retailers[0].gapVsOurPrice).toMatchObject({ ourPrice: 30, competitorPrice: 27, gap: -3, gapPct: -10 });
  });

  it('flags a price older than the stale threshold, never calls it current, and withholds the gap', async () => {
    const { clientId, skuId } = await tenant();
    const m = await mapped(clientId, { sku: 'Old Cola 2L', slug: 'old-2l', ourSkuId: skuId });
    await observe(clientId, m.id, daysAgo(45), 22);

    const result = await getCompetitorShelfPrices({ clientId, now: NOW, staleAfterDays: 7, trendDays: 30 });
    const retailer = result.competitorSkus[0].retailers[0];

    expect(retailer.status).toBe('stale');
    expect(retailer.latest).toMatchObject({ stale: true, ageDays: 45, shelfPrice: 22 });
    expect(retailer.latest!.asOfLabel).toMatch(/^STALE: .* not a current price$/);
    expect(retailer.gapVsOurPrice).toBeNull();
    expect(retailer.gapWithheldReason).toMatch(/older than 7 days/);
    // Outside the trend window, so no trend is claimed either.
    expect(retailer.trend).toBeNull();
  });

  it('treats a promo that had already ended when read as the shelf price', async () => {
    const { clientId } = await tenant();
    const m = await mapped(clientId, { sku: 'Promo Cola', slug: 'ended-promo' });
    await observe(clientId, m.id, daysAgo(1), 30, { price: 20, endsAt: daysAgo(3) });
    const result = await getCompetitorShelfPrices({ clientId, now: NOW, staleAfterDays: 7 });
    expect(result.competitorSkus[0].retailers[0].latest!.effectivePrice).toBe(30);
    expect(result.competitorSkus[0].retailers[0].gapWithheldReason).toMatch(/no product of ours/);
  });

  it('reports a mapped SKU with no observations honestly', async () => {
    const { clientId } = await tenant();
    await mapped(clientId, { sku: 'Unread Cola', slug: 'unread' });
    const result = await getCompetitorShelfPrices({ clientId, now: NOW });
    expect(result.competitorSkus[0].retailers[0]).toMatchObject({ status: 'no_observations', latest: null, trend: null, gapVsOurPrice: null });
  });

  it('filters by competitor SKU name and says when nothing is mapped', async () => {
    const { clientId } = await tenant();
    await mapped(clientId, { sku: 'Fizzy Cola 2L', slug: 'filter-a' });
    await mapped(clientId, { sku: 'Bubbly Lemon 1L', slug: 'filter-b' });
    const one = await getCompetitorShelfPrices({ clientId, now: NOW, competitorSku: 'lemon' });
    expect(one.competitorSkus.map((g) => g.competitorSku)).toEqual(['Bubbly Lemon 1L']);
    const none = await getCompetitorShelfPrices({ clientId, now: NOW, competitorSku: 'nothing like it' });
    expect(none.competitorSkus).toEqual([]);
    expect(none.note).toMatch(/No mapped competitor SKU matches/);
  });

  it('ignores inactive mappings', async () => {
    const { clientId } = await tenant();
    const m = await mapped(clientId, { sku: 'Retired Cola', slug: 'retired' });
    await prisma.competitorSkuMapping.update({ where: { id: m.id }, data: { active: false } });
    expect((await getCompetitorShelfPrices({ clientId, now: NOW })).competitorSkus).toEqual([]);
  });

  it('never returns another tenant’s mappings or observations', async () => {
    const a = await tenant();
    const b = await tenant();
    const theirs = await mapped(b.clientId, { sku: 'Fizzy Cola 2L', slug: 'tenant-b' });
    await observe(b.clientId, theirs.id, daysAgo(1), 99);
    const mine = await mapped(a.clientId, { sku: 'Fizzy Cola 2L', slug: 'tenant-a' });

    const result = await getCompetitorShelfPrices({ clientId: a.clientId, now: NOW });

    expect(result.competitorSkus).toHaveLength(1);
    expect(result.competitorSkus[0].retailers).toHaveLength(1);
    expect(result.competitorSkus[0].retailers[0].latest).toBeNull();
    expect(JSON.stringify(result)).not.toContain(theirs.id);
    expect(JSON.stringify(result)).not.toContain('"shelfPrice":99');
    expect(mine.clientId).toBe(a.clientId);
  });
});

describe('competitor SKU mappings', () => {
  it('validates the product URL against the retailer adapter', () => {
    expect(validateProductUrl('example', 'https://shop.example.test/p/cola-2l#reviews')).toBe(
      'https://shop.example.test/p/cola-2l',
    );
    expect(() => validateProductUrl('example', 'http://shop.example.test/p/cola-2l')).toThrow(/product page URL/);
    expect(() => validateProductUrl('example', 'https://elsewhere.test/p/cola-2l')).toThrow(/product page URL/);
    expect(() => validateProductUrl('example', 'https://shop.example.test/search?q=cola')).toThrow(/product page URL/);
    expect(() => validateProductUrl('nope', 'https://shop.example.test/p/x')).toThrow(/Unknown retailer/);
  });

  it('refuses another tenant’s SKU as ourSkuId', async () => {
    const a = await tenant();
    const b = await tenant();
    await expect(
      createMapping(a.clientId, 'admin', {
        competitorSku: 'Fizzy',
        retailer: 'example',
        productUrl: 'https://shop.example.test/p/cross-sku',
        ourSkuId: b.skuId,
      }),
    ).rejects.toThrow(/not one of your SKUs/);
  });

  it('keeps mappings tenant-scoped for list and update', async () => {
    const a = await tenant();
    const b = await tenant();
    const created = await createMapping(a.clientId, 'admin', {
      competitorSku: 'Fizzy Cola 2L',
      retailer: 'example',
      productUrl: 'https://shop.example.test/p/scoped',
      ourSkuId: a.skuId,
    });
    expect((await listMappings(a.clientId)).map((m) => m.id)).toContain(created.id);
    expect((await listMappings(b.clientId)).map((m) => m.id)).not.toContain(created.id);
    await expect(updateMapping(b.clientId, created.id, { active: false })).rejects.toThrow(/not found/);
    const updated = await updateMapping(a.clientId, created.id, { active: false });
    expect(updated.active).toBe(false);
  });

  it('rejects the same product page mapped twice for one client', async () => {
    const a = await tenant();
    const input = { competitorSku: 'Fizzy', retailer: 'example', productUrl: 'https://shop.example.test/p/dupe' };
    await createMapping(a.clientId, 'admin', input);
    await expect(createMapping(a.clientId, 'admin', input)).rejects.toThrow(/already mapped/);
  });
});
