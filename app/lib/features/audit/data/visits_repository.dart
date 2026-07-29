import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/geo/geofence.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/human_error.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

sealed class CheckInResult {}

class CheckInSucceeded extends CheckInResult {
  CheckInSucceeded(this.visitId);
  final String visitId;
}

class CheckInGeofenceFailed extends CheckInResult {
  CheckInGeofenceFailed(this.distanceMeters);
  final double distanceMeters;
}

class CheckInLocationUnavailable extends CheckInResult {
  CheckInLocationUnavailable(this.message);
  final String message;
}

/// The check-in could not be started for a reason that is not the agent's
/// fault and not about where they are standing — the local database refusing
/// to open, a plugin channel error, a bug.
///
/// It exists so that "this failed" is a *result* the screen must handle rather
/// than an exception it can forget to catch. The distinction matters: an
/// uncaught failure here renders as the locating radar, which tells the agent
/// the app is still trying when it has already given up.
class CheckInFailed extends CheckInResult {
  CheckInFailed(this.message);
  final String message;
}

abstract class VisitsRepository {
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  });

  /// Marks the visit submitted locally and queues the submit for sync
  /// (POST /visits/:remoteId/submit, resolved once the visit has synced).
  Future<void> submitVisit(String visitDraftId);
}

class DriftVisitsRepository implements VisitsRepository {
  DriftVisitsRepository({
    required this.db,
    required this.locationService,
    required this.syncService,
    this.flushTimeout = _defaultFlushTimeout,
  });

  final LocalDb db;
  final LocationService locationService;
  final SyncService syncService;

  /// How long a check-in or submit will wait for the outbox to drain before
  /// carrying on without it.
  ///
  /// The flush is already best-effort — the work is on disk and queued before
  /// it starts. What this bounds is the *waiting*: `flushPending` walks the
  /// whole queue one item at a time, so a backlog serialises Dio's per-request
  /// timeouts and the agent stands at the door of the shop watching a spinner
  /// for something that was never theirs to wait for.
  final Duration flushTimeout;

  static const _defaultFlushTimeout = Duration(seconds: 10);

  static const _uuid = Uuid();

  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async {
    try {
      final locationResult = await locationService.getCurrentPosition();

      return switch (locationResult) {
        LocationDenied() => CheckInLocationUnavailable(
          'Location permission denied',
        ),
        LocationError(:final message) => CheckInLocationUnavailable(message),
        LocationGranted(:final lat, :final lng) => await _checkInAt(
          outletId,
          outletLat,
          outletLng,
          lat,
          lng,
        ),
      };
    } catch (error, stack) {
      // The agent gets the app's one voice; the detail goes to the log, which
      // is where a database-open failure or a channel error is actually
      // diagnosable. Returning rather than rethrowing is the point — see
      // [CheckInFailed].
      debugPrint('Check-in failed for outlet $outletId: $error\n$stack');
      return CheckInFailed(humanErrorMessage(error));
    }
  }

  /// Drains the outbox without letting it become something the agent waits on.
  Future<void> _flushBestEffort() async {
    try {
      await syncService.flushPending().timeout(flushTimeout);
    } catch (_) {
      // Best-effort: the work is already saved locally and queued, so a failed
      // or slow flush just means it stays queued for the next attempt.
    }
  }

  Future<CheckInResult> _checkInAt(
    String outletId,
    double outletLat,
    double outletLng,
    double lat,
    double lng,
  ) async {
    final distance = haversineDistanceMeters(
      Coordinates(lat: outletLat, lng: outletLng),
      Coordinates(lat: lat, lng: lng),
    );
    if (distance > defaultGeofenceRadiusMeters) {
      return CheckInGeofenceFailed(distance);
    }

    final id = _uuid.v4();
    final checkinTs = DateTime.now();
    await db.transaction(() async {
      await db
          .into(db.visitDrafts)
          .insert(
            VisitDraftsCompanion.insert(
              id: id,
              outletId: outletId,
              checkinTs: checkinTs,
              checkinLat: lat,
              checkinLng: lng,
              geofencePass: true,
            ),
          );
      await db.enqueue(
        entityType: 'visit',
        entityId: id,
        payloadJson: jsonEncode({
          'outletId': outletId,
          'lat': lat,
          'lng': lng,
          'checkinTs': checkinTs.toUtc().toIso8601String(),
          'geofencePass': true,
        }),
      );
    });

    await _flushBestEffort();

    return CheckInSucceeded(id);
  }

  @override
  Future<void> submitVisit(String visitDraftId) async {
    await db.transaction(() async {
      await (db.update(db.visitDrafts)..where((t) => t.id.equals(visitDraftId)))
          .write(const VisitDraftsCompanion(status: Value('submitted')));
      await db.enqueue(
        entityType: 'visit_submit',
        entityId: _uuid.v4(),
        payloadJson: jsonEncode({
          'visitDraftId': visitDraftId,
          // Stamped NOW, on the device — the moment the agent actually
          // finished, not whenever the outbox happens to flush. Dwell time
          // is only meaningful measured on one clock, and this is the same
          // clock that produced checkinTs (#101).
          'submittedAtClient': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      // Ask the server to score it. This used to happen only if the agent went
      // into the Score section and tapped "Finalize" — so a visit submitted
      // without opening that screen was never scored at all, and the outcome
      // screen would wait forever for a scorecard nobody had asked for.
      //
      // Queued after the submit (the outbox flushes in id order) so the visit
      // is already `submitted` when the server scores it.
      await db.enqueue(
        entityType: 'scorecard',
        entityId: _uuid.v4(),
        payloadJson: jsonEncode({'visitDraftId': visitDraftId}),
      );
    });

    await _flushBestEffort();
  }
}

final visitsRepositoryProvider = Provider<VisitsRepository>(
  (ref) => DriftVisitsRepository(
    db: ref.read(localDbProvider),
    locationService: ref.read(locationServiceProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);
