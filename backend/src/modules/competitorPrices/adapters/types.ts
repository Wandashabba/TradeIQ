import type { PoliteFetcher } from '../politeFetcher';

/**
 * The retailer adapter contract.
 *
 * One adapter per retailer, and each is **configuration plus a parser**: where
 * the retailer lives, what its product and search URLs look like, and how to
 * read a price off one of its pages. The adapter never sends a request itself —
 * the collector hands its URLs to `PoliteFetcher`, which is where robots.txt,
 * rate limits and block handling live. An adapter therefore cannot opt out of
 * them.
 *
 * Adding one: docs/operations/competitor-price-collection.md → "Adding an
 * adapter".
 */

/** What is collected from a page. Nothing else is read or kept. */
export interface ParsedShelfPrice {
  productName: string;
  packSize: string | null;
  /** The regular price, in ZAR. */
  shelfPrice: number;
  /** A promotional price, only when the page shows one. */
  promoPrice: number | null;
  promoEndsAt: Date | null;
}

export class ShelfPriceParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ShelfPriceParseError';
  }
}

/**
 * An official product feed or API. Where a retailer offers one — and its terms
 * allow this use — it is preferred over reading public pages, and the collector
 * uses it instead of `parseProductPage`.
 */
export interface OfficialFeed {
  /** What the feed is and where its terms are, for the operations doc. */
  description: string;
  /**
   * Requests go through the SAME polite fetcher as pages — robots.txt, spacing,
   * caps and block handling apply to a feed too.
   */
  fetchPrice(productUrl: string, fetcher: PoliteFetcher): Promise<ParsedShelfPrice>;
}

export interface RetailerAdapter {
  /** Stable id, stored on mappings and observations. */
  readonly id: string;
  readonly displayName: string;
  /**
   * `implemented` adapters can collect. `stub` adapters are documentation of
   * intent: the collector never sends a request for one.
   */
  readonly status: 'implemented' | 'stub';
  /**
   * True for the example adapter, which points at a reserved `.test` domain and
   * exists to exercise the framework against a local fixture. The collector
   * skips it unless a test asks otherwise.
   */
  readonly fixtureOnly?: boolean;
  readonly baseUrl: string;
  /** Hosts a mapped product URL may be on. Anything else is refused. */
  readonly allowedHosts: readonly string[];
  /** What a product page URL looks like. A mapping must match it. */
  readonly productUrlPattern: RegExp;
  /**
   * The retailer's search page, for an ADMIN looking up the product URL to map
   * by hand. Never used to match products automatically.
   */
  searchUrl(query: string): string;
  readonly officialFeed?: OfficialFeed;
  /** Read the collected fields from a product page. Throws `ShelfPriceParseError`. */
  parseProductPage(html: string, url: string): ParsedShelfPrice;
  /** Why this is a stub and what is needed before it is not. */
  readonly todo?: string;
}
