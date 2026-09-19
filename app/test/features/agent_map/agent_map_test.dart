import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/agent_map/data/agent_map.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

/// Two points about 1,4 km apart in Soweto, and one 40 m from the first — near
/// enough to be inside a check-in fence.
const _kasi = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.2400,
  lng: 27.8580,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-0221',
  lat: -26.2520,
  lng: 27.8580,
);
const _khumalo = Outlet(
  id: 'o3',
  name: 'Khumalo Superette',
  code: 'KS-0014',
  lat: -26.2600,
  lng: 27.8580,
);

/// Standing at Kasi Corner's door: ~11 m north of it.
final _atKasi = LocationGranted(-26.2399, 27.8580);

class _FakeOutletsRepository implements OutletsRepository {
  _FakeOutletsRepository(this.outlets);

  final List<Outlet> outlets;

  /// Every `mine` flag this repository was asked for. The scope is the
  /// server's, and the only thing the app can get wrong is failing to ask for
  /// it — so the test asserts on the request.
  final List<bool> asked = <bool>[];

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async {
    asked.add(mine);
    return PaginatedResponse<Outlet>(data: outlets, nextCursor: null);
  }

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async => throw UnimplementedError();
}

TodayRoute _route({bool sunriseVisited = false}) => TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: true,
  stops: <RouteStop>[
    const RouteStop(
      sequence: 1,
      outlet: _kasi,
      visited: true,
      distanceMeters: 11,
    ),
    RouteStop(
      sequence: 2,
      outlet: _sunrise,
      visited: sunriseVisited,
      distanceMeters: 1330,
    ),
  ],
);

ProviderContainer _container({
  TodayRoute? route,
  List<Outlet> outlets = const <Outlet>[_kasi, _sunrise, _khumalo],
  LocationResult? fix,
  _FakeOutletsRepository? repo,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      todayRouteProvider.overrideWith((ref) async => route),
      outletsRepositoryProvider.overrideWithValue(
        repo ?? _FakeOutletsRepository(outlets),
      ),
      currentFixProvider.overrideWith((ref) async => fix ?? _atKasi),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('what a store is on this map', () {
    test('the plan decides done, next and later; the patch is the rest',
        () async {
      final view = await _container(route: _route()).read(
        agentMapProvider.future,
      );

      expect(
        view.pins.map((p) => p.outlet.id),
        <String>['o1', 'o2', 'o3'],
        reason: 'planned stops come first, in route order',
      );
      expect(view.pins[0].state, MapPinState.doneToday);
      expect(view.pins[1].state, MapPinState.nextUp);
      expect(view.pins[2].state, MapPinState.territory);
      expect(view.pins[2].sequence, isNull);
    });

    test('a third planned stop is "on today\'s route", not "next"', () async {
      final route = TodayRoute(
        planName: 'p',
        hasLocation: true,
        stops: <RouteStop>[
          const RouteStop(
            sequence: 1,
            outlet: _kasi,
            visited: false,
            distanceMeters: 11,
          ),
          const RouteStop(
            sequence: 2,
            outlet: _sunrise,
            visited: false,
            distanceMeters: 1330,
          ),
        ],
      );
      final view = await _container(route: route).read(agentMapProvider.future);

      expect(view.pins[0].state, MapPinState.nextUp);
      expect(
        view.pins[1].state,
        MapPinState.plannedAhead,
        reason: 'only the first unvisited stop is next up',
      );
    });

    test('no plan at all is not an empty screen — the patch still is one',
        () async {
      final view = await _container().read(agentMapProvider.future);

      expect(view.planned, isEmpty);
      expect(view.territory.length, 3);
      expect(view.pins.every((p) => p.state == MapPinState.territory), isTrue);
    });

    test('a pin under review keeps the state it had', () {
      const pin = MapOutlet(
        outlet: _kasi,
        state: MapPinState.nextUp,
        disputed: true,
      );

      expect(pin.state, MapPinState.nextUp);
      expect(pin.disputed, isTrue);
    });
  });

  group('the scope is the server\'s', () {
    test('the outlets are asked for with ?mine=true', () async {
      final repo = _FakeOutletsRepository(const <Outlet>[_khumalo]);
      await _container(repo: repo).read(agentMapProvider.future);

      expect(
        repo.asked,
        <bool>[true],
        reason:
            'an agent sees their own stores because the server narrowed them, '
            'never because the app filtered a tenant-wide list',
      );
    });
  });

  group('distances, and the refusal to guess one', () {
    test('a fix gives every store a distance, nearest first in the patch',
        () async {
      final view = await _container(route: _route()).read(
        agentMapProvider.future,
      );

      expect(view.hasLocation, isTrue);
      expect(view.problem, isNull);
      expect(view.pins[0].distanceMeters, lessThan(50));
      expect(view.pins[0].distance!.kilometres, isFalse);
      expect(view.pins[1].distance!.kilometres, isTrue);
      expect(view.pins[1].distance!.decimals, 1);
    });

    test('no fix means no distance anywhere, and the patch sorts by name',
        () async {
      final view = await _container(
        outlets: const <Outlet>[_sunrise, _khumalo, _kasi],
        fix: LocationDenied(),
      ).read(agentMapProvider.future);

      expect(view.hasLocation, isFalse);
      expect(view.problem, MapLocationProblem.denied);
      expect(view.pins.every((p) => p.distanceMeters == null), isTrue);
      expect(view.pins.every((p) => p.distance == null), isTrue);
      expect(view.atDoor, isNull, reason: 'nowhere is "here" without a fix');
      expect(
        view.pins.map((p) => p.outlet.name),
        <String>['Kasi Corner Spaza', 'Khumalo Superette', 'Sunrise Spaza'],
        reason:
            'a list half-ordered by a number nobody has is worse than one '
            'ordered by name',
      );
    });

    test('each refusal keeps its own reason', () async {
      Future<MapLocationProblem?> problemFor(LocationResult fix) async =>
          (await _container(fix: fix).read(agentMapProvider.future)).problem;

      expect(await problemFor(LocationDenied()), MapLocationProblem.denied);
      expect(
        await problemFor(
          LocationError('off', kind: LocationErrorKind.servicesDisabled),
        ),
        MapLocationProblem.servicesOff,
      );
      expect(
        await problemFor(LocationError('slow', kind: LocationErrorKind.timedOut)),
        MapLocationProblem.timedOut,
      );
      expect(
        await problemFor(LocationError('boom')),
        MapLocationProblem.failed,
      );
    });
  });

  group('standing in a shop', () {
    test('the nearest store inside its own fence is where you are', () async {
      final view = await _container(route: _route()).read(
        agentMapProvider.future,
      );

      expect(view.atDoor?.outlet.id, 'o1');
    });

    test('a hundred metres away is not standing in it', () async {
      final view = await _container(
        route: _route(),
        fix: LocationGranted(-26.2380, 27.8580),
      ).read(agentMapProvider.future);

      expect(
        view.atDoor,
        isNull,
        reason:
            'the check-in fence is 50 m; anything else would light "check in '
            'here" for a shop across the road',
      );
    });
  });

  group('the marker budget', () {
    test('caps what is drawn, keeps the plan, and says what it hid', () async {
      final many = <Outlet>[
        for (var i = 0; i < agentMapMarkerBudget + 20; i++)
          Outlet(
            id: 'x$i',
            name: 'Store $i',
            code: 'XX-$i',
            // Spread north, so the sort has something to sort by.
            lat: -26.24 - i * 0.001,
            lng: 27.8580,
          ),
      ];
      final view = await _container(route: _route(), outlets: many).read(
        agentMapProvider.future,
      );

      expect(view.drawn.length, agentMapMarkerBudget);
      expect(view.hidden, view.pins.length - agentMapMarkerBudget);
      expect(
        view.drawn.take(2).map((p) => p.outlet.id),
        <String>['o1', 'o2'],
        reason: 'a planned stop is never the thing the budget drops',
      );
      expect(
        view.drawn.skip(2).map((p) => p.distanceMeters!).toList(),
        _ascending,
        reason: 'the patch fills the budget nearest first',
      );
    });

    test('a small patch draws everything and hides nothing', () async {
      final view = await _container(route: _route()).read(
        agentMapProvider.future,
      );

      expect(view.hidden, 0);
      expect(view.drawn.length, view.pins.length);
    });
  });

  group('the distance figure', () {
    test('under 950 m is whole metres, above it is one decimal of a km', () {
      expect(RouteDistance.fromMetres(949).kilometres, isFalse);
      expect(RouteDistance.fromMetres(949).value, 949);
      expect(RouteDistance.fromMetres(949).decimals, 0);
      expect(RouteDistance.fromMetres(1234).kilometres, isTrue);
      expect(RouteDistance.fromMetres(1234).value, closeTo(1.234, 0.0001));
      expect(RouteDistance.fromMetres(1234).decimals, 1);
    });
  });
}

/// Matches a list of numbers that never decreases.
final Matcher _ascending = predicate<List<double>>((values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i] < values[i - 1]) return false;
  }
  return true;
}, 'ascending');
