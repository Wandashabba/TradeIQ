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
import '../../../l10n/l10n.dart';

sealed class CheckInResult {}

class CheckInSucceeded extends CheckInResult {
  CheckInSucceeded(this.visitId);
  final String visitId;
}

class CheckInGeofenceFailed extends CheckInResult {
  CheckInGeofenceFailed(this.distanceMeters);
  final double distanceMeters;
}

/// Why the phone could not say where the agent is.
enum CheckInLocationProblem {
  permissionDenied,
  servicesDisabled,
  timedOut,

  /// The location lookup threw; the detail says what with.
  failed,
}

class CheckInLocationUnavailable extends CheckInResult {
  /// A failure described by [message] alone, shown as it is.
  CheckInLocationUnavailable(this.message) : problem = null, detail = null;

  /// A known failure, worded in the agent's language by the screen.
  CheckInLocationUnavailable.because(
    CheckInLocationProblem this.problem, {
    this.detail,
  }) : message = _locationProblemText(problem, detail, englishLocalizations);

  /// The English copy.
  final String message;

  /// Null when this failure has no code — [message] is then all there is.
  final CheckInLocationProblem? problem;

  /// The underlying error, for [CheckInLocationProblem.failed].
  final String? detail;

  /// The copy in [l10n]'s language.
  String messageIn(AppLocalizations l10n) {
    final problem = this.problem;
    return problem == null
        ? message
        : _locationProblemText(problem, detail, l10n);
  }
}

String _locationProblemText(
  CheckInLocationProblem problem,
  String? detail,
  AppLocalizations l10n,
) => switch (problem) {
  CheckInLocationProblem.permissionDenied =>
    l10n.checkInLocationPermissionDenied,
  CheckInLocationProblem.servicesDisabled =>
    l10n.checkInLocationServicesDisabled,
  CheckInLocationProblem.timedOut => l10n.checkInLocationTimedOut,
  CheckInLocationProblem.failed => l10n.checkInLocationFailed(detail ?? ''),
};

/// The check-in could not be started for a reason that is not the agent's
/// fault and not about where they are standing — the local database refusing
/// to open, a plugin channel error, a bug.
///
/// It exists so that "this failed" is a *result* the screen must handle rather
/// than an exception it can forget to catch. The distinction matters: an
/// uncaught failure here renders as the locating radar, which tells the agent
/// the app is still trying when it has already given up.
class CheckInFailed extends CheckInResult {
  CheckInFailed(this.reason);

  /// What kind of failure — the screen words it via [HumanError.message].
  final HumanError reason;

  /// The English copy.
  String get message => reason.message();
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
        LocationDenied() => CheckInLocationUnavailable.because(
          CheckInLocationProblem.permissionDenied,
        ),
        LocationError(:final kind, :final message, :final detail) =>
          switch (kind) {
            LocationErrorKind.servicesDisabled =>
              CheckInLocationUnavailable.because(
                CheckInLocationProblem.servicesDisabled,
              ),
            LocationErrorKind.timedOut => CheckInLocationUnavailable.because(
              CheckInLocationProblem.timedOut,
            ),
            LocationErrorKind.failed => CheckInLocationUnavailable.because(
              CheckInLocationProblem.failed,
              detail: detail,
            ),
            null => CheckInLocationUnavailable(message),
          },
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
      return CheckInFailed(HumanError.of(error));
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
