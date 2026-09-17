import { parseSchemaOrgProduct } from './schemaOrgProduct';
import { ShelfPriceParseError, type RetailerAdapter } from './types';

export type { ParsedShelfPrice, RetailerAdapter } from './types';
export { ShelfPriceParseError } from './types';

/**
 * The retailer adapters.
 *
 * **One is implemented, and it points at nothing real.** `example` lives on
 * `shop.example.test` — a reserved domain that never resolves — and is
 * exercised against a local fixture page in the tests. It shows the whole path
 * (URL rules, robots.txt, spacing, parsing, storage) working end to end.
 *
 * **Every real retailer is a stub.** Nobody has reviewed their terms of use,
 * and nobody has looked at their pages: no request has ever been sent to any
 * of them from this code, including while writing it. A stub's parser throws,
 * and the collector never fetches for a stub. Turning one into an adapter is
 * the checklist in docs/operations/competitor-price-collection.md, starting
 * with the legal review — not with the parser.
 */

const stubParser = (id: string) => (): never => {
  throw new ShelfPriceParseError(`${id} adapter is a stub and cannot parse pages`);
};

function stub(input: {
  id: string;
  displayName: string;
  baseUrl: string;
  hosts: string[];
  productUrlPattern: RegExp;
  searchPath: (q: string) => string;
}): RetailerAdapter {
  return {
    id: input.id,
    displayName: input.displayName,
    status: 'stub',
    baseUrl: input.baseUrl,
    allowedHosts: input.hosts,
    productUrlPattern: input.productUrlPattern,
    searchUrl: (q) => `${input.baseUrl}${input.searchPath(encodeURIComponent(q))}`,
    parseProductPage: stubParser(input.id),
    todo:
      'TODO before implementing: (1) legal review of the terms of use, signed off; (2) ask whether ' +
      'the retailer offers a product feed or API and use it if so; (3) read robots.txt by hand; ' +
      '(4) confirm the product-page URL pattern and search path below from the public site, ' +
      'by a person, not by this code; (5) write the parser against a saved fixture page, with tests.',
  };
}

export const exampleAdapter: RetailerAdapter = {
  id: 'example',
  displayName: 'Example Retailer (fixture)',
  status: 'implemented',
  fixtureOnly: true,
  baseUrl: 'https://shop.example.test',
  allowedHosts: ['shop.example.test'],
  productUrlPattern: /^https:\/\/shop\.example\.test\/p\/[a-z0-9-]+\/?$/,
  searchUrl: (q) => `https://shop.example.test/search?q=${encodeURIComponent(q)}`,
  parseProductPage: (html) => parseSchemaOrgProduct(html),
};

/*
 * The stubs below are unverified. Base URLs are the retailers' public
 * addresses; the product and search patterns are PLACEHOLDERS to be confirmed
 * by a person during implementation (see `todo`). They exist so an admin can
 * see which retailers are planned and so the mapping API rejects unknown ids.
 */

export const checkersAdapter = stub({
  id: 'checkers',
  displayName: 'Checkers',
  baseUrl: 'https://www.checkers.co.za',
  hosts: ['www.checkers.co.za'],
  // TODO: confirm the product page pattern.
  productUrlPattern: /^https:\/\/www\.checkers\.co\.za\/.+\/p\/[\w-]+$/,
  searchPath: (q) => `/search?q=${q}`,
});

export const picknpayAdapter = stub({
  id: 'picknpay',
  displayName: 'Pick n Pay',
  baseUrl: 'https://www.pnp.co.za',
  hosts: ['www.pnp.co.za'],
  // TODO: confirm the product page pattern.
  productUrlPattern: /^https:\/\/www\.pnp\.co\.za\/.+\/p\/[\w-]+$/,
  searchPath: (q) => `/search/${q}`,
});

export const shopriteAdapter = stub({
  id: 'shoprite',
  displayName: 'Shoprite',
  baseUrl: 'https://www.shoprite.co.za',
  hosts: ['www.shoprite.co.za'],
  // TODO: confirm the product page pattern.
  productUrlPattern: /^https:\/\/www\.shoprite\.co\.za\/.+\/p\/[\w-]+$/,
  searchPath: (q) => `/search?q=${q}`,
});

export const makroAdapter = stub({
  id: 'makro',
  displayName: 'Makro',
  baseUrl: 'https://www.makro.co.za',
  hosts: ['www.makro.co.za'],
  // TODO: confirm the product page pattern.
  productUrlPattern: /^https:\/\/www\.makro\.co\.za\/.+\/p\/[\w-]+$/,
  searchPath: (q) => `/search/?text=${q}`,
});

export const woolworthsAdapter = stub({
  id: 'woolworths',
  displayName: 'Woolworths',
  baseUrl: 'https://www.woolworths.co.za',
  hosts: ['www.woolworths.co.za'],
  // TODO: confirm the product page pattern.
  productUrlPattern: /^https:\/\/www\.woolworths\.co\.za\/prod\/.+$/,
  searchPath: (q) => `/cat?Ntt=${q}`,
});

export const RETAILER_ADAPTERS: readonly RetailerAdapter[] = [
  exampleAdapter,
  checkersAdapter,
  picknpayAdapter,
  shopriteAdapter,
  makroAdapter,
  woolworthsAdapter,
];

export const RETAILER_IDS = RETAILER_ADAPTERS.map((a) => a.id) as [string, ...string[]];

export function adapterFor(id: string): RetailerAdapter | undefined {
  return RETAILER_ADAPTERS.find((a) => a.id === id);
}
