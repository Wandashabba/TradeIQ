import { readFileSync } from 'fs';
import { join } from 'path';
import { prisma } from '../../lib/prisma';
import { adapterFor, exampleAdapter, type RetailerAdapter } from './adapters';
import { BLOCK_COOLDOWN_DAYS, collectForClient, runCompetitorPriceCollection } from './collector';
import { competitorPriceGate } from './gate';
import { PoliteFetcher } from './politeFetcher';

/**
 * The collector against a real database and a scripted fetch.
 *
 * The zero-network cases are asserted twice: the injected fetch is never
 * called, AND a spy on the global `fetch` is never called — so a code path that
 * reached for the real network instead of the injected one would still fail.
 */

const fixture = (name: string) => readFileSync(join(__dirname, '__fixtures__', name), 'utf8');
const ON = { COMPETITOR_PRICE_COLLECTION: 'on', COMPETITOR_PRICE_BOT_CONTACT: 'mailto:bot@tradeiq.example' };
const OFF = { COMPETITOR_PRICE_BOT_CONTACT: 'mailto:bot@tradeiq.example' };
const ROBOTS = 'https://shop.example.test/robots.txt';
const NOW = new Date('2026-09-17T01:00:00.000Z');

let counter = 0;

async function client(options: { enabled?: boolean; approved?: boolean } = {}) {
  counter += 1;
  const row = await prisma.client.create({
    data: {
      name: `CPRICE-${counter}-${Date.now()}`,
      industry: 'FMCG',
      scorecardWeights: {},
      kpiThresholds: {},
      competitorPriceCollectionEnabled: options.enabled ?? false,
      competitorPriceCollectionApprovedBy: options.approved ? 'Legal: A. Counsel' : null,
      competitorPriceCollectionApprovedAt: options.approved ? new Date('2026-09-01') : null,
    },
  });
  return row.id;
}

async function mapping(clientId: string, slug: string, retailer = 'example') {
  const baseUrl = adapterFor(retailer)?.baseUrl ?? 'https://shop.example.test';
  return prisma.competitorSkuMapping.create({
    data: {
      clientId,
      competitorSku: `Fizzy ${slug}`,
      retailer,
      productUrl: retailer === 'example' ? `${baseUrl}/p/${slug}` : `${baseUrl}/x/p/${slug}`,
      createdBy: 'admin-1',
    },
  });
}

function scriptedFetch(routes: Record<string, Array<{ status: number; body?: string }>>) {
  return jest.fn(async (url: string) => {
    const next = routes[url]?.shift();
    if (!next) throw new Error(`unexpected request to ${url}`);
    return new Response(next.body ?? '', { status: next.status });
  });
}

function fetcherWith(fetchMock: jest.Mock) {
  let clock = NOW.getTime();
  return new PoliteFetcher({
    fetch: fetchMock,
    contact: 'mailto:bot@tradeiq.example',
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
    },
    backoffBaseMs: 1,
  });
}

describe('competitor price collector', () => {
  let globalFetch: jest.SpyInstance;
  beforeEach(() => {
    globalFetch = jest.spyOn(global, 'fetch').mockImplementation(async () => {
      throw new Error('real network access attempted in a test');
    });
  });
  afterEach(async () => {
    expect(globalFetch).not.toHaveBeenCalled();
    globalFetch.mockRestore();
    // A recorded block applies to the retailer for every client by design, so
    // one test's block must not silence the next test's collection.
    await prisma.competitorPriceCollectionEvent.deleteMany({ where: { kind: 'blocked' } });
  });

  describe('the gate — zero network calls while closed', () => {
    it('kill switch off: returns before touching the database or the network', async () => {
      const enabled = await client({ enabled: true, approved: true });
      await mapping(enabled, 'kill-switch');
      const fetchMock = scriptedFetch({});
      const findMany = jest.spyOn(prisma.client, 'findMany');

      const report = await runCompetitorPriceCollection({ env: OFF, fetch: fetchMock, allowFixtureAdapters: true });

      expect(report).toEqual({ skipped: 'kill_switch', clients: [] });
      expect(fetchMock).not.toHaveBeenCalled();
      expect(findMany).not.toHaveBeenCalled();
      findMany.mockRestore();
    });

    it.each([
      ['COMPETITOR_PRICE_COLLECTION unset', {}],
      ['set to true rather than on', { COMPETITOR_PRICE_COLLECTION: 'true' }],
      ['set to off', { COMPETITOR_PRICE_COLLECTION: 'off' }],
    ])('kill switch treats %s as off', async (_label, env) => {
      const id = await client({ enabled: true, approved: true });
      expect(await competitorPriceGate(id, env)).toEqual({ active: false, reason: 'kill_switch' });
    });

    it('a client that has not enabled collection makes no request', async () => {
      const id = await client({ enabled: false, approved: true });
      await mapping(id, 'disabled');
      const fetchMock = scriptedFetch({});
      const report = await collectForClient(id, { env: ON, fetch: fetchMock, allowFixtureAdapters: true });
      expect(report.skipped).toBe('client_disabled');
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('an enabled client without both approval fields makes no request', async () => {
      const id = await client({ enabled: true, approved: false });
      await mapping(id, 'unapproved');
      const fetchMock = scriptedFetch({});
      const report = await collectForClient(id, { env: ON, fetch: fetchMock, allowFixtureAdapters: true });
      expect(report.skipped).toBe('not_approved');
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('only runs for enabled, approved clients', async () => {
      const on = await client({ enabled: true, approved: true });
      const off = await client({ enabled: false });
      await mapping(off, 'never-fetched');
      const report = await runCompetitorPriceCollection({
        env: ON,
        fetcher: fetcherWith(scriptedFetch({})),
        adapters: [],
      });
      const ids = report.clients.map((c) => c.clientId);
      expect(ids).toContain(on);
      expect(ids).not.toContain(off);
    });
  });

  it('collects a mapped SKU from the fixture page and appends an observation', async () => {
    const id = await client({ enabled: true, approved: true });
    const m = await mapping(id, 'fizzy-cola-2l');
    const fetchMock = scriptedFetch({
      [ROBOTS]: [{ status: 200, body: 'User-agent: *\nDisallow: /checkout\n' }],
      [m.productUrl]: [{ status: 200, body: fixture('example-product.html') }],
    });

    const report = await collectForClient(id, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(report.observations).toBe(1);
    const rows = await prisma.competitorShelfPriceObservation.findMany({ where: { clientId: id } });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      mappingId: m.id,
      retailer: 'example',
      productName: 'Fizzy Cola Soft Drink 2L',
      packSize: '2L',
      shelfPrice: 24.99,
      promoPrice: null,
      sourceUrl: m.productUrl,
      method: 'page',
    });
    expect(rows[0].retrievedAt).toBeInstanceOf(Date);
  });

  it('observations are append-only: the database refuses an UPDATE', async () => {
    const id = await client({ enabled: true, approved: true });
    const m = await mapping(id, 'append-only');
    const row = await prisma.competitorShelfPriceObservation.create({
      data: {
        clientId: id,
        mappingId: m.id,
        retailer: 'example',
        productName: 'X',
        shelfPrice: 10,
        sourceUrl: m.productUrl,
        retrievedAt: NOW,
      },
    });
    await expect(
      prisma.competitorShelfPriceObservation.update({ where: { id: row.id }, data: { shelfPrice: 1 } }),
    ).rejects.toThrow(/append-only/);
  });

  it('records robots.txt refusals and never requests the page', async () => {
    const id = await client({ enabled: true, approved: true });
    const m = await mapping(id, 'robots-refused');
    const fetchMock = scriptedFetch({ [ROBOTS]: [{ status: 200, body: 'User-agent: TradeIQPriceBot\nDisallow: /\n' }] });

    const report = await collectForClient(id, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(report.events).toEqual({ robots_disallowed: 1 });
    expect(fetchMock.mock.calls.map((c) => c[0])).toEqual([ROBOTS]);
    expect(await prisma.competitorShelfPriceObservation.count({ where: { mappingId: m.id } })).toBe(0);
  });

  it('on a block, records `blocked` and stops asking that retailer for the rest of the run', async () => {
    const id = await client({ enabled: true, approved: true });
    const first = await mapping(id, 'blocked-a');
    await mapping(id, 'blocked-b');
    await mapping(id, 'blocked-c');
    const fetchMock = scriptedFetch({
      [ROBOTS]: [{ status: 200, body: '' }],
      [first.productUrl]: [{ status: 200, body: fixture('example-bot-wall.html') }],
    });

    const report = await collectForClient(id, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(report.events).toEqual({ blocked: 1 });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    const events = await prisma.competitorPriceCollectionEvent.findMany({ where: { clientId: id } });
    expect(events.map((e) => e.kind)).toEqual(['blocked']);
  });

  it(`honours a block recorded in the last ${BLOCK_COOLDOWN_DAYS} days, for every client`, async () => {
    const blockedFor = await client({ enabled: true, approved: true });
    await prisma.competitorPriceCollectionEvent.create({
      data: { clientId: blockedFor, retailer: 'example', kind: 'blocked', detail: 'HTTP 403' },
    });
    const other = await client({ enabled: true, approved: true });
    await mapping(other, 'after-block');
    const fetchMock = scriptedFetch({});

    const report = await collectForClient(other, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(fetchMock).not.toHaveBeenCalled();
    expect(report.observations).toBe(0);
  });

  it('never fetches for a stub adapter', async () => {
    const id = await client({ enabled: true, approved: true });
    await mapping(id, 'stubbed', 'checkers');
    const fetchMock = scriptedFetch({});

    const report = await collectForClient(id, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(fetchMock).not.toHaveBeenCalled();
    expect(report.events).toEqual({ adapter_unavailable: 1 });
  });

  it('never fetches for the fixture-only example outside tests', async () => {
    const id = await client({ enabled: true, approved: true });
    await mapping(id, 'fixture-in-prod');
    const fetchMock = scriptedFetch({});
    await collectForClient(id, { env: ON, fetcher: fetcherWith(fetchMock) });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('prefers an official feed over reading pages when the adapter has one', async () => {
    const id = await client({ enabled: true, approved: true });
    await mapping(id, 'feed');
    const fetchPrice = jest.fn(async () => ({
      productName: 'Fizzy Cola 2L',
      packSize: '2L',
      shelfPrice: 23.5,
      promoPrice: null,
      promoEndsAt: null,
    }));
    const withFeed: RetailerAdapter = { ...exampleAdapter, officialFeed: { description: 'fixture feed', fetchPrice } };
    const fetchMock = scriptedFetch({});

    const report = await collectForClient(id, {
      env: ON,
      fetcher: fetcherWith(fetchMock),
      adapters: [withFeed],
      allowFixtureAdapters: true,
      now: () => NOW,
    });

    expect(report.observations).toBe(1);
    expect(fetchPrice).toHaveBeenCalledTimes(1);
    expect(fetchMock).not.toHaveBeenCalled();
    const row = await prisma.competitorShelfPriceObservation.findFirstOrThrow({ where: { clientId: id } });
    expect(row.method).toBe('feed');
  });

  it('stops mid-run when the gate closes between mappings', async () => {
    const id = await client({ enabled: true, approved: true });
    const first = await mapping(id, 'gate-a');
    await mapping(id, 'gate-b');
    const fetchMock = jest.fn(async (url: string) => {
      if (url === ROBOTS) return new Response('', { status: 200 });
      // An admin switches collection off while the first page is in flight.
      await prisma.client.update({ where: { id }, data: { competitorPriceCollectionEnabled: false } });
      return new Response(fixture('example-product.html'), { status: 200 });
    });

    const report = await collectForClient(id, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(report.skipped).toBe('gate_closed_during_run');
    expect(fetchMock.mock.calls.map((c) => c[0])).toEqual([ROBOTS, first.productUrl]);
  });

  it('collects only the client’s own mappings (tenant isolation)', async () => {
    const mine = await client({ enabled: true, approved: true });
    const theirs = await client({ enabled: false });
    const myMapping = await mapping(mine, 'mine');
    await mapping(theirs, 'theirs');
    const fetchMock = scriptedFetch({
      [ROBOTS]: [{ status: 200, body: '' }],
      [myMapping.productUrl]: [{ status: 200, body: fixture('example-product.html') }],
    });

    await collectForClient(mine, { env: ON, fetcher: fetcherWith(fetchMock), allowFixtureAdapters: true });

    expect(fetchMock.mock.calls.map((c) => c[0])).toEqual([ROBOTS, myMapping.productUrl]);
    expect(await prisma.competitorShelfPriceObservation.count({ where: { clientId: theirs } })).toBe(0);
  });
});
