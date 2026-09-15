import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';

/// Counts reads so a test can tell a cached answer from a fresh fetch.
class _CountingBeatPlansRepository implements BeatPlansRepository {
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
    return const BeatPlanDetail(
      plan: _plan,
      stops: [],
      stopsTotal: 0,
      stopsVisited: 0,
      adherenceRate: 0,
    );
  }

  @override
  Future<void> markStopVisited(String planId, String stopId, bool visited) async {}

  @override
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  }) async => _plan;
}

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

  setUp(() async {
    final db = LocalDb(NativeDatabase.memory());
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

  test('a submitted visit reaching the server refetches the beat plans (#52)', () async {
    expect(repo.listCalls, 1);
    expect(repo.detailCalls, 1);

    container.read(syncServiceProvider).onItemSynced!(_synced('visit_submit'));
    await container.read(beatPlansListProvider.future);
    await container.read(beatPlanDetailProvider('bp1').future);

    expect(repo.listCalls, 2);
    expect(repo.detailCalls, 2);
  });

  test('other captures syncing leave the cached route alone', () async {
    container.read(syncServiceProvider).onItemSynced!(_synced('stock'));
    await container.read(beatPlansListProvider.future);
    await container.read(beatPlanDetailProvider('bp1').future);

    expect(repo.listCalls, 1);
    expect(repo.detailCalls, 1);
  });
}
