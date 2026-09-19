import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/network/human_error.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this._result);
  final LocationResult _result;

  @override
  Future<LocationResult> getCurrentPosition() async => _result;
}

class _ThrowingLocationService extends LocationService {
  @override
  Future<LocationResult> getCurrentPosition() async =>
      throw StateError('local database unavailable');
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

  group('"the pin is wrong" (#386)', () {
    DriftVisitsRepository repo() => DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.2100, 28.0473)),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    test('a failed fence keeps the position it measured, as evidence', () async {
      final result = await repo().checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );
      final failed = result as CheckInGeofenceFailed;
      expect(failed.lat, -26.2100);
      expect(failed.lng, 28.0473);
      expect(failed.canDisputePin, isTrue);
    });

    test('the claim is not offered beyond the server cap', () {
      expect(
        CheckInGeofenceFailed(25001, lat: -26.2, lng: 28.0).canDisputePin,
        isFalse,
      );
      expect(
        CheckInGeofenceFailed(25000, lat: -26.2, lng: 28.0).canDisputePin,
        isTrue,
      );
      // No position, no evidence, no claim.
      expect(CheckInGeofenceFailed(180).canDisputePin, isFalse);
    });

    test(
      'a disputed check-in is stored and queued as OUTSIDE the fence',
      () async {
        final result = await repo().checkInDisputingPin(
          outletId: 'outlet-1',
          lat: -26.2100,
          lng: 28.0473,
          distanceMeters: 656,
          note: '  Pinned on the depot  ',
        );

        expect(result, isA<CheckInOverridden>());
        final overridden = result as CheckInOverridden;
        expect(overridden.distanceMeters, 656);

        final draft = (await db.select(db.visitDrafts).get()).single;
        expect(draft.id, overridden.visitId);
        // Never a pass. The value is the measurement, not a permission.
        expect(draft.geofencePass, isFalse);
        expect(draft.checkinLat, -26.2100);

        final item = (await db.select(db.syncQueueItems).get()).single;
        expect(item.entityType, 'visit');
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        expect(payload['geofencePass'], isFalse);
        expect(payload['lat'], -26.2100);
        expect(payload['pinDispute'], <String, dynamic>{
          'note': 'Pinned on the depot',
        });
        // The device never sends a distance: the server measures its own, and
        // a client-supplied distance would be a client-supplied verdict.
        expect(payload.containsKey('distanceM'), isFalse);
      },
    );

    test('an empty note sends the claim without one', () async {
      await repo().checkInDisputingPin(
        outletId: 'outlet-1',
        lat: -26.2100,
        lng: 28.0473,
        distanceMeters: 656,
        note: '   ',
      );
      final item = (await db.select(db.syncQueueItems).get()).single;
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      expect(payload['pinDispute'], <String, dynamic>{});
    });

    test('a note past the server limit is cut to it, not refused', () async {
      await repo().checkInDisputingPin(
        outletId: 'outlet-1',
        lat: -26.2100,
        lng: 28.0473,
        distanceMeters: 656,
        note: 'x' * 1500,
      );
      final item = (await db.select(db.syncQueueItems).get()).single;
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      expect(
        (payload['pinDispute'] as Map<String, dynamic>)['note'],
        hasLength(pinDisputeNoteMaxLength),
      );
    });

    test('an ordinary check-in carries no claim', () async {
      final repository = DriftVisitsRepository(
        db: db,
        locationService: _FakeLocationService(
          LocationGranted(-26.20400, 28.0473),
        ),
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      );
      await repository.checkIn(
        outletId: 'outlet-1',
        outletLat: -26.2041,
        outletLng: 28.0473,
      );
      final item = (await db.select(db.syncQueueItems).get()).single;
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      expect(payload.containsKey('pinDispute'), isFalse);
      expect(payload['geofencePass'], isTrue);
    });

    test('a local write that fails is a result, not an exception', () async {
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
      final result = await DriftVisitsRepository(
        db: unopenable,
        locationService: _FakeLocationService(
          LocationGranted(-26.2100, 28.0473),
        ),
        syncService: SyncService(db: unopenable, flusher: _NoopFlusher()),
      ).checkInDisputingPin(
        outletId: 'outlet-1',
        lat: -26.2100,
        lng: 28.0473,
        distanceMeters: 656,
      );
      expect(result, isA<CheckInFailed>());
    });
  });

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

  group('check-in failure codes', () {
    final af = lookupAppLocalizations(const Locale('af'));

    Future<CheckInResult> checkInWith(LocationService service) =>
        DriftVisitsRepository(
          db: db,
          locationService: service,
          syncService: SyncService(db: db, flusher: _NoopFlusher()),
        ).checkIn(
          outletId: 'outlet-1',
          outletLat: -26.2041,
          outletLng: 28.0473,
        );

    test('each location failure maps to its code and copy', () async {
      final cases = <(LocationResult, CheckInLocationProblem, String, String)>[
        (
          LocationDenied(),
          CheckInLocationProblem.permissionDenied,
          'Location permission denied',
          'Toestemming vir ligging is geweier',
        ),
        (
          LocationError(
            'Location services are disabled',
            kind: LocationErrorKind.servicesDisabled,
          ),
          CheckInLocationProblem.servicesDisabled,
          'Location services are disabled',
          'Liggingdienste is afgeskakel',
        ),
        (
          LocationError('late', kind: LocationErrorKind.timedOut),
          CheckInLocationProblem.timedOut,
          'Took too long. Check location is on for TradeIQ, then try again.',
          'Dit het te lank geneem. Maak seker ligging is aan vir TradeIQ, '
              'en probeer weer.',
        ),
        (
          LocationError(
            'Failed to get current location: boom',
            kind: LocationErrorKind.failed,
            detail: 'boom',
          ),
          CheckInLocationProblem.failed,
          'Failed to get current location: boom',
          'Kon nie jou huidige ligging kry nie: boom',
        ),
      ];
      for (final (location, problem, english, afrikaans) in cases) {
        final result =
            await checkInWith(_FakeLocationService(location))
                as CheckInLocationUnavailable;
        expect(result.problem, problem);
        expect(result.message, english);
        expect(result.messageIn(englishLocalizations), english);
        expect(result.messageIn(af), afrikaans);
      }
    });

    test('an uncoded location message is shown as it is', () {
      final result = CheckInLocationUnavailable('gps timeout');
      expect(result.problem, isNull);
      expect(result.messageIn(af), 'gps timeout');
    });

    test('a thrown check-in returns a coded failure, not a sentence', () async {
      final result =
          await checkInWith(_ThrowingLocationService()) as CheckInFailed;
      expect(result.reason, HumanError.generic);
      expect(result.message, 'Something went wrong. Please try again.');
      expect(
        result.reason.message(af),
        'Iets het fout gegaan. Probeer asseblief weer.',
      );
    });
  });

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

  test(
    'a flush that never returns does not hold the agent at the door',
    () async {
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
    },
  );

  test(
    'a local write that throws surfaces as CheckInFailed, not an exception',
    () async {
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
    },
  );
}
