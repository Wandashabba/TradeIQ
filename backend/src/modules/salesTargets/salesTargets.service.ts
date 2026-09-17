import { randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { buildPage } from '../../lib/pagination';
import { round2 } from '../../lib/kpiMath';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { getClientTimeZone } from '../clients/clients.service';
import { CsvSyntaxError, normaliseHeader, parseCsv } from './csv';
import { MonthWindow, localMonthOf, monthKey, monthWindow, parseMonth } from './salesMonth';

/**
 * Monthly sell-in targets per SKU, and actual-vs-target attainment (#119).
 *
 * ## What "actual" means here
 *
 * **Sell-in, from orders.** Actual units are the sum of `OrderLine.quantity`
 * on the client's orders that are not `cancelled`, placed within the target
 * month's local calendar days in `Client.timezone` (see `salesMonth.ts`). It
 * is what outlets ordered through TradeIQ, NOT what shoppers bought — there is
 * no POS or sell-out feed. Every surface labels it {@link SELL_IN_LABEL}; never
 * relabel it as consumer sales. `VisitStock.salesActual` / `salesTarget` are a
 * different, retired idea (#112) and are not read here.
 *
 * An order's moment is `Order.capturedAt` — when the agent took it on the
 * device — not `createdAt`, which is when the server received it (#338). An
 * order captured at 23:30 on 30 September and synced on 1 October is September
 * sell-in, because September is when the outlet ordered.
 */
export const SELL_IN_METRIC = 'sell_in_units' as const;
export const SELL_IN_LABEL = 'Sell-in (orders)';

/** A ceiling that no real monthly SKU target approaches; keeps `int4` safe. */
export const MAX_TARGET_UNITS = 1_000_000_000;
/** Rows one upload may carry. A client-wide month is SKUs x scopes, not more. */
export const MAX_IMPORT_ROWS = 5_000;
/** SKUs listed in one attainment report; `truncated` says when there were more. */
export const MAX_ATTAINMENT_SKUS = 1_000;

export type SalesTargetScope = 'client' | 'territory' | 'outlet';
export const SALES_TARGET_SCOPES: readonly SalesTargetScope[] = ['client', 'territory', 'outlet'];

const targetInclude = {
  sku: { select: { id: true, name: true } },
  territory: { select: { id: true, name: true, code: true } },
  outlet: { select: { id: true, name: true, code: true } },
} satisfies Prisma.SalesTargetInclude;

type TargetRow = Prisma.SalesTargetGetPayload<{ include: typeof targetInclude }>;

export function scopeOf(row: { territoryId: string | null; outletId: string | null }): SalesTargetScope {
  if (row.outletId) return 'outlet';
  if (row.territoryId) return 'territory';
  return 'client';
}

/** The wire shape: `month` as `YYYY-MM`, never a Date whose zone invites a guess. */
export function toSalesTargetDto(row: TargetRow) {
  return {
    id: row.id,
    skuId: row.skuId,
    sku: row.sku,
    month: monthKey(row.month),
    scope: scopeOf(row),
    territoryId: row.territoryId,
    territory: row.territory,
    outletId: row.outletId,
    outlet: row.outlet,
    targetUnits: row.targetUnits,
    createdById: row.createdById,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

export type SalesTargetDto = ReturnType<typeof toSalesTargetDto>;

/**
 * Attainment as a percentage, or null when there is no target to attain.
 *
 * Null, not 0 and not infinity, for a missing or zero target: "0% of nothing"
 * reads as a miss and "∞%" as a triumph, and neither is a measurement — the
 * same reasoning as `campaigns/roi.ts`.
 */
export function attainmentPct(actualUnits: number, targetUnits: number | null): number | null {
  if (targetUnits === null || targetUnits <= 0) return null;
  return round2((100 * actualUnits) / targetUnits);
}

// ── CRUD ────────────────────────────────────────────────────────────────────

export interface ListSalesTargetsInput {
  clientId: string;
  month?: Date;
  skuId?: string;
  territoryId?: string;
  outletId?: string;
  scope?: SalesTargetScope;
  limit: number;
  cursor?: string;
}

export async function listSalesTargets(input: ListSalesTargetsInput) {
  const and: Prisma.SalesTargetWhereInput[] = [{ clientId: input.clientId }];
  if (input.month) and.push({ month: input.month });
  if (input.skuId) and.push({ skuId: input.skuId });
  if (input.territoryId) and.push({ territoryId: input.territoryId });
  if (input.outletId) and.push({ outletId: input.outletId });
  if (input.scope === 'client') and.push({ territoryId: null, outletId: null });
  if (input.scope === 'territory') and.push({ territoryId: { not: null } });
  if (input.scope === 'outlet') and.push({ outletId: { not: null } });

  const rows = await prisma.salesTarget.findMany({
    where: { AND: and },
    // Tiebreaker direction matches the primary sort, as the cursor requires.
    orderBy: [{ month: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
    include: targetInclude,
  });
  const page = buildPage(rows, input.limit);
  return { ...page, data: page.data.map(toSalesTargetDto) };
}

interface UpsertRow {
  skuId: string;
  month: Date;
  territoryId: string | null;
  outletId: string | null;
  targetUnits: number;
}

/**
 * Upserts every row in ONE statement — so one transaction: all of them land or
 * none do.
 *
 * `ON CONFLICT` names the exact expression list of `sales_targets_scope_key`
 * (see the migration). Prisma's `upsert` cannot target an expression index, and
 * a find-then-write would race a second manager saving the same cell. Nullable
 * scope ids travel as '' and are turned back into NULL by `NULLIF`, so no array
 * parameter ever holds a null whose type the driver would have to guess.
 *
 * Callers must not pass the same scope twice: Postgres refuses to update one
 * row twice in a single statement. The CSV import rejects such duplicates as
 * row errors first.
 */
async function upsertRows(
  clientId: string,
  userId: string,
  rows: UpsertRow[],
): Promise<Array<{ id: string; inserted: boolean }>> {
  if (rows.length === 0) return [];
  // Columns are `timestamp without time zone` holding UTC, so the instant goes
  // as ISO text cast to `timestamp` rather than `now()`, which would be read in
  // the session's zone.
  const now = new Date().toISOString();
  return prisma.$queryRaw<Array<{ id: string; inserted: boolean }>>`
    INSERT INTO "sales_targets" (
      "id", "client_id", "sku_id", "month", "territory_id", "outlet_id",
      "target_units", "created_by_id", "created_at", "updated_at"
    )
    SELECT u.id, ${clientId}, u.sku_id, u.month, NULLIF(u.territory_id, ''), NULLIF(u.outlet_id, ''),
      u.target_units, ${userId}, ${now}::timestamp, ${now}::timestamp
    FROM unnest(
      ${rows.map(() => randomUUID())}::text[],
      ${rows.map((r) => r.skuId)}::text[],
      ${rows.map((r) => r.month.toISOString().slice(0, 10))}::date[],
      ${rows.map((r) => r.territoryId ?? '')}::text[],
      ${rows.map((r) => r.outletId ?? '')}::text[],
      ${rows.map((r) => r.targetUnits)}::int[]
    ) AS u(id, sku_id, month, territory_id, outlet_id, target_units)
    ON CONFLICT ("client_id", "sku_id", "month", (COALESCE("territory_id", '')), (COALESCE("outlet_id", '')))
    DO UPDATE SET "target_units" = EXCLUDED."target_units", "updated_at" = EXCLUDED."updated_at"
    RETURNING "id", ("xmax" = 0) AS "inserted"
  `;
}

export interface UpsertSalesTargetInput {
  clientId: string;
  userId: string;
  skuId: string;
  month: Date;
  territoryId?: string | null;
  outletId?: string | null;
  targetUnits: number;
}

/**
 * Sets the target for one SKU, month and scope — creating it or replacing its
 * units. Every id is resolved inside the caller's client first: another
 * tenant's SKU, territory or outlet is a 404, exactly as if it did not exist.
 */
export async function upsertSalesTarget(
  input: UpsertSalesTargetInput,
): Promise<{ target: SalesTargetDto; created: boolean }> {
  const territoryId = input.territoryId ?? null;
  const outletId = input.outletId ?? null;
  if (territoryId && outletId) {
    throw new ValidationError('A target is scoped to a territory or an outlet, not both');
  }

  const [sku, territory, outlet] = await Promise.all([
    prisma.sku.findFirst({ where: { id: input.skuId, clientId: input.clientId }, select: { id: true } }),
    territoryId
      ? prisma.territory.findFirst({ where: { id: territoryId, clientId: input.clientId }, select: { id: true } })
      : null,
    outletId
      ? prisma.outlet.findFirst({ where: { id: outletId, clientId: input.clientId }, select: { id: true } })
      : null,
  ]);
  if (!sku) throw new NotFoundError('SKU not found');
  if (territoryId && !territory) throw new NotFoundError('Territory not found');
  if (outletId && !outlet) throw new NotFoundError('Outlet not found');

  const [result] = await upsertRows(input.clientId, input.userId, [
    { skuId: input.skuId, month: input.month, territoryId, outletId, targetUnits: input.targetUnits },
  ]);
  const row = await prisma.salesTarget.findUniqueOrThrow({
    where: { id: result.id },
    include: targetInclude,
  });
  return { target: toSalesTargetDto(row), created: result.inserted };
}

export async function deleteSalesTarget(id: string, clientId: string): Promise<void> {
  const { count } = await prisma.salesTarget.deleteMany({ where: { id, clientId } });
  if (count === 0) {
    throw new NotFoundError('Sales target not found');
  }
}

// ── CSV import ──────────────────────────────────────────────────────────────

type ImportColumn = 'month' | 'sku' | 'targetUnits' | 'territory' | 'outlet';

/** Accepted header spellings, after `normaliseHeader`. */
const COLUMN_ALIASES: Record<string, ImportColumn> = {
  month: 'month',
  sku: 'sku',
  skuid: 'sku',
  skuname: 'sku',
  targetunits: 'targetUnits',
  target: 'targetUnits',
  units: 'targetUnits',
  territory: 'territory',
  territoryid: 'territory',
  territorycode: 'territory',
  outlet: 'outlet',
  outletid: 'outlet',
  outletcode: 'outlet',
};

const REQUIRED_COLUMNS: readonly ImportColumn[] = ['month', 'sku', 'targetUnits'];

export interface ImportRowError {
  /** 1-based CSV row; the header is row 1. */
  row: number;
  column: ImportColumn | null;
  message: string;
}

export interface ImportPreviewRow {
  row: number;
  skuId: string;
  skuName: string;
  month: string;
  scope: SalesTargetScope;
  territoryId: string | null;
  territoryCode: string | null;
  outletId: string | null;
  outletCode: string | null;
  targetUnits: number;
  /** Whether this row creates a target or replaces an existing one's units. */
  action: 'create' | 'update';
}

export interface ImportResult {
  dryRun: boolean;
  /** Non-blank data rows read. */
  totalRows: number;
  validRows: number;
  invalidRows: number;
  errors: ImportRowError[];
  rows: ImportPreviewRow[];
  /** Applied counts, or — on a dry run — what applying would do. */
  created: number;
  updated: number;
}

export interface ImportSalesTargetsInput {
  clientId: string;
  userId: string;
  csv: string;
  dryRun: boolean;
}

const WHOLE_NUMBER = /^\d+$/;

function scopeKey(skuId: string, month: Date, territoryId: string | null, outletId: string | null): string {
  return `${skuId}|${monthKey(month)}|${territoryId ?? ''}|${outletId ?? ''}`;
}

/**
 * Validates every row of a target upload and, unless `dryRun`, upserts all the
 * valid ones in one statement.
 *
 * A file-level problem (unreadable CSV, missing required column, no rows, too
 * many rows) is a {@link ValidationError} — there is nothing row-shaped to
 * report. Everything else is a per-row error, and invalid rows never block the
 * valid ones: the manager fixes the few bad lines and re-uploads, and because
 * the write is an upsert, re-uploading the rows that already landed is a no-op.
 *
 * Columns: `month` (`YYYY-MM`), `sku` (SKU id, or its exact name ignoring
 * case), `targetUnits` (whole number), and optional `territory` (id or code)
 * and `outlet` (id or code). Every lookup is confined to the caller's client,
 * so another tenant's id or code is "not found" like any typo.
 */
export async function importSalesTargets(input: ImportSalesTargetsInput): Promise<ImportResult> {
  let records;
  try {
    records = parseCsv(input.csv);
  } catch (err) {
    if (err instanceof CsvSyntaxError) throw new ValidationError(err.message);
    throw err;
  }
  if (records.length === 0) {
    throw new ValidationError('The CSV is empty');
  }

  const columnIndex = new Map<ImportColumn, number>();
  records[0].fields.forEach((name, index) => {
    const column = COLUMN_ALIASES[normaliseHeader(name)];
    if (!column) return;
    if (columnIndex.has(column)) {
      throw new ValidationError(`The header names the ${column} column more than once`);
    }
    columnIndex.set(column, index);
  });
  const missing = REQUIRED_COLUMNS.filter((column) => !columnIndex.has(column));
  if (missing.length > 0) {
    throw new ValidationError(
      `The header row must include ${REQUIRED_COLUMNS.join(', ')} (missing: ${missing.join(', ')})`,
    );
  }

  const dataRows = records.slice(1);
  if (dataRows.length === 0) {
    throw new ValidationError('The CSV has a header but no target rows');
  }
  if (dataRows.length > MAX_IMPORT_ROWS) {
    throw new ValidationError(`At most ${MAX_IMPORT_ROWS} rows per upload (got ${dataRows.length})`);
  }

  const cell = (fields: string[], column: ImportColumn): string => {
    const index = columnIndex.get(column);
    return index === undefined ? '' : (fields[index] ?? '').trim();
  };

  const territoryTokens = new Set<string>();
  const outletTokens = new Set<string>();
  for (const record of dataRows) {
    const territory = cell(record.fields, 'territory');
    const outlet = cell(record.fields, 'outlet');
    if (territory) territoryTokens.add(territory);
    if (outlet) outletTokens.add(outlet);
  }

  // SKUs have no code, so a row may name one by id or by name; the whole
  // client catalog is read once (two columns) rather than guessing which rows
  // hold which.
  const [skus, territories, outlets] = await Promise.all([
    prisma.sku.findMany({ where: { clientId: input.clientId }, select: { id: true, name: true } }),
    territoryTokens.size > 0
      ? prisma.territory.findMany({
          where: {
            clientId: input.clientId,
            OR: [{ id: { in: [...territoryTokens] } }, { code: { in: [...territoryTokens] } }],
          },
          select: { id: true, code: true },
        })
      : [],
    outletTokens.size > 0
      ? prisma.outlet.findMany({
          where: {
            clientId: input.clientId,
            OR: [{ id: { in: [...outletTokens] } }, { code: { in: [...outletTokens] } }],
          },
          select: { id: true, code: true },
        })
      : [],
  ]);

  const skuById = new Map(skus.map((s) => [s.id, s]));
  const skusByName = new Map<string, typeof skus>();
  for (const sku of skus) {
    const key = sku.name.trim().toLowerCase();
    skusByName.set(key, [...(skusByName.get(key) ?? []), sku]);
  }
  const territoryByToken = new Map<string, { id: string; code: string }>();
  for (const t of territories) {
    territoryByToken.set(t.id, t);
    territoryByToken.set(t.code, t);
  }
  const outletByToken = new Map<string, { id: string; code: string }>();
  for (const o of outlets) {
    outletByToken.set(o.id, o);
    outletByToken.set(o.code, o);
  }

  const errors: ImportRowError[] = [];
  const valid: Array<Omit<ImportPreviewRow, 'action'> & { monthDate: Date }> = [];
  const firstRowForKey = new Map<string, number>();

  for (const record of dataRows) {
    const rowErrors: ImportRowError[] = [];
    const fail = (column: ImportColumn | null, message: string) =>
      rowErrors.push({ row: record.row, column, message });

    const monthRaw = cell(record.fields, 'month');
    const month = parseMonth(monthRaw);
    if (!month) fail('month', monthRaw ? `"${monthRaw}" is not a month; use YYYY-MM` : 'month is required');

    const skuRaw = cell(record.fields, 'sku');
    let sku: { id: string; name: string } | undefined;
    if (!skuRaw) {
      fail('sku', 'sku is required');
    } else {
      sku = skuById.get(skuRaw);
      if (!sku) {
        const byName = skusByName.get(skuRaw.toLowerCase()) ?? [];
        if (byName.length === 1) sku = byName[0];
        else if (byName.length > 1) fail('sku', `"${skuRaw}" matches ${byName.length} SKUs; use the SKU id`);
        else fail('sku', `No SKU "${skuRaw}" in this account`);
      }
    }

    const unitsRaw = cell(record.fields, 'targetUnits');
    const targetUnits = WHOLE_NUMBER.test(unitsRaw) ? Number(unitsRaw) : NaN;
    if (!(targetUnits >= 0 && targetUnits <= MAX_TARGET_UNITS)) {
      fail('targetUnits', `targetUnits must be a whole number from 0 to ${MAX_TARGET_UNITS}`);
    }

    const territoryRaw = cell(record.fields, 'territory');
    const outletRaw = cell(record.fields, 'outlet');
    let territory: { id: string; code: string } | undefined;
    let outlet: { id: string; code: string } | undefined;
    if (territoryRaw && outletRaw) {
      fail(null, 'A target is scoped to a territory or an outlet, not both');
    } else if (territoryRaw) {
      territory = territoryByToken.get(territoryRaw);
      if (!territory) fail('territory', `No territory "${territoryRaw}" in this account`);
    } else if (outletRaw) {
      outlet = outletByToken.get(outletRaw);
      if (!outlet) fail('outlet', `No outlet "${outletRaw}" in this account`);
    }

    if (rowErrors.length === 0 && month && sku) {
      const key = scopeKey(sku.id, month, territory?.id ?? null, outlet?.id ?? null);
      const earlier = firstRowForKey.get(key);
      if (earlier !== undefined) {
        fail(null, `Duplicates row ${earlier}: same SKU, month and scope`);
      } else {
        firstRowForKey.set(key, record.row);
      }
    }

    if (rowErrors.length > 0) {
      errors.push(...rowErrors);
      continue;
    }
    valid.push({
      row: record.row,
      skuId: sku!.id,
      skuName: sku!.name,
      month: monthKey(month!),
      monthDate: month!,
      scope: outlet ? 'outlet' : territory ? 'territory' : 'client',
      territoryId: territory?.id ?? null,
      territoryCode: territory?.code ?? null,
      outletId: outlet?.id ?? null,
      outletCode: outlet?.code ?? null,
      targetUnits,
    });
  }

  const existing =
    valid.length > 0
      ? await prisma.salesTarget.findMany({
          where: {
            clientId: input.clientId,
            skuId: { in: [...new Set(valid.map((v) => v.skuId))] },
            month: { in: [...new Map(valid.map((v) => [v.month, v.monthDate])).values()] },
          },
          select: { skuId: true, month: true, territoryId: true, outletId: true },
        })
      : [];
  const existingKeys = new Set(existing.map((e) => scopeKey(e.skuId, e.month, e.territoryId, e.outletId)));

  const rows: ImportPreviewRow[] = valid.map(({ monthDate, ...row }) => ({
    ...row,
    action: existingKeys.has(scopeKey(row.skuId, monthDate, row.territoryId, row.outletId)) ? 'update' : 'create',
  }));

  let created = rows.filter((r) => r.action === 'create').length;
  let updated = rows.length - created;

  if (!input.dryRun && valid.length > 0) {
    const results = await upsertRows(
      input.clientId,
      input.userId,
      valid.map((v) => ({
        skuId: v.skuId,
        month: v.monthDate,
        territoryId: v.territoryId,
        outletId: v.outletId,
        targetUnits: v.targetUnits,
      })),
    );
    // The statement's own answer, not the preview's: a concurrent save between
    // the read above and this write would otherwise be miscounted.
    created = results.filter((r) => r.inserted).length;
    updated = results.length - created;
  }

  return {
    dryRun: input.dryRun,
    totalRows: dataRows.length,
    validRows: rows.length,
    invalidRows: new Set(errors.map((e) => e.row)).size,
    errors,
    rows,
    created,
    updated,
  };
}

// ── Actual vs target ────────────────────────────────────────────────────────

interface SellInRow {
  sku_id: string;
  outlet_id: string;
  territory_code: string;
  units: bigint | number;
}

/**
 * Sell-in units for the month, per SKU per outlet, with each outlet's
 * territory code (`Outlet.territoryId` stores `Territory.code`, never its id —
 * see `dashboard.service.ts`). One grouped query; the rollups happen in memory.
 *
 * Dated by `captured_at` (#338), so an order taken offline on the last day of
 * the month counts toward that month rather than the next one.
 */
async function sellInForMonth(clientId: string, window: MonthWindow, skuId?: string): Promise<SellInRow[]> {
  return prisma.$queryRaw<SellInRow[]>`
    SELECT ol."sku_id", o."outlet_id", ou."territory_id" AS "territory_code",
      SUM(ol."quantity")::bigint AS "units"
    FROM "order_lines" ol
    JOIN "orders" o ON o."id" = ol."order_id"
    JOIN "outlets" ou ON ou."id" = o."outlet_id"
    WHERE o."client_id" = ${clientId}
      AND o."status" <> 'cancelled'
      AND o."captured_at" >= ${window.from.toISOString()}::timestamp
      AND o."captured_at" < ${window.to.toISOString()}::timestamp
      ${skuId ? Prisma.sql`AND ol."sku_id" = ${skuId}` : Prisma.empty}
    GROUP BY ol."sku_id", o."outlet_id", ou."territory_id"
  `;
}

export interface AttainmentFigures {
  targetUnits: number | null;
  actualUnits: number;
  attainmentPct: number | null;
}

export interface ScopedAttainment extends AttainmentFigures {
  targetId: string;
  targetUnits: number;
  scope: Exclude<SalesTargetScope, 'client'>;
  territory: { id: string; name: string; code: string } | null;
  outlet: { id: string; name: string; code: string } | null;
}

export interface SkuAttainment extends AttainmentFigures {
  skuId: string;
  skuName: string;
  category: string;
  /** The client-wide target's id, or null when this SKU has none this month. */
  targetId: string | null;
  /** Territory- and outlet-scoped targets for this SKU, territories first. */
  scoped: ScopedAttainment[];
}

export interface LevelSummary {
  targets: number;
  targetUnits: number;
  actualUnits: number;
  attainmentPct: number | null;
}

export interface AttainmentReport {
  month: string;
  timeZone: string;
  /** The month's local days as instants, `[from, to)`. */
  from: Date;
  to: Date;
  metric: typeof SELL_IN_METRIC;
  metricLabel: typeof SELL_IN_LABEL;
  skus: SkuAttainment[];
  /**
   * Totals per scope level. Levels are never added together: a client-wide
   * target and a territory target for the same SKU count the same orders, so a
   * grand total would double-count. Within one level the targets are disjoint
   * (an outlet sits in one territory), so their sums are honest.
   */
  summary: Record<SalesTargetScope, LevelSummary>;
  truncated: boolean;
}

/**
 * Actual sell-in against target for every SKU in the month.
 *
 * Every SKU gets a row — with `targetUnits: null` where no client-wide target
 * is set — so a manager sees what sold without a target, not only what was
 * targeted. Scoped targets hang off their SKU with their own actuals: a
 * territory's is the sell-in of the outlets in that territory, an outlet's is
 * that outlet's.
 */
export async function getSalesAttainment(input: {
  clientId: string;
  /**
   * The month to report on. Omitted means *the client's* current month (#339):
   * which month it is is decided by the wall clock in `Client.timezone`, not by
   * the clock of whatever device asked. At 23:30Z on 30 September a Johannesburg
   * account is already in October and a UTC one is still in September, and two
   * managers looking at the same account must not see different months.
   */
  month?: Date;
  skuId?: string;
  /** The instant read as "now" when `month` is omitted. Tests pin it. */
  now?: Date;
}): Promise<AttainmentReport> {
  const timeZone = await getClientTimeZone(input.clientId);
  const month = input.month ?? localMonthOf(input.now ?? new Date(), timeZone);
  const window = monthWindow(month, timeZone);

  const [skuRows, targets, sellIn] = await Promise.all([
    prisma.sku.findMany({
      where: { clientId: input.clientId, ...(input.skuId ? { id: input.skuId } : {}) },
      select: { id: true, name: true, category: true },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      take: MAX_ATTAINMENT_SKUS + 1,
    }),
    prisma.salesTarget.findMany({
      where: { clientId: input.clientId, month: window.month, ...(input.skuId ? { skuId: input.skuId } : {}) },
      include: targetInclude,
    }),
    sellInForMonth(input.clientId, window, input.skuId),
  ]);

  const bySku = new Map<string, number>();
  const bySkuOutlet = new Map<string, number>();
  const bySkuTerritoryCode = new Map<string, number>();
  const add = (map: Map<string, number>, key: string, units: number) =>
    map.set(key, (map.get(key) ?? 0) + units);
  for (const row of sellIn) {
    const units = Number(row.units);
    add(bySku, row.sku_id, units);
    add(bySkuOutlet, `${row.sku_id}|${row.outlet_id}`, units);
    add(bySkuTerritoryCode, `${row.sku_id}|${row.territory_code}`, units);
  }

  const summary: Record<SalesTargetScope, LevelSummary> = {
    client: { targets: 0, targetUnits: 0, actualUnits: 0, attainmentPct: null },
    territory: { targets: 0, targetUnits: 0, actualUnits: 0, attainmentPct: null },
    outlet: { targets: 0, targetUnits: 0, actualUnits: 0, attainmentPct: null },
  };
  const clientTargetBySku = new Map<string, TargetRow>();
  const scopedBySku = new Map<string, ScopedAttainment[]>();

  for (const target of targets) {
    const scope = scopeOf(target);
    let actualUnits: number;
    if (scope === 'client') {
      actualUnits = bySku.get(target.skuId) ?? 0;
      clientTargetBySku.set(target.skuId, target);
    } else if (scope === 'territory') {
      actualUnits = bySkuTerritoryCode.get(`${target.skuId}|${target.territory!.code}`) ?? 0;
    } else {
      actualUnits = bySkuOutlet.get(`${target.skuId}|${target.outletId}`) ?? 0;
    }

    const level = summary[scope];
    level.targets += 1;
    level.targetUnits += target.targetUnits;
    level.actualUnits += actualUnits;

    if (scope !== 'client') {
      scopedBySku.set(target.skuId, [
        ...(scopedBySku.get(target.skuId) ?? []),
        {
          targetId: target.id,
          scope,
          territory: target.territory,
          outlet: target.outlet,
          targetUnits: target.targetUnits,
          actualUnits,
          attainmentPct: attainmentPct(actualUnits, target.targetUnits),
        },
      ]);
    }
  }
  for (const level of Object.values(summary)) {
    level.attainmentPct = attainmentPct(level.actualUnits, level.targetUnits);
  }

  const scopeLabel = (s: ScopedAttainment) => `${s.scope === 'territory' ? 0 : 1}|${s.territory?.name ?? s.outlet?.name ?? ''}`;
  const skus: SkuAttainment[] = skuRows.slice(0, MAX_ATTAINMENT_SKUS).map((sku) => {
    const target = clientTargetBySku.get(sku.id);
    const actualUnits = bySku.get(sku.id) ?? 0;
    const targetUnits = target?.targetUnits ?? null;
    return {
      skuId: sku.id,
      skuName: sku.name,
      category: sku.category,
      targetId: target?.id ?? null,
      targetUnits,
      actualUnits,
      attainmentPct: attainmentPct(actualUnits, targetUnits),
      scoped: (scopedBySku.get(sku.id) ?? []).sort((a, b) => scopeLabel(a).localeCompare(scopeLabel(b))),
    };
  });

  return {
    month: window.key,
    timeZone,
    from: window.from,
    to: window.to,
    metric: SELL_IN_METRIC,
    metricLabel: SELL_IN_LABEL,
    skus,
    summary,
    truncated: skuRows.length > MAX_ATTAINMENT_SKUS,
  };
}
