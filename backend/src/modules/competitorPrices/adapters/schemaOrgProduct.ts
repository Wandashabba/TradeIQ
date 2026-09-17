import { ShelfPriceParseError, type ParsedShelfPrice } from './types';

/**
 * Read a shelf price from a page's schema.org `Product` structured data
 * (JSON-LD) — the markup retailers publish precisely so machines can read a
 * product's name and price.
 *
 * **A whitelist, not a scrape of the page.** Only `name`, `size`/`weight`,
 * and the offer's `price`, `priceCurrency`, `priceValidUntil` and a
 * `StrikethroughPrice`/`ListPrice` price specification are read. Everything
 * else in the block — `review`, `aggregateRating`, authors, sellers — is never
 * touched, so there is no path by which personal data or reviews are kept.
 *
 * Price semantics:
 * - one price → that is the shelf price, no promo;
 * - a strikethrough/list price ABOVE the offer price → the strikethrough is the
 *   shelf price, the offer price is the promo, and `priceValidUntil` (when
 *   shown) is when the promo ends.
 */

const MAX_PRICE = 100_000;
const JSON_LD = /<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
const PACK_SIZE = /\b(\d+\s*[x×]\s*)?\d+(?:[.,]\d+)?\s*(ml|l|lt|litre|g|kg|s|pack|pk|ea)\b/i;

type Json = unknown;

function isRecord(value: Json): value is Record<string, Json> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function typesOf(node: Record<string, Json>): string[] {
  const t = node['@type'];
  return (Array.isArray(t) ? t : [t]).filter((x): x is string => typeof x === 'string');
}

/** Every object in a JSON-LD document, through arrays and `@graph`. */
function* nodes(value: Json): Generator<Record<string, Json>> {
  if (Array.isArray(value)) {
    for (const item of value) yield* nodes(item);
  } else if (isRecord(value)) {
    yield value;
    if (Array.isArray(value['@graph'])) yield* nodes(value['@graph']);
  }
}

function cleanText(value: Json, max: number): string | null {
  if (typeof value !== 'string') return null;
  const text = value
    .replace(/<[^>]*>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&quot;/g, '"')
    // Control characters never belong in a product name.
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text === '' ? null : text.slice(0, max);
}

function priceOf(value: Json): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' ? Number(value.replace(/[^\d.]/g, '')) : NaN;
  return Number.isFinite(n) && n > 0 && n < MAX_PRICE ? Math.round(n * 100) / 100 : null;
}

function dateOf(value: Json): Date | null {
  if (typeof value !== 'string') return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function packSizeOf(product: Record<string, Json>, name: string): string | null {
  for (const key of ['size', 'weight']) {
    const v = product[key];
    if (typeof v === 'string') return cleanText(v, 40);
    if (isRecord(v) && (typeof v.value === 'number' || typeof v.value === 'string')) {
      const unit = cleanText(v.unitText ?? v.unitCode ?? '', 10) ?? '';
      return `${v.value}${unit}`.slice(0, 40);
    }
  }
  const match = PACK_SIZE.exec(name);
  return match ? match[0].replace(/\s+/g, '') : null;
}

function firstOffer(offers: Json): Record<string, Json> | null {
  for (const node of nodes(offers)) {
    const types = typesOf(node);
    if (types.includes('Offer') || types.includes('AggregateOffer') || 'price' in node || 'lowPrice' in node) {
      return node;
    }
  }
  return null;
}

function regularPriceOf(offer: Record<string, Json>): number | null {
  for (const spec of nodes(offer.priceSpecification)) {
    const priceType = typeof spec.priceType === 'string' ? spec.priceType : '';
    if (/StrikethroughPrice|ListPrice|SRP|MSRP/i.test(priceType)) {
      const price = priceOf(spec.price);
      if (price !== null) return price;
    }
  }
  return null;
}

export function parseSchemaOrgProduct(html: string): ParsedShelfPrice {
  const products: Record<string, Json>[] = [];
  for (const match of html.matchAll(JSON_LD)) {
    let doc: Json;
    try {
      doc = JSON.parse(match[1]);
    } catch {
      continue; // one malformed block does not spoil the others
    }
    for (const node of nodes(doc)) if (typesOf(node).includes('Product')) products.push(node);
  }
  if (products.length === 0) throw new ShelfPriceParseError('no schema.org Product structured data');
  if (products.length > 1) {
    // A listing or a "you may also like" block. Picking one would be a guess.
    throw new ShelfPriceParseError(`found ${products.length} products on the page; expected one`);
  }

  const product = products[0];
  const productName = cleanText(product.name, 200);
  if (!productName) throw new ShelfPriceParseError('product has no name');

  const offer = firstOffer(product.offers);
  if (!offer) throw new ShelfPriceParseError('product has no offer');
  const currency = typeof offer.priceCurrency === 'string' ? offer.priceCurrency.toUpperCase() : 'ZAR';
  if (currency !== 'ZAR') throw new ShelfPriceParseError(`price is in ${currency}, not ZAR`);

  const offerPrice = priceOf(offer.price ?? offer.lowPrice);
  if (offerPrice === null) throw new ShelfPriceParseError('offer has no usable price');

  const regular = regularPriceOf(offer);
  const onPromo = regular !== null && regular > offerPrice;

  return {
    productName,
    packSize: packSizeOf(product, productName),
    shelfPrice: onPromo ? regular : offerPrice,
    promoPrice: onPromo ? offerPrice : null,
    promoEndsAt: onPromo ? dateOf(offer.priceValidUntil) : null,
  };
}
