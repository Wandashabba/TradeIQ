# S2 Stock/Availability Audit Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a new `skus` read-only module, the `stock` backend module (per-SKU stock recording with server-computed coverage-days), and wire the Flutter S2 screen so a field agent can record stock/availability for every SKU during an audit visit, offline-first.

**Architecture:** Backend: a new `skus.service.ts`/`skus.routes.ts` pair (read-only, mirrors `outlets`), and a `stock.service.ts`/`stock.routes.ts` pair (mirrors `visits`' tenant-scoping pattern, calling the existing `forecast.service.ts` for `coverageDaysPredicted`). Flutter: a `SkusRepository` (mirrors `OutletsRepository`), a new `StockDrafts` Drift table + `StockRepository` (mirrors `VisitsRepository`'s offline-first write-then-sync pattern minus the geofence step), a `'stock'` case in `HttpQueueFlusher`, and an `S2StockScreen` rewrite (SKU list with per-SKU completion state, a form dialog for data entry) wired to receive the real `visitId` from `AuditShellScreen`.

**Tech Stack:** Node.js/Express/TypeScript/Prisma (backend), Flutter/Riverpod/Drift/Dio (app), Jest+Supertest (backend tests), flutter_test (app tests).

**Spec:** `docs/superpowers/specs/2026-07-03-s2-stock-availability-design.md`

---

## Task 1: Backend — `GET /skus` module

**Files:**
- Create: `backend/src/modules/skus/skus.service.ts`
- Create: `backend/src/modules/skus/skus.routes.ts`
- Test: `backend/src/modules/skus/skus.routes.test.ts` (new)
- Modify: `backend/src/app.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/modules/skus/skus.routes.test.ts`:

```ts
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('skus routes', () => {
  let clientId: string;
  let token: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    token = issueToken({ userId: 'seed-user', role: 'manager', clientId });

    await prisma.sku.create({
      data: { clientId, name: 'Test SKU', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
  });

  afterAll(async () => {
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it("lists SKUs for the caller's client", async () => {
    const res = await request(app).get('/skus').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].name).toBe('Test SKU');
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/skus');
    expect(res.status).toBe(401);
  });

  it('does not leak SKUs across clients', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    await prisma.sku.create({
      data: { clientId: otherClient.id, name: 'Other Client SKU', category: 'Snacks', minFacingsStandard: 2, rrp: 9.99 },
    });

    try {
      const res = await request(app).get('/skus').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.some((sku: { name: string }) => sku.name === 'Other Client SKU')).toBe(false);
    } finally {
      await prisma.sku.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest skus.routes.test.ts`
Expected: FAIL — `Cannot find module '../../app'` resolves fine, but there's no `/skus` route mounted yet, so every request returns Express's default 404, not the expected 200/401.

- [ ] **Step 3: Implement `skus.service.ts`**

Create `backend/src/modules/skus/skus.service.ts`:

```ts
import { prisma } from '../../lib/prisma';

export function listSkusForClient(clientId: string) {
  return prisma.sku.findMany({ where: { clientId } });
}
```

- [ ] **Step 4: Implement `skus.routes.ts`**

Create `backend/src/modules/skus/skus.routes.ts`:

```ts
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { listSkusForClient } from './skus.service';

export const skusRouter = Router();
skusRouter.use(requireAuth);

skusRouter.get('/', async (req: AuthedRequest, res) => {
  const skus = await listSkusForClient(req.user!.clientId);
  res.status(200).json(skus);
});
```

- [ ] **Step 5: Mount the router**

In `backend/src/app.ts`, add the import alongside the other module imports:

```ts
import { skusRouter } from './modules/skus/skus.routes';
```

And add the mount line alongside the other `app.use(...)` calls, right after `app.use('/outlets', outletsRouter);`:

```ts
app.use('/skus', skusRouter);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd backend && npx jest skus.routes.test.ts`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/skus/skus.service.ts backend/src/modules/skus/skus.routes.ts backend/src/modules/skus/skus.routes.test.ts backend/src/app.ts
git commit -m "feat(backend): add read-only GET /skus module"
```

---

## Task 2: Backend — `POST /stock` endpoint

**Files:**
- Create: `backend/src/modules/stock/stock.service.ts`
- Modify: `backend/src/modules/stock/stock.routes.ts`
- Test: `backend/src/modules/stock/stock.routes.test.ts` (new)

- [ ] **Step 1: Write the failing test**

Create `backend/src/modules/stock/stock.routes.test.ts`:

```ts
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('stock routes', () => {
  let clientId: string;
  let token: string;
  let visitId: string;
  let skuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: {
        email: 'stock-test-agent@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    token = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Test Outlet',
        code: 'STOCK-TEST-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        clientId,
      },
    });

    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;

    const sku = await prisma.sku.create({
      data: { clientId, name: 'Test SKU', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;
  });

  afterAll(async () => {
    await prisma.visitStock.deleteMany({ where: { visitId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates a VisitStock row with a server-computed coverageDaysPredicted', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${token}`)
      .send({
        visitId,
        skuId,
        unitsAvailable: 40,
        lastStockinDate: '2026-06-30',
        daysOutOfStock: 0,
        velocityAvg: 10,
        salesActual: 350,
        salesTarget: 400,
      });

    expect(res.status).toBe(201);
    expect(res.body.visitId).toBe(visitId);
    expect(res.body.skuId).toBe(skuId);
    expect(res.body.coverageDaysPredicted).toBe(4);
  });

  it('returns 404 when the visit belongs to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'stock-test-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: otherClient.id,
      },
    });
    const otherToken = issueToken({ userId: otherAgent.id, role: 'field_agent', clientId: otherClient.id });

    try {
      const res = await request(app)
        .post('/stock')
        .set('Authorization', `Bearer ${otherToken}`)
        .send({
          visitId,
          skuId,
          unitsAvailable: 40,
          lastStockinDate: '2026-06-30',
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        });

      expect(res.status).toBe(404);
    } finally {
      await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('returns 404 when the sku belongs to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherSku = await prisma.sku.create({
      data: { clientId: otherClient.id, name: 'Other SKU', category: 'Snacks', minFacingsStandard: 2, rrp: 9.99 },
    });

    try {
      const res = await request(app)
        .post('/stock')
        .set('Authorization', `Bearer ${token}`)
        .send({
          visitId,
          skuId: otherSku.id,
          unitsAvailable: 40,
          lastStockinDate: '2026-06-30',
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        });

      expect(res.status).toBe(404);
    } finally {
      await prisma.sku.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('rejects a request with a missing required field', async () => {
    const res = await request(app)
      .post('/stock')
      .set('Authorization', `Bearer ${token}`)
      .send({ visitId, skuId });

    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/stock').send({ visitId, skuId });
    expect(res.status).toBe(401);
  });

  it('GET / is not implemented yet', async () => {
    const res = await request(app).get('/stock').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(501);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest stock.routes.test.ts`
Expected: FAIL — the current skeleton has no `POST` handler, so the first 5 assertions fail against the 501-only skeleton behavior.

- [ ] **Step 3: Implement `stock.service.ts`**

Create `backend/src/modules/stock/stock.service.ts`:

```ts
import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../middleware/errorHandler';
import { predictCoverageDays } from '../../services/forecast.service';

export interface RecordStockInput {
  visitId: string;
  skuId: string;
  unitsAvailable: number;
  lastStockinDate: Date;
  daysOutOfStock: number;
  velocityAvg: number;
  salesActual: number;
  salesTarget: number;
  clientId: string;
}

export async function recordStock(input: RecordStockInput) {
  const [visit, sku] = await Promise.all([
    prisma.visit.findFirst({ where: { id: input.visitId, clientId: input.clientId } }),
    prisma.sku.findFirst({ where: { id: input.skuId, clientId: input.clientId } }),
  ]);
  if (!visit) {
    throw new NotFoundError('Visit not found');
  }
  if (!sku) {
    throw new NotFoundError('Sku not found');
  }

  const coverageDaysPredicted = predictCoverageDays({
    unitsAvailable: input.unitsAvailable,
    velocityAvg: input.velocityAvg,
  });

  return prisma.visitStock.create({
    data: {
      visitId: input.visitId,
      skuId: input.skuId,
      unitsAvailable: input.unitsAvailable,
      lastStockinDate: input.lastStockinDate,
      daysOutOfStock: input.daysOutOfStock,
      velocityAvg: input.velocityAvg,
      coverageDaysPredicted,
      salesActual: input.salesActual,
      salesTarget: input.salesTarget,
    },
  });
}
```

- [ ] **Step 4: Implement `stock.routes.ts`**

Replace the full contents of `backend/src/modules/stock/stock.routes.ts`:

```ts
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';
import { recordStock } from './stock.service';

export const stockRouter = Router();
stockRouter.use(requireAuth);

stockRouter.post('/', async (req: AuthedRequest, res) => {
  const {
    visitId,
    skuId,
    unitsAvailable,
    lastStockinDate,
    daysOutOfStock,
    velocityAvg,
    salesActual,
    salesTarget,
  } = req.body as {
    visitId?: string;
    skuId?: string;
    unitsAvailable?: number;
    lastStockinDate?: string;
    daysOutOfStock?: number;
    velocityAvg?: number;
    salesActual?: number;
    salesTarget?: number;
  };

  if (
    !visitId ||
    !skuId ||
    unitsAvailable === undefined ||
    !lastStockinDate ||
    daysOutOfStock === undefined ||
    velocityAvg === undefined ||
    salesActual === undefined ||
    salesTarget === undefined
  ) {
    res.status(400).json({
      error:
        'visitId, skuId, unitsAvailable, lastStockinDate, daysOutOfStock, velocityAvg, salesActual, and salesTarget are required',
    });
    return;
  }

  const stock = await recordStock({
    visitId,
    skuId,
    unitsAvailable,
    lastStockinDate: new Date(lastStockinDate),
    daysOutOfStock,
    velocityAvg,
    salesActual,
    salesTarget,
    clientId: req.user!.clientId,
  });
  res.status(201).json(stock);
});

stockRouter.get('/', () => {
  throw new NotImplementedError('Stock listing is not implemented yet');
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && npx jest stock.routes.test.ts`
Expected: PASS (6 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/stock/stock.service.ts backend/src/modules/stock/stock.routes.ts backend/src/modules/stock/stock.routes.test.ts
git commit -m "feat(backend): implement POST /stock with server-computed coverage days"
```

---

## Task 3: Backend — retire `/stock` from the module-skeleton test and verify

**Files:**
- Modify: `backend/src/modules/moduleSkeletons.test.ts`

- [ ] **Step 1: Update the skeleton route list**

In `backend/src/modules/moduleSkeletons.test.ts`, remove `'/stock'`:

```ts
const skeletonRoutes = [
  '/visibility', '/pricing', '/competitive',
  '/capability', '/risks', '/tasks', '/scorecards', '/dashboard',
];
```

- [ ] **Step 2: Run the full backend suite and lint**

Run: `cd backend && npm run lint && npm test`
Expected: PASS — all suites green

- [ ] **Step 3: Commit**

```bash
git add backend/src/modules/moduleSkeletons.test.ts
git commit -m "test(backend): drop /stock from the generic 501 skeleton coverage"
```

---

## Task 4: Flutter — `Sku` model + `SkusRepository`

**Files:**
- Create: `app/lib/features/skus/data/skus_repository.dart`

- [ ] **Step 1: Implement `Sku` and `SkusRepository`**

Create `app/lib/features/skus/data/skus_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Sku {
  const Sku({required this.id, required this.name, required this.category});
  final String id;
  final String name;
  final String category;

  factory Sku.fromJson(Map<String, dynamic> json) => Sku(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
      );
}

abstract class SkusRepository {
  Future<List<Sku>> listSkus();
}

class DioSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async {
    final response = await dio.get('/skus');
    return (response.data as List)
        .map((json) => Sku.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final skusRepositoryProvider = Provider<SkusRepository>((ref) => DioSkusRepository());

final skusListProvider = FutureProvider<List<Sku>>((ref) {
  return ref.read(skusRepositoryProvider).listSkus();
});
```

No dedicated unit test for this file — consistent with `outlets_repository.dart`'s `DioOutletsRepository`, which has never had one either (the real Dio path is only ever exercised via widget tests using fakes).

- [ ] **Step 2: Verify it compiles**

Run: `cd app && flutter analyze`
Expected: PASS — no issues (file isn't consumed by anything yet)

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/skus/data/skus_repository.dart
git commit -m "feat(app): add Sku model and SkusRepository"
```

---

## Task 5: Flutter — `StockDrafts` Drift table

**Files:**
- Modify: `app/lib/core/storage/tables.dart`
- Modify: `app/lib/core/storage/local_db.dart`

- [ ] **Step 1: Add the `StockDrafts` table**

In `app/lib/core/storage/tables.dart`, add after the existing `VisitDrafts` class:

```dart
/// Local mirror of a per-SKU stock/availability observation recorded during
/// S2 of an audit visit. Synced to the backend via the [SyncQueueItems]
/// outbox, same pattern as [VisitDrafts] for S1.
class StockDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get visitId => text()();
  TextColumn get skuId => text()();
  IntColumn get unitsAvailable => integer()();
  DateTimeColumn get lastStockinDate => dateTime()();
  IntColumn get daysOutOfStock => integer()();
  RealColumn get velocityAvg => real()();
  RealColumn get salesActual => real()();
  RealColumn get salesTarget => real()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Register the table and bump the schema version**

In `app/lib/core/storage/local_db.dart`, change:

```dart
@DriftDatabase(tables: [VisitDrafts, SyncQueueItems])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;
```

to:

```dart
@DriftDatabase(tables: [VisitDrafts, SyncQueueItems, StockDrafts])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;
```

(No migration strategy needed — there are no shipped installs with existing local data to migrate yet.)

- [ ] **Step 3: Regenerate the Drift codegen**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: `local_db.g.dart` is regenerated, now containing `StockDraftsCompanion`, `StockDraft`, and a `db.stockDrafts` accessor, alongside the existing generated code.

- [ ] **Step 4: Run the existing storage test to confirm no regression**

Run: `cd app && flutter test test/core/storage/local_db_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/storage/tables.dart app/lib/core/storage/local_db.dart app/lib/core/storage/local_db.g.dart
git commit -m "feat(app): add StockDrafts local table for S2 offline-first stock capture"
```

---

## Task 6: Flutter — wire `HttpQueueFlusher`'s `'stock'` case

**Files:**
- Modify: `app/lib/core/sync/sync_service.dart`
- Modify: `app/test/core/sync/sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

In `app/test/core/sync/sync_service_test.dart`, add this test inside the existing `group('HttpQueueFlusher', () { ... })` block, after the `'posts the visit payload...'` test:

```dart
    test('posts the stock payload to /stock and succeeds on 2xx', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      await flusher.flush(_visitQueueItem('{"visitId":"v1","skuId":"s1"}').copyWith(entityType: 'stock'));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: FAIL — the current `default:` branch throws `UnimplementedError('HTTP sync for stock not wired yet')`

- [ ] **Step 3: Add the `'stock'` case**

In `app/lib/core/sync/sync_service.dart`, change:

```dart
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        return;
      default:
        throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
    }
  }
```

to:

```dart
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        return;
      case 'stock':
        await _dio.post('/stock', data: jsonDecode(item.payloadJson));
        return;
      default:
        throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/sync/sync_service.dart app/test/core/sync/sync_service_test.dart
git commit -m "feat(app): wire HttpQueueFlusher's stock case to POST /stock"
```

---

## Task 7: Flutter — `StockRepository`

**Files:**
- Create: `app/lib/features/audit/data/stock_repository.dart`
- Test: `app/test/features/audit/stock_repository_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/features/audit/stock_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    throw Exception('network error');
  }
}

void main() {
  late LocalDb db;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('recording stock writes a StockDraft and enqueues a sync item', () async {
    final repository = DriftStockRepository(db: db, syncService: SyncService(db: db, flusher: _NoopFlusher()));

    await repository.recordStock(
      visitId: 'visit-1',
      skuId: 'sku-1',
      unitsAvailable: 40,
      lastStockinDate: DateTime(2026, 6, 30),
      daysOutOfStock: 0,
      velocityAvg: 10,
      salesActual: 350,
      salesTarget: 400,
    );

    final drafts = await db.select(db.stockDrafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.first.visitId, 'visit-1');
    expect(drafts.first.skuId, 'sku-1');
    expect(drafts.first.unitsAvailable, 40);

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued, hasLength(1));
    expect(queued.first.entityType, 'stock');
  });

  test('a failing sync flush does not throw or block the local write', () async {
    final repository = DriftStockRepository(db: db, syncService: SyncService(db: db, flusher: _ThrowingFlusher()));

    await repository.recordStock(
      visitId: 'visit-1',
      skuId: 'sku-1',
      unitsAvailable: 40,
      lastStockinDate: DateTime(2026, 6, 30),
      daysOutOfStock: 0,
      velocityAvg: 10,
      salesActual: 350,
      salesTarget: 400,
    );

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued.first.synced, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/stock_repository_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'tradeiq_app' in 'package:tradeiq_app/features/audit/data/stock_repository.dart'` (file doesn't exist yet)

- [ ] **Step 3: Implement `StockRepository`**

Create `app/lib/features/audit/data/stock_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

abstract class StockRepository {
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  });
}

class DriftStockRepository implements StockRepository {
  DriftStockRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;

  static const _uuid = Uuid();

  @override
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  }) async {
    final id = _uuid.v4();
    await db.transaction(() async {
      await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
            id: id,
            visitId: visitId,
            skuId: skuId,
            unitsAvailable: unitsAvailable,
            lastStockinDate: lastStockinDate,
            daysOutOfStock: daysOutOfStock,
            velocityAvg: velocityAvg,
            salesActual: salesActual,
            salesTarget: salesTarget,
          ));
      await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
            entityType: 'stock',
            entityId: id,
            payloadJson: jsonEncode({
              'visitId': visitId,
              'skuId': skuId,
              'unitsAvailable': unitsAvailable,
              'lastStockinDate': lastStockinDate.toIso8601String(),
              'daysOutOfStock': daysOutOfStock,
              'velocityAvg': velocityAvg,
              'salesActual': salesActual,
              'salesTarget': salesTarget,
            }),
          ));
    });

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the entry is already saved locally and queued; a
      // failed flush just means it stays queued for the next attempt.
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) => DriftStockRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/stock_repository_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/audit/data/stock_repository.dart app/test/features/audit/stock_repository_test.dart
git commit -m "feat(app): add StockRepository for offline-first per-SKU stock capture"
```

---

## Task 8: Flutter — `S2StockScreen`

**Files:**
- Modify: `app/lib/features/audit/presentation/sections/s2_stock_screen.dart`
- Test: `app/test/features/audit/sections/s2_stock_screen_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/features/audit/sections/s2_stock_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';
import 'package:tradeiq_app/features/skus/data/skus_repository.dart';

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 'sku-1', name: 'Demo Brand 500ml', category: 'Beverages'),
      ];
}

class _RecordingStockRepository implements StockRepository {
  final List<String> recordedSkuIds = [];

  @override
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  }) async {
    recordedSkuIds.add(skuId);
  }
}

Widget _screenWith(StockRepository stockRepository, {LocalDb? db}) {
  return ProviderScope(
    overrides: [
      localDbProvider.overrideWithValue(db ?? LocalDb(NativeDatabase.memory())),
      skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      stockRepositoryProvider.overrideWithValue(stockRepository),
    ],
    child: const MaterialApp(home: Scaffold(body: S2StockScreen(visitId: 'visit-1'))),
  );
}

void main() {
  testWidgets('renders SKUs and opens the stock form on tap', (tester) async {
    await tester.pumpWidget(_screenWith(_RecordingStockRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Demo Brand 500ml'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.text('Demo Brand 500ml'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: Demo Brand 500ml'), findsOneWidget);
  });

  testWidgets('submitting the form records stock and shows the SKU as recorded', (tester) async {
    final stockRepository = _RecordingStockRepository();
    await tester.pumpWidget(_screenWith(stockRepository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo Brand 500ml'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Units available'), '40');
    await tester.enterText(find.widgetWithText(TextFormField, 'Days out of stock'), '0');
    await tester.enterText(find.widgetWithText(TextFormField, 'Average daily velocity'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Sales actual'), '350');
    await tester.enterText(find.widgetWithText(TextFormField, 'Sales target'), '400');

    await tester.tap(find.text('Last stock-in date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: Demo Brand 500ml'), findsNothing);
    expect(stockRepository.recordedSkuIds, ['sku-1']);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping an already-recorded SKU does nothing', (tester) async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
          id: 'draft-1',
          visitId: 'visit-1',
          skuId: 'sku-1',
          unitsAvailable: 40,
          lastStockinDate: DateTime(2026, 6, 30),
          daysOutOfStock: 0,
          velocityAvg: 10,
          salesActual: 350,
          salesTarget: 400,
        ));

    await tester.pumpWidget(_screenWith(_RecordingStockRepository(), db: db));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Demo Brand 500ml'));
    await tester.pumpAndSettle();

    expect(find.text('Stock: Demo Brand 500ml'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/sections/s2_stock_screen_test.dart`
Expected: FAIL — `The named parameter 'visitId' isn't defined` (current `S2StockScreen` takes no constructor params)

- [ ] **Step 3: Implement `S2StockScreen`**

Replace the full contents of `app/lib/features/audit/presentation/sections/s2_stock_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_db.dart';
import '../../data/stock_repository.dart';
import '../../../skus/data/skus_repository.dart';

class S2StockScreen extends ConsumerStatefulWidget {
  const S2StockScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<S2StockScreen> createState() => _S2StockScreenState();
}

class _S2StockScreenState extends ConsumerState<S2StockScreen> {
  Set<String> _recordedSkuIds = {};
  bool _loadedRecorded = false;

  @override
  void initState() {
    super.initState();
    _loadRecordedSkuIds();
  }

  Future<void> _loadRecordedSkuIds() async {
    final db = ref.read(localDbProvider);
    final rows = await (db.select(db.stockDrafts)..where((t) => t.visitId.equals(widget.visitId))).get();
    if (!mounted) return;
    setState(() {
      _recordedSkuIds = rows.map((r) => r.skuId).toSet();
      _loadedRecorded = true;
    });
  }

  Future<void> _openStockForm(Sku sku) async {
    final result = await showDialog<_StockFormResult>(
      context: context,
      builder: (context) => _StockFormDialog(sku: sku),
    );
    if (result == null) return;

    await ref.read(stockRepositoryProvider).recordStock(
          visitId: widget.visitId,
          skuId: sku.id,
          unitsAvailable: result.unitsAvailable,
          lastStockinDate: result.lastStockinDate,
          daysOutOfStock: result.daysOutOfStock,
          velocityAvg: result.velocityAvg,
          salesActual: result.salesActual,
          salesTarget: result.salesTarget,
        );

    if (!mounted) return;
    setState(() => _recordedSkuIds = {..._recordedSkuIds, sku.id});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedRecorded) {
      return const Center(child: CircularProgressIndicator());
    }

    final skusAsync = ref.watch(skusListProvider);

    return skusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load SKUs: $err')),
      data: (skus) => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: skus.length,
        itemBuilder: (context, index) {
          final sku = skus[index];
          final recorded = _recordedSkuIds.contains(sku.id);
          return ListTile(
            title: Text(sku.name),
            subtitle: Text(sku.category),
            trailing: recorded ? const Icon(Icons.check_circle, color: Colors.green) : null,
            onTap: recorded ? null : () => _openStockForm(sku),
          );
        },
      ),
    );
  }
}

class _StockFormResult {
  const _StockFormResult({
    required this.unitsAvailable,
    required this.lastStockinDate,
    required this.daysOutOfStock,
    required this.velocityAvg,
    required this.salesActual,
    required this.salesTarget,
  });

  final int unitsAvailable;
  final DateTime lastStockinDate;
  final int daysOutOfStock;
  final double velocityAvg;
  final double salesActual;
  final double salesTarget;
}

class _StockFormDialog extends StatefulWidget {
  const _StockFormDialog({required this.sku});

  final Sku sku;

  @override
  State<_StockFormDialog> createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<_StockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _unitsAvailableController = TextEditingController();
  final _daysOutOfStockController = TextEditingController();
  final _velocityAvgController = TextEditingController();
  final _salesActualController = TextEditingController();
  final _salesTargetController = TextEditingController();
  DateTime? _lastStockinDate;

  @override
  void dispose() {
    _unitsAvailableController.dispose();
    _daysOutOfStockController.dispose();
    _velocityAvgController.dispose();
    _salesActualController.dispose();
    _salesTargetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastStockinDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _lastStockinDate = picked);
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _lastStockinDate == null) {
      setState(() {}); // rebuild so a missing-date error becomes visible
      return;
    }

    Navigator.of(context).pop(_StockFormResult(
      unitsAvailable: int.parse(_unitsAvailableController.text),
      lastStockinDate: _lastStockinDate!,
      daysOutOfStock: int.parse(_daysOutOfStockController.text),
      velocityAvg: double.parse(_velocityAvgController.text),
      salesActual: double.parse(_salesActualController.text),
      salesTarget: double.parse(_salesTargetController.text),
    ));
  }

  String? _requiredInt(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (int.tryParse(value) == null) return 'Must be a whole number';
    return null;
  }

  String? _requiredDouble(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Must be a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Stock: ${widget.sku.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _unitsAvailableController,
                decoration: const InputDecoration(labelText: 'Units available'),
                keyboardType: TextInputType.number,
                validator: _requiredInt,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_lastStockinDate == null
                    ? 'Last stock-in date'
                    : 'Last stock-in: ${_lastStockinDate!.toIso8601String().split('T').first}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              if (_lastStockinDate == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Required', style: TextStyle(color: Colors.red)),
                ),
              TextFormField(
                controller: _daysOutOfStockController,
                decoration: const InputDecoration(labelText: 'Days out of stock'),
                keyboardType: TextInputType.number,
                validator: _requiredInt,
              ),
              TextFormField(
                controller: _velocityAvgController,
                decoration: const InputDecoration(labelText: 'Average daily velocity'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredDouble,
              ),
              TextFormField(
                controller: _salesActualController,
                decoration: const InputDecoration(labelText: 'Sales actual'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredDouble,
              ),
              TextFormField(
                controller: _salesTargetController,
                decoration: const InputDecoration(labelText: 'Sales target'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _requiredDouble,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/sections/s2_stock_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/audit/presentation/sections/s2_stock_screen.dart app/test/features/audit/sections/s2_stock_screen_test.dart
git commit -m "feat(app): implement S2StockScreen with per-SKU stock capture"
```

---

## Task 9: Flutter — `AuditShellScreen` wiring

**Files:**
- Modify: `app/lib/features/audit/presentation/audit_shell_screen.dart`
- Modify: `app/test/features/audit/audit_shell_screen_test.dart`

- [ ] **Step 1: Replace the test file with the failing test**

Replace the full contents of `app/test/features/audit/audit_shell_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/skus/data/skus_repository.dart';

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];
}

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async => const [
        Sku(id: 'sku-1', name: 'Demo Brand 500ml', category: 'Beverages'),
      ];
}

class _SucceedingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');
}

class _GeofenceFailingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInGeofenceFailed(650);
}

class _LocationUnavailableVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInLocationUnavailable('Location permission denied');
}

Widget _appWith(VisitsRepository visitsRepository) {
  return ProviderScope(
    overrides: [
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(visitsRepository),
      skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
      localDbProvider.overrideWithValue(LocalDb(NativeDatabase.memory())),
    ],
    child: const MaterialApp(home: AuditShellScreen(outletId: 'o1')),
  );
}

void main() {
  testWidgets('shows a stepper with all 10 audit sections after a successful check-in', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });

  testWidgets('passes the real visitId from a successful check-in to S2StockScreen', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    // S2's SKU list rendering (rather than a stuck spinner) proves
    // S2StockScreen built with a real, non-null visitId — its local Drift
    // query is keyed on visitId and its FutureBuilder-driven load would
    // never resolve into the list view otherwise.
    expect(find.text('Demo Brand 500ml'), findsOneWidget);
  });

  testWidgets('shows a blocking error when the check-in fails the geofence', (tester) async {
    await tester.pumpWidget(_appWith(_GeofenceFailingVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('650'), findsOneWidget);
    expect(find.text('S1 Outlet Information'), findsNothing);
  });

  testWidgets('shows a retry action when location is unavailable', (tester) async {
    await tester.pumpWidget(_appWith(_LocationUnavailableVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Location permission denied'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });

  testWidgets('the check-in confirmation timestamp stays fixed across step navigation', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    final firstTimestampFinder = find.textContaining('Checked in at').first;
    final firstText = tester.widget<Text>(firstTimestampFinder).data;

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();

    final secondTimestampFinder = find.textContaining('Checked in at').first;
    final secondText = tester.widget<Text>(secondTimestampFinder).data;

    expect(secondText, firstText);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: FAIL to compile — `The named parameter 'visitId' is required, but there's no corresponding argument` at `audit_shell_screen.dart`'s `const S2StockScreen()` call (Task 8 already made `visitId` a required param; `AuditShellScreen` hasn't been updated to supply it yet).

- [ ] **Step 3: Wire `visitId` through `AuditShellScreen`**

In `app/lib/features/audit/presentation/audit_shell_screen.dart`, change:

```dart
  List<Widget> _sections() => [
        S1OutletInfoScreen(checkinTs: _checkinTs),
        const S2StockScreen(),
        const S3S4VisibilityDisplayScreen(),
        const S5PricingPromotionsScreen(),
        const S6CompetitiveScreen(),
        const S7CapabilityScreen(),
        const S8RisksScreen(),
        const S9ActionPlanScreen(),
        const S10ScorecardScreen(),
      ];
```

to:

```dart
  // Only ever called from _buildStepper(), which only renders once
  // _checkInResult is CheckInSucceeded, so this cast is always safe.
  List<Widget> _sections() {
    final visitId = (_checkInResult as CheckInSucceeded).visitId;
    return [
      S1OutletInfoScreen(checkinTs: _checkinTs),
      S2StockScreen(visitId: visitId),
      const S3S4VisibilityDisplayScreen(),
      const S5PricingPromotionsScreen(),
      const S6CompetitiveScreen(),
      const S7CapabilityScreen(),
      const S8RisksScreen(),
      const S9ActionPlanScreen(),
      const S10ScorecardScreen(),
    ];
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/audit/presentation/audit_shell_screen.dart app/test/features/audit/audit_shell_screen_test.dart
git commit -m "feat(app): thread the real visitId from check-in into S2StockScreen"
```

---

## Task 10: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full backend suite**

Run: `cd backend && npm run lint && npm test`
Expected: PASS, all suites green

- [ ] **Step 2: Run the full app suite and analyzer**

Run: `cd app && flutter analyze && flutter test`
Expected: PASS, no analyzer warnings

- [ ] **Step 3: Manual end-to-end verification against the real backend**

1. `make dev` (or `cd backend && npm run dev` if Postgres is already up)
2. `cd app && flutter run -d macos` (Chrome can't run this app — Drift's `NativeDatabase` needs `dart:ffi`, unavailable on web; macOS already has the location/network entitlements configured from the S1 feature)
3. Log in as `agent@demo-fmcg.tradeiq.com` / `demo-password-123`
4. Pick an outlet, approve location, and get past the check-in (override your Mac's location to the outlet's coordinates via System Settings if needed, or accept the geofence-fail screen as expected if your real location isn't near Gauteng — either way you reach the stepper or can retry)
5. Once on the stepper, navigate to step 2 (tap "2" or "Continue" once) and confirm the SKU list renders (e.g. "Demo Brand 500ml" from the seed data)
6. Tap the SKU, fill in the 6 fields, pick a stock-in date, tap Save
7. Confirm the SKU now shows a green checkmark and the dialog closed
8. Query Postgres to confirm the row landed: `docker exec -it tradeiq-postgres-1 psql -U tradeiq -d tradeiq -c "select visit_id, sku_id, units_available, coverage_days_predicted from visit_stock order by id desc limit 1;"`

- [ ] **Step 4: No commit for this task** — it's verification only; if any step fails, return to the relevant task above and fix it there (with its own commit), don't fix it here.
