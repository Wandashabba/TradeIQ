import { BOT_TOKEN, MIN_DOMAIN_INTERVAL_MS, userAgent } from './config';
import { DISALLOW_ALL, parseRobots, robotsForStatus, type RobotsPolicy } from './robots';

/**
 * The only way this module talks to a retailer.
 *
 * Every request goes through `get`, and `get` does, in order:
 *
 * 1. refuses anything not https on one of the adapter's own hosts;
 * 2. refuses a host that has already blocked us in this process;
 * 3. refuses once the host's daily cap is spent;
 * 4. reads robots.txt (cached 24h) and refuses a disallowed path;
 * 5. waits out the global and per-domain spacing (never under 10s per domain,
 *    and never under a stated crawl-delay);
 * 6. sends ONE plain GET with an honest User-Agent — no cookies, no login, no
 *    browser disguise, no proxy;
 * 7. stops at 401/403/429 or a captcha / bot-wall page, and remembers the host
 *    as blocked. It never retries past a block.
 *
 * Only a 5xx or a network error is retried, with exponential backoff, and only
 * a few times.
 *
 * `fetch`, the clock and `sleep` are injected so every rule above is tested
 * without a network. Nothing in the test suite constructs this with the real
 * `fetch`.
 */

export class CollectionRefusedError extends Error {
  constructor(
    readonly kind: 'blocked' | 'robots_disallowed' | 'daily_cap' | 'not_found' | 'http_error' | 'invalid_url' | 'not_configured',
    message: string,
  ) {
    super(message);
    this.name = 'CollectionRefusedError';
  }
}

export interface FetchedPage {
  url: string;
  status: number;
  body: string;
  retrievedAt: Date;
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface PoliteFetcherOptions {
  fetch: FetchLike;
  /** Contact URL or email, from COMPETITOR_PRICE_BOT_CONTACT. Required. */
  contact: string | null;
  domainIntervalMs?: number;
  globalIntervalMs?: number;
  dailyCapPerDomain?: number;
  maxAttempts?: number;
  backoffBaseMs?: number;
  now?: () => number;
  sleep?: (ms: number) => Promise<void>;
}

export const ROBOTS_TTL_MS = 24 * 60 * 60 * 1000;
/** An unreadable robots.txt is re-tried sooner than a readable one expires. */
export const ROBOTS_ERROR_TTL_MS = 60 * 60 * 1000;
export const MAX_PAGE_BYTES = 2 * 1024 * 1024;
const MAX_REDIRECTS = 3;

/**
 * Markers of a bot wall or captcha. Deliberately broad: a false positive costs
 * one missed price; a false negative means we kept going past a site that
 * asked us to stop.
 */
const BOT_WALL_MARKERS: readonly RegExp[] = [
  /captcha/i,
  /cf-challenge|cf_chl_|challenge-platform|just a moment\.\.\./i,
  /are you a (human|robot)/i,
  /verify (that )?you are (a )?human/i,
  /unusual traffic/i,
  /access denied/i,
  /perimeterx|px-captcha/i,
  /incapsula|_incapsula_resource/i,
  /datadome/i,
  /request unsuccessful\. incapsula/i,
  /bot (detection|protection)/i,
];

export function looksLikeBotWall(body: string): boolean {
  return BOT_WALL_MARKERS.some((re) => re.test(body));
}

const defaultSleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

function utcDay(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

export class PoliteFetcher {
  private readonly fetchImpl: FetchLike;
  private readonly contact: string | null;
  private readonly domainIntervalMs: number;
  private readonly globalIntervalMs: number;
  private readonly dailyCap: number;
  private readonly maxAttempts: number;
  private readonly backoffBaseMs: number;
  private readonly now: () => number;
  private readonly sleep: (ms: number) => Promise<void>;

  private readonly robots = new Map<string, { policy: RobotsPolicy; expiresAt: number }>();
  private readonly lastRequestAt = new Map<string, number>();
  private lastGlobalRequestAt = -Infinity;
  private readonly dailyCounts = new Map<string, { day: string; count: number }>();
  private readonly blocked = new Map<string, string>();

  constructor(options: PoliteFetcherOptions) {
    this.fetchImpl = options.fetch;
    this.contact = options.contact;
    this.domainIntervalMs = Math.max(MIN_DOMAIN_INTERVAL_MS, options.domainIntervalMs ?? 15_000);
    this.globalIntervalMs = Math.max(0, options.globalIntervalMs ?? 3_000);
    this.dailyCap = Math.max(1, options.dailyCapPerDomain ?? 50);
    this.maxAttempts = Math.max(1, Math.min(options.maxAttempts ?? 3, 5));
    this.backoffBaseMs = options.backoffBaseMs ?? 30_000;
    this.now = options.now ?? Date.now;
    this.sleep = options.sleep ?? defaultSleep;
  }

  /** Why a host is blocked, if it has blocked us in this process. */
  blockedReason(host: string): string | null {
    return this.blocked.get(host.toLowerCase()) ?? null;
  }

  /** Requests sent to `host` today (UTC), robots.txt included. */
  requestsToday(host: string): number {
    const entry = this.dailyCounts.get(host.toLowerCase());
    return entry && entry.day === utcDay(this.now()) ? entry.count : 0;
  }

  /** GET a page, obeying every rule in the file header. */
  async get(rawUrl: string, allowedHosts: readonly string[]): Promise<FetchedPage> {
    if (!this.contact) {
      throw new CollectionRefusedError(
        'not_configured',
        'COMPETITOR_PRICE_BOT_CONTACT is not set; refusing to send requests without a contact in the User-Agent',
      );
    }
    let url = this.checkUrl(rawUrl, allowedHosts);

    for (let hop = 0; ; hop += 1) {
      const response = await this.send(url, allowedHosts);
      const status = response.status;

      if (status >= 300 && status < 400) {
        const location = response.headers.get('location');
        if (!location || hop >= MAX_REDIRECTS) {
          throw new CollectionRefusedError('http_error', `redirect without a usable location (${status})`);
        }
        // Same hosts only, and the new path is robots-checked on the next send.
        url = this.checkUrl(new URL(location, url).toString(), allowedHosts);
        continue;
      }

      const body = await readCapped(response);
      if (status === 401 || status === 403 || status === 429) {
        throw this.markBlocked(url.hostname, `HTTP ${status}`);
      }
      if (looksLikeBotWall(body)) {
        throw this.markBlocked(url.hostname, `bot wall or captcha page (HTTP ${status})`);
      }
      if (status === 404 || status === 410) {
        throw new CollectionRefusedError('not_found', `HTTP ${status}`);
      }
      if (status < 200 || status >= 300) {
        throw new CollectionRefusedError('http_error', `HTTP ${status}`);
      }
      return { url: url.toString(), status, body, retrievedAt: new Date(this.now()) };
    }
  }

  private checkUrl(rawUrl: string, allowedHosts: readonly string[]): URL {
    let url: URL;
    try {
      url = new URL(rawUrl);
    } catch {
      throw new CollectionRefusedError('invalid_url', 'not a URL');
    }
    const hosts = allowedHosts.map((h) => h.toLowerCase());
    if (url.protocol !== 'https:' || url.username || url.password || url.port || !hosts.includes(url.hostname)) {
      throw new CollectionRefusedError('invalid_url', `not an https URL on ${hosts.join(', ')}`);
    }
    url.hash = '';
    return url;
  }

  private markBlocked(host: string, reason: string): CollectionRefusedError {
    this.blocked.set(host.toLowerCase(), reason);
    return new CollectionRefusedError('blocked', `${host} blocked collection: ${reason}`);
  }

  /** robots, cap and spacing, then one request (with backoff on 5xx/network only). */
  private async send(url: URL, allowedHosts: readonly string[]): Promise<Response> {
    const host = url.hostname;
    const blockedWhy = this.blockedReason(host);
    if (blockedWhy) throw new CollectionRefusedError('blocked', `${host} blocked collection: ${blockedWhy}`);

    const robots = await this.robotsFor(url, allowedHosts);
    if (!robots.isAllowed(url.pathname + url.search)) {
      throw new CollectionRefusedError('robots_disallowed', `robots.txt disallows ${url.pathname}`);
    }

    let lastError: unknown;
    for (let attempt = 0; attempt < this.maxAttempts; attempt += 1) {
      if (attempt > 0) await this.sleep(this.backoffBaseMs * 2 ** (attempt - 1));
      try {
        const response = await this.request(url, robots.crawlDelaySeconds, 'text/html');
        if (response.status >= 500) {
          const body = await readCapped(response);
          if (looksLikeBotWall(body)) throw this.markBlocked(host, `bot wall or captcha page (HTTP ${response.status})`);
          lastError = new CollectionRefusedError('http_error', `HTTP ${response.status}`);
          continue;
        }
        return response;
      } catch (err) {
        if (err instanceof CollectionRefusedError) throw err;
        lastError = err;
      }
    }
    if (lastError instanceof CollectionRefusedError) throw lastError;
    throw new CollectionRefusedError('http_error', 'network error after retries');
  }

  private async robotsFor(url: URL, allowedHosts: readonly string[]): Promise<RobotsPolicy> {
    const origin = url.origin;
    const cached = this.robots.get(origin);
    if (cached && cached.expiresAt > this.now()) return cached.policy;

    let policy: RobotsPolicy;
    let ttl = ROBOTS_TTL_MS;
    try {
      const robotsUrl = new URL('/robots.txt', origin);
      this.checkUrl(robotsUrl.toString(), allowedHosts);
      const response = await this.request(robotsUrl, null, 'text/plain');
      if (response.status === 429 || response.status === 401 || response.status === 403) {
        // Refused at the front door: blocked, and nothing else is sent.
        throw this.markBlocked(url.hostname, `robots.txt returned HTTP ${response.status}`);
      }
      const byStatus = robotsForStatus(response.status);
      if (byStatus) {
        policy = byStatus;
        // A redirect or 5xx is read as complete disallow, and asked again sooner.
        if (response.status >= 300 && (response.status < 400 || response.status >= 500)) {
          ttl = ROBOTS_ERROR_TTL_MS;
        }
      } else {
        policy = parseRobots(await readCapped(response), BOT_TOKEN);
      }
    } catch (err) {
      if (err instanceof CollectionRefusedError && err.kind === 'blocked') throw err;
      policy = DISALLOW_ALL;
      ttl = ROBOTS_ERROR_TTL_MS;
    }
    this.robots.set(origin, { policy, expiresAt: this.now() + ttl });
    return policy;
  }

  /** Spacing, the daily cap, and the request itself. */
  private async request(url: URL, crawlDelaySeconds: number | null, accept: string): Promise<Response> {
    const host = url.hostname;
    const today = utcDay(this.now());
    const counted = this.dailyCounts.get(host);
    const count = counted && counted.day === today ? counted.count : 0;
    if (count >= this.dailyCap) {
      throw new CollectionRefusedError('daily_cap', `daily cap of ${this.dailyCap} requests to ${host} reached`);
    }

    const spacing = Math.max(this.domainIntervalMs, (crawlDelaySeconds ?? 0) * 1000);
    const earliest = Math.max(
      (this.lastRequestAt.get(host) ?? -Infinity) + spacing,
      this.lastGlobalRequestAt + this.globalIntervalMs,
    );
    const wait = earliest - this.now();
    if (wait > 0) await this.sleep(wait);

    const sentAt = this.now();
    this.lastRequestAt.set(host, sentAt);
    this.lastGlobalRequestAt = sentAt;
    this.dailyCounts.set(host, { day: utcDay(sentAt), count: count + 1 });

    return this.fetchImpl(url.toString(), {
      method: 'GET',
      redirect: 'manual',
      credentials: 'omit',
      headers: {
        'User-Agent': userAgent(this.contact ?? ''),
        Accept: accept,
        'Accept-Language': 'en-ZA,en;q=0.8',
      },
      signal: AbortSignal.timeout(30_000),
    });
  }
}

async function readCapped(response: Response): Promise<string> {
  const text = await response.text();
  return text.length > MAX_PAGE_BYTES ? text.slice(0, MAX_PAGE_BYTES) : text;
}
