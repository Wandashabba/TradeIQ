import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

import '../../helpers/routed_app.dart';

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async =>
      const DashboardKpis(
        numericDistribution: 72.5,
        weightedDistribution: 81.3,
        osaPct: 93.1,
        executionScore: 67.8,
        priceCompliancePct: 88.0,
        visibilityCompliancePct: 76.4,
        shareOfShelf: 41.2,
        perfectStoreRate: 55.6,
      );
}

class _ThrowingDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async =>
      throw Exception('network down');
}

class _FakeTerritoriesRepository implements TerritoriesRepository {
  _FakeTerritoriesRepository([this.territories = const []]);

  final List<Territory> territories;

  @override
  Future<List<Territory>> listTerritories() async => territories;

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      const TerritoryCoverage(outletCount: 0, agentCount: 0);

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

class _FakeAlertsRepository implements AlertsRepository {
  _FakeAlertsRepository([this.alerts = const []]);

  final List<AlertItem> alerts;

  @override
  Future<List<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async =>
      alerts;

  @override
  Future<AlertItem> acknowledge(String id) async => throw UnimplementedError();
}

class _FakeTasksRepository implements TasksAdminRepository {
  _FakeTasksRepository([this.tasks = const []]);

  final List<TaskItem> tasks;

  @override
  Future<List<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async =>
      tasks;

  @override
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> verifyTask(String id) async => throw UnimplementedError();
}

class _FakeTrendsRepository implements TrendsRepository {
  _FakeTrendsRepository({this.scorecardPoints = const []});

  final List<TrendPoint> scorecardPoints;

  @override
  Future<List<TrendPoint>> scorecards() async => scorecardPoints;

  @override
  Future<List<TrendPoint>> availability() async => const [
        TrendPoint(period: '2026-W25', value: 92.6),
        TrendPoint(period: '2026-W26', value: 93.1),
      ];

  @override
  Future<List<TrendPoint>> perfectStore() async => const [];
}

AlertItem _alert({required String severity, String metric = 'out_of_stock'}) =>
    AlertItem(
      id: 'a-$severity-$metric',
      metric: metric,
      message: 'msg',
      severity: severity,
      acknowledged: false,
    );

TaskItem _task({required String priority, String status = 'open'}) => TaskItem(
      id: 't-$priority-$status',
      findingType: 'stockout',
      requiredFix: 'restock',
      priority: priority,
      status: status,
      closureVerified: false,
      outletId: 'o1',
    );

/// The dashboard is a desktop console and its body is a lazy [ListView] — at the
/// default 800×600 test surface the KPI strip never gets built. Every test here
/// drives it at a real desktop viewport.
Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1440, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Widget _app({
  DashboardRepository? dashboard,
  List<Territory> territories = const [],
  List<AlertItem> alerts = const [],
  List<TaskItem> tasks = const [],
  List<TrendPoint> scorecards = const [],
}) =>
    routedApp(
      const DashboardShellScreen(),
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(dashboard ?? _FakeDashboardRepository()),
        territoriesRepositoryProvider
            .overrideWithValue(_FakeTerritoriesRepository(territories)),
        alertsRepositoryProvider.overrideWithValue(_FakeAlertsRepository(alerts)),
        tasksAdminRepositoryProvider
            .overrideWithValue(_FakeTasksRepository(tasks)),
        trendsRepositoryProvider.overrideWithValue(
          _FakeTrendsRepository(scorecardPoints: scorecards),
        ),
      ],
    );

void main() {
  testWidgets('leads with the execution score as the hero figure', (tester) async {
    await _pump(tester, _app());

    expect(find.byKey(const ValueKey('kpi-execution-score')), findsOneWidget);
    expect(find.text('67.8'), findsOneWidget);
  });

  testWidgets('renders the KPI strip labels with their values', (tester) async {
    await _pump(tester, _app());

    const expected = {
      'On-shelf availability': '93.1%',
      'Perfect-store rate': '55.6%',
      'Price compliance': '88.0%',
      'Visibility compliance': '76.4%',
      'Share of shelf': '41.2%',
      'Weighted distribution': '81.3%',
      'Numeric distribution': '72.5%',
    };
    // Scoped to the tile: "On-shelf availability" is also a panel title, so a
    // bare find.text would match twice.
    expected.forEach((label, value) {
      final tile = find.byKey(ValueKey('kpi-$label'));
      expect(tile, findsOneWidget, reason: 'tile: $label');
      expect(
        find.descendant(of: tile, matching: find.text(label)),
        findsOneWidget,
        reason: 'label: $label',
      );
      expect(
        find.descendant(of: tile, matching: find.text(value)),
        findsOneWidget,
        reason: 'value: $value',
      );
    });
  });

  testWidgets('counts open alerts by severity in the needs-attention panel', (
    tester,
  ) async {
    await _pump(
      tester,
      _app(
        alerts: [
          _alert(severity: 'critical'),
          _alert(severity: 'critical', metric: 'price_deviation'),
          _alert(severity: 'warning', metric: 'low_scorecard'),
        ],
      )
    );

    expect(
      find.byKey(const ValueKey('attention-critical-alerts')),
      findsOneWidget,
    );
    expect(find.text('Critical alerts open'), findsOneWidget);
    // 2 critical, 1 warning — counts render as plain figures.
    expect(find.text('2'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('reports open tasks rather than an SLA-breach count', (tester) async {
    // GET /tasks returns no dueAt, so the screen must not claim an SLA figure
    // it cannot compute.
    await _pump(
      tester,
      _app(
        tasks: [
          _task(priority: 'critical'),
          _task(priority: 'normal'),
          _task(priority: 'high', status: 'closed'),
        ],
      )
    );

    expect(find.byKey(const ValueKey('attention-open-tasks')), findsOneWidget);
    expect(find.text('Tasks still open'), findsOneWidget);
    expect(find.text('1 at critical priority'), findsOneWidget);
    expect(find.textContaining('SLA'), findsNothing);
  });

  testWidgets('plots the execution-score trend once it loads', (tester) async {
    await _pump(
      tester,
      _app(
        scorecards: const [
          TrendPoint(period: '2026-06-29', value: 74.1),
          TrendPoint(period: '2026-07-06', value: 76.2),
          TrendPoint(period: '2026-07-13', value: 78.4),
        ],
      )
    );

    expect(find.byType(LineChart), findsOneWidget);
    // The delta is derived from the series, not invented: 78.4 − 76.2 = 2.2.
    expect(find.text('▲ 2.2'), findsOneWidget);
  });

  testWidgets('shows an error state with a Retry when the KPI fetch fails', (
    tester,
  ) async {
    await _pump(tester, _app(dashboard: _ThrowingDashboardRepository()));

    expect(find.textContaining('Could not load KPIs'), findsWidgets);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('renders the KPI filter bar (territory + date range)', (tester) async {
    await _pump(tester, _app());

    expect(find.byKey(const ValueKey('filter-territory')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-daterange')), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await _pump(tester, _app());

    await tester.tap(find.byIcon(Icons.logout).first);
    await tester.pump();

    final context = tester.element(find.byType(DashboardShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });
}
