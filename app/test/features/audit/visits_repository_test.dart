import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  Future<void> flush(SyncQueueItem item) async {}
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    throw Exception('network error');
  }
}

/// A send that neither succeeds nor fails — a half-open socket, or a captive
/// portal swallowing the request. Dio's timeouts bound one call; a queue with
/// a backlog of them serialises those bounds.
class _HangingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) => Completer<void>().future;
}

void main() {
  late LocalDb db;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
    'a check-in within the geofence writes a VisitDraft and enqueues a sync item',
    () async {
      final repository = DriftVisitsRepository(
        db: db,
        locationService: _FakeLocationService(
          LocationGranted(-26.20400, 28.0473),
        ),
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      );

      final result = await repository.checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );

      expect(result, isA<CheckInSucceeded>());

      final drafts = await db.select(db.visitDrafts).get();
      expect(drafts, hasLength(1));
      expect(drafts.first.outletId, 'outlet-1');
      expect(drafts.first.geofencePass, isTrue);

      final queued = await db.select(db.syncQueueItems).get();
      expect(queued, hasLength(1));
      expect(queued.first.entityType, 'visit');

      final payload =
          jsonDecode(queued.first.payloadJson) as Map<String, dynamic>;
      expect(payload['checkinTs'], isNotNull);
      expect(payload['geofencePass'], isTrue);
    },
  );

  test(
    'a check-in outside the geofence writes nothing and returns the distance',
    () async {
      final repository = DriftVisitsRepository(
        db: db,
        locationService: _FakeLocationService(
          LocationGranted(-26.2100, 28.0473),
        ),
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      );

      final result = await repository.checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );

      expect(result, isA<CheckInGeofenceFailed>());
      expect((result as CheckInGeofenceFailed).distanceMeters, greaterThan(50));
      expect(await db.select(db.visitDrafts).get(), isEmpty);
      expect(await db.select(db.syncQueueItems).get(), isEmpty);
    },
  );

  test(
    'a denied location permission returns CheckInLocationUnavailable and writes nothing',
    () async {
      final repository = DriftVisitsRepository(
        db: db,
        locationService: _FakeLocationService(LocationDenied()),
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      );

      final result = await repository.checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );

      expect(result, isA<CheckInLocationUnavailable>());
      expect(await db.select(db.visitDrafts).get(), isEmpty);
    },
  );

  test(
    'a LocationError from the location service returns CheckInLocationUnavailable with its message',
    () async {
      final repository = DriftVisitsRepository(
        db: db,
        locationService: _FakeLocationService(LocationError('gps timeout')),
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      );

      final result = await repository.checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );

      expect(result, isA<CheckInLocationUnavailable>());
      expect((result as CheckInLocationUnavailable).message, 'gps timeout');
      expect(await db.select(db.visitDrafts).get(), isEmpty);
    },
  );

  test('a failing sync flush does not fail the check-in', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(
        LocationGranted(-26.20400, 28.0473),
      ),
      syncService: SyncService(db: db, flusher: _ThrowingFlusher()),
    );

    final result = await repository.checkIn(
      outletId: 'outlet-1',
      outletLat: -26.2041,
      outletLng: 28.0473,
    );

    expect(result, isA<CheckInSucceeded>());
    final queued = await db.select(db.syncQueueItems).get();
    expect(queued.first.synced, isFalse);
  });

  test(
    'submitVisit marks the draft submitted and enqueues a visit_submit item',
    () async {
      final repository = DriftVisitsRepository(
        db: db,
        locationService: _FakeLocationService(
          LocationGranted(-26.20400, 28.0473),
        ),
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      );
      final result = await repository.checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );
      final visitId = (result as CheckInSucceeded).visitId;

      await repository.submitVisit(visitId);

      final drafts = await db.select(db.visitDrafts).get();
      expect(drafts.firstWhere((d) => d.id == visitId).status, 'submitted');

      final items = await db.select(db.syncQueueItems).get();
      expect(items.where((i) => i.entityType == 'visit_submit'), hasLength(1));
    },
  );

  test('a flush that never returns does not hold the agent at the door', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(
        LocationGranted(-26.20400, 28.0473),
      ),
      syncService: SyncService(db: db, flusher: _HangingFlusher()),
      flushTimeout: const Duration(milliseconds: 20),
    );

    // The visit is already on disk by the time the flush starts; making the
    // agent wait for the network to answer before the visit opens is exactly
    // the spinner this bounds. The outer timeout is what fails the test
    // rather than hanging it if the bound is missing.
    final result = await repository
        .checkIn(
          outletId: 'outlet-1',
          outletLat: -26.2041,
          outletLng: 28.0473,
        )
        .timeout(const Duration(seconds: 5));

    expect(result, isA<CheckInSucceeded>());
    final drafts = await db.select(db.visitDrafts).get();
    expect(drafts, hasLength(1));
  });

  test('a local write that throws surfaces as CheckInFailed, not an exception', () async {
    // A database whose file cannot be opened at all. This is the class of
    // failure the check-in screen used to swallow: the future threw, the
    // post-frame callback that awaited it had no catch, and the agent was
    // left on the locating radar with no error and no way forward.
    final unopenable = LocalDb(
      NativeDatabase(File('/nonexistent-directory/tradeiq_local.sqlite')),
    );
    addTearDown(() async {
      try {
        await unopenable.close();
      } catch (_) {
        // It never opened; closing it is allowed to fail.
      }
    });

    final repository = DriftVisitsRepository(
      db: unopenable,
      locationService: _FakeLocationService(
        LocationGranted(-26.20400, 28.0473),
      ),
      syncService: SyncService(db: unopenable, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(
      outletId: 'outlet-1',
      outletLat: -26.2041,
      outletLng: 28.0473,
    );

    expect(result, isA<CheckInFailed>());
  });
}
