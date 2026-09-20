import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart'
    show nowProvider;
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

/// Counts reads so a test can tell a cached answer from a fresh fetch.
class _CountingBeatPlansRepository implements BeatPlansRepository {
  _CountingBeatPlansRepository({this.stops = const <BeatPlanStop>[]});

  final List<BeatPlanStop> stops;
  int listCalls = 0;
  int detailCalls = 0;

  static const _plan = BeatPlan(
    id: 'bp1',
    name: 'Soweto East',
    status: 'planned',
    scheduledDate: '2026-07-10',
  );

  @override
  Future<PaginatedResponse<BeatPlan>> listBeatPlans() async {
    listCalls += 1;
    return const PaginatedResponse(data: [_plan], nextCursor: null);
  }

  @override
  Future<BeatPlanDetail> getBeatPlan(String id) async {
    detailCalls += 1;
    return BeatPlanDetail(
      plan: _plan,
      stops: stops,
      stopsTotal: stops.length,
      stopsVisited: 0,
      adherenceRate: 0,
    );
  }

  @override
  Future<void> markStopVisited(
    String planId,
    String stopId,
    bool visited,
  ) async {}

  @override
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  }) async => _plan;
}

/// A phone that is somewhere else every time it is asked: 0.01° further north
/// on each call, which is 1 112 m from a store on the equator the first time
/// and 2 224 m the second. It can also start out refusing, the way a phone
/// does before the agent turns location on.
class _WalkingLocation extends LocationService {
  _WalkingLocation({this.refuseFirst = false});

  final bool refuseFirst;
  int calls = 0;

  @override
  Future<LocationResult> getCurrentPosition() async {
    calls += 1;
    if (refuseFirst && calls == 1) return LocationDenied();
    return LocationGranted(0.01 * calls, 0);
  }
}

const _storeOnTheEquator = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: 0,
  lng: 0,
);

SyncQueueItem _synced(String entityType) => SyncQueueItem(
  id: 1,
  entityType: entityType,
  entityId: 'item-1',
  payloadJson: '{}',
  queuedAt: DateTime(2026, 7, 10),
  synced: true,
  attempts: 1,
);

void main() {
  late _CountingBeatPlansRepository repo;
  late ProviderContainer container;
  late LocalDb db;

  setUp(() async {
    db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    repo = _CountingBeatPlansRepository();
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(db),
        beatPlansRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    // Something on screen is reading the route — the Today screen, in the app.
    container.listen(beatPlansListProvider, (previous, next) {});
    container.listen(beatPlanDetailProvider('bp1'), (previous, next) {});
    await container.read(beatPlansListProvider.future);
    await container.read(beatPlanDetailProvider('bp1').future);
  });

  test(
    'a submitted visit reaching the server refetches the beat plans (#52)',
    () async {
      expect(repo.listCalls, 1);
      expect(repo.detailCalls, 1);

      container.read(syncServiceProvider).onItemSynced!(
        _synced('visit_submit'),
      );
      await container.read(beatPlansListProvider.future);
      await container.read(beatPlanDetailProvider('bp1').future);

      expect(repo.listCalls, 2);
      expect(repo.detailCalls, 2);
    },
  );

  test('other captures syncing leave the cached route alone', () async {
    container.read(syncServiceProvider).onItemSynced!(_synced('stock'));
    await container.read(beatPlansListProvider.future);
    await container.read(beatPlanDetailProvider('bp1').future);

    expect(repo.listCalls, 1);
    expect(repo.detailCalls, 1);
  });

  // The route's distances are from wherever the phone was when the route was
  // built. Before the fix was shared with the map, every rebuild asked the
  // phone again; the shared fix kept the first answer for the whole session,
  // so a route rebuilt at 14:00 still measured from the 07:00 depot.
  group('a rebuilt route asks the phone where it is again', () {
    late _WalkingLocation location;

    // The `db` is the one `setUp` opened: two in one test is two drift
    // databases on one executor, which drift warns about for good reason.
    Future<ProviderContainer> standUp({bool refuseFirst = false}) async {
      location = _WalkingLocation(refuseFirst: refuseFirst);
      final routed = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(db),
          beatPlansRepositoryProvider.overrideWithValue(
            _CountingBeatPlansRepository(
              stops: const <BeatPlanStop>[
                BeatPlanStop(
                  id: 's1',
                  outletId: 'o1',
                  sequence: 1,
                  visited: false,
                ),
              ],
            ),
          ),
          outletsListProvider.overrideWith(
            (ref) async => const <Outlet>[_storeOnTheEquator],
          ),
          nowProvider.overrideWithValue(() => DateTime(2026, 7, 10, 7)),
          locationServiceProvider.overrideWithValue(location),
        ],
      );
      addTearDown(routed.dispose);
      // The Today screen, in the app.
      routed.listen(todayRouteProvider, (previous, next) {});
      await routed.read(todayRouteProvider.future);
      return routed;
    }

    test(
      'a submitted visit reaching the server re-measures every stop',
      () async {
        final routed = await standUp();
        final morning = (await routed.read(todayRouteProvider.future))!;
        expect(location.calls, 1);
        expect(morning.stops.single.distanceMeters!.round(), 1112);

        routed.read(syncServiceProvider).onItemSynced!(_synced('visit_submit'));
        final afternoon = (await routed.read(todayRouteProvider.future))!;

        expect(
          location.calls,
          2,
          reason:
              'the route was rebuilt, so the phone must be asked again — '
              'a rebuilt route on a cached fix measures from where the agent '
              'was this morning',
        );
        expect(
          afternoon.stops.single.distanceMeters!.round(),
          2224,
          reason: 'the agent has walked; the distance must follow them',
        );
      },
    );

    test(
      'a refusal is not kept: turning location on brings distances back',
      () async {
        final routed = await standUp(refuseFirst: true);
        final before = (await routed.read(todayRouteProvider.future))!;
        expect(before.hasLocation, isFalse);
        expect(before.stops.single.distanceMeters, isNull);

        routed.read(syncServiceProvider).onItemSynced!(_synced('visit_submit'));
        final after = (await routed.read(todayRouteProvider.future))!;

        expect(location.calls, 2);
        expect(
          after.hasLocation,
          isTrue,
          reason:
              'a cached LocationDenied would keep the agent without '
              'distances until they restarted the app',
        );
        expect(after.stops.single.distanceMeters, isNotNull);
      },
    );

    test('other captures syncing do not spend a GPS fix', () async {
      final routed = await standUp();
      routed.read(syncServiceProvider).onItemSynced!(_synced('stock'));
      await routed.read(todayRouteProvider.future);

      expect(location.calls, 1);
    });
  });
}
