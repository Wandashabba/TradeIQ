import { prisma } from '../../lib/prisma';
import { adapterFor, ShelfPriceParseError, type RetailerAdapter } from './adapters';
import { collectionConfig, isCollectionGloballyEnabled } from './config';
import { competitorPriceGate, ENABLED_CLIENT_WHERE } from './gate';
import { CollectionRefusedError, PoliteFetcher } from './politeFetcher';

/**
 * One collection run: for every client whose gate is open, for every ACTIVE
 * MAPPED competitor SKU, read the price once and append it.
 *
 * The order of refusals matters and is tested:
 *
 * - Kill switch off → return before the database or the network is touched.
 * - Per client, the gate is re-checked (the switch may have been turned off
 *   since the client list was read).
 * - A stub adapter, or the fixture-only example outside tests, is never
 *   fetched.
 * - A retailer that blocked us — in this run, for any client, or recorded in
 *   the last `BLOCK_COOLDOWN_DAYS` — is not asked again. We never retry our way
 *   past a block; a person decides what happens next.
 */

export const BLOCK_COOLDOWN_DAYS = 14;

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface CollectorDeps {
  env?: NodeJS.ProcessEnv;
  now?: () => Date;
  /** Injected in tests. Defaults to the global fetch, only ever reached with the gate open. */
  fetch?: FetchLike;
  /** Reuse one fetcher across clients so spacing, caps and blocks are shared. */
  fetcher?: PoliteFetcher;
  /** Tests only: let the fixture example adapter collect. */
  allowFixtureAdapters?: boolean;
  adapters?: readonly RetailerAdapter[];
}

export interface ClientCollectionReport {
  clientId: string;
  skipped?: string;
  observations: number;
  events: Record<string, number>;
}

export interface CollectionReport {
  skipped?: 'kill_switch';
  clients: ClientCollectionReport[];
}

export async function runCompetitorPriceCollection(deps: CollectorDeps = {}): Promise<CollectionReport> {
  const env = deps.env ?? process.env;
  if (!isCollectionGloballyEnabled(env)) return { skipped: 'kill_switch', clients: [] };

  const clients = await prisma.client.findMany({ where: ENABLED_CLIENT_WHERE, select: { id: true } });
  const fetcher = deps.fetcher ?? buildFetcher(deps);
  const reports: ClientCollectionReport[] = [];
  for (const client of clients) {
    reports.push(await collectForClient(client.id, { ...deps, fetcher }));
  }
  return { clients: reports };
}

function buildFetcher(deps: CollectorDeps): PoliteFetcher {
  const config = collectionConfig(deps.env ?? process.env);
  return new PoliteFetcher({
    fetch: deps.fetch ?? ((input, init) => fetch(input, init)),
    contact: config.contact,
    domainIntervalMs: config.domainIntervalMs,
    globalIntervalMs: config.globalIntervalMs,
    dailyCapPerDomain: config.dailyCapPerDomain,
  });
}

export async function collectForClient(clientId: string, deps: CollectorDeps = {}): Promise<ClientCollectionReport> {
  const env = deps.env ?? process.env;
  const report: ClientCollectionReport = { clientId, observations: 0, events: {} };

  const gate = await competitorPriceGate(clientId, env);
  if (!gate.active) return { ...report, skipped: gate.reason };

  const now = deps.now ?? (() => new Date());
  const lookup = (id: string) => (deps.adapters ? deps.adapters.find((a) => a.id === id) : adapterFor(id));
  const fetcher = deps.fetcher ?? buildFetcher(deps);

  const mappings = await prisma.competitorSkuMapping.findMany({
    where: { clientId, active: true },
    select: { id: true, retailer: true, productUrl: true },
    orderBy: [{ retailer: 'asc' }, { createdAt: 'asc' }],
  });
  if (mappings.length === 0) return report;

  // A block recorded for a retailer is honoured for every client: it is the
  // retailer's answer to our bot, not to one tenant.
  const recentBlocks = await prisma.competitorPriceCollectionEvent.findMany({
    where: {
      kind: 'blocked',
      retailer: { in: [...new Set(mappings.map((m) => m.retailer))] },
      createdAt: { gte: new Date(now().getTime() - BLOCK_COOLDOWN_DAYS * 86_400_000) },
    },
    select: { retailer: true },
    distinct: ['retailer'],
  });
  const stopped = new Set(recentBlocks.map((b) => b.retailer));
  const unusable = new Set<string>();

  const record = async (kind: string, retailer: string, mappingId: string | null, url: string | null, detail: string) => {
    report.events[kind] = (report.events[kind] ?? 0) + 1;
    await prisma.competitorPriceCollectionEvent.create({
      data: { clientId, retailer, mappingId, kind, url, detail: detail.slice(0, 500) },
    });
  };

  for (const mapping of mappings) {
    if (stopped.has(mapping.retailer) || unusable.has(mapping.retailer)) continue;

    // Re-checked between requests: turning the switch off stops a run in
    // progress at the next mapping, not at the end of it.
    if (!(await competitorPriceGate(clientId, env)).active) {
      report.skipped = 'gate_closed_during_run';
      break;
    }

    const adapter = lookup(mapping.retailer);
    if (!adapter || adapter.status !== 'implemented' || (adapter.fixtureOnly && !deps.allowFixtureAdapters)) {
      unusable.add(mapping.retailer);
      await record('adapter_unavailable', mapping.retailer, null, null, adapter ? `${adapter.id} is a ${adapter.fixtureOnly ? 'fixture-only' : adapter.status} adapter` : 'unknown retailer');
      continue;
    }

    const blockedWhy = adapter.allowedHosts.map((h) => fetcher.blockedReason(h)).find(Boolean);
    if (blockedWhy) {
      stopped.add(mapping.retailer);
      continue;
    }

    try {
      let parsed;
      let sourceUrl = mapping.productUrl;
      let retrievedAt: Date;
      let method = 'page';
      if (adapter.officialFeed) {
        parsed = await adapter.officialFeed.fetchPrice(mapping.productUrl, fetcher);
        retrievedAt = now();
        method = 'feed';
      } else {
        const page = await fetcher.get(mapping.productUrl, adapter.allowedHosts);
        parsed = adapter.parseProductPage(page.body, page.url);
        sourceUrl = page.url;
        retrievedAt = page.retrievedAt;
      }
      await prisma.competitorShelfPriceObservation.create({
        data: {
          clientId,
          mappingId: mapping.id,
          retailer: adapter.id,
          productName: parsed.productName,
          packSize: parsed.packSize,
          shelfPrice: parsed.shelfPrice,
          promoPrice: parsed.promoPrice,
          promoEndsAt: parsed.promoEndsAt,
          sourceUrl,
          retrievedAt,
          method,
        },
      });
      report.observations += 1;
    } catch (err) {
      if (err instanceof CollectionRefusedError) {
        await record(err.kind, mapping.retailer, mapping.id, mapping.productUrl, err.message);
        if (err.kind === 'blocked' || err.kind === 'daily_cap') stopped.add(mapping.retailer);
        if (err.kind === 'not_configured') break;
      } else if (err instanceof ShelfPriceParseError) {
        await record('parse_failed', mapping.retailer, mapping.id, mapping.productUrl, err.message);
      } else {
        await record('error', mapping.retailer, mapping.id, mapping.productUrl, err instanceof Error ? err.name : 'error');
      }
    }
  }
  return report;
}
