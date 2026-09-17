import { Prisma, ReportDefinition, TaskStatus, VisitStatus } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { buildPage } from '../../lib/pagination';

// The report kinds a ReportDefinition can generate. `ReportDefinition.type` is a
// free-text column at the schema level; this is the runtime allow-list.
export const REPORT_TYPES = ['visits', 'scorecards', 'tasks', 'orders'] as const;
export type ReportType = (typeof REPORT_TYPES)[number];

export function isReportType(value: unknown): value is ReportType {
  return typeof value === 'string' && (REPORT_TYPES as readonly string[]).includes(value);
}

// A generated report is a homogeneous list of Prisma rows for the definition's
// type; callers treat each row as an opaque bag of scalar/JSON fields.
export type ReportRow = Record<string, unknown>;

export interface GeneratedReport {
  definition: ReportDefinition;
  generatedAt: string;
  rowCount: number;
  rows: ReportRow[];
}

export interface CreateReportInput {
  clientId: string;
  name: string;
  type: ReportType;
  filters: Prisma.InputJsonValue;
}

export async function createReport(input: CreateReportInput): Promise<ReportDefinition> {
  return prisma.reportDefinition.create({
    data: {
      clientId: input.clientId,
      name: input.name,
      type: input.type,
      filters: input.filters,
    },
  });
}

export interface ListReportsInput {
  clientId: string;
  limit: number;
  cursor?: string;
}

export async function listReports(
  input: ListReportsInput,
): Promise<{ data: ReportDefinition[]; nextCursor: string | null }> {
  const rows = await prisma.reportDefinition.findMany({
    where: { clientId: input.clientId },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two report definitions share a createdAt — same reasoning as
    // alerts.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}

export async function findReportForClient(id: string, clientId: string): Promise<ReportDefinition> {
  const definition = await prisma.reportDefinition.findFirst({ where: { id, clientId } });
  if (!definition) {
    throw new NotFoundError('Report definition not found');
  }
  return definition;
}

export async function deleteReport(id: string, clientId: string): Promise<void> {
  // Tenant check first — a cross-tenant id must 404, not delete.
  await findReportForClient(id, clientId);
  await prisma.reportDefinition.delete({ where: { id } });
}

// The subset of a definition's stored `filters` JSON we act on. Everything else
// in the JSON is ignored.
interface ReportFilters {
  from?: string;
  to?: string;
  outletId?: string;
  status?: string;
}

function readFilters(raw: Prisma.JsonValue): ReportFilters {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return {};
  }
  const obj = raw as Record<string, unknown>;
  const filters: ReportFilters = {};
  if (typeof obj.from === 'string') {
    filters.from = obj.from;
  }
  if (typeof obj.to === 'string') {
    filters.to = obj.to;
  }
  if (typeof obj.outletId === 'string') {
    filters.outletId = obj.outletId;
  }
  if (typeof obj.status === 'string') {
    filters.status = obj.status;
  }
  return filters;
}

// Build a Prisma date-range filter from optional { from, to }; invalid dates are
// dropped. `asOf`, when given, caps the upper bound (the tighter of it and
// `to` wins). Returns undefined when no bound is usable.
function dateRange(filters: ReportFilters, asOf?: Date): { gte?: Date; lte?: Date } | undefined {
  const range: { gte?: Date; lte?: Date } = {};
  if (filters.from) {
    const from = new Date(filters.from);
    if (!Number.isNaN(from.getTime())) {
      range.gte = from;
    }
  }
  if (filters.to) {
    const to = new Date(filters.to);
    if (!Number.isNaN(to.getTime())) {
      range.lte = to;
    }
  }
  if (asOf && (!range.lte || asOf < range.lte)) {
    range.lte = asOf;
  }
  return range.gte || range.lte ? range : undefined;
}

export interface GenerateReportOptions {
  /**
   * Only rows whose report date (checkinTs for visits, capturedAt for orders,
   * createdAt otherwise) is
   * at or before this instant. A scheduled run's CSV is regenerated with its
   * `generatedAt` here (#66), so records added after the run stay out of it.
   */
  asOf?: Date;
}

export async function generateReport(
  id: string,
  clientId: string,
  options: GenerateReportOptions = {},
): Promise<GeneratedReport> {
  const definition = await findReportForClient(id, clientId);
  const filters = readFilters(definition.filters);
  const range = dateRange(filters, options.asOf);

  let rows: ReportRow[];
  switch (definition.type) {
    case 'scorecards':
      // Scorecards carry no clientId of their own — scope through the visit;
      // only a createdAt date window applies.
      rows = (await prisma.scorecard.findMany({
        where: {
          visit: { clientId },
          ...(range ? { createdAt: range } : {}),
        },
        orderBy: { createdAt: 'desc' },
      })) as unknown as ReportRow[];
      break;
    case 'tasks':
      // Tasks scope through their outlet; support status + createdAt window.
      rows = (await prisma.task.findMany({
        where: {
          outlet: { clientId },
          ...(filters.status ? { status: filters.status as TaskStatus } : {}),
          ...(range ? { createdAt: range } : {}),
        },
        orderBy: { createdAt: 'desc' },
      })) as unknown as ReportRow[];
      break;
    case 'orders':
      // Dated by capture, like visits are dated by checkinTs rather than the
      // row's createdAt (#338). "Orders between the 1st and the 30th" is a
      // question about when the outlets ordered, so an order taken on the 30th
      // and synced on the 1st belongs in the earlier report — the same rule the
      // attainment and forecast reads follow, so a manager reconciling a CSV
      // against the attainment screen sees the same orders in the same month.
      rows = (await prisma.order.findMany({
        where: {
          clientId,
          ...(filters.outletId ? { outletId: filters.outletId } : {}),
          ...(filters.status ? { status: filters.status } : {}),
          ...(range ? { capturedAt: range } : {}),
        },
        orderBy: { capturedAt: 'desc' },
      })) as unknown as ReportRow[];
      break;
    case 'visits':
    default:
      // Visits are the default kind; date window applies to checkinTs.
      rows = (await prisma.visit.findMany({
        where: {
          clientId,
          ...(filters.outletId ? { outletId: filters.outletId } : {}),
          ...(filters.status ? { status: filters.status as VisitStatus } : {}),
          ...(range ? { checkinTs: range } : {}),
        },
        orderBy: { checkinTs: 'desc' },
      })) as unknown as ReportRow[];
      break;
  }

  return {
    definition,
    generatedAt: new Date().toISOString(),
    rowCount: rows.length,
    rows,
  };
}

function csvCell(value: unknown): string {
  let cell: string;
  if (value === null || value === undefined) {
    cell = '';
  } else if (value instanceof Date) {
    cell = value.toISOString();
  } else if (typeof value === 'object') {
    // JSON/nested fields are stringified rather than flattened into columns.
    cell = JSON.stringify(value);
  } else {
    cell = String(value);
  }
  // Formula-injection guard (CWE-1236): a spreadsheet treats a cell beginning
  // with = + - @ (or a leading tab/CR) as a formula. Prefix with an apostrophe
  // so it is rendered as text. Applied before CSV quoting.
  if (/^[=+\-@\t\r]/.test(cell)) {
    cell = `'${cell}`;
  }
  return /[",\n\r]/.test(cell) ? `"${cell.replace(/"/g, '""')}"` : cell;
}

// Serialize generated rows to CSV: a header row, then one line per row.
// Nested/JSON values are stringified; empty input yields ''.
export function rowsToCsv(rows: ReportRow[]): string {
  if (rows.length === 0) {
    return '';
  }

  // The column set is the UNION of every row's keys, in first-seen order — not
  // the first row's keys alone. Report rows are assembled per record, so a
  // nullable field absent from row 1 is ordinary. Taking only row 1's keys
  // silently dropped later columns, and a row missing an early field shifted
  // every later value one column left: a file that reads as clean data while
  // attributing values to the wrong column. Misaligned data is worse than
  // absent data, because nothing about it looks wrong.
  const columns: string[] = [];
  const seen = new Set<string>();
  for (const row of rows) {
    for (const key of Object.keys(row)) {
      if (!seen.has(key)) {
        seen.add(key);
        columns.push(key);
      }
    }
  }

  // Header cells go through the same escaping as data cells. A report
  // definition whose field is named `price, ex VAT` otherwise emitted one more
  // header column than every data row.
  const header = columns.map((col) => csvCell(col)).join(',');
  const lines = rows.map((row) => columns.map((col) => csvCell(row[col])).join(','));
  return [header, ...lines].join('\n');
}
