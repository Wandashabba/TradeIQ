import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { round2 } from '../../lib/kpiMath';
import { ConflictError, NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { adapterFor } from './adapters';
import { collectionConfig, isCollectionGloballyEnabled } from './config';

/**
 * Competitor shelf prices: the legal switch, the admin-maintained SKU
 * mappings, and the read the assistant uses.
 *
 * Every function takes `clientId` and filters on it in the `where`. Mappings,
 * observations and the audit trail are all tenant-scoped; nothing here reads
 * across tenants.
 */

// ── The switch ─────────────────────────────────────────────────────────────

export interface CollectionSettings {
  enabled: boolean;
  approvedBy: string | null;
  approvedAt: string | null;
  /** The global kill switch as this process sees it. */
  killSwitch: 'on' | 'off';
  /** Whether collection and the assistant tool are actually live for this client. */
  active: boolean;
  /** Why not, when not. */
  inactiveReason: 'kill_switch' | 'client_disabled' | 'not_approved' | null;
}

export async function getCollectionSettings(
  clientId: string,
  env: NodeJS.ProcessEnv = process.env,
): Promise<CollectionSettings> {
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: {
      competitorPriceCollectionEnabled: true,
      competitorPriceCollectionApprovedBy: true,
      competitorPriceCollectionApprovedAt: true,
    },
  });
  if (!client) throw new NotFoundError('Client not found');
  const global = isCollectionGloballyEnabled(env);
  const approved = Boolean(client.competitorPriceCollectionApprovedBy && client.competitorPriceCollectionApprovedAt);
  const inactiveReason = !global
    ? 'kill_switch'
    : !client.competitorPriceCollectionEnabled
      ? 'client_disabled'
      : !approved
        ? 'not_approved'
        : null;
  return {
    enabled: client.competitorPriceCollectionEnabled,
    approvedBy: client.competitorPriceCollectionApprovedBy,
    approvedAt: client.competitorPriceCollectionApprovedAt?.toISOString() ?? null,
    killSwitch: global ? 'on' : 'off',
    active: inactiveReason === null,
    inactiveReason,
  };
}

/**
 * Switch collection on for a client. Both approval fields are required, and the
 * change and its audit row are one transaction: there is no state in which the
 * switch is on and the ledger does not say who approved it.
 */
export async function enableCollection(
  input: { clientId: string; userId: string; approvedBy: string; approvedAt: Date; note?: string },
  env: NodeJS.ProcessEnv = process.env,
): Promise<CollectionSettings> {
  await prisma.$transaction([
    prisma.client.update({
      where: { id: input.clientId },
      data: {
        competitorPriceCollectionEnabled: true,
        competitorPriceCollectionApprovedBy: input.approvedBy,
        competitorPriceCollectionApprovedAt: input.approvedAt,
      },
    }),
    prisma.competitorPriceCollectionAudit.create({
      data: {
        clientId: input.clientId,
        userId: input.userId,
        action: 'enabled',
        approvedBy: input.approvedBy,
        approvedAt: input.approvedAt,
        note: input.note ?? null,
      },
    }),
  ]);
  return getCollectionSettings(input.clientId, env);
}

/**
 * Switch it off. The approval is cleared, so switching back on needs a fresh
 * one; the previous approval stays in the audit ledger.
 */
export async function disableCollection(
  input: { clientId: string; userId: string; note?: string },
  env: NodeJS.ProcessEnv = process.env,
): Promise<CollectionSettings> {
  await prisma.$transaction([
    prisma.client.update({
      where: { id: input.clientId },
      data: {
        competitorPriceCollectionEnabled: false,
        competitorPriceCollectionApprovedBy: null,
        competitorPriceCollectionApprovedAt: null,
      },
    }),
    prisma.competitorPriceCollectionAudit.create({
      data: { clientId: input.clientId, userId: input.userId, action: 'disabled', note: input.note ?? null },
    }),
  ]);
  return getCollectionSettings(input.clientId, env);
}

export async function listCollectionAudit(clientId: string) {
  return prisma.competitorPriceCollectionAudit.findMany({
    where: { clientId },
    orderBy: { createdAt: 'desc' },
    take: 100,
  });
}

// ── Mappings ───────────────────────────────────────────────────────────────

export interface MappingInput {
  competitorSku: string;
  competitorBrand?: string | null;
  retailer: string;
  productUrl: string;
  packSize?: string | null;
  ourSkuId?: string | null;
}

const MAPPING_SELECT = {
  id: true,
  competitorSku: true,
  competitorBrand: true,
  retailer: true,
  productUrl: true,
  packSize: true,
  ourSkuId: true,
  active: true,
  createdAt: true,
  updatedAt: true,
} as const;

/** The URL must be a product page on the retailer's own host. */
export function validateProductUrl(retailer: string, productUrl: string): string {
  const adapter = adapterFor(retailer);
  if (!adapter) throw new ValidationError(`Unknown retailer "${retailer}"`);
  let url: URL;
  try {
    url = new URL(productUrl);
  } catch {
    throw new ValidationError('productUrl must be a URL');
  }
  url.hash = '';
  const normalised = url.toString();
  if (
    url.protocol !== 'https:' ||
    url.username ||
    url.password ||
    url.port ||
    !adapter.allowedHosts.includes(url.hostname) ||
    !adapter.productUrlPattern.test(normalised)
  ) {
    throw new ValidationError(`productUrl must be a ${adapter.displayName} product page URL`);
  }
  return normalised;
}

async function assertOwnSku(clientId: string, skuId: string | null | undefined) {
  if (!skuId) return;
  const sku = await prisma.sku.findFirst({ where: { id: skuId, clientId }, select: { id: true } });
  // Another tenant's SKU id reads exactly like one that does not exist.
  if (!sku) throw new ValidationError('ourSkuId is not one of your SKUs');
}

export async function listMappings(clientId: string, filter: { includeInactive?: boolean } = {}) {
  return prisma.competitorSkuMapping.findMany({
    where: { clientId, ...(filter.includeInactive ? {} : { active: true }) },
    select: MAPPING_SELECT,
    orderBy: [{ competitorSku: 'asc' }, { retailer: 'asc' }],
    take: 500,
  });
}

export async function createMapping(clientId: string, userId: string, input: MappingInput) {
  const productUrl = validateProductUrl(input.retailer, input.productUrl);
  await assertOwnSku(clientId, input.ourSkuId);
  try {
    return await prisma.competitorSkuMapping.create({
      data: {
        clientId,
        createdBy: userId,
        competitorSku: input.competitorSku.trim(),
        competitorBrand: input.competitorBrand?.trim() || null,
        retailer: input.retailer,
        productUrl,
        packSize: input.packSize?.trim() || null,
        ourSkuId: input.ourSkuId ?? null,
      },
      select: MAPPING_SELECT,
    });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      throw new ConflictError('That product page is already mapped');
    }
    throw err;
  }
}

export async function updateMapping(
  clientId: string,
  id: string,
  input: Partial<Omit<MappingInput, 'retailer' | 'productUrl'>> & { active?: boolean },
) {
  const existing = await prisma.competitorSkuMapping.findFirst({ where: { id, clientId }, select: { id: true } });
  if (!existing) throw new NotFoundError('Mapping not found');
  await assertOwnSku(clientId, input.ourSkuId);
  return prisma.competitorSkuMapping.update({
    where: { id },
    data: {
      ...(input.competitorSku !== undefined ? { competitorSku: input.competitorSku.trim() } : {}),
      ...(input.competitorBrand !== undefined ? { competitorBrand: input.competitorBrand?.trim() || null } : {}),
      ...(input.packSize !== undefined ? { packSize: input.packSize?.trim() || null } : {}),
      ...(input.ourSkuId !== undefined ? { ourSkuId: input.ourSkuId } : {}),
      ...(input.active !== undefined ? { active: input.active } : {}),
    },
    select: MAPPING_SELECT,
  });
}

// ── The assistant's read ───────────────────────────────────────────────────

export const OUTSIDE_DATA_LABEL = 'outside_public_retailer_website';

export interface ShelfPriceProvenance {
  origin: typeof OUTSIDE_DATA_LABEL;
  retailer: string;
  url: string;
  domain: string;
  retrievedAt: string;
  method: string;
}

export interface RetailerShelfPrice {
  retailer: string;
  retailerName: string;
  mappedPackSize: string | null;
  /** current · stale · no_observations */
  status: 'current' | 'stale' | 'no_observations';
  latest: {
    productNameOnPage: string;
    packSizeOnPage: string | null;
    shelfPrice: number;
    promoPrice: number | null;
    promoEndsAt: string | null;
    /** The promo price while a promo was showing, else the shelf price. */
    effectivePrice: number;
    retrievedAt: string;
    ageDays: number;
    stale: boolean;
    /** How to say it. For a stale price this says so; never quote it as current. */
    asOfLabel: string;
    provenance: ShelfPriceProvenance;
  } | null;
  trend: {
    from: string;
    to: string;
    observations: number;
    firstEffectivePrice: number;
    lastEffectivePrice: number;
    changePct: number | null;
    minEffectivePrice: number;
    maxEffectivePrice: number;
    /** Last price read each day, oldest first. */
    daily: { date: string; effectivePrice: number }[];
  } | null;
  gapVsOurPrice:
    | {
        ourPrice: number;
        competitorPrice: number;
        /** Competitor minus ours. Positive: the competitor is dearer. */
        gap: number;
        gapPct: number;
        note: string;
      }
    | null;
  gapWithheldReason: string | null;
}

export interface CompetitorShelfPrices {
  dataOrigin: typeof OUTSIDE_DATA_LABEL;
  about: string;
  asOf: string;
  staleAfterDays: number;
  trendDays: number;
  competitorSkus: {
    competitorSku: string;
    competitorBrand: string | null;
    ourSku: { skuId: string; name: string; price: number; priceBasis: string } | null;
    retailers: RetailerShelfPrice[];
  }[];
  /** One entry per page quoted: title, url, domain, retrievedAt. */
  sources: { title: string; url: string; domain: string; pageAge: string | null; retrievedAt: string; snippet: null }[];
  note: string | null;
}

const DAY_MS = 86_400_000;
const MAX_MAPPINGS = 40;
const OUR_PRICE_DAYS = 30;

/**
 * Latest price, trend and gap to our own price, per mapped competitor SKU and
 * retailer. Only mapped SKUs; only this client's observations.
 */
export async function getCompetitorShelfPrices(input: {
  clientId: string;
  now: Date;
  competitorSku?: string;
  retailer?: string;
  trendDays?: number;
  staleAfterDays?: number;
}): Promise<CompetitorShelfPrices> {
  const staleAfterDays = input.staleAfterDays ?? collectionConfig().staleAfterDays;
  const trendDays = input.trendDays ?? 30;
  const since = new Date(input.now.getTime() - trendDays * DAY_MS);

  const mappings = await prisma.competitorSkuMapping.findMany({
    where: {
      clientId: input.clientId,
      active: true,
      ...(input.retailer ? { retailer: input.retailer } : {}),
      ...(input.competitorSku
        ? {
            OR: [
              { competitorSku: { contains: input.competitorSku, mode: 'insensitive' as const } },
              { competitorBrand: { contains: input.competitorSku, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    },
    select: {
      id: true,
      competitorSku: true,
      competitorBrand: true,
      retailer: true,
      packSize: true,
      ourSku: { select: { id: true, name: true, rrp: true } },
    },
    orderBy: [{ competitorSku: 'asc' }, { retailer: 'asc' }],
    take: MAX_MAPPINGS,
  });

  const ids = mappings.map((m) => m.id);
  const [windowRows, latestRows, ourPrices] = await Promise.all([
    prisma.competitorShelfPriceObservation.findMany({
      where: { clientId: input.clientId, mappingId: { in: ids }, retrievedAt: { gte: since, lte: input.now } },
      orderBy: { retrievedAt: 'asc' },
      take: 5000,
    }),
    ids.length === 0
      ? Promise.resolve([])
      : prisma.$queryRaw<Array<{ id: string }>>`
          SELECT DISTINCT ON ("mapping_id") "id"
          FROM "competitor_shelf_price_observations"
          WHERE "client_id" = ${input.clientId}
            AND "mapping_id" IN (${Prisma.join(ids)})
            AND "retrieved_at" <= ${input.now.toISOString()}::timestamp
          ORDER BY "mapping_id", "retrieved_at" DESC
        `.then((rows) =>
          rows.length === 0
            ? []
            : prisma.competitorShelfPriceObservation.findMany({
                where: { clientId: input.clientId, id: { in: rows.map((r) => r.id) } },
              }),
        ),
    ourShelfPrices(
      input.clientId,
      [...new Set(mappings.map((m) => m.ourSku?.id).filter((x): x is string => Boolean(x)))],
      input.now,
    ),
  ]);

  const latestByMapping = new Map(latestRows.map((r) => [r.mappingId, r]));
  const windowByMapping = new Map<string, typeof windowRows>();
  for (const row of windowRows) {
    const list = windowByMapping.get(row.mappingId) ?? [];
    list.push(row);
    windowByMapping.set(row.mappingId, list);
  }

  const effective = (r: { shelfPrice: number; promoPrice: number | null; promoEndsAt: Date | null; retrievedAt: Date }) =>
    r.promoPrice !== null && (r.promoEndsAt === null || r.promoEndsAt >= r.retrievedAt) ? r.promoPrice : r.shelfPrice;

  const groups = new Map<string, CompetitorShelfPrices['competitorSkus'][number]>();
  const sources = new Map<string, CompetitorShelfPrices['sources'][number]>();

  for (const mapping of mappings) {
    const adapter = adapterFor(mapping.retailer);
    const retailerName = adapter?.displayName ?? mapping.retailer;
    const latest = latestByMapping.get(mapping.id) ?? null;
    const window = windowByMapping.get(mapping.id) ?? [];

    const key = mapping.competitorSku.trim().toLowerCase();
    const our = mapping.ourSku;
    const ourPrice = our ? ourPrices.get(our.id) : undefined;
    const group =
      groups.get(key) ??
      {
        competitorSku: mapping.competitorSku,
        competitorBrand: mapping.competitorBrand,
        ourSku: our
          ? ourPrice
            ? { skuId: our.id, name: our.name, price: ourPrice.price, priceBasis: ourPrice.basis }
            : { skuId: our.id, name: our.name, price: our.rrp, priceBasis: 'our RRP (no shelf prices captured by our agents in the last 30 days)' }
          : null,
        retailers: [],
      };
    groups.set(key, group);

    let latestOut: RetailerShelfPrice['latest'] = null;
    let status: RetailerShelfPrice['status'] = 'no_observations';
    let gap: RetailerShelfPrice['gapVsOurPrice'] = null;
    let gapWithheldReason: string | null = null;

    if (latest) {
      const ageDays = Math.floor((input.now.getTime() - latest.retrievedAt.getTime()) / DAY_MS);
      const stale = ageDays > staleAfterDays;
      status = stale ? 'stale' : 'current';
      const day = latest.retrievedAt.toISOString().slice(0, 10);
      const domain = safeDomain(latest.sourceUrl);
      latestOut = {
        productNameOnPage: latest.productName,
        packSizeOnPage: latest.packSize,
        shelfPrice: latest.shelfPrice,
        promoPrice: latest.promoPrice,
        promoEndsAt: latest.promoEndsAt?.toISOString() ?? null,
        effectivePrice: effective(latest),
        retrievedAt: latest.retrievedAt.toISOString(),
        ageDays,
        stale,
        asOfLabel: stale
          ? `STALE: last read from ${retailerName}'s website on ${day} (${ageDays} days ago) — not a current price`
          : `${retailerName} website, read ${day}`,
        provenance: {
          origin: OUTSIDE_DATA_LABEL,
          retailer: retailerName,
          url: latest.sourceUrl,
          domain,
          retrievedAt: latest.retrievedAt.toISOString(),
          method: latest.method,
        },
      };
      if (!sources.has(latest.sourceUrl)) {
        sources.set(latest.sourceUrl, {
          title: `${retailerName}: ${latest.productName}`,
          url: latest.sourceUrl,
          domain,
          pageAge: null,
          retrievedAt: latest.retrievedAt.toISOString(),
          snippet: null,
        });
      }

      if (!our) {
        gapWithheldReason = 'no product of ours is mapped to this competitor SKU';
      } else if (stale) {
        gapWithheldReason = `the latest competitor price is older than ${staleAfterDays} days`;
      } else {
        const ours = group.ourSku!.price;
        const theirs = latestOut.effectivePrice;
        gap = {
          ourPrice: ours,
          competitorPrice: theirs,
          gap: round2(theirs - ours),
          gapPct: round2(((theirs - ours) / ours) * 100),
          note:
            `Competitor price from ${retailerName}'s website vs ${group.ourSku!.priceBasis}. ` +
            'Different sources and possibly different pack sizes — compare with care.',
        };
      }
    } else {
      gapWithheldReason = 'no price has been collected for this mapping';
    }

    let trend: RetailerShelfPrice['trend'] = null;
    if (window.length > 0) {
      const daily = new Map<string, number>();
      for (const r of window) daily.set(r.retrievedAt.toISOString().slice(0, 10), effective(r));
      const first = effective(window[0]);
      const last = effective(window[window.length - 1]);
      const prices = window.map(effective);
      trend = {
        from: window[0].retrievedAt.toISOString(),
        to: window[window.length - 1].retrievedAt.toISOString(),
        observations: window.length,
        firstEffectivePrice: first,
        lastEffectivePrice: last,
        changePct: window.length > 1 ? round2(((last - first) / first) * 100) : null,
        minEffectivePrice: Math.min(...prices),
        maxEffectivePrice: Math.max(...prices),
        daily: [...daily.entries()].slice(-31).map(([date, effectivePrice]) => ({ date, effectivePrice })),
      };
    }

    group.retailers.push({
      retailer: mapping.retailer,
      retailerName,
      mappedPackSize: mapping.packSize,
      status,
      latest: latestOut,
      trend,
      gapVsOurPrice: gap,
      gapWithheldReason,
    });
  }

  return {
    dataOrigin: OUTSIDE_DATA_LABEL,
    about:
      'OUTSIDE, PUBLIC data: shelf prices read from retailers\' public websites by an automated collector. ' +
      'Not captured by our field team, not TradeIQ sales data, and online prices can differ from any given store. ' +
      'Quote every figure with its retailer and the date it was read; never present a stale price as current.',
    asOf: input.now.toISOString(),
    staleAfterDays,
    trendDays,
    competitorSkus: [...groups.values()],
    sources: [...sources.values()],
    note:
      mappings.length === 0
        ? input.competitorSku || input.retailer
          ? 'No mapped competitor SKU matches that. Only products an admin has mapped to a retailer page are collected.'
          : 'No competitor SKUs are mapped to retailer pages yet, so there is nothing to report.'
        : mappings.length === MAX_MAPPINGS
          ? `Showing the first ${MAX_MAPPINGS} mappings; narrow by competitor SKU or retailer for the rest.`
          : null,
  };
}

function safeDomain(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return '';
  }
}

/** Our average captured shelf price per SKU over the last 30 days. */
async function ourShelfPrices(clientId: string, skuIds: string[], now: Date) {
  const out = new Map<string, { price: number; basis: string }>();
  if (skuIds.length === 0) return out;
  const since = new Date(now.getTime() - OUR_PRICE_DAYS * DAY_MS);
  const rows = await prisma.$queryRaw<Array<{ skuId: string; avg: number; lines: number }>>`
    SELECT p."sku_id" AS "skuId", AVG(p."price_actual")::float AS "avg", COUNT(*)::int AS "lines"
    FROM "visit_pricing" p
    JOIN "visits" v ON v."id" = p."visit_id"
    JOIN "skus" s ON s."id" = p."sku_id"
    WHERE v."client_id" = ${clientId}
      AND s."client_id" = ${clientId}
      AND p."sku_id" IN (${Prisma.join(skuIds)})
      AND v."checkin_ts" >= ${since.toISOString()}::timestamp
      AND v."checkin_ts" <= ${now.toISOString()}::timestamp
    GROUP BY p."sku_id"
  `;
  for (const row of rows) {
    if (row.lines > 0 && row.avg > 0) {
      out.set(row.skuId, {
        price: round2(row.avg),
        basis: `our average shelf price captured by our agents over the last ${OUR_PRICE_DAYS} days (${row.lines} lines)`,
      });
    }
  }
  return out;
}
