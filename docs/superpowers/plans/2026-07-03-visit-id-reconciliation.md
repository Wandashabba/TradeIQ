# Local-to-Remote Visit ID Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every audit-section sync silently failing forever because `SyncService` sends a child record's *local* `visitId` to the backend instead of resolving it to the *real* backend `Visit.id` first.

**Architecture:** Add a nullable `remoteId` column to the local `VisitDrafts` Drift table. Widen `QueueFlusher.flush()`'s return type so a successful `'visit'` sync can report back the backend-assigned ID, which `SyncService` writes into `VisitDrafts.remoteId`. Before flushing any other entity type, `SyncService` resolves that entity's payload `visitId` field from local → remote, skipping (not failing) the item if the parent hasn't synced yet. This is fully generic — no entity-type-specific logic beyond "not `'visit'`" — so every future S3–S10 module benefits without touching `SyncService` again.

**Tech Stack:** Flutter, Drift, Dio, flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-03-visit-id-reconciliation-design.md`

---

## Task 1: Add `remoteId` to `VisitDrafts`

**Files:**
- Modify: `app/lib/core/storage/tables.dart`
- Modify: `app/lib/core/storage/local_db.dart`

- [ ] **Step 1: Add the column**

In `app/lib/core/storage/tables.dart`, change the `VisitDrafts` class from:

```dart
class VisitDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get outletId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('in_progress'))();
  DateTimeColumn get checkinTs => dateTime()();
  RealColumn get checkinLat => real()();
  RealColumn get checkinLng => real()();
  BoolColumn get geofencePass => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}
```

to:

```dart
class VisitDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get outletId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('in_progress'))();
  DateTimeColumn get checkinTs => dateTime()();
  RealColumn get checkinLat => real()();
  RealColumn get checkinLng => real()();
  BoolColumn get geofencePass => boolean()();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Bump the schema version**

In `app/lib/core/storage/local_db.dart`, change:

```dart
  @override
  int get schemaVersion => 2;
```

to:

```dart
  @override
  int get schemaVersion => 3;
```

(No migration strategy needed — there are no shipped installs with existing local data to migrate yet.)

- [ ] **Step 3: Regenerate the Drift codegen**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: `local_db.g.dart` is regenerated. `VisitDraft`/`VisitDraftsCompanion` now include a nullable `remoteId` field; `VisitDraftsCompanion.insert(...)`'s existing required parameters are unchanged (the new column is optional, defaulting to `Value.absent()`), so no other file needs to change.

- [ ] **Step 4: Run the existing storage and visits-repository tests to confirm no regression**

Run: `cd app && flutter test test/core/storage/local_db_test.dart test/features/audit/visits_repository_test.dart`
Expected: PASS (1 + 5 = 6 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/storage/tables.dart app/lib/core/storage/local_db.dart app/lib/core/storage/local_db.g.dart
git commit -m "feat(app): add remoteId column to VisitDrafts for sync ID reconciliation"
```

---

## Task 2: Resolve local→remote visit IDs in `SyncService`

**Files:**
- Modify: `app/lib/core/sync/sync_service.dart`
- Modify: `app/test/core/sync/sync_service_test.dart`

- [ ] **Step 1: Replace the test file with the failing tests**

Replace the full contents of `app/test/core/sync/sync_service_test.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

class NoopFlusher implements QueueFlusher {
  int callCount = 0;

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    callCount += 1;
    return null;
  }
}

class _FailFirstFlusher implements QueueFlusher {
  final List<String> attempted = [];

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    attempted.add(item.entityId);
    if (item.entityId == 'visit-1') {
      throw Exception('network error');
    }
    return null;
  }
}

class _RecordingFlusher implements QueueFlusher {
  final List<String> receivedPayloads = [];
  Map<String, dynamic>? Function(SyncQueueItem item)? onFlush;

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    receivedPayloads.add(item.payloadJson);
    return onFlush?.call(item);
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode);
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

SyncQueueItem _visitQueueItem(String payloadJson) => SyncQueueItem(
      id: 1,
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: payloadJson,
      queuedAt: DateTime(2026, 1, 1),
      synced: false,
    );

Future<void> _insertVisitDraft(LocalDb db, {required String id, String? remoteId}) async {
  await db.into(db.visitDrafts).insert(VisitDraftsCompanion.insert(
        id: id,
        outletId: 'outlet-1',
        checkinTs: DateTime(2026, 1, 1),
        checkinLat: 0,
        checkinLng: 0,
        geofencePass: true,
      ));
  if (remoteId != null) {
    await (db.update(db.visitDrafts)..where((t) => t.id.equals(id)))
        .write(VisitDraftsCompanion(remoteId: Value(remoteId)));
  }
}

void main() {
  test('flushPending marks queued items as synced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));

    final flusher = NoopFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.callCount, 1);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });

  test('flushPending does not let one failing item block the rest of the queue', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-2',
      payloadJson: '{}',
    ));

    final flusher = _FailFirstFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.attempted, ['visit-1', 'visit-2']);
    final rows = await db.select(db.syncQueueItems).get();
    final byEntityId = {for (final row in rows) row.entityId: row.synced};
    expect(byEntityId['visit-1'], isFalse);
    expect(byEntityId['visit-2'], isTrue);
  });

  test('writes the response id back to VisitDrafts.remoteId after a successful visit flush', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertVisitDraft(db, id: 'local-visit-1');
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'local-visit-1',
      payloadJson: '{"outletId":"outlet-1"}',
    ));

    final flusher = _RecordingFlusher()..onFlush = (_) => {'id': 'remote-visit-1'};
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    final draft = await (db.select(db.visitDrafts)..where((t) => t.id.equals('local-visit-1'))).getSingle();
    expect(draft.remoteId, 'remote-visit-1');
  });

  test('skips a child item whose parent visit has not synced yet', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertVisitDraft(db, id: 'local-visit-1');
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'stock',
      entityId: 'stock-1',
      payloadJson: '{"visitId":"local-visit-1","skuId":"sku-1"}',
    ));

    final flusher = _RecordingFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.receivedPayloads, isEmpty);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isFalse);
  });

  test("resolves a child item to the parent visit's remote id once it is known", () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertVisitDraft(db, id: 'local-visit-1', remoteId: 'remote-visit-1');
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'stock',
      entityId: 'stock-1',
      payloadJson: '{"visitId":"local-visit-1","skuId":"sku-1"}',
    ));

    final flusher = _RecordingFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.receivedPayloads, ['{"visitId":"remote-visit-1","skuId":"sku-1"}']);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });

  group('HttpQueueFlusher', () {
    test('posts the visit payload to /visits and returns the decoded response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
        ..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      final response = await flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}'));
      expect(response, isA<Map<String, dynamic>>());
    });

    test('posts the stock payload to /stock and succeeds on 2xx', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      await flusher.flush(_visitQueueItem('{"visitId":"v1","skuId":"s1"}').copyWith(entityType: 'stock'));
    });

    test('throws when the backend rejects the check-in with 422', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(422);
      final flusher = HttpQueueFlusher(dio: dio);

      await expectLater(
        flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}')),
        throwsA(isA<DioException>()),
      );
    });

    test('throws UnimplementedError for an unhandled entity type', () async {
      final flusher = HttpQueueFlusher(dio: Dio());
      await expectLater(
        flusher.flush(_visitQueueItem('{}').copyWith(entityType: 'receipt')),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: FAIL to compile — `The return type 'Future<void>' isn't a 'Future<Map<String, dynamic>?>', as required by the method it's overriding` (the test fakes now declare the new return type, but `QueueFlusher`/`HttpQueueFlusher` in the source still declare `Future<void>`)

- [ ] **Step 3: Widen `QueueFlusher`'s contract and implement the resolution logic**

Replace the full contents of `app/lib/core/sync/sync_service.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';

abstract class QueueFlusher {
  Future<Map<String, dynamic>?> flush(SyncQueueItem item);
}

/// Posts queued entities to their matching backend endpoint. Only 'visit'
/// and 'stock' are wired so far — other entity types get their own case as
/// their S3-S10 modules land. Returns the decoded response body so callers
/// (see [SyncService.flushPending]) can capture a backend-assigned ID;
/// entity types with no downstream consumer for their response just return
/// null.
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({Dio? dio}) : _dio = dio ?? api_client.dio;

  final Dio _dio;

  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        final response = await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        return response.data as Map<String, dynamic>?;
      case 'stock':
        await _dio.post('/stock', data: jsonDecode(item.payloadJson));
        return null;
      default:
        throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
    }
  }
}

class SyncService {
  SyncService({required this.db, required this.flusher});

  final LocalDb db;
  final QueueFlusher flusher;

  Future<void> flushPending() async {
    final pending = await (db.select(db.syncQueueItems)
          ..where((tbl) => tbl.synced.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)]))
        .get();

    for (final item in pending) {
      var payloadJson = item.payloadJson;

      if (item.entityType != 'visit') {
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final localVisitId = payload['visitId'] as String?;
        if (localVisitId != null) {
          final parent = await (db.select(db.visitDrafts)
                ..where((tbl) => tbl.id.equals(localVisitId)))
              .getSingleOrNull();
          if (parent?.remoteId == null) {
            // Parent visit hasn't synced yet — retry on the next flushPending() call.
            continue;
          }
          payload['visitId'] = parent!.remoteId;
          payloadJson = jsonEncode(payload);
        }
      }

      Map<String, dynamic>? response;
      try {
        response = await flusher.flush(item.copyWith(payloadJson: payloadJson));
      } catch (_) {
        // One item's failure (network error, terminal rejection, or an
        // unimplemented entity type) must not block the rest of the queue
        // from being attempted — it just stays unsynced for next time.
        continue;
      }

      if (item.entityType == 'visit' && response?['id'] is String) {
        await (db.update(db.visitDrafts)..where((tbl) => tbl.id.equals(item.entityId)))
            .write(VisitDraftsCompanion(remoteId: Value(response!['id'] as String)));
      }

      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(db: ref.read(localDbProvider), flusher: HttpQueueFlusher()),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Run the full app test suite and analyzer to confirm no regressions**

Run: `cd app && flutter analyze && flutter test`
Expected: PASS, no analyzer warnings

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/sync/sync_service.dart app/test/core/sync/sync_service_test.dart
git commit -m "fix(app): resolve local visit IDs to their backend-assigned remoteId before syncing child records"
```

---

## Task 3: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full app suite and analyzer**

Run: `cd app && flutter analyze && flutter test`
Expected: PASS, no analyzer warnings

- [ ] **Step 2: Manual end-to-end verification against the real backend, reproducing the originally-broken scenario**

1. `make dev` (or `cd backend && npm run dev` if Postgres is already up)
2. `cd app && flutter run -d macos`
3. Log in as `agent@demo-fmcg.tradeiq.com` / `demo-password-123`
4. Check in to an outlet you can pass the geofence for (see `docs/superpowers/plans/2026-07-03-s2-stock-availability.md`'s Task 10 for the location-override approach if needed)
5. Navigate to S2, tap the seeded SKU, fill in the form, and save
6. Confirm the checkmark appears (local write still succeeds immediately, as before)
7. Find the local SQLite file and confirm the queued stock item now carries the **real backend** visit ID, not a local one:
   ```bash
   sqlite3 "$HOME/Library/Containers/com.tradeiq.tradeiqApp/Data/Documents/tradeiq_local.sqlite" \
     "select entity_type, entity_id, payload_json, synced from sync_queue_items order by id desc limit 2;"
   ```
   Expected: the `'stock'` row's `synced` column is `1`, and its `payload_json`'s `visitId` matches a real `Visit.id` in Postgres (not the `VisitDrafts.id` used locally).
8. Confirm the row landed in Postgres:
   ```bash
   docker exec tradeiq-postgres-1 psql -U tradeiq -d tradeiq -c \
     "select visit_id, sku_id, units_available, coverage_days_predicted from visit_stock order by id desc limit 1;"
   ```
   Expected: a new row referencing the visit you just created in step 4, with the values you entered in step 5.

- [ ] **Step 3: No commit for this task** — it's verification only; if any step fails, return to the relevant task above and fix it there (with its own commit), don't fix it here.
