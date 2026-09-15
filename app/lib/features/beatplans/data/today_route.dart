import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/geofence.dart';
import '../../../core/location/location_service.dart';
import '../../dashboard/data/dashboard_repository.dart' show nowProvider;
import '../../outlets/data/outlets_repository.dart';
import 'beatplans_repository.dart';

/// One stop on the agent's day.
class RouteStop {
  const RouteStop({
    required this.sequence,
    required this.outlet,
    required this.visited,
    required this.distanceMeters,
  });

  final int sequence;
  final Outlet outlet;
  final bool visited;

  /// Null when we do not know where the phone is. An agent who declined location
  /// gets no distances rather than made-up ones.
  final double? distanceMeters;

  /// "42 m away" / "1.2 km" — near enough is a walk, far enough is a drive, and
  /// that is the only distinction an agent needs from this number.
  String? get distanceLabel {
    final metres = distanceMeters;
    if (metres == null) return null;
    if (metres < 950) return '${metres.round()} m away';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }
}

/// The agent's day, as planned for them.
class TodayRoute {
  const TodayRoute({
    required this.planName,
    required this.stops,
    required this.hasLocation,
  });

  final String planName;
  final List<RouteStop> stops;

  /// Whether the phone knows where it is. Drives whether distances are shown at
  /// all — a route screen with half its distances missing is worse than one with
  /// none.
  final bool hasLocation;

  int get total => stops.length;
  int get doneCount => stops.where((s) => s.visited).length;
  int get remaining => total - doneCount;

  /// The store they are on their way to: the first one not yet visited.
  RouteStop? get next {
    for (final stop in stops) {
      if (!stop.visited) return stop;
    }
    return null;
  }

  bool get isComplete => total > 0 && remaining == 0;
}

/// Drops every cached read the Today route is built from, so the next read
/// fetches the plan and its stops again.
///
/// Called when a submitted visit reaches the server: the server marks the
/// matching stop visited (#52), and Today must show that when the agent comes
/// back to it rather than the route as it was this morning.
void invalidateRouteProgress(Ref ref) {
  ref.invalidate(beatPlansListProvider);
  ref.invalidate(beatPlanDetailProvider);
  ref.invalidate(todayRouteProvider);
}

/// Today's route, or null if nobody planned one.
///
/// Null is a real answer, not a loading state. A manager who has not built a
/// beat plan for this agent today has not built one, and the screen says exactly
/// that rather than inventing a route out of the outlet list.
final todayRouteProvider = FutureProvider<TodayRoute?>((ref) async {
  final now = ref.watch(nowProvider)();
  final plans = await ref.watch(beatPlansListProvider.future);

  // GET /beatplans already scopes a field agent to their own plans, so "today's
  // plan" is just today's date among them.
  BeatPlan? todays;
  for (final plan in plans) {
    final scheduled = DateTime.tryParse(plan.scheduledDate)?.toLocal();
    if (scheduled == null) continue;
    if (scheduled.year == now.year &&
        scheduled.month == now.month &&
        scheduled.day == now.day) {
      todays = plan;
      break;
    }
  }
  if (todays == null) return null;

  final detail = await ref.watch(beatPlanDetailProvider(todays.id).future);
  final outlets = await ref.watch(outletsListProvider.future);
  final byId = {for (final outlet in outlets) outlet.id: outlet};

  // Where the phone is, if it will say. A refusal is not an error here: the
  // route still works, it just cannot tell them how far away anything is.
  final position = await ref.read(locationServiceProvider).getCurrentPosition();
  final here = position is LocationGranted
      ? Coordinates(lat: position.lat, lng: position.lng)
      : null;

  final stops = <RouteStop>[];
  for (final stop in detail.stops) {
    final outlet = byId[stop.outletId];
    // An outlet we cannot name is one we cannot send anyone to. Skipping it is
    // better than a row that says "Unknown store".
    if (outlet == null) continue;
    stops.add(
      RouteStop(
        sequence: stop.sequence,
        outlet: outlet,
        visited: stop.visited,
        distanceMeters: here == null
            ? null
            : haversineDistanceMeters(
                here,
                Coordinates(lat: outlet.lat, lng: outlet.lng),
              ),
      ),
    );
  }
  stops.sort((a, b) => a.sequence.compareTo(b.sequence));

  return TodayRoute(
    planName: todays.name,
    stops: stops,
    hasLocation: here != null,
  );
});
