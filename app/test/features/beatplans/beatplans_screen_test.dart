import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/presentation/beatplans_screen.dart';

const _plans = [
  BeatPlan(
    id: 'bp1',
    name: 'North Route',
    status: 'scheduled',
    scheduledDate: '2026-07-10',
  ),
  BeatPlan(
    id: 'bp2',
    name: 'South Route',
    status: 'in_progress',
    scheduledDate: '2026-07-11',
  ),
];

const _detail = BeatPlanDetail(
  plan: BeatPlan(
    id: 'bp1',
    name: 'North Route',
    status: 'in_progress',
    scheduledDate: '2026-07-10',
  ),
  stops: [
    BeatPlanStop(id: 's1', outletId: 'o1', sequence: 1, visited: true),
    BeatPlanStop(id: 's2', outletId: 'o2', sequence: 2, visited: false),
  ],
  stopsTotal: 2,
  stopsVisited: 1,
  adherenceRate: 0.5,
);

class _FakeBeatPlansRepository implements BeatPlansRepository {
  String? visitedPlanId;
  String? visitedStopId;
  bool? visitedValue;

  @override
  Future<List<BeatPlan>> listBeatPlans() async => _plans;

  @override
  Future<BeatPlanDetail> getBeatPlan(String id) async => _detail;

  @override
  Future<void> markStopVisited(
    String planId,
    String stopId,
    bool visited,
  ) async {
    visitedPlanId = planId;
    visitedStopId = stopId;
    visitedValue = visited;
  }
}

Widget _listApp(_FakeBeatPlansRepository repo) => ProviderScope(
      overrides: [
        beatPlansRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: BeatPlansScreen()),
    );

Widget _detailApp(_FakeBeatPlansRepository repo) => ProviderScope(
      overrides: [
        beatPlansRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: BeatPlanDetailScreen(planId: 'bp1'),
      ),
    );

void main() {
  testWidgets('renders beat plan names once loaded', (tester) async {
    await tester.pumpWidget(_listApp(_FakeBeatPlansRepository()));
    await tester.pumpAndSettle();

    expect(find.text('North Route'), findsOneWidget);
    expect(find.text('South Route'), findsOneWidget);
  });

  testWidgets('detail renders stops and adherence', (tester) async {
    await tester.pumpWidget(_detailApp(_FakeBeatPlansRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('adherence')), findsOneWidget);
    expect(find.text('1 / 2 stops'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stop-s1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stop-s2')), findsOneWidget);
    expect(find.text('Stop 1'), findsOneWidget);
    expect(find.text('Stop 2'), findsOneWidget);
  });

  testWidgets('tapping a stop checkbox records markStopVisited',
      (tester) async {
    final repo = _FakeBeatPlansRepository();
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('stop-s2')));
    await tester.pumpAndSettle();

    expect(repo.visitedPlanId, 'bp1');
    expect(repo.visitedStopId, 's2');
    expect(repo.visitedValue, true);
  });
}
