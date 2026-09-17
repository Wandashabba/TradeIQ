import { readFileSync } from 'fs';
import { join } from 'path';
import { RETAILER_ADAPTERS, ShelfPriceParseError, adapterFor, exampleAdapter } from './index';
import { parseSchemaOrgProduct } from './schemaOrgProduct';

const fixture = (name: string) => readFileSync(join(__dirname, '..', '__fixtures__', name), 'utf8');

describe('the example adapter, on local fixture pages', () => {
  it('reads name, pack size and a regular shelf price', () => {
    const parsed = exampleAdapter.parseProductPage(fixture('example-product.html'), 'https://shop.example.test/p/fizzy-cola-2l');
    expect(parsed).toEqual({
      productName: 'Fizzy Cola Soft Drink 2L',
      packSize: '2L',
      shelfPrice: 24.99,
      promoPrice: null,
      promoEndsAt: null,
    });
  });

  it('reads a promo: strikethrough is the shelf price, the offer is the promo, with its end date', () => {
    const parsed = exampleAdapter.parseProductPage(fixture('example-product-promo.html'), 'https://shop.example.test/p/x');
    expect(parsed).toEqual({
      productName: 'Fizzy Cola & Lime 6 x 330ml',
      packSize: '6x330ml',
      shelfPrice: 74.99,
      promoPrice: 59.99,
      promoEndsAt: new Date('2026-09-30T21:59:59Z'),
    });
  });

  it('keeps nothing but the whitelisted fields — no reviews, ratings or people', () => {
    const parsed = exampleAdapter.parseProductPage(fixture('example-product.html'), 'https://shop.example.test/p/x');
    const text = JSON.stringify(parsed);
    expect(Object.keys(parsed).sort()).toEqual(['packSize', 'productName', 'promoEndsAt', 'promoPrice', 'shelfPrice']);
    expect(text).not.toMatch(/Thandi|review|rating|@example/i);
  });

  it('refuses to guess on a page with several products', () => {
    expect(() => parseSchemaOrgProduct(fixture('example-listing.html'))).toThrow(/2 products/);
  });

  it('refuses a page with no product data (e.g. a bot wall)', () => {
    expect(() => parseSchemaOrgProduct(fixture('example-bot-wall.html'))).toThrow(ShelfPriceParseError);
  });

  it('refuses a price that is not in rand, or is not a price', () => {
    const page = (offer: object) =>
      `<script type="application/ld+json">${JSON.stringify({ '@type': 'Product', name: 'X 1L', offers: offer })}</script>`;
    expect(() => parseSchemaOrgProduct(page({ price: '2.50', priceCurrency: 'USD' }))).toThrow(/USD/);
    expect(() => parseSchemaOrgProduct(page({ price: 'call us', priceCurrency: 'ZAR' }))).toThrow(/usable price/);
    expect(() => parseSchemaOrgProduct(page({ price: 0, priceCurrency: 'ZAR' }))).toThrow(/usable price/);
  });

  it('skips a malformed JSON-LD block instead of failing the page', () => {
    const html = `<script type="application/ld+json">{ not json</script>${fixture('example-product.html')}`;
    expect(parseSchemaOrgProduct(html).shelfPrice).toBe(24.99);
  });

  it('is fixture-only, on a reserved .test domain', () => {
    expect(exampleAdapter.fixtureOnly).toBe(true);
    expect(exampleAdapter.allowedHosts).toEqual(['shop.example.test']);
    expect(exampleAdapter.productUrlPattern.test('https://shop.example.test/p/fizzy-cola-2l')).toBe(true);
    expect(exampleAdapter.productUrlPattern.test('https://shop.example.test/search?q=cola')).toBe(false);
  });
});

describe('the retailer registry', () => {
  it('ships exactly one implemented adapter, and it is the fixture example', () => {
    expect(RETAILER_ADAPTERS.filter((a) => a.status === 'implemented').map((a) => a.id)).toEqual(['example']);
  });

  it.each(['checkers', 'picknpay', 'shoprite', 'makro', 'woolworths'])('%s is a documented stub that cannot parse', (id) => {
    const adapter = adapterFor(id)!;
    expect(adapter.status).toBe('stub');
    expect(adapter.todo).toMatch(/legal review/);
    expect(adapter.baseUrl).toMatch(/^https:\/\//);
    expect(() => adapter.parseProductPage('<html></html>', adapter.baseUrl)).toThrow(/stub/);
  });

  it('has unique ids and https base URLs on an allowed host', () => {
    const ids = RETAILER_ADAPTERS.map((a) => a.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const adapter of RETAILER_ADAPTERS) {
      expect(adapter.allowedHosts).toContain(new URL(adapter.baseUrl).hostname);
    }
  });

  it('builds a search URL for an admin to look products up by hand', () => {
    expect(exampleAdapter.searchUrl('cola 2l')).toBe('https://shop.example.test/search?q=cola%202l');
  });
});
