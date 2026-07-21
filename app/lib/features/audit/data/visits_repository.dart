import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/geo/geofence.dart';
import '../../../core/location/location_service.dart';
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
  });

  final LocalDb db;
  final LocationService locationService;
  final SyncService syncService;

  static const _uuid = Uuid();

  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async {
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

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the visit is already saved locally and queued; a
      // failed flush just means it stays queued for the next attempt.
    }

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

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: submission is recorded locally and queued for sync.
    }
  }
}

final visitsRepositoryProvider = Provider<VisitsRepository>(
  (ref) => DriftVisitsRepository(
    db: ref.read(localDbProvider),
    locationService: ref.read(locationServiceProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);
