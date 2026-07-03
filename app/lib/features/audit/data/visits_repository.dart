import 'dart:convert';

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
}

class DriftVisitsRepository implements VisitsRepository {
  DriftVisitsRepository({required this.db, required this.locationService, required this.syncService});

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
      LocationDenied() => CheckInLocationUnavailable('Location permission denied'),
      LocationError(:final message) => CheckInLocationUnavailable(message),
      LocationGranted(:final lat, :final lng) => await _checkInAt(outletId, outletLat, outletLng, lat, lng),
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
    if (distance > 50) {
      return CheckInGeofenceFailed(distance);
    }

    final id = _uuid.v4();
    await db.into(db.visitDrafts).insert(VisitDraftsCompanion.insert(
          id: id,
          outletId: outletId,
          checkinTs: DateTime.now(),
          checkinLat: lat,
          checkinLng: lng,
          geofencePass: true,
        ));
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'visit',
          entityId: id,
          payloadJson: jsonEncode({'outletId': outletId, 'lat': lat, 'lng': lng}),
        ));

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the visit is already saved locally and queued; a
      // failed flush just means it stays queued for the next attempt.
    }

    return CheckInSucceeded(id);
  }
}

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) => DriftVisitsRepository(
      db: ref.read(localDbProvider),
      locationService: ref.read(locationServiceProvider),
      syncService: ref.read(syncServiceProvider),
    ));
