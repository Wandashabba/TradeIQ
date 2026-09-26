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

  /// The distance as a **figure**, not a string: near enough is a walk, far
  /// enough is a drive, and that is the only distinction an agent needs from
  /// this number.
  ///
  /// It hands back the value and how many decimals the metric carries, and
  /// the screen renders it through `FigureSlot` — which owns the grouping,
  /// the decimal mark (`1,2 km` in Afrikaans) and the mono face. The old
  /// `distanceLabel` built the string here with `toStringAsFixed(1)` and an
  /// English " m away" glued on, which is two of the things the one formatter
  /// exists to stop.
  ///
  /// Null when the phone will not say where it is. An agent who declined
  /// location gets a sentence, never a wrong number.
  RouteDistance? get distance {
    final metres = distanceMeters;
    return metres == null ? null : RouteDistance.fromMetres(metres);
  }
}

/// How far away a stop is, as a figure the one formatter can set.
class RouteDistance {
  const RouteDistance({
    required this.value,
    required this.decimals,
    required this.kilometres,
  });

  final num value;

  /// The precision the *metric* carries, not the precision this value happens
  /// to have: metres are whole, kilometres get one place.
  final int decimals;

  /// Whether the unit word is kilometres or metres. The word itself is
  /// translated by the screen and passed as a `TiqUnit.worded` — this class
  /// does not own language.
  final bool kilometres;

  /// The one rule for turning metres into a figure: near enough is a walk and
  /// is whole metres, far enough is a drive and is kilometres to one place.
  ///
  /// It lives here rather than in a screen because two screens now read the
  /// same distances — the day's route and the map — and a store that is
  /// "980 m" on one and "1,0 km" on the other is a store the agent has to
  /// think about twice.
  factory RouteDistance.fromMetres(double metres) => metres < 950
      ? RouteDistance(value: metres.round(), decimals: 0, kilometres: false)
      : RouteDistance(value: metres / 1000, decimals: 1, kilometres: true);
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
///
/// It drops the **location fix** too. The distances on this route are from
/// wherever the phone was when the route was last built, and an agent who has
/// just submitted a visit has, by definition, moved since then: a route that
/// refetches its stops but keeps the 07:00 fix says every store is as far away
/// as it was from the depot. Before the fix was shared with the map, this
/// route asked the phone afresh every time it was rebuilt, and this line is
/// what keeps that true. It also means a refusal or a timed-out fix is asked
/// again, so an agent who turns location on gets distances back without
/// restarting the app.
void invalidateRouteProgress(Ref ref) {
  ref.invalidate(currentFixProvider);
  ref.invalidate(beatPlansPageProvider);
  ref.invalidate(beatPlanDetailProvider);
  ref.invalidate(todayRouteProvider);
}

/// How many pages "today's route" will walk before giving up.
///
/// The walk normally stops on its own at the first plan scheduled before
/// today, so this is a backstop against a server that changes the ordering —
/// not the mechanism. Twenty pages of fifty is a thousand plans, which is more
/// than a year of a daily recurrence.
const int _pageCap = 20;

/// Today's route, or null if nobody planned one.
///
/// Null is a real answer, not a loading state. A manager who has not built a
/// beat plan for this agent today has not built one, and the screen says exactly
/// that rather than inventing a route out of the outlet list.
final todayRouteProvider = FutureProvider<TodayRoute?>((ref) async {
  final now = ref.watch(nowProvider)();

  // GET /beatplans already scopes a field agent to their own plans, so "today's
  // plan" is just today's date among them.
  //
  // "Today" is the DEVICE's local date, deliberately not `Client.timezone`
  // (#309): an agent's phone is in the zone their client works in, which is the
  // same calendar the server uses to tick a stop when a visit is submitted. If
  // devices ever roam outside the client's zone, this is the comparison to move
  // onto the client's timezone. Note too that `scheduledDate` is a calendar date
  // stored as UTC midnight, and `.toLocal()` keeps that date only in zones at or
  // east of UTC — a zone west of UTC would need the date read in UTC instead.
  //
  // AND IT IS NOT RELIABLY ON PAGE ONE. This read `beatPlansListProvider` —
  // the first page, and only the first page — so an agent whose plan sat
  // further down was told "No route today" and had no way to know the app had
  // simply stopped looking. The server orders plans **descending by scheduled
  // date** and recurrence creates them ahead of time, so a daily plan set up
  // for a year puts three hundred future dates above today's.
  //
  // The walk is bounded by the data rather than by a guess: the list is
  // sorted, so the first plan scheduled *before* today proves today's is not
  // further down, and the loop stops there. [_pageCap] is a backstop against a
  // server that ever changes that order, not the mechanism.
  BeatPlan? todays;
  String? cursor;
  var pages = 0;
  final repo = ref.read(beatPlansRepositoryProvider);
  final today = DateTime(now.year, now.month, now.day);
  outer:
  while (pages < _pageCap) {
    final page = pages == 0
        ? await ref.watch(beatPlansPageProvider.future)
        : await repo.listBeatPlans(cursor: cursor);
    pages++;
    for (final plan in page.data) {
      final scheduled = DateTime.tryParse(plan.scheduledDate)?.toLocal();
      if (scheduled == null) continue;
      final day = DateTime(scheduled.year, scheduled.month, scheduled.day);
      if (day == today) {
        todays = plan;
        break outer;
      }
      // Sorted newest first: once the list is past today, today is not in it.
      if (day.isBefore(today)) break outer;
    }
    cursor = page.nextCursor;
    if (cursor == null) break;
  }
  if (todays == null) return null;

  final detail = await ref.watch(beatPlanDetailProvider(todays.id).future);
  final outlets = await ref.watch(outletsListProvider.future);
  final byId = {for (final outlet in outlets) outlet.id: outlet};

  // Where the phone is, if it will say. A refusal is not an error here: the
  // route still works, it just cannot tell them how far away anything is.
  // Through `currentFixProvider`, not the service directly: the map of the
  // agent's stores reads the same fix, and a phone that takes fifteen seconds
  // to see the sky should not take them once per screen. That provider keeps
  // its answer until somebody drops it — `invalidateRouteProgress` does, so a
  // rebuilt route is a re-asked phone.
  final position = await ref.watch(currentFixProvider.future);
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
