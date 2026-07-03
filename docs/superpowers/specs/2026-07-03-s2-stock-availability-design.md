# S2 — Stock/Availability Audit Section — Design Spec

Date: 2026-07-03
Status: Approved

## 1. Purpose

Close [issue #8](https://github.com/Wandashabba/TradeIQ/issues/8): implement
the `stock` backend module (currently a 501 skeleton) and wire the Flutter S2
screen so a field agent can record per-SKU stock/availability data during an
audit visit, feeding the "availability" scorecard weight (0.3, per the seed
`Client.scorecardWeights`) and the existing `forecast.service.ts` coverage-days
calculation.

## 2. Scope

In scope:
- `GET /skus` — a new, minimal, read-only module. Nothing in the backend
  currently exposes a client's SKU catalog over HTTP (SKUs are only ever
  created via `backend/scripts/seed.ts`'s direct Prisma calls) — the S2 screen
  needs this to know which SKUs to show.
- `POST /stock` — creates one `VisitStock` row per SKU per visit, with
  `coverageDaysPredicted` computed server-side.
- Offline-first stock recording: local Drift write + sync-queue outbox +
  best-effort flush, per ADR 0005 and mirroring the S1 `VisitsRepository`
  pattern.
- A new `StockDrafts` Drift table (local mirror of `VisitStock`).
- The S2 Flutter screen: a SKU list with per-SKU completion state and a form
  dialog for data entry.

Explicitly out of scope (deferred, not part of this change):
- `GET /stock` — stays the 501 skeleton, matching the `GET /visits` precedent
  from S1. Nothing needs it this pass (local Drift state is the source of
  truth for "what's been recorded this visit" during an active session).
- SKU management (create/update/delete) — `GET /skus` is read-only; SKUs
  remain seed-script-only for now.
- Editing/resubmitting a SKU's stock entry once recorded in the current visit
  — a one-shot entry per SKU per visit, matching S1's check-in being a
  one-shot action. Tapping an already-recorded SKU in the list is a no-op.
- Gating the Stepper's "Continue" action on S2 completion — the agent can
  move to S3 regardless of how many SKUs they've recorded, consistent with
  the existing free-navigation Stepper.
- Outlet-specific SKU assignment — every visit reports on *all* of the
  client's SKUs (the schema has no outlet↔SKU relation); a subset/assignment
  model is a plausible Phase 2 addition, not needed now given the seed data's
  single SKU.
- Computing `velocityAvg` from historical `VisitStock` rows — it's a direct
  agent-entered field this pass, like the other five data fields. There's no
  POS/inventory integration in Phase 1 to source it from automatically.

## 3. Backend: `skus` module

`backend/src/modules/skus/skus.service.ts` (new, mirrors
`outlets.service.ts`):

```ts
export function listSkusForClient(clientId: string) {
  return prisma.sku.findMany({ where: { clientId } });
}
```

`backend/src/modules/skus/skus.routes.ts` (new):

```ts
export const skusRouter = Router();
skusRouter.use(requireAuth);

skusRouter.get('/', async (req: AuthedRequest, res) => {
  const skus = await listSkusForClient(req.user!.clientId);
  res.status(200).json(skus);
});
```

Mounted in `app.ts` as `app.use('/skus', skusRouter)`. No `POST`/`PUT`/`DELETE`
— SKU management isn't in scope.

## 4. Backend: `stock` module

`backend/src/modules/stock/stock.service.ts` (new, mirrors
`visits.service.ts`'s tenant-scoping pattern):

```ts
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
  if (!visit) throw new NotFoundError('Visit not found');
  if (!sku) throw new NotFoundError('Sku not found');

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

`backend/src/modules/stock/stock.routes.ts` (rewritten): `POST /` validates
all 8 required body fields present (400 otherwise), calls `recordStock` with
`clientId` from `req.user!.clientId`, returns 201. `GET /` stays the existing
501 `NotImplementedError` skeleton.

`moduleSkeletons.test.ts` drops `/stock` from `skeletonRoutes` (its own test
file now covers `GET /stock`'s 501, same pattern as `/visits`).

## 5. Flutter: data/sync layer

**`Sku` model + repository** (new, `app/lib/features/skus/data/skus_repository.dart`,
mirrors `outlets_repository.dart` exactly):

```dart
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
    return (response.data as List).map((j) => Sku.fromJson(j as Map<String, dynamic>)).toList();
  }
}

final skusRepositoryProvider = Provider<SkusRepository>((ref) => DioSkusRepository());
final skusListProvider = FutureProvider<List<Sku>>((ref) => ref.read(skusRepositoryProvider).listSkus());
```

Only `id`/`name`/`category` for now — `minFacingsStandard`/`rrp` aren't needed
by S2; add them when a later section (e.g. S5 Pricing needing `rrp`) actually
requires them, following the same incremental-field pattern `Outlet` used
(started with `id`/`name`/`code`, grew `lat`/`lng` when S1 needed them).

**New Drift table** (`app/lib/core/storage/tables.dart`):

```dart
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

Added to `@DriftDatabase(tables: [VisitDrafts, SyncQueueItems, StockDrafts])`
in `local_db.dart`, requiring a `dart run build_runner build` to regenerate
`local_db.g.dart`. Schema version bumps from 1 to 2 (no migration needed yet —
no shipped installs to migrate).

**`StockRepository`** (new, `app/lib/features/audit/data/stock_repository.dart`):

```dart
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
```

`DriftStockRepository.recordStock`: writes a `StockDrafts` row + a
`SyncQueueItems` row (`entityType: 'stock'`, `payloadJson` containing all 8
fields keyed to match `POST /stock`'s body) inside a single `db.transaction`
(reusing the atomicity fix from S1's `VisitsRepository`), then attempts one
best-effort `syncService.flushPending()`, swallowing any failure — the local
write already succeeded. Returns `Future<void>`: unlike `VisitsRepository`,
there's no rejection condition analogous to geofence-fail here (no
client-side validation step that can reject the write), so a multi-variant
result type would be unused ceremony.

**`HttpQueueFlusher`** (`app/lib/core/sync/sync_service.dart`, modified): add
the `'stock'` case — `POST /stock` with the decoded `payloadJson` — the exact
extension point its own code comment already anticipated ("other entity
types get their own case as their S2-S10 modules land").

## 6. Flutter: UI

- **`S2StockScreen`** (`app/lib/features/audit/presentation/sections/s2_stock_screen.dart`,
  rewritten): gains a required `visitId` param.
- **`AuditShellScreen`** (`app/lib/features/audit/presentation/audit_shell_screen.dart`,
  modified): `_sections()` passes `S2StockScreen(visitId: (_checkInResult as CheckInSucceeded).visitId)`
  — the first consumer of the `visitId` that check-in already produces.
- S2 body: `ConsumerStatefulWidget` watching `skusListProvider` for the SKU
  list, plus a local Drift query (`db.select(db.stockDrafts)..where((t) => t.visitId.equals(widget.visitId))`)
  on init to know which `skuId`s are already recorded this visit.
- Each SKU renders as a `ListTile` (name, category subtitle), with a
  checkmark `Icon` trailing once recorded. Tapping an unrecorded SKU opens an
  `AlertDialog` form: `unitsAvailable` (number field), `lastStockinDate` (date
  picker), `daysOutOfStock` (number field), `velocityAvg`/`salesActual`/`salesTarget`
  (decimal fields) — validation is "non-empty and parses via `int.tryParse`/
  `double.tryParse`" only (no range/plausibility checks this pass, e.g.
  negative units or a stock-in date in the future are accepted). Submitting calls
  `StockRepository.recordStock(...)`, closes the dialog, and refreshes the
  recorded-SKU set so the list updates immediately.
- Tapping an already-recorded SKU does nothing (no edit flow, see §2).

## 7. Testing

Backend (Jest + Supertest):
- `skus.routes.test.ts` (new): 200 + tenant-scoped list (mirrors
  `outlets.routes.test.ts`'s list/tenant-isolation shape); 401 unauthenticated.
- `stock.routes.test.ts` (new): 201 + persisted `VisitStock` with correctly
  computed `coverageDaysPredicted` (e.g. `unitsAvailable: 40, velocityAvg: 10`
  → `4`, matching `forecast.service.test.ts`'s existing case); 404 when
  `visitId` belongs to another client; 404 when `skuId` belongs to another
  client; 400 on any missing field; 401 unauthenticated. Fixtures: a `Client`
  + `User` (agent) + `Outlet` + `Visit` (extending the pattern from
  `visits.routes.test.ts`) + a `Sku` row.
- `moduleSkeletons.test.ts` (modified): remove `/stock` from `skeletonRoutes`.

Flutter (`flutter_test`):
- `stock_repository_test.dart` (new, mirrors `visits_repository_test.dart`'s
  in-memory-Drift pattern): recording stock writes one `StockDrafts` row and
  one `SyncQueueItems` row with `entityType: 'stock'`; a failing sync flush
  doesn't make `recordStock` fail or throw.
- `sync_service_test.dart` (modified): add a `'stock'` case to the
  `HttpQueueFlusher` test group (success on 2xx; throws on non-2xx, same
  shape as the `'visit'` case).
- `skus_repository_test.dart`: not added — `DioSkusRepository`/`Outlet`'s
  equivalent has never had a dedicated unit test in this codebase (the real
  Dio path is only exercised via widget tests with fakes), consistent with
  existing precedent.
- `s2_stock_screen_test.dart` (new): renders the SKU list with names/categories;
  tapping an unrecorded SKU opens the form dialog; submitting valid values
  closes the dialog and shows that SKU as recorded (checkmark); tapping an
  already-recorded SKU is a no-op (dialog doesn't open).
- `audit_shell_screen_test.dart` (modified): Flutter's `Stepper` mounts every
  step's content simultaneously regardless of which step is current (already
  observed during S1's implementation) — so once `S2StockScreen` is wired in,
  *every* existing test in this file that reaches the `CheckInSucceeded`
  stepper state will build `S2StockScreen`, which calls `skusListProvider`
  and reads local Drift state. All such tests must therefore add two
  overrides to `_appWith(...)`'s `ProviderScope`, not just the new
  visitId-specific one: `skusRepositoryProvider.overrideWithValue(...)` (a
  fake returning an empty or fixed SKU list) and
  `localDbProvider.overrideWithValue(LocalDb(NativeDatabase.memory()))` (a
  fresh in-memory DB per test) — otherwise they'd fall through to the real
  `DioSkusRepository` (network call) and real file-backed `LocalDb` (platform
  channel, throws in widget tests), exactly the class of bug already caught
  once in the S1 router test. One test specifically asserts `S2StockScreen`
  receives the real `visitId` from `CheckInSucceeded` (e.g. by checking a
  rendered SKU name after navigating to step 2 with a fake `SkusRepository`
  returning a known SKU).
- Full `flutter test` suite stays green; `flutter analyze` clean.

## 8. Explicitly out of scope for this spec

- `GET /stock` (see §2)
- SKU management/CRUD (see §2)
- Editing a recorded SKU entry within the same visit (see §2)
- Stepper completion gating (see §2)
- Outlet-specific SKU assignment (see §2)
- Velocity computed from history rather than agent-entered (see §2)
