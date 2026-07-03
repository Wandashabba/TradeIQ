# Local-to-Remote Visit ID Reconciliation — Design Spec

Date: 2026-07-03
Status: Approved

## 1. Purpose

Fix a bug found during manual end-to-end verification of the S2 (stock/availability)
feature: every audit-section record that references "this visit" (starting with
`VisitStock`, and every S3–S10 module to come) silently and permanently fails to
sync to the backend, because it's given the wrong ID.

`VisitsRepository.checkIn()` returns a **client-generated local UUID** (the primary
key of the local `VisitDrafts` row) as `CheckInSucceeded.visitId` — not the real
`Visit.id` that Postgres assigns when `POST /visits` creates the row. Nothing
consumed that ID for a second network call until S2's `StockRepository` needed to
send `POST /stock` with a `visitId` the backend could actually look up. The backend
correctly rejects the bogus ID with 404, `HttpQueueFlusher` throws, `SyncService`
catches it (per the existing per-item isolation fix) and leaves the item queued
forever — with zero visibility, since the local Drift write (and the UI checkmark)
always succeeds regardless of sync outcome.

Confirmed via live inspection: a real check-in's backend `Visit.id` was
`2dc3e038-...`, but the corresponding local sync-queue's stock payload referenced
`visitId: fd41ff96-...` (the local draft ID) — completely different values.

## 2. Scope

In scope:
- A `remoteId` column on `VisitDrafts`, populated once the visit's own sync succeeds.
- `SyncService.flushPending()` resolving any child item's `visitId` (read from its
  JSON payload) from local → remote before sending, generically — not hardcoded to
  `'stock'`, so every future S3–S10 module gets this for free without touching
  `SyncService` again.
- Skipping (not failing) a child item whose parent hasn't synced yet, leaving it
  queued for the next `flushPending()` call.
- Deterministic FIFO ordering of the pending-items query, so a visit enqueued
  before its children is always attempted before them.

Explicitly out of scope (deferred, not part of this change):
- A proactive background sync/retry driver — already deferred per the S1 spec;
  this fix only makes an *attempted* sync succeed, it doesn't add new triggers
  for when syncing is attempted.
- Any change to `VisitsRepository`, `StockRepository`, `S2StockScreen`, or
  `AuditShellScreen` — none of them are wrong today. They all consistently use
  the local ID, which is exactly correct for local storage and UI purposes. The
  bug is entirely that the sync layer forwarded that local ID to the backend
  verbatim instead of resolving it first, so the fix is fully contained to the
  sync layer.
- Retroactively repairing already-stuck local queue items created before this
  fix existed (e.g., from manual testing) — their parent visit's own sync-queue
  item is already marked `synced`, so `remoteId` can never be backfilled for
  them automatically. This is acceptable to leave as dev-data debris; redoing
  the flow after this fix ships demonstrates the corrected behavior.
- Any `remoteId`-style column on `StockDrafts` or future section tables —
  nothing references a stock (or S3–S10) record's ID as a foreign key, so only
  the visit needs this treatment.

## 3. Schema change

`app/lib/core/storage/tables.dart` — add to `VisitDrafts`:

```dart
class VisitDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get outletId => text()();
  TextColumn get status => text().withDefault(const Constant('in_progress'))();
  DateTimeColumn get checkinTs => dateTime()();
  RealColumn get checkinLat => real()();
  RealColumn get checkinLng => real()();
  BoolColumn get geofencePass => boolean()();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`app/lib/core/storage/local_db.dart` — `schemaVersion` bumps from 2 to 3 (still no
migration strategy needed; no shipped installs).

## 4. Sync layer changes

`app/lib/core/sync/sync_service.dart`:

**`QueueFlusher`'s contract widens** so callers can read back a server-assigned ID:

```dart
abstract class QueueFlusher {
  Future<Map<String, dynamic>?> flush(SyncQueueItem item);
}
```

**`HttpQueueFlusher.flush()`** returns the decoded response body for `'visit'`
(where the backend-assigned `id` is needed downstream), and `null` for `'stock'`
and any other type (nothing currently needs their response bodies):

```dart
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
```

**`SyncService.flushPending()`** gains the resolve-then-flush-then-capture sequence,
applied generically to any non-`'visit'` item whose payload has a `visitId` key:

```dart
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
          continue; // parent visit hasn't synced yet — retry on the next flushPending() call
        }
        payload['visitId'] = parent!.remoteId;
        payloadJson = jsonEncode(payload);
      }
    }

    Map<String, dynamic>? response;
    try {
      response = await flusher.flush(item.copyWith(payloadJson: payloadJson));
    } catch (_) {
      // One item's failure must not block the rest of the queue.
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
```

Note `item.copyWith(payloadJson: payloadJson)` is passed to `flusher.flush(...)`
rather than mutating `item` itself — the resolved payload is only used for the
outgoing request, not persisted back to `SyncQueueItems` (the stored payload
keeps the local ID, which is fine since it's re-resolved fresh on every attempt
in case `remoteId` wasn't available on an earlier pass).

## 5. Testing

`app/test/core/sync/sync_service_test.dart`:
- Update the existing `HttpQueueFlusher` tests for the new `Future<Map<String, dynamic>?>`
  return type (mechanical — `_FakeAdapter`'s `'{}'` response body already decodes
  to an empty map without changes).
- New: a child item (`entityType: 'stock'`, payload containing `visitId` pointing
  at a `VisitDrafts` row with `remoteId: null`) is skipped — assert the flusher's
  `flush()` is never called for it, and it remains `synced: false`.
- New: once that `VisitDrafts` row's `remoteId` is set, a subsequent `flushPending()`
  call resolves and sends the child — assert the flusher receives the *remote* ID
  in its payload, not the local one, and the item ends up `synced: true`.
- New: a successful `'visit'` flush (fake flusher returning `{'id': 'remote-id-1'}`)
  writes `'remote-id-1'` into the matching `VisitDrafts.remoteId`.
- Full `flutter test` suite stays green; `flutter analyze` clean.

## 6. Explicitly out of scope for this spec

- Background/proactive sync retry driver (see §2)
- Changes to `VisitsRepository`, `StockRepository`, `S2StockScreen`, `AuditShellScreen` (see §2)
- Retroactive repair of already-stuck local queue items (see §2)
- `remoteId` columns on any table other than `VisitDrafts` (see §2)
