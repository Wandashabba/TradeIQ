/**
 * Environment for competitor shelf-price collection.
 *
 * **Everything defaults to the conservative side.** The kill switch is off
 * unless it says exactly `on`; the per-domain spacing cannot be configured
 * below ten seconds; the daily cap is small. A typo in the environment must
 * never be the reason requests start going to a retailer.
 *
 * See docs/operations/competitor-price-collection.md.
 */

/** The product token robots.txt groups are matched against. */
export const BOT_TOKEN = 'TradeIQPriceBot';
export const BOT_VERSION = '1.0';

/** The floor for per-domain spacing. Configuration can widen it, never narrow it. */
export const MIN_DOMAIN_INTERVAL_MS = 10_000;

export interface CollectionConfig {
  /** The global kill switch: true only when COMPETITOR_PRICE_COLLECTION=on. */
  globallyEnabled: boolean;
  /** Contact URL or email for the User-Agent. Null means collection refuses to run. */
  contact: string | null;
  domainIntervalMs: number;
  globalIntervalMs: number;
  dailyCapPerDomain: number;
  staleAfterDays: number;
}

function intFrom(raw: string | undefined, fallback: number, min: number, max: number): number {
  const parsed = raw === undefined || raw.trim() === '' ? NaN : Number(raw);
  if (!Number.isInteger(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

/**
 * The global kill switch. Anything other than the exact word `on` — unset,
 * `true`, `yes`, `ON ` with a typo — is off, and off overrides every client
 * setting.
 */
export function isCollectionGloballyEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.COMPETITOR_PRICE_COLLECTION?.trim().toLowerCase() === 'on';
}

export function collectionConfig(env: NodeJS.ProcessEnv = process.env): CollectionConfig {
  const contact = env.COMPETITOR_PRICE_BOT_CONTACT?.trim();
  return {
    globallyEnabled: isCollectionGloballyEnabled(env),
    // Printable ASCII only: it goes into a header.
    contact: contact && /^[\x20-\x7e]{3,200}$/.test(contact) ? contact : null,
    domainIntervalMs: intFrom(
      env.COMPETITOR_PRICE_DOMAIN_INTERVAL_MS,
      15_000,
      MIN_DOMAIN_INTERVAL_MS,
      3_600_000,
    ),
    globalIntervalMs: intFrom(env.COMPETITOR_PRICE_GLOBAL_INTERVAL_MS, 3_000, 1_000, 3_600_000),
    dailyCapPerDomain: intFrom(env.COMPETITOR_PRICE_DAILY_CAP, 50, 1, 200),
    staleAfterDays: intFrom(env.COMPETITOR_PRICE_STALE_DAYS, 7, 1, 90),
  };
}

/**
 * The honest User-Agent: who we are, why, and how to reach a person. No
 * browser string, ever — a site owner reading their logs should be able to
 * tell exactly what this is and ask us to stop.
 */
export function userAgent(contact: string): string {
  return `${BOT_TOKEN}/${BOT_VERSION} (+${contact}; competitor shelf-price research for TradeIQ; honours robots.txt)`;
}
