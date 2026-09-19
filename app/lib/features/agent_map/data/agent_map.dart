/// WHERE THE AGENT'S STORES ARE — the view model behind the Map tab.
///
/// The list answers *what is next*; this answers *where am I, and what is
/// near me*. It is built from three reads and nothing else:
///
/// 1. **today's route** (`todayRouteProvider`) — which stores are on the plan,
///    in which order, and which are already done;
/// 2. **the agent's own outlets** (`myTerritoryOutletsProvider`) — `GET
///    /outlets?mine=true`, narrowed **by the server** from the caller's own
///    token to the territories assigned to them. The app never filters a
///    tenant-wide list down to "mine": a client-side narrowing is a display
///    convention, not a scope, and the one thing a map of somebody's stores
///    must not do is depend on the client to decide whose they are;
/// 3. **one location fix** (`currentFixProvider`) — shared with Today, so a
///    phone that takes fifteen seconds to see the sky takes them once.
///
/// What it deliberately does not do is invent a position. A refused permission,
/// a switched-off radio and a cold fix that never arrives are three different
/// sentences, all of them true, and none of them a distance.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/geofence.dart';
import '../../../core/location/location_service.dart';
import '../../beatplans/data/today_route.dart';
import '../../outlets/data/outlets_repository.dart';

/// What a pin on the map *is*, beyond where it is.
///
/// The four states are drawn as four different silhouettes and named in words
/// on every row and in the sheet — a marker's hue is never the only thing
/// carrying its state (unify §4, non-colour encoding).
enum MapPinState {
  /// A stop on today's route that has already been visited.
  doneToday,

  /// The next stop on today's route: the first one not yet visited.
  nextUp,

  /// On today's route, further down it.
  plannedAhead,

  /// One of the agent's stores, not on today's plan.
  territory,
}

/// Why the phone will not say where it is.
///
/// Null means it did. Each member is a different sentence on screen, because
/// "turn location on" and "wait for a fix" are different actions and a single
/// "location unavailable" tells the agent which of them to take: neither.
enum MapLocationProblem {
  /// The agent said no, or the OS has it switched off for this app.
  denied,

  /// Location services are off on the device.
  servicesOff,

  /// The radio is on and no fix arrived inside the service's window.
  timedOut,

  /// The platform failed in a way we have no code for.
  failed,
}

/// One store on the map, and in the list beneath it.
class MapOutlet {
  const MapOutlet({
    required this.outlet,
    required this.state,
    this.sequence,
    this.distanceMeters,
    this.disputed = false,
  });

  final Outlet outlet;
  final MapPinState state;

  /// Its place on today's route, or null when it is not on it.
  final int? sequence;

  /// Null when the phone would not say where it is. There is no third case:
  /// an agent who declined location gets no distances rather than made-up
  /// ones.
  final double? distanceMeters;

  /// Whether this outlet's coordinates are under dispute (#386).
  ///
  /// **The slot, not the wiring.** #386 — an agent reporting that a pin is in
  /// the wrong place — is being built in parallel and has no field on the wire
  /// yet, so nothing sets this to true outside a test. The marker, the word
  /// and the sheet line are built anyway: the work that lands later is one
  /// assignment in this constructor, not a new state to design under pressure.
  ///
  /// It is deliberately **not** a fifth [MapPinState]: a disputed pin is still
  /// on the route or still in the patch, and losing that would trade one fact
  /// for another.
  final bool disputed;

  /// How far away, as a figure the one formatter can set — or null.
  RouteDistance? get distance {
    final metres = distanceMeters;
    return metres == null ? null : RouteDistance.fromMetres(metres);
  }

  /// Whether the agent is standing inside this store's check-in fence.
  bool get atDoor {
    final metres = distanceMeters;
    return metres != null && metres <= defaultGeofenceRadiusMeters;
  }

  MapOutlet copyWith({MapPinState? state, bool? disputed}) => MapOutlet(
    outlet: outlet,
    state: state ?? this.state,
    sequence: sequence,
    distanceMeters: distanceMeters,
    disputed: disputed ?? this.disputed,
  );
}

/// How many pins the map may draw.
///
/// Tiles and markers are the expensive half of this screen. Every planned stop
/// is drawn whatever happens — a route is a dozen stores, not a hundred — and
/// the territory fills the rest of the budget nearest-first. What is left over
/// is not hidden: [AgentMapView.hidden] is a sentence under the list, never a
/// silent truncation.
const int agentMapMarkerBudget = 60;

/// The agent's stores, ordered the way the screen reads them.
class AgentMapView {
  const AgentMapView({
    required this.pins,
    required this.here,
    required this.problem,
    required this.planName,
  });

  /// Planned stops first, in route order; then the rest of the patch, nearest
  /// first (by name when there is no fix).
  final List<MapOutlet> pins;

  /// Where the phone says it is, or null.
  final Coordinates? here;

  /// Why [here] is null. Null when it is not.
  final MapLocationProblem? problem;

  /// Today's plan, when there is one.
  final String? planName;

  bool get hasLocation => here != null;

  List<MapOutlet> get planned => <MapOutlet>[
    for (final p in pins)
      if (p.state != MapPinState.territory) p,
  ];

  List<MapOutlet> get territory => <MapOutlet>[
    for (final p in pins)
      if (p.state == MapPinState.territory) p,
  ];

  /// What the map actually draws, and what the list actually lists — one
  /// budget, so the two can never disagree about which stores exist.
  List<MapOutlet> get drawn => pins.length <= agentMapMarkerBudget
      ? pins
      : pins.take(agentMapMarkerBudget).toList();

  int get hidden => pins.length - drawn.length;

  /// The store the agent is standing in, if any: the nearest one inside its
  /// own check-in fence that has **not** been visited today.
  ///
  /// This is what makes the nav circle honest. "Check in here" is the expected
  /// next move when *here* is a shop, and a plus sign the rest of the time.
  ///
  /// A stop already done today is never it. An agent who has just submitted a
  /// visit is usually still standing in the shop, and a second check-in there
  /// is not what anybody expects — the store's own sheet demotes it to a ghost
  /// "Check in again" with no amber. Lighting the circle for it would put the
  /// one expected move on a screen whose own sheet says otherwise, and amber on
  /// a screen where nothing is armed. So a visited store is skipped: an
  /// unvisited one in range still wins, and a visited one alone gives null.
  MapOutlet? get atDoor {
    MapOutlet? best;
    for (final pin in pins) {
      if (!pin.atDoor) continue;
      if (pin.state == MapPinState.doneToday) continue;
      if (best == null || pin.distanceMeters! < best.distanceMeters!) {
        best = pin;
      }
    }
    return best;
  }
}

/// The agent's own outlets, scoped **by the server** to their territories.
///
/// Deliberately not [assignedOutletsProvider]: that one is wired to the outlet
/// picker's "only my territories" toggle, which an agent legitimately turns off
/// to check into a store filed under somebody else's patch. A map titled
/// *your stores* that silently became a map of four hundred is a different
/// screen, and one whose marker budget nothing would survive.
final myTerritoryOutletsProvider = FutureProvider<List<Outlet>>((ref) {
  return fetchAllOutlets(ref.read(outletsRepositoryProvider), mine: true);
});

/// The map's view model.
final agentMapProvider = FutureProvider<AgentMapView>((ref) async {
  final route = await ref.watch(todayRouteProvider.future);
  final outlets = await ref.watch(myTerritoryOutletsProvider.future);
  final fix = await ref.watch(currentFixProvider.future);

  final here = fix is LocationGranted
      ? Coordinates(lat: fix.lat, lng: fix.lng)
      : null;
  final problem = switch (fix) {
    LocationGranted() => null,
    LocationDenied() => MapLocationProblem.denied,
    LocationError(kind: LocationErrorKind.servicesDisabled) =>
      MapLocationProblem.servicesOff,
    LocationError(kind: LocationErrorKind.timedOut) =>
      MapLocationProblem.timedOut,
    LocationError() => MapLocationProblem.failed,
  };

  double? metresTo(Outlet outlet) => here == null
      ? null
      : haversineDistanceMeters(
          here,
          Coordinates(lat: outlet.lat, lng: outlet.lng),
        );

  final stops = route?.stops ?? const <RouteStop>[];
  final nextId = route?.next?.outlet.id;
  final planned = <MapOutlet>[
    for (final stop in stops)
      MapOutlet(
        outlet: stop.outlet,
        state: stop.visited
            ? MapPinState.doneToday
            : stop.outlet.id == nextId
            ? MapPinState.nextUp
            : MapPinState.plannedAhead,
        sequence: stop.sequence,
        // Recomputed here rather than taken from `RouteStop.distanceMeters`
        // so every distance on this screen comes from the same fix. Today's
        // route and the map share `currentFixProvider`, so in practice they
        // are the same number; taking it twice from one place is what keeps
        // that true if either screen ever stops sharing.
        distanceMeters: metresTo(stop.outlet),
      ),
  ]..sort((a, b) => (a.sequence ?? 0).compareTo(b.sequence ?? 0));

  final plannedIds = <String>{for (final p in planned) p.outlet.id};
  final rest = <MapOutlet>[
    for (final outlet in outlets)
      if (!plannedIds.contains(outlet.id))
        MapOutlet(
          outlet: outlet,
          state: MapPinState.territory,
          distanceMeters: metresTo(outlet),
        ),
  ];
  rest.sort((a, b) {
    final da = a.distanceMeters;
    final db = b.distanceMeters;
    // No fix means no ordering by distance — and a list half-sorted by a
    // number nobody has is worse than one sorted by name.
    if (da == null || db == null) return a.outlet.name.compareTo(b.outlet.name);
    return da.compareTo(db);
  });

  return AgentMapView(
    pins: <MapOutlet>[...planned, ...rest],
    here: here,
    problem: problem,
    planName: route?.planName,
  );
});
