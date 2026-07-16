# Quick Wins Batch — #120, #121, #99, #96, #95 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close five independent, well-scoped backend issues in one batch: a perf fix, a bug fix, a schema-extending feature (promo pricing), and two new read endpoints (territory coverage rate, share-of-shelf trend).

**Architecture:** Five independent tasks, no ordering dependency between them except Task 5 depends on a small shared-lib extraction that Task 5 itself performs. Each task is its own commit(s), reviewed independently.

**Tech Stack:** Node/Express/TypeScript/Prisma/PostgreSQL (backend only — Task 3 also touches the Flutter app). Jest+Supertest for tests.

---

## Task 1: Backend — #120: bound `fetchStockHistoryForOutlet`'s fetch + add ORDER BY tiebreaker

`backend/src/services/stock-derived.service.ts`'s `fetchStockHistoryForOutlet` currently fetches **every** `VisitStock` row for an outlet (no `take`), then caps to 5-per-SKU in a JS loop — Prisma can't express per-group `LIMIT` without raw SQL. Replace with a `ROW_NUMBER() OVER (PARTITION BY sku_id ...)` raw query that does the capping in Postgres, and add `created_at` as a secondary sort key so two visits with identical `checkin_ts` (unlikely but possible) don't make the result nondeterministic.

Confirmed table/column names via `schema.prisma`'s `@map`s: `visit_stock` (`sku_id`, `units_available`, `visit_id`, `created_at`), `visits` (`outlet_id`, `client_id`, `checkin_ts`, `id`).

```ts
import { Prisma } from '@prisma/client';
import { prisma } from '../lib/prisma';

// ... StockHistoryRow, computeDaysOutOfStock, computeVelocityAvg unchanged ...

const HISTORY_WINDOW = 5;

interface RankedStockRow {
  sku_id: string;
  units_available: number;
  checkin_ts: Date;
}

/**
 * One query for every SKU's stock history at this outlet, capped at the
 * last 5 VisitStock rows per SKU (newest-first) via a window function --
 * Postgres does the per-SKU capping, so this is a single bounded round trip
 * regardless of how much history the outlet has accumulated (#120; the
 * earlier fetch-all-then-slice-in-memory version had no bound on the initial
 * fetch, matching the pattern dashboard.service.ts's getDashboardByTerritory
 * uses for its own N+1 fix, #97, but without that fix's "small dataset"
 * assumption holding here as history grows).
 */
export async function fetchStockHistoryForOutlet(
  outletId: string,
  clientId: string,
): Promise<Map<string, StockHistoryRow[]>> {
  const rows = await prisma.$queryRaw<RankedStockRow[]>(
    Prisma.sql`
      SELECT sku_id, units_available, checkin_ts
      FROM (
        SELECT vs.sku_id, vs.units_available, v.checkin_ts,
          ROW_NUMBER() OVER (
            PARTITION BY vs.sku_id
            ORDER BY v.checkin_ts DESC, vs.created_at DESC
          ) AS rn
        FROM visit_stock vs
        JOIN visits v ON v.id = vs.visit_id
        WHERE v.outlet_id = ${outletId} AND v.client_id = ${clientId}
      ) ranked
      WHERE rn <= ${HISTORY_WINDOW}
      ORDER BY sku_id, checkin_ts DESC
    `,
  );

  const bySku = new Map<string, StockHistoryRow[]>();
  for (const row of rows) {
    const list = bySku.get(row.sku_id) ?? [];
    list.push({ visitCheckinTs: row.checkin_ts, unitsAvailable: row.units_available });
    bySku.set(row.sku_id, list);
  }
  return bySku;
}
```

The window function guarantees at most 5 rows per SKU come back at all (no post-hoc JS length check needed) and `ORDER BY sku_id, checkin_ts DESC` in the outer query keeps each SKU's group internally newest-first, matching what `computeDaysOutOfStock`/`computeVelocityAvg` already assume.

**Testing:** `stock-derived.service.test.ts` currently only tests the pure functions (no test for `fetchStockHistoryForOutlet` — matches the established precedent of not unit-testing thin data-access functions). Add a new test file `stock-derived.service.fetch.test.ts` (real Postgres, like `skus.routes.test.ts`'s history test) that:
- Seeds a `Client`/`User`/`Outlet` and two `Sku`s.
- Creates 7 `Visit`+`VisitStock` pairs for SKU A at that outlet (staggered `checkinTs`, 1 day apart) and 1 pair for SKU B.
- Creates 1 `Visit`+`VisitStock` pair for SKU A at a **different** outlet (same client) with an extreme `unitsAvailable` (e.g. `999`) to prove outlet-scoping.
- Calls `fetchStockHistoryForOutlet(outletId, clientId)`, asserts: the returned map has exactly 2 keys; SKU A's array has length 5 (capped from 7); the array is ordered newest-first (assert `visitCheckinTs` descending); the newest row's `unitsAvailable` matches the 7th (most recent) seeded row; the foreign-outlet row's `999` value never appears anywhere in SKU A's array.

Run: `cd backend && npx jest stock-derived.service.fetch.test.ts` — expect PASS. Also rerun `npx jest skus.routes.test.ts stock.routes.test.ts` (both already exercise this function indirectly) to confirm no behavior change. Commit: `perf(backend): bound stock-history fetch with a windowed query, add ORDER BY tiebreaker (#120)`.

## Task 2: Backend — #121: reject duplicate `skuId` within one `POST /stock` request

`backend/src/modules/stock/stock.routes.ts`'s handler currently validates per-item shape but never checks for a `skuId` repeated across `items[]`. After the existing `isValidItem` guard (which type-narrows `items` to `StockItemInput[]`), add a duplicate check:

```ts
stockRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, items } = req.body as { visitId?: string; items?: unknown[] };

  if (!visitId || !Array.isArray(items) || items.length === 0 || !items.every(isValidItem)) {
    res.status(400).json({ error: 'visitId and a non-empty items[] with all required fields are required' });
    return;
  }

  const skuIds = items.map((item) => item.skuId);
  if (new Set(skuIds).size !== skuIds.length) {
    res.status(400).json({ error: 'items[] must not contain duplicate skuId values' });
    return;
  }

  const rows = await recordStock({ visitId, clientId: req.user!.clientId, items });
  res.status(201).json(rows);
});
```

Rejecting (rather than silently deduping to the last occurrence) matches this codebase's existing convention of failing loud on malformed input rather than guessing intent.

**Testing:** `stock.routes.test.ts` — add `it('rejects duplicate skuId within items[] with 400', ...)`: POST with `items: [validItem(), { ...validItem(), unitsAvailable: 5 }]` (same `skuId`, different `unitsAvailable`), assert `400` and the error message. Also assert via a follow-up `GET /stock?visitId=` (or checking `res.body` isn't an array of created rows) that nothing was persisted — the request should fail atomically, not partially.

Run: `npx jest stock.routes.test.ts` — expect PASS (adds 1 test to the existing 15). Commit: `fix(backend): reject POST /stock requests with duplicate skuId in items[] (#121)`.

## Task 3: Backend + App — #99: `PromoCalendar` gains real discount fields, order pricing defaults to the discounted price

### Backend: schema

`backend/prisma/schema.prisma`'s `PromoCalendar` model gains three nullable fields (nullable since existing seeded rows have none, and a promo with no discount is legitimately just a merchandising-compliance entry):

```prisma
model PromoCalendar {
  id            String   @id @default(uuid())
  clientId      String   @map("client_id")
  client        Client   @relation(fields: [clientId], references: [id])
  promoName     String   @map("promo_name")
  activeFrom    DateTime @map("active_from")
  activeTo      DateTime @map("active_to")
  requiredPosm  Json     @map("required_posm")
  outletScope   Json     @map("outlet_scope")
  discountType  String?  @map("discount_type") // 'percent' | 'fixed'
  discountValue Float?   @map("discount_value")
  skuScope      Json?    @map("sku_scope") // { skuIds: string[] } | null (null = every SKU)

  @@map("promo_calendar")
}
```

Run `cd backend && npx prisma migrate dev --name promo_calendar_discount_fields`. Expect three additive `ALTER TABLE ... ADD COLUMN` statements, no data loss.

### Backend: `skus.service.ts` computes `effectivePrice`

`backend/src/modules/skus/skus.service.ts`'s `listSkusForClient(clientId, outletId)` already fetches the SKU catalog and per-outlet stock history in parallel (added in #112). Add a third parallel fetch — the outlet's `code` (needed to match `PromoCalendar.outletScope`) and the client's currently-active promos — then compute each SKU's `effectivePrice`:

```ts
import { prisma } from '../../lib/prisma';
import { computeDaysOutOfStock, computeVelocityAvg, fetchStockHistoryForOutlet } from '../../services/stock-derived.service';

interface PromoDiscount {
  discountType: string;
  discountValue: number;
  outletScope: unknown;
  skuScope: unknown;
}

function matchesScope(scope: unknown, key: 'outletCodes' | 'skuIds', value: string): boolean {
  if (scope === null || typeof scope !== 'object') return true; // no scope recorded -> matches everything
  const list = (scope as Record<string, unknown>)[key];
  if (!Array.isArray(list)) return true; // malformed/missing scope key -> matches everything, same permissive default
  return list.includes(value);
}

function computeEffectivePrice(rrp: number, promo: PromoDiscount | undefined): number {
  if (!promo) return rrp;
  if (promo.discountType === 'percent') {
    return Math.max(0, Math.round(rrp * (1 - promo.discountValue / 100) * 100) / 100);
  }
  if (promo.discountType === 'fixed') {
    return Math.max(0, Math.round((rrp - promo.discountValue) * 100) / 100);
  }
  return rrp; // unrecognized discountType -> no discount rather than guessing
}

export async function listSkusForClient(clientId: string, outletId: string) {
  const [skus, historyBySku, outlet, activePromos] = await Promise.all([
    prisma.sku.findMany({ where: { clientId }, orderBy: { name: 'asc' } }),
    fetchStockHistoryForOutlet(outletId, clientId),
    prisma.outlet.findUnique({ where: { id: outletId }, select: { code: true } }),
    prisma.promoCalendar.findMany({
      where: {
        clientId,
        activeFrom: { lte: new Date() },
        activeTo: { gte: new Date() },
        discountType: { not: null },
        discountValue: { not: null },
      },
      select: { discountType: true, discountValue: true, outletScope: true, skuScope: true },
    }),
  ]);

  const outletCode = outlet?.code;
  const asOf = new Date();

  return skus.map((sku) => {
    const history = historyBySku.get(sku.id) ?? [];
    const promo = outletCode
      ? (activePromos.find(
          (p) =>
            matchesScope(p.outletScope, 'outletCodes', outletCode) &&
            matchesScope(p.skuScope, 'skuIds', sku.id),
        ) as PromoDiscount | undefined)
      : undefined;
    return {
      ...sku,
      daysOutOfStock: computeDaysOutOfStock(history, asOf),
      velocityAvg: computeVelocityAvg(history),
      effectivePrice: computeEffectivePrice(sku.rrp, promo),
    };
  });
}
```

Note: `activePromos.find(...)` picks the *first* matching promo if more than one applies to the same outlet+SKU — a known, simple tie-break (last-write-wins would be equally arbitrary; documented behavior, not silently undefined). `discountType`/`discountValue` are guaranteed non-null by the query's `where` clause but Prisma's generated type still shows them as nullable, hence the `as PromoDiscount` cast — narrower than adding a runtime check for a condition the query already guarantees.

### App: `Sku` model gains `effectivePrice`; order form uses it

`app/lib/features/audit/data/skus_repository.dart`'s `Sku` gains `required this.effectivePrice` (a `double`, parsed the same way as `rrp`):

```dart
class Sku {
  const Sku({
    required this.id,
    required this.name,
    required this.category,
    required this.minFacingsStandard,
    required this.rrp,
    required this.daysOutOfStock,
    required this.velocityAvg,
    required this.effectivePrice,
  });
  // ... existing fields ...
  final double effectivePrice;

  factory Sku.fromJson(Map<String, dynamic> json) => Sku(
        // ... existing fields ...
        effectivePrice: (json['effectivePrice'] as num).toDouble(),
      );
}
```

`app/lib/features/orders/presentation/order_form_screen.dart`: both places that currently read `sku.rrp` for pricing switch to `sku.effectivePrice` — the running total (`_total`, line ~36: `total += (_qty[sku.id] ?? 0) * sku.rrp;` → `* sku.effectivePrice`) and the submitted line (`_submit`, line ~49: `OrderLine(skuId: sku.id, quantity: _qty[sku.id]!, unitPrice: sku.rrp)` → `unitPrice: sku.effectivePrice`). `sku.rrp` itself stays displayed elsewhere (e.g. the S2 stock screen's "RRP X.XX" label) unchanged — only order pricing switches to the discounted figure. There is currently no price-override UI on the order form (confirmed: `unitPrice` has always been exactly `sku.rrp`, non-editable) — this task does not add one; that remains unchanged, out of scope.

Every OTHER `Sku(...)` construction across the app/test tree (fakes in `visit_progress_test.dart`, `visit_review_test.dart`, `s2_stock_screen_test.dart`, `s5_pricing_promotions_screen_test.dart`, `skus_repository_test.dart`, `audit_shell_screen_test.dart`, `order_form_screen_test.dart`) needs `effectivePrice: <same value as rrp>` added (no promo in those fixtures, so effective price equals rrp) — grep for `Sku(` across `app/lib` and `app/test` first to get the complete list; don't rely on this list being exhaustive.

**Testing:**
- `skus.routes.test.ts`: add tests seeding a `PromoCalendar` row with `discountType: 'percent', discountValue: 20, outletScope: {outletCodes: [<seeded outlet's code>]}, skuScope: null` (matches all SKUs) — assert `GET /skus?outletId=` returns `effectivePrice` 20% below `rrp` for every SKU. Add a second test with a promo scoped to a *different* outlet code — assert `effectivePrice` equals `rrp` unchanged (no match). Add a third test with an expired promo (`activeTo` in the past) — assert no discount applied.
- `order_form_screen_test.dart`: update the fake `Sku` fixtures to have `effectivePrice` different from `rrp` (e.g. `rrp: 10.00, effectivePrice: 8.00`), assert the running total and the submitted `OrderLine.unitPrice` both reflect `effectivePrice`, not `rrp`.

Run: `cd backend && npx jest skus.routes.test.ts` and `cd app && flutter test test/features/orders/order_form_screen_test.dart` — expect PASS both. Then `cd backend && npx tsc --noEmit && npm run lint` and `cd app && flutter analyze` — clean. Commit (likely 2 commits, backend then app, or 1 if convenient): `feat(backend): PromoCalendar gains discount fields, GET /skus serves effectivePrice (#99)` and `feat(app): order form prices lines at the promo-discounted rate (#99)`.

## Task 4: Backend — #96: territory coverage rate

`backend/src/modules/territories/territories.service.ts`'s `getTerritoryCoverage` gains optional `from`/`to` window params and computes a real coverage percentage instead of returning bare lists:

```ts
export async function getTerritoryCoverage(
  territoryId: string,
  clientId: string,
  from?: Date,
  to?: Date,
): Promise<{
  territory: Territory;
  outlets: Outlet[];
  agents: User[];
  coverage: { outletsVisited: number; outletsTotal: number; coverageRate: number };
}> {
  const territory = await findTerritoryForClient(territoryId, clientId);

  const outlets = await prisma.outlet.findMany({
    where: { territoryId: territory.code, clientId },
  });

  const assignments = await prisma.userTerritory.findMany({
    where: { territoryId: territory.id },
    include: { user: true },
  });
  const agents = assignments.map((assignment) => assignment.user);

  const outletIds = outlets.map((outlet) => outlet.id);
  const visitWhere: Prisma.VisitWhereInput = { clientId, outletId: { in: outletIds } };
  if (from || to) {
    visitWhere.checkinTs = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
  }
  const visitedOutlets = outletIds.length
    ? await prisma.visit.findMany({ where: visitWhere, select: { outletId: true }, distinct: ['outletId'] })
    : [];

  const outletsTotal = outlets.length;
  const outletsVisited = visitedOutlets.length;
  const coverageRate = outletsTotal > 0 ? Math.round((100 * outletsVisited / outletsTotal) * 100) / 100 : 0;

  return { territory, outlets, agents, coverage: { outletsVisited, outletsTotal, coverageRate } };
}
```

(`distinct: ['outletId']` on the `Visit` query is what turns "how many visits happened" into "how many distinct outlets were visited" — an outlet visited 5 times in the window still counts once.)

`backend/src/modules/territories/territories.routes.ts`'s `/:id/coverage` handler parses optional `from`/`to` query params the same way `trends.routes.ts`'s `parseQuery` does (ISO date strings, 400 on invalid):

```ts
territoriesRouter.get('/:id/coverage', async (req: AuthedRequest, res) => {
  const { id: territoryId } = req.params as { id: string };
  const { from, to } = req.query as { from?: string; to?: string };

  let fromDate: Date | undefined;
  let toDate: Date | undefined;
  if (from !== undefined) {
    fromDate = new Date(from);
    if (Number.isNaN(fromDate.getTime())) {
      res.status(400).json({ error: 'from must be a valid ISO date' });
      return;
    }
  }
  if (to !== undefined) {
    toDate = new Date(to);
    if (Number.isNaN(toDate.getTime())) {
      res.status(400).json({ error: 'to must be a valid ISO date' });
      return;
    }
  }

  const coverage = await getTerritoryCoverage(territoryId, req.user!.clientId, fromDate, toDate);
  res.status(200).json(coverage);
});
```

**Testing:** `territories.routes.test.ts` — read the existing coverage test(s) first to match fixture style. Add: seed a territory with 3 outlets, `Visit` rows checking in to 2 of them (one outlet visited twice, still counts once — proves the `distinct` works), assert `coverage: { outletsVisited: 2, outletsTotal: 3, coverageRate: 66.67 }`. Add a second test with `from`/`to` narrowing the window to exclude one of those visits, assert `coverageRate` drops accordingly. Add a 400 test for an invalid `from` value. Confirm the existing bare `outlets`/`agents` list assertions in the pre-existing test(s) still pass unmodified (the response gained a field, didn't remove any).

Run: `npx jest territories.routes.test.ts` — expect PASS. Commit: `feat(backend): GET /territories/:id/coverage returns a real coverage rate, not just lists (#96)`.

## Task 5: Backend — #95: share-of-shelf trend endpoint

### Extract shared KPI math to stop the #93-class drift risk

`round2`/`mean`/`pct` are currently duplicated verbatim between `dashboard.service.ts` and `trends.service.ts`; `facingsTotal` exists only in `dashboard.service.ts` but the new endpoint needs it too. Rather than adding a third copy (exactly the drift `dashboard.service.ts`'s own comments already flag as a past bug, #93), extract all four to a new shared file:

`backend/src/lib/kpiMath.ts`:

```ts
export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Ratio helper that returns 0 (never NaN) on an empty denominator. */
export function pct(numerator: number, denominator: number): number {
  return denominator > 0 ? round2((100 * numerator) / denominator) : 0;
}

export function mean(values: number[]): number {
  return values.length > 0 ? round2(values.reduce((sum, v) => sum + v, 0) / values.length) : 0;
}

/** Safely read the `.total` field out of a facingsCount Json column. */
export function facingsTotal(value: unknown): number {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return 0;
  }
  const total = (value as Record<string, unknown>).total;
  return typeof total === 'number' && Number.isFinite(total) ? total : 0;
}
```

`dashboard.service.ts` and `trends.service.ts` both delete their local `round2`/`mean`/`pct` (and `dashboard.service.ts` deletes its local `facingsTotal`) and import all four from `../../lib/kpiMath` instead. This is a pure refactor — run both files' existing tests before and after to confirm zero behavior change (`npx jest dashboard.routes.test.ts dashboard.by-territory.routes.test.ts trends.routes.test.ts` — same pass count before and after the extraction, no assertions change).

### New endpoint

`trends.service.ts` gains a `visitWhere` helper (the existing `scorecardWhere`/`stockWhere` don't cover `Visit` directly) and `getShareOfShelfTrend`:

```ts
function visitWhere(filters: TrendFilters): Prisma.VisitWhereInput {
  const where: Prisma.VisitWhereInput = { clientId: filters.clientId };
  if (filters.from || filters.to) {
    where.checkinTs = {
      ...(filters.from ? { gte: filters.from } : {}),
      ...(filters.to ? { lte: filters.to } : {}),
    };
  }
  return where;
}

export async function getShareOfShelfTrend(filters: TrendFilters): Promise<TrendSeries> {
  const visits = await prisma.visit.findMany({
    where: visitWhere(filters),
    select: {
      createdAt: true,
      visibility: { select: { facingsCount: true } },
      competitive: { select: { facingsCount: true } },
    },
  });
  return buildSeries(visits, filters.interval, (visit) => visit.createdAt, (bucket) => {
    const ownFacings = bucket.reduce(
      (sum, visit) => sum + (visit.visibility ? facingsTotal(visit.visibility.facingsCount) : 0),
      0,
    );
    const competitorFacings = bucket.reduce(
      (sum, visit) => sum + visit.competitive.reduce((n, row) => n + row.facingsCount, 0),
      0,
    );
    return pct(ownFacings, ownFacings + competitorFacings);
  });
}
```

This is deliberately the exact same `ownFacings`/`competitorFacings`/`pct(...)` shape as `dashboard.service.ts`'s `computeKpisFromScope`, just bucketed over time instead of computed once over a scope — using the same imported `pct`/`facingsTotal` guarantees the numbers can never drift apart the way #93 already burned this codebase once.

`trends.routes.ts`: register the route the same way the other three are:

```ts
trendRoute('/share-of-shelf', getShareOfShelfTrend);
```

**Testing:** `trends.routes.test.ts` — read the existing tests first to match fixture style (likely seeds visits with `createdAt` spread across buckets). Add tests: (a) a basic case — 2 visits in one bucket with known `VisitVisibility.facingsCount`/`VisitCompetitive.facingsCount` values, assert the bucket's `value` matches the hand-computed percentage; (b) a cross-check test — seed the same visits, call both `GET /dashboard` (or directly invoke `getDashboardSummary`) and `GET /trends/share-of-shelf`, assert the dashboard's `shareOfShelf` KPI and the trend's single-bucket value are numerically equal (proves the two can't drift, the actual point of the shared-math extraction); (c) empty state — no visibility/competitive rows in a bucket returns `0`, not `NaN`/error.

Run: `npx jest trends.routes.test.ts` — expect PASS. Also rerun `npx jest dashboard.routes.test.ts dashboard.by-territory.routes.test.ts` to confirm the `kpiMath.ts` extraction didn't change dashboard behavior. Commit: `feat(backend): GET /trends/share-of-shelf, extract shared KPI math to stop #93-class drift (#95)`.

## Task 6: Verify

- Backend: `cd backend && npm run lint && npm run build && npx jest --runInBand` — full suite green.
- App: `cd app && flutter analyze && flutter test` — full suite green.
- Manual sanity check (per this repo's UI-change convention, for Task 3's app-visible change): run the app, open the order form for an outlet with an active seeded promo, confirm the displayed/submitted price reflects the discount.
