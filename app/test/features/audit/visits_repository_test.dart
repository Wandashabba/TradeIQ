import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this._result);
  final LocationResult _result;

  @override
  Future<LocationResult> getCurrentPosition() async => _result;
}

class _NoopFlusher implements QueueFlusher {
  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async => null;
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<Map<String, dynamic>?> flush(SyncQueueItem item) async {
    throw Exception('network error');
  }
}

void main() {
  late LocalDb db;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('a check-in within the geofence writes a VisitDraft and enqueues a sync item', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.20400, 28.0473)),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInSucceeded>());

    final drafts = await db.select(db.visitDrafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.first.outletId, 'outlet-1');
    expect(drafts.first.geofencePass, isTrue);

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued, hasLength(1));
    expect(queued.first.entityType, 'visit');
  });

  test('a check-in outside the geofence writes nothing and returns the distance', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.2100, 28.0473)),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInGeofenceFailed>());
    expect((result as CheckInGeofenceFailed).distanceMeters, greaterThan(50));
    expect(await db.select(db.visitDrafts).get(), isEmpty);
    expect(await db.select(db.syncQueueItems).get(), isEmpty);
  });

  test('a denied location permission returns CheckInLocationUnavailable and writes nothing', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationDenied()),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInLocationUnavailable>());
    expect(await db.select(db.visitDrafts).get(), isEmpty);
  });

  test('a LocationError from the location service returns CheckInLocationUnavailable with its message', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationError('gps timeout')),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInLocationUnavailable>());
    expect((result as CheckInLocationUnavailable).message, 'gps timeout');
    expect(await db.select(db.visitDrafts).get(), isEmpty);
  });

  test('a failing sync flush does not fail the check-in', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.20400, 28.0473)),
      syncService: SyncService(db: db, flusher: _ThrowingFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInSucceeded>());
    final queued = await db.select(db.syncQueueItems).get();
    expect(queued.first.synced, isFalse);
  });
}
