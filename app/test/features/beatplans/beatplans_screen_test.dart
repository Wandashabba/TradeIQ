import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/presentation/beatplans_screen.dart';

import '../../helpers/routed_app.dart';

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
  Future<PaginatedResponse<BeatPlan>> listBeatPlans() async =>
      const PaginatedResponse(data: _plans, nextCursor: null);

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

  @override
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  }) async => _plans.first;
}

Widget _listApp(_FakeBeatPlansRepository repo, {ThemeData? theme}) => routedApp(
  const BeatPlansScreen(),
  theme: theme,
  overrides: [beatPlansRepositoryProvider.overrideWithValue(repo)],
);

Widget _detailApp(_FakeBeatPlansRepository repo, {ThemeData? theme}) =>
    routedApp(
      const BeatPlanDetailScreen(planId: 'bp1'),
      theme: theme,
      overrides: [beatPlansRepositoryProvider.overrideWithValue(repo)],
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

  testWidgets('tapping a stop checkbox records markStopVisited', (
    tester,
  ) async {
    final repo = _FakeBeatPlansRepository();
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('stop-s2')));
    await tester.pumpAndSettle();

    expect(repo.visitedPlanId, 'bp1');
    expect(repo.visitedStopId, 's2');
    expect(repo.visitedValue, true);
  });

  testWidgets('light: plans are glass worklist tiles', (tester) async {
    await tester.pumpWidget(
      _listApp(_FakeBeatPlansRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<GlassPane>(
      find
          .ancestor(
            of: find.text('North Route'),
            matching: find.byType(GlassPane),
          )
          .first,
    );
    expect(tile.kind, GlassKind.tile);
  });

  testWidgets('light: adherence is a figure and each stop a glass tile', (
    tester,
  ) async {
    final repo = _FakeBeatPlansRepository();
    await tester.pumpWidget(_detailApp(repo, theme: AppTheme.light()));
    await tester.pumpAndSettle();

    final adherence = find.byKey(const ValueKey<String>('adherence'));
    final figure = tester.widget<Text>(
      find.descendant(of: adherence, matching: find.text('1 / 2 stops')),
    );
    expect(figure.style?.fontFamily, 'JetBrains Mono');
    expect(find.text('50% adherence'), findsOneWidget);

    final stop = find.byKey(const ValueKey<String>('stop-s2'));
    final tile = tester.widget<GlassPane>(
      find.ancestor(of: stop, matching: find.byType(GlassPane)).first,
    );
    expect(tile.kind, GlassKind.tile);
    expect(tile.blur, isFalse);

    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(repo.visitedStopId, 's2');
    expect(repo.visitedValue, true);
  });
}
