# S2 — Server-Derived Stock Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close #112 — `daysOutOfStock` and `velocityAvg` become server-computed from `VisitStock` history instead of agent-typed; `salesActual`/`salesTarget` are removed from the S2 form entirely since no data source for either exists anywhere in the system.

**Architecture:** A new shared derivation module (`backend/src/services/stock-derived.service.ts`) computes both values from a single per-outlet history query, reused by both the read side (`GET /skus?outletId=`, for context before the agent opens the form) and the write side (`POST /stock`, which now computes-and-stamps instead of accepting client input). `VisitStock.salesActual`/`salesTarget` become nullable via migration. The Flutter S2 form drops all four TextFields; only `unitsAvailable` (the existing `CountStepper`) and `lastStockinDate` remain agent input, with the two computed values shown as read-only context text.

**Tech Stack:** Node/Express/TypeScript/Prisma/PostgreSQL (backend), Flutter/Riverpod/Drift (app), Jest+Supertest / flutter_test (tests).

**Reference:** design spec at `docs/superpowers/specs/2026-07-16-s2-server-derived-stock-context-design.md`.

**Note on divergence from the design spec:** the spec assumed `POST /stock`/`RecordStockInput` took one SKU at a time. The actual current code (`backend/src/modules/stock/stock.service.ts`) is a **batch** endpoint — `POST /stock` takes `{ visitId, items: StockItemInput[] }`, one row per SKU per call. This plan targets the real batch shape; the architecture decisions from the spec (shared derivation logic, nullable sales fields, no client-writable path for the two computed fields) are unaffected.

---

## Task 1: Backend — `stock-derived.service.ts` (pure derivation functions, TDD)

New file `backend/src/services/stock-derived.service.ts`, alongside the existing `services/forecast.service.ts`.

```ts
export interface StockHistoryRow {
  visitCheckinTs: Date;
  unitsAvailable: number;
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export function computeDaysOutOfStock(history: StockHistoryRow[], asOfCheckinTs: Date): number {
  const lastInStock = history.find((row) => row.unitsAvailable > 0);
  if (!lastInStock) return 0;
  const days = (asOfCheckinTs.getTime() - lastInStock.visitCheckinTs.getTime()) / MS_PER_DAY;
  return days > 0 ? Math.round(days) : 0;
}

export function computeVelocityAvg(history: StockHistoryRow[]): number {
  const rates: number[] = [];
  for (let i = 0; i < history.length - 1; i += 1) {
    const newer = history[i];
    const older = history[i + 1];
    const daysBetween = (newer.visitCheckinTs.getTime() - older.visitCheckinTs.getTime()) / MS_PER_DAY;
    if (daysBetween <= 0) continue; // e.g. a same-visit re-submission — don't divide by zero
    const consumed = Math.max(0, older.unitsAvailable - newer.unitsAvailable);
    rates.push(consumed / daysBetween);
  }
  if (rates.length === 0) return 0;
  return Math.round((rates.reduce((sum, r) => sum + r, 0) / rates.length) * 100) / 100;
}
```

`history` is newest-first in both functions (matches the query added in Task 2).

`daysOutOfStock`: days since the most recent prior row with `unitsAvailable > 0`; no such row → `0` (no history yet, not "out of stock forever"). Visit-cadence approximation per the design spec — exact for daily beats, coarser for weekly ones.

`velocityAvg`: average consumption (`older.unitsAvailable - newer.unitsAvailable`, floored at 0) across adjacent visit-pairs. A restock (`newer > older`) contributes `0` to that interval, not a negative number. Fewer than 2 rows → `0`.

**TDD sequence:** write `stock-derived.service.test.ts` first with these cases, confirm each fails (module doesn't exist yet), then implement:

```ts
import { computeDaysOutOfStock, computeVelocityAvg, StockHistoryRow } from './stock-derived.service';

const now = new Date('2026-07-16T00:00:00.000Z');
const daysAgo = (n: number, unitsAvailable: number): StockHistoryRow => ({
  visitCheckinTs: new Date(now.getTime() - n * 24 * 60 * 60 * 1000),
  unitsAvailable,
});

describe('computeDaysOutOfStock', () => {
  it('returns 0 with no history', () => {
    expect(computeDaysOutOfStock([], now)).toBe(0);
  });
  it('returns 0 when no prior row ever had stock', () => {
    expect(computeDaysOutOfStock([daysAgo(3, 0), daysAgo(10, 0)], now)).toBe(0);
  });
  it('computes days since the most recent in-stock row', () => {
    expect(computeDaysOutOfStock([daysAgo(3, 0), daysAgo(10, 5)], now)).toBe(10);
  });
  it('approximates at visit-cadence granularity for weekly beats', () => {
    expect(computeDaysOutOfStock([daysAgo(7, 0)], now)).toBe(7);
  });
});

describe('computeVelocityAvg', () => {
  it('returns 0 with fewer than 2 rows', () => {
    expect(computeVelocityAvg([])).toBe(0);
    expect(computeVelocityAvg([daysAgo(0, 20)])).toBe(0);
  });
  it('averages consumption across consecutive visits', () => {
    expect(computeVelocityAvg([daysAgo(5, 80), daysAgo(10, 100)])).toBe(4); // 20 units / 5 days
  });
  it('treats a restock as zero consumption for that interval, not negative', () => {
    // interval A (2d-5d): 10 -> 90 is a restock -> 0/3 days = 0
    // interval B (5d-10d): 100 -> 10 -> 90 consumed / 5 days = 18
    // average of [0, 18] = 9
    expect(computeVelocityAvg([daysAgo(2, 90), daysAgo(5, 10), daysAgo(10, 100)])).toBe(9);
  });
  it('skips a zero-elapsed-time interval instead of dividing by zero', () => {
    const sameTs = daysAgo(5, 100).visitCheckinTs;
    const history = [
      { visitCheckinTs: sameTs, unitsAvailable: 80 },
      { visitCheckinTs: sameTs, unitsAvailable: 100 },
      daysAgo(10, 100),
    ];
    expect(computeVelocityAvg(history)).toBe(0);
  });
});
```

Run: `cd backend && npx jest stock-derived.service.test.ts` — expect FAIL (no module), implement, rerun — expect all 8 cases PASS. Commit: `feat(backend): server-side daysOutOfStock/velocityAvg derivation (#112)`.

## Task 2: Backend — `fetchStockHistoryForOutlet` (shared query)

Add to `stock-derived.service.ts`:

```ts
import { prisma } from '../lib/prisma';

const HISTORY_WINDOW = 5;

/**
 * One query for every SKU's stock history at this outlet, capped at the
 * last 5 VisitStock rows per SKU (newest-first). A single round trip
 * regardless of SKU-catalog size — fetch once, group in memory — matching
 * the pattern dashboard.service.ts's getDashboardByTerritory already
 * established, rather than one query per SKU (the #97 N+1 lesson).
 */
export async function fetchStockHistoryForOutlet(
  outletId: string,
  clientId: string,
): Promise<Map<string, StockHistoryRow[]>> {
  const rows = await prisma.visitStock.findMany({
    where: { visit: { outletId, clientId } },
    orderBy: { visit: { checkinTs: 'desc' } },
    select: { skuId: true, unitsAvailable: true, visit: { select: { checkinTs: true } } },
  });

  const bySku = new Map<string, StockHistoryRow[]>();
  for (const row of rows) {
    const list = bySku.get(row.skuId) ?? [];
    if (list.length < HISTORY_WINDOW) {
      list.push({ visitCheckinTs: row.visit.checkinTs, unitsAvailable: row.unitsAvailable });
      bySku.set(row.skuId, list);
    }
  }
  return bySku;
}
```

No dedicated test for this function alone (it's a thin Prisma query, exercised end-to-end by Task 4/5's route tests) — consistent with this codebase's existing precedent of not unit-testing thin one-query data-access functions in isolation (e.g. `listSkusForClient`/`listStockForVisit` have no dedicated unit tests either, only route-level tests).

Commit: `feat(backend): shared per-outlet stock-history query (#112)`.

## Task 3: Backend — migration: nullable `salesActual`/`salesTarget`

`backend/prisma/schema.prisma` — `VisitStock` model:

```prisma
  salesActual           Float?   @map("sales_actual")
  salesTarget           Float?   @map("sales_target")
```

Run: `cd backend && npx prisma migrate dev --name s2_optional_sales_fields`. Expect the generated SQL to be two `ALTER TABLE "visit_stock" ALTER COLUMN ... DROP NOT NULL` statements. Verify `npx prisma generate` completes (updates the Prisma Client types so `salesActual`/`salesTarget` become `number | null`).

Commit: `feat(backend): make VisitStock.salesActual/salesTarget nullable (#112)` (includes the new migration folder).

## Task 4: Backend — `GET /skus?outletId=` serves computed context

`skus.service.ts`:

```ts
import { prisma } from '../../lib/prisma';
import { computeDaysOutOfStock, computeVelocityAvg, fetchStockHistoryForOutlet } from '../../services/stock-derived.service';

export async function listSkusForClient(clientId: string, outletId: string) {
  const [skus, historyBySku] = await Promise.all([
    prisma.sku.findMany({ where: { clientId }, orderBy: { name: 'asc' } }),
    fetchStockHistoryForOutlet(outletId, clientId),
  ]);
  const asOf = new Date();
  return skus.map((sku) => {
    const history = historyBySku.get(sku.id) ?? [];
    return {
      ...sku,
      daysOutOfStock: computeDaysOutOfStock(history, asOf),
      velocityAvg: computeVelocityAvg(history),
    };
  });
}
```

`skus.routes.ts`:

```ts
skusRouter.get('/', async (req: AuthedRequest, res) => {
  const { outletId } = req.query;
  if (typeof outletId !== 'string' || outletId.length === 0) {
    res.status(400).json({ error: 'outletId query param is required' });
    return;
  }
  const skus = await listSkusForClient(req.user!.clientId, outletId);
  res.status(200).json(skus);
});
```

`skus.routes.test.ts` updates: every existing `request(app).get('/skus')` call gains `.query({ outletId: someOutlet.id })` — since the outlet doesn't need to belong to the caller's client for the SKU list itself to return (history merely comes back empty for a foreign/bogus outlet — the SKU catalog is client-wide, not outlet-gated), fixtures can reuse a single seeded `Outlet` row for the client under test. Add:
- `it('rejects a request without outletId with 400', ...)`.
- `it('computes daysOutOfStock/velocityAvg from VisitStock history for the outlet', ...)`: seed an `Outlet`, two `Visit` rows for it (`checkinTs` 10 and 5 days apart) each with a `VisitStock` row for the same `Sku` (`unitsAvailable: 100` then `80`), call `GET /skus?outletId=`, assert the SKU's `velocityAvg` is `4` and `daysOutOfStock` is `0` (both visits had stock).

Run: `npx jest skus.routes.test.ts` — expect PASS. Commit: `feat(backend): GET /skus?outletId= serves computed stock context (#112)`.

## Task 5: Backend — `POST /stock` computes-and-stamps `daysOutOfStock`/`velocityAvg`

`stock.service.ts`:

```ts
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';
import { computeDaysOutOfStock, computeVelocityAvg, fetchStockHistoryForOutlet } from '../../services/stock-derived.service';
import { computeSlaDueAt } from '../../lib/slaClock';
import { kpiThreshold } from '../../lib/kpiThresholds';

const DEFAULT_STOCKOUT_UNITS_THRESHOLD = 0;
const STOCKOUT_FINDING_TYPE = 'stockout';

export interface StockItemInput {
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: string; // ISO
  salesActual?: number;
  salesTarget?: number;
}

export interface RecordStockInput {
  visitId: string;
  clientId: string;
  items: StockItemInput[];
}

function coverageFor(unitsAvailable: number, velocityAvg: number): number {
  const coverage = predictCoverageDays({ unitsAvailable, velocityAvg });
  return Number.isFinite(coverage) ? coverage : 0;
}

export async function listStockForVisit(visitId: string, clientId: string) {
  const visit = await prisma.visit.findFirst({ where: { id: visitId, clientId } });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  return prisma.visitStock.findMany({ where: { visitId }, orderBy: { createdAt: 'desc' } });
}

export async function recordStock(input: RecordStockInput) {
  const visit = await prisma.visit.findFirst({
    where: { id: input.visitId, clientId: input.clientId },
  });
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }

  const skuIds = input.items.map((i) => i.skuId);
  const skus = await prisma.sku.findMany({
    where: { id: { in: skuIds }, clientId: input.clientId },
    select: { id: true },
  });
  const validSkuIds = new Set(skus.map((s) => s.id));
  const unknown = skuIds.find((id) => !validSkuIds.has(id));
  if (unknown) {
    throw new NotFoundError(`SKU not found: ${unknown}`);
  }

  const historyBySku = await fetchStockHistoryForOutlet(visit.outletId, input.clientId);

  const rows = await prisma.$transaction(
    input.items.map((item) => {
      const history = historyBySku.get(item.skuId) ?? [];
      const daysOutOfStock = computeDaysOutOfStock(history, visit.checkinTs);
      const velocityAvg = computeVelocityAvg(history);
      return prisma.visitStock.create({
        data: {
          visitId: input.visitId,
          skuId: item.skuId,
          unitsAvailable: item.unitsAvailable,
          lastStockinDate: new Date(item.lastStockinDate),
          daysOutOfStock,
          velocityAvg,
          coverageDaysPredicted: coverageFor(item.unitsAvailable, velocityAvg),
          salesActual: item.salesActual ?? null,
          salesTarget: item.salesTarget ?? null,
        },
      });
    }),
  );

  await createStockoutTasks(input.visitId, input.clientId, visit.outletId, visit.agentId, input.items);

  return rows;
}

async function createStockoutTasks(
  visitId: string,
  clientId: string,
  outletId: string,
  agentId: string,
  items: StockItemInput[],
): Promise<void> {
  try {
    const client = await prisma.client.findUnique({ where: { id: clientId }, select: { kpiThresholds: true } });
    const unitsThreshold = kpiThreshold(client?.kpiThresholds, 'stockoutUnits', DEFAULT_STOCKOUT_UNITS_THRESHOLD);

    const stockouts = items.filter((item) => item.unitsAvailable <= unitsThreshold);
    if (stockouts.length === 0) return;

    const existing = await prisma.task.findMany({
      where: { visitId, findingType: STOCKOUT_FINDING_TYPE },
      select: { requiredFix: true },
    });
    const existingFixes = new Set(existing.map((t) => t.requiredFix));

    const now = new Date();
    for (const item of stockouts) {
      const requiredFix = `Restock SKU ${item.skuId}`;
      if (existingFixes.has(requiredFix)) continue;
      await prisma.task.create({
        data: {
          visitId,
          findingType: STOCKOUT_FINDING_TYPE,
          outletId,
          requiredFix,
          priority: 'high',
          slaDueAt: computeSlaDueAt('high', now),
          ownerId: agentId,
        },
      });
      existingFixes.add(requiredFix);
    }
  } catch {
    // Swallow: stock capture already succeeded; task backfill is low-risk (#47).
  }
}
```

Note: `createStockoutTasks(items)` still works unmodified — it only reads `item.unitsAvailable`, never the removed fields.

`stock.routes.ts`:

```ts
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { listStockForVisit, recordStock, StockItemInput } from './stock.service';

export const stockRouter = Router();
stockRouter.use(requireAuth);

function isValidItem(item: unknown): item is StockItemInput {
  if (typeof item !== 'object' || item === null) return false;
  const i = item as Record<string, unknown>;
  if (typeof i.skuId !== 'string' || typeof i.lastStockinDate !== 'string') return false;
  if (typeof i.unitsAvailable !== 'number') return false;
  if (i.salesActual !== undefined && typeof i.salesActual !== 'number') return false;
  if (i.salesTarget !== undefined && typeof i.salesTarget !== 'number') return false;
  return true;
}

stockRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, items } = req.body as { visitId?: string; items?: unknown[] };

  if (!visitId || !Array.isArray(items) || items.length === 0 || !items.every(isValidItem)) {
    res.status(400).json({ error: 'visitId and a non-empty items[] with all required fields are required' });
    return;
  }

  const rows = await recordStock({ visitId, clientId: req.user!.clientId, items });
  res.status(201).json(rows);
});

stockRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId } = req.query;
  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId query param is required' });
    return;
  }
  const rows = await listStockForVisit(visitId, req.user!.clientId);
  res.status(200).json(rows);
});
```

`stock.routes.test.ts` updates:
- `validItem()` fixture drops `daysOutOfStock`/`velocityAvg`:
  ```ts
  const validItem = () => ({
    skuId,
    unitsAvailable: 20,
    lastStockinDate: '2026-07-01T00:00:00.000Z',
  });
  ```
- The existing "records stock rows and computes coverage days (201)" test currently asserts `coverageDaysPredicted ≈ 5` from a client-sent `velocityAvg: 4`. Since velocity is now server-computed and this is the first-ever entry for that SKU+outlet (no history), rewrite its expectation:
  ```ts
  it('records stock rows with zero coverage when there is no prior history (201)', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId, items: [validItem()] });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].daysOutOfStock).toBe(0);
    expect(res.body[0].velocityAvg).toBe(0);
    expect(res.body[0].coverageDaysPredicted).toBe(0);
    expect(res.body[0].salesActual).toBeNull();
    expect(res.body[0].salesTarget).toBeNull();
  });
  ```
- Add a new test proving the end-to-end computation from real history, using two earlier `Visit` rows (not the shared `visitId`, which is reused by other tests in this file):
  ```ts
  it('computes daysOutOfStock/velocityAvg from prior visits to the same outlet (#112)', async () => {
    const historySku = await prisma.sku.create({
      data: { clientId, name: 'History Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 9.99 },
    });
    const outlet = await prisma.outlet.findFirstOrThrow({ where: { clientId } });

    const visitA = await prisma.visit.create({
      data: {
        outletId: outlet.id, agentId: (await prisma.user.findFirstOrThrow({ where: { clientId } })).id,
        clientId, checkinTs: new Date('2026-06-21T00:00:00.000Z'),
        checkinLat: -26.2041, checkinLng: 28.0473, geofencePass: true, status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: visitA.id, skuId: historySku.id, unitsAvailable: 100,
        lastStockinDate: new Date('2026-06-21T00:00:00.000Z'),
        daysOutOfStock: 0, velocityAvg: 0, coverageDaysPredicted: 0,
      },
    });

    const visitB = await prisma.visit.create({
      data: {
        outletId: outlet.id, agentId: visitA.agentId, clientId,
        checkinTs: new Date('2026-06-26T00:00:00.000Z'), // 5 days after visitA
        checkinLat: -26.2041, checkinLng: 28.0473, geofencePass: true, status: 'in_progress',
      },
    });

    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({
        visitId: visitB.id,
        items: [{ skuId: historySku.id, unitsAvailable: 80, lastStockinDate: '2026-06-26T00:00:00.000Z' }],
      });

    expect(res.status).toBe(201);
    // 100 -> 80 over 5 days = 4/day; still in stock, so daysOutOfStock stays 0.
    expect(res.body[0].velocityAvg).toBe(4);
    expect(res.body[0].daysOutOfStock).toBe(0);
    expect(res.body[0].coverageDaysPredicted).toBeCloseTo(20); // 80 / 4
  });
  ```
- Every other `validItem()`-based test in the file (`auto-creates a stockout Task...`, `respects a client-configured kpiThresholds...`, `returns 404...`, `rejects a missing/empty items array...`, `forbids a manager...`, `rejects requests without a bearer token...`) needs no changes beyond the shrunk `validItem()` fixture already covering them, since none of those tests assert on `daysOutOfStock`/`velocityAvg`/`salesActual`/`salesTarget` values.
- The `'lists a visit stock rows...'` test's direct `prisma.visitStock.create` fixture (line ~193 in the current file) is unaffected — it bypasses `recordStock` entirely and still supplies all fields explicitly, which remains valid since the migration only relaxed the NOT NULL constraint, it didn't remove the columns.

Run: `npx jest stock.routes.test.ts` — expect PASS. Commit: `feat(backend): POST /stock computes daysOutOfStock/velocityAvg server-side (#112)`.

## Task 6: App — `Sku` model gains computed fields; `listSkus` requires `outletId`

`skus_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Sku {
  const Sku({
    required this.id,
    required this.name,
    required this.category,
    required this.minFacingsStandard,
    required this.rrp,
    required this.daysOutOfStock,
    required this.velocityAvg,
  });
  final String id;
  final String name;
  final String category;
  final int minFacingsStandard;
  final double rrp;
  final int daysOutOfStock;
  final double velocityAvg;

  factory Sku.fromJson(Map<String, dynamic> json) => Sku(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        minFacingsStandard: (json['minFacingsStandard'] as num).toInt(),
        rrp: (json['rrp'] as num).toDouble(),
        daysOutOfStock: (json['daysOutOfStock'] as num).toInt(),
        velocityAvg: (json['velocityAvg'] as num).toDouble(),
      );
}

abstract class SkusRepository {
  Future<List<Sku>> listSkus({required String outletId});
}

class DioSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async {
    final response = await dio.get('/skus', queryParameters: {'outletId': outletId});
    return (response.data as List)
        .map((json) => Sku.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final skusRepositoryProvider = Provider<SkusRepository>((ref) => DioSkusRepository());

final skusListProvider = FutureProvider.family<List<Sku>, String>(
  (ref, outletId) => ref.read(skusRepositoryProvider).listSkus(outletId: outletId),
);
```

(`.family<List<Sku>, String>` keyed by `outletId` mirrors the existing `dispatchResultProvider`/`territoryCoverageProvider` pattern in this codebase.)

`skus_repository_test.dart` updates:
```dart
class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99,
            daysOutOfStock: 2, velocityAvg: 3.5),
      ];
}

void main() {
  test('skusListProvider resolves the repository result for the given outlet', () async {
    final container = ProviderContainer(
      overrides: [skusRepositoryProvider.overrideWithValue(_FakeSkusRepository())],
    );
    addTearDown(container.dispose);

    final skus = await container.read(skusListProvider('outlet-1').future);

    expect(skus, hasLength(1));
    expect(skus.first.name, 'Test Cola');
    expect(skus.first.daysOutOfStock, 2);
    expect(skus.first.velocityAvg, 3.5);
  });

  test('Sku.fromJson parses numeric fields', () {
    final sku = Sku.fromJson({
      'id': 's2', 'name': 'Water 1L', 'category': 'Beverages',
      'minFacingsStandard': 3, 'rrp': 12.5, 'daysOutOfStock': 1, 'velocityAvg': 6.0,
    });
    expect(sku.minFacingsStandard, 3);
    expect(sku.rrp, 12.5);
    expect(sku.daysOutOfStock, 1);
    expect(sku.velocityAvg, 6.0);
  });
}
```

Run: `cd app && flutter test test/features/audit/skus_repository_test.dart` — expect PASS. Commit: `feat(app): Sku model carries server-computed stock context (#112)`.

## Task 7: App — `StockEntry`/`StockDrafts` drop the four removed fields

`stock_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One captured stock line for a SKU during a visit. daysOutOfStock,
/// velocityAvg, salesActual, and salesTarget are no longer agent input —
/// the server computes the first two and there is no source for the other
/// two yet (#112).
class StockEntry {
  const StockEntry({
    required this.skuId,
    required this.unitsAvailable,
    required this.lastStockinDate,
  });
  final String skuId;
  final int unitsAvailable;
  final DateTime lastStockinDate;

  Map<String, dynamic> toJson() => {
        'skuId': skuId,
        'unitsAvailable': unitsAvailable,
        'lastStockinDate': lastStockinDate.toUtc().toIso8601String(),
      };
}

abstract class StockRepository {
  Future<void> saveStock({required String visitDraftId, required List<StockEntry> entries});
}

class DriftStockRepository implements StockRepository {
  DriftStockRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveStock({required String visitDraftId, required List<StockEntry> entries}) async {
    final batchId = _uuid.v4();
    await db.transaction(() async {
      for (final entry in entries) {
        await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
              id: _uuid.v4(),
              visitDraftId: visitDraftId,
              skuId: entry.skuId,
              unitsAvailable: entry.unitsAvailable,
              lastStockinDate: entry.lastStockinDate,
            ));
      }
      await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
            entityType: 'stock',
            entityId: batchId,
            payloadJson: jsonEncode({
              'visitDraftId': visitDraftId,
              'items': entries.map((e) => e.toJson()).toList(),
            }),
          ));
    });

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: rows are persisted and queued for the next flush.
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) => DriftStockRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));
```

`tables.dart` — `StockDrafts` drops the four columns:

```dart
class StockDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get visitDraftId => text()();
  TextColumn get skuId => text()();
  IntColumn get unitsAvailable => integer()();
  DateTimeColumn get lastStockinDate => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Bump the Drift schema version in `local_db.dart` (find the current `schemaVersion` getter and increment it by 1 — no migration strategy needed, matching the original S2 table addition's precedent of a bare version bump with no shipped installs to migrate). Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `local_db.g.dart`.

`stock_repository_test.dart` update:

```dart
StockEntry _entry() => const StockEntry(
      skuId: 'sku-1',
      unitsAvailable: 20,
      lastStockinDate: DateTime.utc(2026, 7, 1),
    );

void main() {
  late LocalDb db;

  setUp(() => db = LocalDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('saveStock writes stock drafts and enqueues one stock sync item', () async {
    final repository = DriftStockRepository(
      db: db,
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    await repository.saveStock(visitDraftId: 'visit-1', entries: [_entry(), _entry()]);

    final drafts = await db.select(db.stockDrafts).get();
    expect(drafts, hasLength(2));
    expect(drafts.first.visitDraftId, 'visit-1');

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued, hasLength(1));
    expect(queued.first.entityType, 'stock');

    final payload = jsonDecode(queued.first.payloadJson) as Map<String, dynamic>;
    expect(payload['visitDraftId'], 'visit-1');
    expect((payload['items'] as List), hasLength(2));
    expect((payload['items'] as List).first['skuId'], 'sku-1');
    expect((payload['items'] as List).first.containsKey('velocityAvg'), isFalse);
  });
}
```

(`_entry` is `const` now since `StockEntry` has no default-valued fields left requiring runtime construction — if the const constructor doesn't apply cleanly, drop `const` from the call site only, not from the class.)

No `sync_service_test.dart` changes needed — the `HttpQueueFlusher`'s `'stock'` case (`sync_service.dart:49-53`) forwards `payload['items']` verbatim without touching field shape, so it's agnostic to which fields are present.

Run: `flutter test test/features/audit/stock_repository_test.dart` — expect PASS. Commit: `feat(app): StockEntry/StockDrafts drop server-owned and unsourced fields (#112)`.

## Task 8: App — S2 form UI: remove four inputs, show read-only context, thread `outletId`

`audit_shell_screen.dart` — `_sectionBody`, change:
```dart
AuditSection.stock => S2StockScreen(visitDraftId: visitDraftId),
```
to:
```dart
AuditSection.stock => S2StockScreen(visitDraftId: visitDraftId, outletId: widget.outletId),
```
(mirrors the existing `S5PricingPromotionsScreen(visitDraftId: visitDraftId, outletId: widget.outletId)` call directly above it.)

`s2_stock_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../data/skus_repository.dart';
import '../../data/stock_repository.dart';

/// S2 — Stock & Availability capture. One row per client SKU; on save the
/// entries are persisted locally and queued for sync (POST /stock).
class S2StockScreen extends ConsumerWidget {
  const S2StockScreen({super.key, required this.visitDraftId, required this.outletId});

  final String visitDraftId;
  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skus = ref.watch(skusListProvider(outletId));
    return skus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load SKUs: $err')),
      data: (list) => _StockForm(visitDraftId: visitDraftId, skus: list),
    );
  }
}

class _StockForm extends ConsumerStatefulWidget {
  const _StockForm({required this.visitDraftId, required this.skus});

  final String visitDraftId;
  final List<Sku> skus;

  @override
  ConsumerState<_StockForm> createState() => _StockFormState();
}

class _StockFormState extends ConsumerState<_StockForm> {
  /// The count on the shelf — the one thing here the agent can actually observe,
  /// and the one that raises a stockout task. Null means "not counted yet",
  /// which is a different thing from zero.
  final _units = <String, int?>{};
  final _lastStockin = <String, DateTime>{};
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    for (final sku in widget.skus) {
      _units[sku.id] = null;
      _lastStockin[sku.id] = DateTime.now();
    }
  }

  Future<void> _save() async {
    final entries = widget.skus.map((sku) {
      return StockEntry(
        skuId: sku.id,
        // An uncounted SKU is recorded as 0 — the server reads that as out of
        // stock, which is why the hub will not let the visit be submitted until
        // every SKU has actually been counted.
        unitsAvailable: _units[sku.id] ?? 0,
        lastStockinDate: _lastStockin[sku.id]!,
      );
    }).toList();

    await ref.read(stockRepositoryProvider).saveStock(
          visitDraftId: widget.visitDraftId,
          entries: entries,
        );
    if (mounted) setState(() => _saved = true);
  }

  /// Tap the number to type it. A shelf can hold sixty units, and nobody taps
  /// "+" sixty times — the +/- is for adjusting, this is for entering.
  Future<void> _typeCount(Sku sku) async {
    final entered = await showDialog<int>(
      context: context,
      builder: (_) => _CountInputDialog(sku: sku, initial: _units[sku.id]),
    );
    if (entered != null && mounted) {
      setState(() => _units[sku.id] = entered);
    }
  }

  /// "selling ~4/day · 12 days cover" — read-only server context, not agent
  /// input (#112: an agent standing at a shelf cannot observe either number).
  String _contextLine(Sku sku) {
    final velocity = sku.velocityAvg > 0 ? '~${sku.velocityAvg.toStringAsFixed(1)}/day' : 'no sales history yet';
    final oos = sku.daysOutOfStock > 0 ? ' · out of stock ${sku.daysOutOfStock}d' : '';
    return 'Selling $velocity$oos';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skus.isEmpty) {
      return const Center(child: Text('No SKUs configured for this client.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('S2 Stock & Availability'),
        const SizedBox(height: 8),
        for (final sku in widget.skus)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          sku.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink1,
                          ),
                        ),
                      ),
                      Text(
                        'RRP ${sku.rrp.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contextLine(sku),
                    key: ValueKey('context-${sku.id}'),
                    style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 10),
                  CountStepper(
                    key: ValueKey('units-${sku.id}'),
                    value: _units[sku.id],
                    zeroIsFinding: true,
                    onChanged: (v) => setState(() => _units[sku.id] = v),
                    onEdit: () => _typeCount(sku),
                  ),
                  if (_units[sku.id] == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_outlined, size: 15, color: AppColors.crit),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Out of stock — this raises a task for the manager',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.crit),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _save, child: const Text('Save stock')),
        if (_saved)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Stock saved — queued for sync'),
          ),
      ],
    );
  }
}

/// Owns its own controller, so the field is never disposed while the dialog is
/// still animating away.
class _CountInputDialog extends StatefulWidget {
  const _CountInputDialog({required this.sku, required this.initial});

  final Sku sku;
  final int? initial;

  @override
  State<_CountInputDialog> createState() => _CountInputDialogState();
}

class _CountInputDialogState extends State<_CountInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      title: Text(widget.sku.name, style: const TextStyle(fontSize: 15)),
      content: TextField(
        key: ValueKey('units-input-${widget.sku.id}'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Units on shelf', isDense: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          key: ValueKey('units-confirm-${widget.sku.id}'),
          onPressed: () => Navigator.of(context).pop(int.tryParse(_controller.text.trim())),
          child: const Text('Set'),
        ),
      ],
    );
  }
}
```

`s2_stock_screen_test.dart` updates:

```dart
class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [
        Sku(id: 's1', name: 'Test Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99,
            daysOutOfStock: 0, velocityAvg: 4.2),
      ];
}

class _SpyStockRepository implements StockRepository {
  String? visitDraftId;
  List<StockEntry>? entries;

  @override
  Future<void> saveStock({required String visitDraftId, required List<StockEntry> entries}) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

void main() {
  testWidgets('shows read-only server context and calls saveStock on Save', (tester) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Selling ~4.2/day'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '20');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.skuId, 's1');
    expect(spy.entries!.first.unitsAvailable, 20);
    expect(find.text('Stock saved — queued for sync'), findsOneWidget);
  });

  testWidgets('the +/- stepper adjusts the count without a keyboard', (tester) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final plus = find.descendant(of: find.byKey(const ValueKey('units-s1')), matching: find.byIcon(Icons.add));
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.entries!.first.unitsAvailable, 3);
  });

  testWidgets('a zero count is shown as the finding it is', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
        stockRepositoryProvider.overrideWithValue(_SpyStockRepository()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '0');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    expect(find.text('Out of stock — this raises a task for the manager'), findsOneWidget);
  });
}
```

`audit_shell_screen_test.dart`: its `_FakeSkusRepository` (line ~38-40) gains the `{required String outletId}` parameter:
```dart
class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async => const [];
}
```
No other change needed in that file — `skusRepositoryProvider.overrideWithValue(...)` still works unmodified since it's the repository, not the now-family `skusListProvider`, being overridden.

Run: `flutter analyze && flutter test test/features/audit/s2_stock_screen_test.dart test/features/audit/audit_shell_screen_test.dart` — expect PASS. Commit: `feat(app): S2 form drops unobservable fields, shows server context (#112)`.

## Task 9: Verify

- Backend: `cd backend && npm run lint && npm run build && npm test` — full suite green.
- App: `cd app && flutter analyze && flutter test` — full suite green (build_runner output from Task 7 must be committed or regenerated fresh; confirm `local_db.g.dart` reflects the trimmed `StockDrafts` table).
- Manual smoke check (per this repo's UI-change convention): run the app, start a visit, open S2, confirm only "Units on shelf" and the read-only context line appear per SKU — no numeric text fields for days-out/velocity/sales.
