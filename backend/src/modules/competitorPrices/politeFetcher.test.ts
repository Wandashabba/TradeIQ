import { readFileSync } from 'fs';
import { join } from 'path';
import { CollectionRefusedError, PoliteFetcher, ROBOTS_TTL_MS, looksLikeBotWall } from './politeFetcher';

/**
 * Every rule in the fetcher, with a scripted `fetch`. No test here — or
 * anywhere in this module — reaches a network: the hosts are `.test` names and
 * `fetch` is a jest mock that fails on anything it was not told to expect.
 */

const HOSTS = ['shop.example.test'];
const PRODUCT = 'https://shop.example.test/p/fizzy-cola-2l';
const fixture = (name: string) => readFileSync(join(__dirname, '__fixtures__', name), 'utf8');

type Route = { status: number; body?: string; headers?: Record<string, string> } | (() => never);

function scripted(routes: Record<string, Route | Route[]>) {
  const calls: { url: string; init?: RequestInit; at: number }[] = [];
  let clock = Date.parse('2026-09-17T01:00:00.000Z');
  const sleeps: number[] = [];
  const fetchMock = jest.fn(async (url: string, init?: RequestInit) => {
    calls.push({ url, init, at: clock });
    const entry = routes[url];
    if (entry === undefined) throw new Error(`unexpected request to ${url}`);
    const route = Array.isArray(entry) ? entry.shift() : entry;
    if (!route) throw new Error(`no more scripted responses for ${url}`);
    if (typeof route === 'function') return route();
    return new Response(route.body ?? '', { status: route.status, headers: route.headers });
  });
  const fetcher = (overrides: Partial<ConstructorParameters<typeof PoliteFetcher>[0]> = {}) =>
    new PoliteFetcher({
      fetch: fetchMock,
      contact: 'mailto:bot@tradeiq.example',
      now: () => clock,
      sleep: async (ms) => {
        sleeps.push(ms);
        clock += ms;
      },
      backoffBaseMs: 1_000,
      ...overrides,
    });
  return {
    calls,
    sleeps,
    fetchMock,
    fetcher,
    advance: (ms: number) => {
      clock += ms;
    },
  };
}

const ROBOTS = 'https://shop.example.test/robots.txt';
const okRobots = { status: 200, body: 'User-agent: *\nDisallow: /checkout\n' };

describe('PoliteFetcher', () => {
  let globalFetch: jest.SpyInstance;
  beforeEach(() => {
    // Belt and braces: if anything slipped past the injected fetch, fail loudly.
    globalFetch = jest.spyOn(global, 'fetch').mockImplementation(async () => {
      throw new Error('real network access attempted in a test');
    });
  });
  afterEach(() => {
    expect(globalFetch).not.toHaveBeenCalled();
    globalFetch.mockRestore();
  });

  it('checks robots.txt first, then fetches the page with an honest User-Agent', async () => {
    const s = scripted({ [ROBOTS]: okRobots, [PRODUCT]: { status: 200, body: fixture('example-product.html') } });
    const page = await s.fetcher().get(PRODUCT, HOSTS);

    expect(page.body).toContain('Fizzy Cola');
    expect(s.calls.map((c) => c.url)).toEqual([ROBOTS, PRODUCT]);
    const headers = s.calls[1].init!.headers as Record<string, string>;
    expect(headers['User-Agent']).toMatch(/^TradeIQPriceBot\/1\.0 \(\+mailto:bot@tradeiq\.example; /);
    expect(headers['User-Agent']).not.toMatch(/Mozilla|Chrome|Safari/);
    expect(s.calls[1].init!.redirect).toBe('manual');
    expect(s.calls[1].init!.credentials).toBe('omit');
    expect(headers).not.toHaveProperty('Cookie');
  });

  it('refuses a path robots.txt disallows, without requesting the page', async () => {
    const s = scripted({ [ROBOTS]: { status: 200, body: 'User-agent: *\nDisallow: /p/\n' } });
    await expect(s.fetcher().get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'robots_disallowed' });
    expect(s.calls.map((c) => c.url)).toEqual([ROBOTS]);
  });

  it('refuses everything when robots.txt is unreachable (network error)', async () => {
    const s = scripted({
      [ROBOTS]: () => {
        throw new Error('ECONNREFUSED');
      },
    });
    await expect(s.fetcher().get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'robots_disallowed' });
    expect(s.calls.map((c) => c.url)).toEqual([ROBOTS]);
  });

  it('caches robots.txt for 24 hours, then reads it again', async () => {
    const page = { status: 200, body: fixture('example-product.html') };
    const s = scripted({ [ROBOTS]: [okRobots, okRobots], [PRODUCT]: [page, page, page] });
    const fetcher = s.fetcher();
    await fetcher.get(PRODUCT, HOSTS);
    await fetcher.get(PRODUCT, HOSTS);
    expect(s.calls.filter((c) => c.url === ROBOTS)).toHaveLength(1);
    s.advance(ROBOTS_TTL_MS + 1);
    await fetcher.get(PRODUCT, HOSTS);
    expect(s.calls.filter((c) => c.url === ROBOTS)).toHaveLength(2);
  });

  it('spaces requests to one domain at least 10 seconds apart, even if configured lower', async () => {
    const page = { status: 200, body: fixture('example-product.html') };
    const s = scripted({ [ROBOTS]: okRobots, [PRODUCT]: [page, page, page] });
    const fetcher = s.fetcher({ domainIntervalMs: 1_000, globalIntervalMs: 0 });
    await fetcher.get(PRODUCT, HOSTS);
    await fetcher.get(PRODUCT, HOSTS);
    await fetcher.get(PRODUCT, HOSTS);
    const times = s.calls.map((c) => c.at);
    for (let i = 1; i < times.length; i += 1) expect(times[i] - times[i - 1]).toBeGreaterThanOrEqual(10_000);
  });

  it('honours a crawl-delay longer than our own spacing', async () => {
    const page = { status: 200, body: fixture('example-product.html') };
    const s = scripted({
      [ROBOTS]: { status: 200, body: 'User-agent: *\nCrawl-delay: 60\n' },
      [PRODUCT]: [page, page],
    });
    const fetcher = s.fetcher({ globalIntervalMs: 0 });
    await fetcher.get(PRODUCT, HOSTS);
    await fetcher.get(PRODUCT, HOSTS);
    const pages = s.calls.filter((c) => c.url === PRODUCT);
    expect(pages[1].at - pages[0].at).toBeGreaterThanOrEqual(60_000);
  });

  it('spaces requests globally across domains', async () => {
    const other = 'https://other.example.test/p/x';
    const s = scripted({
      [ROBOTS]: okRobots,
      'https://other.example.test/robots.txt': okRobots,
      [PRODUCT]: { status: 200, body: fixture('example-product.html') },
      [other]: { status: 200, body: fixture('example-product.html') },
    });
    const fetcher = s.fetcher({ globalIntervalMs: 5_000 });
    await fetcher.get(PRODUCT, HOSTS);
    await fetcher.get(other, ['other.example.test']);
    const times = s.calls.map((c) => c.at);
    for (let i = 1; i < times.length; i += 1) expect(times[i] - times[i - 1]).toBeGreaterThanOrEqual(5_000);
  });

  it('stops at the daily cap per domain, counting robots.txt', async () => {
    const page = { status: 200, body: fixture('example-product.html') };
    const s = scripted({ [ROBOTS]: okRobots, [PRODUCT]: [page, page, page] });
    const fetcher = s.fetcher({ dailyCapPerDomain: 3 });
    await fetcher.get(PRODUCT, HOSTS);
    await fetcher.get(PRODUCT, HOSTS);
    await expect(fetcher.get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'daily_cap' });
    expect(s.calls).toHaveLength(3);
    expect(fetcher.requestsToday('shop.example.test')).toBe(3);
  });

  it.each([401, 403, 429])('stops on HTTP %i, marks the host blocked, and sends nothing more', async (status) => {
    const s = scripted({ [ROBOTS]: okRobots, [PRODUCT]: { status } });
    const fetcher = s.fetcher();
    await expect(fetcher.get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'blocked' });
    expect(fetcher.blockedReason('shop.example.test')).toContain(String(status));
    await expect(fetcher.get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'blocked' });
    // One robots read and one page request — no retry of the blocked page.
    expect(s.calls).toHaveLength(2);
  });

  it('stops on a captcha / bot-wall page served with 200', async () => {
    const s = scripted({ [ROBOTS]: okRobots, [PRODUCT]: { status: 200, body: fixture('example-bot-wall.html') } });
    const fetcher = s.fetcher();
    await expect(fetcher.get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'blocked' });
    expect(fetcher.blockedReason('shop.example.test')).toMatch(/bot wall/);
  });

  it('stops when robots.txt itself answers 429 or 403', async () => {
    const s = scripted({ [ROBOTS]: { status: 429 } });
    const fetcher = s.fetcher();
    await expect(fetcher.get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'blocked' });
    expect(s.calls.map((c) => c.url)).toEqual([ROBOTS]);
  });

  it('retries a 5xx with exponential backoff, a bounded number of times', async () => {
    const s = scripted({
      [ROBOTS]: okRobots,
      [PRODUCT]: [{ status: 503 }, { status: 502 }, { status: 500 }],
    });
    await expect(s.fetcher({ maxAttempts: 3, backoffBaseMs: 1_000 }).get(PRODUCT, HOSTS)).rejects.toMatchObject({
      kind: 'http_error',
    });
    expect(s.calls.filter((c) => c.url === PRODUCT)).toHaveLength(3);
    expect(s.sleeps).toEqual(expect.arrayContaining([1_000, 2_000]));
  });

  it('recovers when a retry succeeds', async () => {
    const s = scripted({
      [ROBOTS]: okRobots,
      [PRODUCT]: [{ status: 503 }, { status: 200, body: fixture('example-product.html') }],
    });
    await expect(s.fetcher().get(PRODUCT, HOSTS)).resolves.toMatchObject({ status: 200 });
  });

  it('reports a 404 as not found without blocking the host', async () => {
    const s = scripted({ [ROBOTS]: okRobots, [PRODUCT]: { status: 404 } });
    const fetcher = s.fetcher();
    await expect(fetcher.get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'not_found' });
    expect(fetcher.blockedReason('shop.example.test')).toBeNull();
  });

  it('follows a same-host redirect, robots-checking the new path', async () => {
    const moved = 'https://shop.example.test/p/fizzy-cola-2l-new';
    const s = scripted({
      [ROBOTS]: { status: 200, body: 'User-agent: *\nDisallow: /p/fizzy-cola-2l-new\n' },
      [PRODUCT]: { status: 301, headers: { location: '/p/fizzy-cola-2l-new' } },
    });
    await expect(s.fetcher().get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'robots_disallowed' });
    expect(s.calls.map((c) => c.url)).not.toContain(moved);
  });

  it('refuses a redirect to another host', async () => {
    const s = scripted({
      [ROBOTS]: okRobots,
      [PRODUCT]: { status: 302, headers: { location: 'https://evil.example.test/p/x' } },
    });
    await expect(s.fetcher().get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'invalid_url' });
    expect(s.calls).toHaveLength(2);
  });

  it.each([
    'http://shop.example.test/p/x',
    'https://elsewhere.example.test/p/x',
    'https://user:pw@shop.example.test/p/x',
    'https://shop.example.test:8443/p/x',
    'not a url',
  ])('refuses %s without any request', async (url) => {
    const s = scripted({});
    await expect(s.fetcher().get(url, HOSTS)).rejects.toBeInstanceOf(CollectionRefusedError);
    expect(s.fetchMock).not.toHaveBeenCalled();
  });

  it('refuses to send anything without a contact for the User-Agent', async () => {
    const s = scripted({});
    await expect(s.fetcher({ contact: null }).get(PRODUCT, HOSTS)).rejects.toMatchObject({ kind: 'not_configured' });
    expect(s.fetchMock).not.toHaveBeenCalled();
  });
});

describe('bot-wall detection', () => {
  it('recognises the fixture wall and leaves a normal product page alone', () => {
    expect(looksLikeBotWall(fixture('example-bot-wall.html'))).toBe(true);
    expect(looksLikeBotWall(fixture('example-product.html'))).toBe(false);
  });
});
