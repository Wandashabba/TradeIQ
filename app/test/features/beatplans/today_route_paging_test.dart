import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart'
    show nowProvider;
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

/// TODAY'S ROUTE IS NOT RELIABLY ON PAGE ONE.
///
/// `GET /beatplans` is ordered **descending by scheduled date**, and
/// `createBeatPlan` takes a `recurrence` — so a daily plan set up for a year
/// puts three hundred future-dated plans above today's. The provider read the
/// first page and only the first page, found no plan for today, and returned
/// null. The screen then said "No route today" to an agent who had one, with
/// nothing on screen admitting the app had simply stopped looking.
///
/// The walk is bounded by the data rather than by a guess: the list is sorted,
/// so the first plan scheduled *before* today proves today's is not further
/// down. These tests hold both halves — that it walks, and that it stops.
void main() {
  final now = DateTime(2026, 9, 26, 9);

  BeatPlan plan(String id, DateTime date) => BeatPlan(
    id: id,
    name: 'Plan $id',
    status: 'planned',
    scheduledDate:
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
  );

  late _PagedBeatPlans repo;
  late ProviderContainer container;
  late LocalDb db;

  Future<TodayRoute?> route() async {
    db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(db),
        beatPlansRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => now),
        outletsRepositoryProvider.overrideWithValue(_NoOutlets()),
      ],
    );
    addTearDown(container.dispose);
    return container.read(todayRouteProvider.future);
  }

  test('today’s plan is found when it sits past the first page', () async {
    repo = _PagedBeatPlans(<List<BeatPlan>>[
      // A year of a daily recurrence, newest first: every one of these is in
      // the future, so none of them is today and the walk must go on.
      <BeatPlan>[
        for (var i = 30; i > 0; i--)
          plan('future$i', now.add(Duration(days: i))),
      ],
      <BeatPlan>[
        plan('today', now),
        plan('old', now.subtract(const Duration(days: 1))),
      ],
    ]);

    final found = await route();
    expect(found, isNotNull);
    expect(found!.planName, 'Plan today');
    expect(repo.cursorsAsked, <String?>[null, 'page-1']);
  });

  test(
    'it stops at the first plan older than today, not at the last page',
    () async {
      repo = _PagedBeatPlans(<List<BeatPlan>>[
        <BeatPlan>[
          plan('future', now.add(const Duration(days: 2))),
          // Sorted descending, so nothing below this can be today.
          plan('old', now.subtract(const Duration(days: 1))),
        ],
        <BeatPlan>[plan('today', now)],
      ]);

      expect(await route(), isNull);
      expect(
        repo.cursorsAsked,
        <String?>[null],
        reason: 'the sort is the bound — a second page here is wasted signal',
      );
    },
  );

  test('no plan anywhere is still a real null, not a loading state', () async {
    repo = _PagedBeatPlans(<List<BeatPlan>>[
      <BeatPlan>[plan('future', now.add(const Duration(days: 3)))],
      <BeatPlan>[plan('further', now.add(const Duration(days: 4)))],
    ]);

    expect(await route(), isNull);
    // Both pages, and then the server stopped sending a cursor.
    expect(repo.cursorsAsked, <String?>[null, 'page-1']);
  });
}

/// Pages, newest scheduled date first, exactly as the server orders them.
class _PagedBeatPlans implements BeatPlansRepository {
  _PagedBeatPlans(this.pages);

  final List<List<BeatPlan>> pages;
  final List<String?> cursorsAsked = <String?>[];

  @override
  Future<PaginatedResponse<BeatPlan>> listBeatPlans({String? cursor}) async {
    cursorsAsked.add(cursor);
    final index = cursor == null ? 0 : int.parse(cursor.split('-').last);
    return PaginatedResponse<BeatPlan>(
      data: pages[index],
      nextCursor: index + 1 < pages.length ? 'page-${index + 1}' : null,
    );
  }

  @override
  Future<BeatPlanDetail> getBeatPlan(String id) async => BeatPlanDetail(
    plan: pages.expand((p) => p).firstWhere((p) => p.id == id),
    stops: const <BeatPlanStop>[],
    stopsTotal: 0,
    stopsVisited: 0,
    adherenceRate: 0,
  );

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
  }) async => throw UnimplementedError();
}

class _NoOutlets implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async =>
      const PaginatedResponse<Outlet>(data: <Outlet>[], nextCursor: null);

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
