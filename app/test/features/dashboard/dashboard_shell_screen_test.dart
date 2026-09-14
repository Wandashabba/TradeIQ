import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/core/widgets/delta_pill.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.byTerritory = const []});

  final List<TerritoryDashboardKpis> byTerritory;

  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async => const DashboardKpis(
    numericDistribution: 72.5,
    weightedDistribution: 81.3,
    osaPct: 93.1,
    executionScore: 67.8,
    priceCompliancePct: 88.0,
    visibilityCompliancePct: 76.4,
    shareOfShelf: 41.2,
    perfectStoreRate: 55.6,
  );

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async => byTerritory;
}

/// Serves whatever [score] currently holds, so a test can change the server's
/// answer between fetches and prove the screen went back for it rather than
/// replaying a cached one.
class _MutableDashboardRepository implements DashboardRepository {
  double score = 10.0;

  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async => DashboardKpis(
    numericDistribution: 72.5,
    weightedDistribution: 81.3,
    osaPct: 93.1,
    executionScore: score,
    priceCompliancePct: 88.0,
    visibilityCompliancePct: 76.4,
    shareOfShelf: 41.2,
    perfectStoreRate: 55.6,
  );

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async => const [];
}

/// Which of the dashboard's two fetches this is — the previous window, or the
/// current one.
///
/// The console asks for the current window (`from` = now − 30d) and the equally
/// long one before it (`from` = now − 60d), so any threshold strictly between
/// those two separates them. This used to be the fixed date 2026-06-14, which
/// only sat between them while the calendar cooperated: it stopped doing so on
/// 2026-08-13 and took five tests down with it on a suite that had not changed
/// a line. A midpoint 45 days back is the same discriminator expressed
/// relatively — ~15 days of margin either side, and it cannot go stale.
///
/// Every test here drives the default `last30` range; a fake that must also
/// serve a shorter or longer range would need the threshold derived from that
/// range rather than pinned at 45.
bool _isPreviousWindow(String? from) =>
    from != null &&
    DateTime.parse(
      from,
    ).isBefore(DateTime.now().subtract(const Duration(days: 45)));

/// Returns a LOWER figure for the earlier window, so the console has a real rise
/// to report rather than an invented one.
class _ImprovingDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async {
    // The previous window is the one that ends where the current one starts.
    final isPrevious = _isPreviousWindow(from);
    final osa = isPrevious ? 88.0 : 93.1;
    final perfect = isPrevious ? 60.0 : 55.6;
    final execution = isPrevious ? 76.3 : 78.4;

    return DashboardKpis(
      numericDistribution: 72.5,
      weightedDistribution: 81.3,
      osaPct: osa,
      executionScore: execution,
      priceCompliancePct: 88.0,
      visibilityCompliancePct: 76.4,
      shareOfShelf: 41.2,
      perfectStoreRate: perfect,
    );
  }

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async => const [];
}

/// Every KPI sat exactly 2.0 points lower in the previous window, so all
/// seven tiles have a real rise to wear a pill for.
class _AllRisingDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async {
    final isPrevious = _isPreviousWindow(from);
    final bump = isPrevious ? -2.0 : 0.0;
    return DashboardKpis(
      numericDistribution: 72.5 + bump,
      weightedDistribution: 81.3 + bump,
      osaPct: 93.1 + bump,
      executionScore: 67.8 + bump,
      priceCompliancePct: 88.0 + bump,
      visibilityCompliancePct: 76.4 + bump,
      shareOfShelf: 41.2 + bump,
      perfectStoreRate: 55.6 + bump,
    );
  }

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async => const [];
}

/// Takes a real (fake-clock) 50ms per fetch. Fast fakes resolve before the
/// next frame ever builds, so the `when` loading arm — the remount path that
/// once replayed the hero count-up — never renders; this fake forces it to.
class _SlowDashboardRepository extends _FakeDashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return super.fetchKpis(territoryId: territoryId, from: from, to: to);
  }
}

class _ThrowingDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async => throw Exception('network down');

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async => throw Exception('network down');
}

/// Fails only the by-territory fetch while the KPI fetch keeps succeeding —
/// isolating the territory-scores panel's error handling from the rest of the
/// dashboard. The failure persists until the test flips [failing] off:
/// Riverpod 3 auto-retries a failed provider, so a fail-once fake would be
/// quietly healed by the automatic retry before the error state could ever be
/// asserted.
class _ByTerritoryFailingRepository extends _FakeDashboardRepository {
  _ByTerritoryFailingRepository({required super.byTerritory});

  bool failing = true;

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async {
    if (failing) {
      throw Exception('network down');
    }
    return super.fetchByTerritory(from: from, to: to);
  }
}

class _FakeTerritoriesRepository implements TerritoriesRepository {
  _FakeTerritoriesRepository([this.territories = const []]);

  final List<Territory> territories;

  @override
  Future<PaginatedResponse<Territory>> listTerritories() async =>
      PaginatedResponse(data: territories, nextCursor: null);

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      const TerritoryCoverage(outletCount: 0, agentCount: 0);

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async => throw UnimplementedError();

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

class _FakeAlertsRepository implements AlertsRepository {
  _FakeAlertsRepository([this.alerts = const []]);

  final List<AlertItem> alerts;

  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async => PaginatedResponse(data: alerts, nextCursor: null);

  @override
  Future<AlertItem> acknowledge(String id) async => throw UnimplementedError();
}

class _FakeTasksRepository implements TasksAdminRepository {
  _FakeTasksRepository([this.tasks = const []]);

  final List<TaskItem> tasks;

  @override
  Future<PaginatedResponse<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async => PaginatedResponse(data: tasks, nextCursor: null);

  @override
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  }) async => throw UnimplementedError();

  @override
  Future<TaskItem> verifyTask(String id) async => throw UnimplementedError();
}

class _FakeTrendsRepository implements TrendsRepository {
  _FakeTrendsRepository({
    this.scorecardPoints = const [],
    this.perfectStorePoints = const [],
  });

  final List<TrendPoint> scorecardPoints;
  final List<TrendPoint> perfectStorePoints;

  @override
  Future<List<TrendPoint>> scorecards([
    TrendQuery query = const TrendQuery(),
  ]) async => scorecardPoints;

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) async => const [
    TrendPoint(period: '2026-W25', value: 92.6),
    TrendPoint(period: '2026-W26', value: 93.1),
  ];

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) async => perfectStorePoints;
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
  slaDueAt: DateTime(2026, 8, 1),
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
  List<TrendPoint> perfectStore = const [],
  ThemeData? theme,
}) => routedApp(
  const DashboardShellScreen(),
  theme: theme,
  overrides: [
    dashboardRepositoryProvider.overrideWithValue(
      dashboard ?? _FakeDashboardRepository(),
    ),
    territoriesRepositoryProvider.overrideWithValue(
      _FakeTerritoriesRepository(territories),
    ),
    alertsRepositoryProvider.overrideWithValue(_FakeAlertsRepository(alerts)),
    tasksAdminRepositoryProvider.overrideWithValue(_FakeTasksRepository(tasks)),
    trendsRepositoryProvider.overrideWithValue(
      _FakeTrendsRepository(
        scorecardPoints: scorecards,
        perfectStorePoints: perfectStore,
      ),
    ),
  ],
);

/// The rendered decoration of one range chip — read from the tree, so the
/// assertions hold whatever constants the implementation routes through.
BoxDecoration _chipBox(WidgetTester tester, String range) {
  final box = find.descendant(
    of: find.byKey(ValueKey('range-$range')),
    matching: find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.decoration is BoxDecoration,
    ),
  );
  return tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;
}

Text _chipLabel(WidgetTester tester, String range, String label) =>
    tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('range-$range')),
        matching: find.text(label),
      ),
    );

/// The rendered pill decoration behind the territory trigger — read from the
/// tree so the assertions hold whatever tokens the implementation routes
/// through. Scoped to the trigger's key, so the (identical-looking) menu items
/// never match once the menu is open.
BoxDecoration _territoryPillBox(WidgetTester tester) {
  final box = find.descendant(
    of: find.byKey(const ValueKey('filter-territory')),
    matching: find.byWidgetPredicate(
      (w) => w is Container && w.decoration is BoxDecoration,
    ),
  );
  return tester.widget<Container>(box).decoration! as BoxDecoration;
}

Text _territoryPillLabel(WidgetTester tester, String label) =>
    tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('filter-territory')),
        matching: find.text(label),
      ),
    );

void main() {
  testWidgets('leads with the execution score as the hero figure', (
    tester,
  ) async {
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
      ),
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

  testWidgets('reports open tasks rather than an SLA-breach count', (
    tester,
  ) async {
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
      ),
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
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);

    // The hero trend is the redesign's glass chart: a 2.5px line over an area
    // fill fading brand 28% -> 0%. Config asserted here; the painter owns it.
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.lineWidth, 2.5);
    expect(chart.gradientFill, isTrue);
  });

  testWidgets(
    'the hero delta is measured against the previous window, like the tiles',
    (tester) async {
      await _pump(tester, _app(dashboard: _ImprovingDashboardRepository()));

      // Execution score went 76.3 -> 78.4 across the two windows: +2.1 points.
      // It used to be derived from the last two points of the trend series, which
      // answered a different question from every tile beneath it.
      final hero = find.byKey(const ValueKey('kpi-execution-score'));
      expect(hero, findsOneWidget);
      // +2.1 is the hero's own figure — no tile moved by that amount, so this
      // pill can only be the one beside the score.
      expect(find.widgetWithText(DeltaPill, '▲ 2.1'), findsOneWidget);
    },
  );

  testWidgets('light: the execution score is the dark glass pane', (
    tester,
  ) async {
    await _pump(tester, _app(theme: AppTheme.light()));

    // Lumen Glass puts the headline number on the one heavy pane.
    final hero = find.ancestor(
      of: find.byKey(const ValueKey('kpi-execution-score')),
      matching: find.byWidgetPredicate(
        (w) => w is GlassPane && w.kind == GlassKind.dark,
      ),
    );
    expect(hero, findsOneWidget);

    final score = tester.widget<Text>(find.text('67.8'));
    expect(score.style?.fontSize, 56);
    expect(score.style?.color, Colors.white);
    expect(
      contrastRatio(score.style!.color!, LumenGlass.darkPaneGround),
      greaterThanOrEqualTo(4.5),
      reason: 'the score on the dark pane',
    );
  });

  testWidgets('light: every KPI is drawn against its standard', (tester) async {
    await _pump(tester, _app(theme: AppTheme.light()));

    // The benchmark grid replaces the KPI strip: a word, a figure and a bar
    // with its target tick for each.
    for (final label in [
      'On-shelf availability',
      'Perfect-store rate',
      'Price compliance',
      'Visibility compliance',
      'Share of shelf',
      'Weighted distribution',
    ]) {
      expect(
        find.byKey(ValueKey('benchmark-$label')),
        findsOneWidget,
        reason: label,
      );
    }
    // 55.6% perfect-store rate is > 10 points under 80: a breach, in words.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('benchmark-Perfect-store rate')),
        matching: find.text('BREACH'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dark theme: the score is the same dark glass pane, readable at night', (
    tester,
  ) async {
    // The regression this guards: a pane ground that does not follow the theme
    // under a score that does — near-white on white (~1.1:1), one theme-toggle
    // click away.
    await _pump(tester, _app(theme: AppTheme.dark()));

    final hero = find.ancestor(
      of: find.byKey(const ValueKey('kpi-execution-score')),
      matching: find.byWidgetPredicate(
        (w) => w is GlassPane && w.kind == GlassKind.dark,
      ),
    );
    expect(hero, findsOneWidget);

    final score = tester.widget<Text>(find.text('67.8'));
    expect(score.style?.fontSize, 56);
    expect(score.style?.color, Colors.white);
    // The night dark pane over the brightest the night ground gets: its top
    // stop, lit by the violet bloom.
    final ground = Color.alphaBlend(
      LumenPalette.dark.darkFill,
      Color.alphaBlend(
        LumenPalette.dark.bloomViolet,
        LumenPalette.dark.groundTop,
      ),
    );
    expect(
      contrastRatio(score.style!.color!, ground),
      greaterThanOrEqualTo(4.5),
      reason: 'the score on the night dark pane ($ground)',
    );
  });

  testWidgets(
    'KPI tiles carry a pill and a gradient micro-trend — never an icon',
    (tester) async {
      await _pump(
        tester,
        _app(
          dashboard: _AllRisingDashboardRepository(),
          perfectStore: const [
            TrendPoint(period: '2026-W25', value: 54.2),
            TrendPoint(period: '2026-W26', value: 55.6),
          ],
        ),
      );

      const labels = [
        'On-shelf availability',
        'Perfect-store rate',
        'Price compliance',
        'Visibility compliance',
        'Share of shelf',
        'Weighted distribution',
        'Numeric distribution',
      ];
      for (final label in labels) {
        final tile = find.byKey(ValueKey('kpi-$label'));
        expect(
          find.descendant(of: tile, matching: find.byType(DeltaPill)),
          findsOneWidget,
          reason: 'pill: $label',
        );
        // Every KPI rose, so every pill is the green tone.
        expect(
          tester
              .widget<DeltaPill>(
                find.descendant(of: tile, matching: find.byType(DeltaPill)),
              )
              .tone,
          DeltaTone.good,
          reason: 'tone: $label',
        );
        // The user removed icons from these tiles twice. Never reintroduce one.
        expect(
          find.descendant(of: tile, matching: find.byType(Icon)),
          findsNothing,
          reason: 'icon: $label',
        );
      }

      // Only the two KPIs with a real /trends history may draw a shape (#95) —
      // exactly two on the whole screen, so a fabricated third cannot slip in.
      expect(find.byType(Sparkline), findsNWidgets(2));
      for (final label in const [
        'On-shelf availability',
        'Perfect-store rate',
      ]) {
        final tile = find.byKey(ValueKey('kpi-$label'));
        final spark = find.descendant(
          of: tile,
          matching: find.byType(Sparkline),
        );
        expect(spark, findsOneWidget, reason: 'spark: $label');
        expect(
          tester.widget<Sparkline>(spark).gradient,
          isTrue,
          reason: 'gradient spark: $label',
        );
      }
    },
  );

  testWidgets('shows an error state with a Retry when the KPI fetch fails', (
    tester,
  ) async {
    await _pump(tester, _app(dashboard: _ThrowingDashboardRepository()));

    expect(find.textContaining('Could not load KPIs'), findsWidgets);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets(
    'plots the execution-score-by-territory bar chart from a single by-territory fetch',
    (tester) async {
      // Two territories, and a fetchByTerritory response keyed by
      // Territory.id — proving the chart no longer needs one GET /dashboard
      // call per territory (#97).
      const territories = [
        Territory(id: 't-north', name: 'North', code: 'north'),
        Territory(id: 't-south', name: 'South', code: 'south'),
      ];
      const byTerritory = [
        TerritoryDashboardKpis(
          territoryId: 't-north',
          territoryName: 'North',
          kpis: DashboardKpis(
            numericDistribution: 80,
            weightedDistribution: 80,
            osaPct: 80,
            executionScore: 82.0,
            priceCompliancePct: 80,
            visibilityCompliancePct: 80,
            shareOfShelf: 80,
            perfectStoreRate: 80,
          ),
        ),
        TerritoryDashboardKpis(
          territoryId: 't-south',
          territoryName: 'South',
          kpis: DashboardKpis(
            numericDistribution: 60,
            weightedDistribution: 60,
            osaPct: 60,
            executionScore: 58.5,
            priceCompliancePct: 60,
            visibilityCompliancePct: 60,
            shareOfShelf: 60,
            perfectStoreRate: 60,
          ),
        ),
      ];

      await _pump(
        tester,
        _app(
          territories: territories,
          dashboard: _FakeDashboardRepository(byTerritory: byTerritory),
        ),
      );

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('No territories defined'), findsNothing);
    },
  );

  testWidgets(
    'a failed by-territory fetch shows an error with Retry, not an eternal spinner',
    (tester) async {
      // The regression this guards: the by-territory error arm rendered
      // _InlineLoader, so a failed fetch spun forever — reading as "still
      // loading" — while every sibling panel named the failure and offered a
      // Retry. (An eternal spinner would also hang the pumpAndSettle in
      // _pump, so merely reaching these asserts proves the panel settled.)
      const territories = [
        Territory(id: 't-north', name: 'North', code: 'north'),
      ];
      const byTerritory = [
        TerritoryDashboardKpis(
          territoryId: 't-north',
          territoryName: 'North',
          kpis: DashboardKpis(
            numericDistribution: 80,
            weightedDistribution: 80,
            osaPct: 80,
            executionScore: 82.0,
            priceCompliancePct: 80,
            visibilityCompliancePct: 80,
            shareOfShelf: 80,
            perfectStoreRate: 80,
          ),
        ),
      ];
      final repo = _ByTerritoryFailingRepository(byTerritory: byTerritory);

      await _pump(tester, _app(territories: territories, dashboard: repo));

      expect(find.text('Could not load territory scores'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The server is back. Retry must refetch and recover the chart — a
      // dead-end error state is as much a bug as the spinner was.
      repo.failing = false;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load territory scores'), findsNothing);
      expect(find.byType(BarChart), findsOneWidget);
    },
  );

  testWidgets(
    'territories with no by-territory data show an empty state, not an '
    'eternal spinner',
    (tester) async {
      // The regression this guards (#222): the *data* arm returned
      // _InlineLoader when no summary overlapped the territory list — a real
      // backend state (territories created before any KPI data exists for
      // them). The future had already completed successfully, so that spinner
      // could never resolve. Exactly the anti-pattern the error arm above
      // was fixed for, one branch over.
      const territories = [
        Territory(id: 't-north', name: 'North', code: 'north'),
      ];

      // Territories exist; the by-territory fetch just has nothing for them.
      await _pump(
        tester,
        _app(
          territories: territories,
          dashboard: _FakeDashboardRepository(byTerritory: const []),
        ),
      );

      expect(find.text('No territory scores yet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BarChart), findsNothing);

      // Territories *are* defined — borrowing the sibling copy would be a lie
      // about which of the two empty states this is.
      expect(find.text('No territories defined'), findsNothing);
    },
  );

  testWidgets('renders the KPI filter bar (territory + date range)', (
    tester,
  ) async {
    await _pump(tester, _app());

    expect(find.byKey(const ValueKey('filter-territory')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-daterange')), findsOneWidget);
  });

  testWidgets(
    'territory trigger is an inactive-style pill (light): surface1, hairline, '
    'radiusPill, muted ink label + chevron, AA-safe',
    (tester) async {
      await _pump(tester, _app(theme: AppTheme.light()));

      final box = _territoryPillBox(tester);
      expect(box.color, const Color(0xFFF7F6FB)); // Lumen surface1
      expect(box.borderRadius, BorderRadius.circular(999)); // radiusPill
      expect(
        (box.border! as Border).top.color,
        const Color(0xFFDCD8EA),
      ); // Lumen line

      // Nothing selected → the hint label, in the same muted ink the inactive
      // range pills carry.
      final label = _territoryPillLabel(tester, 'All territories');
      expect(label.style?.color, const Color(0xFF3E3A5C)); // Lumen ink2
      expect(label.style?.fontSize, 12.5);

      // A chevron makes it read as a menu trigger, not a static chip.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('filter-territory')),
          matching: find.byIcon(Icons.expand_more),
        ),
        findsOneWidget,
      );

      // AA, measured from the rendered tree — not the token table.
      expect(
        contrastRatio(label.style!.color!, box.color!),
        greaterThanOrEqualTo(4.5),
        reason: 'trigger label on the surface1 pill',
      );
    },
  );

  testWidgets('territory trigger stays a readable rendered pair in dark', (
    tester,
  ) async {
    await _pump(tester, _app(theme: AppTheme.dark()));

    final box = _territoryPillBox(tester);
    expect(box.color, TiqColors.night.surface1);
    expect(box.borderRadius, BorderRadius.circular(999));
    expect((box.border! as Border).top.color, TiqColors.night.line);

    final label = _territoryPillLabel(tester, 'All territories');
    expect(label.style?.color, TiqColors.night.ink2);
    expect(
      contrastRatio(label.style!.color!, box.color!),
      greaterThanOrEqualTo(4.5),
      reason: 'trigger label on the night surface1 pill',
    );
  });

  testWidgets(
    'territory menu lists All territories + each territory, and selection '
    'flows both ways',
    (tester) async {
      // Territories with no matching by-territory data leaves the scores panel
      // an intentional inline loader (see _TerritoryScoreBars), so this drives
      // the tree with bounded pumps rather than pumpAndSettle. The upshot the
      // assertions rely on: the bar chart never renders, so a territory name
      // appears only inside this menu — nowhere else on the screen.
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          territories: const [
            Territory(id: 't-north', name: 'North', code: 'north'),
            Territory(id: 't-south', name: 'South', code: 'south'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Closed: the trigger shows the hint; the territory names are not painted.
      expect(find.text('North'), findsNothing);
      expect(find.text('South'), findsNothing);

      // Open: All territories + every territory is offered.
      await tester.tap(find.byKey(const ValueKey('filter-territory')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('All territories'), findsWidgets); // trigger + menu item
      expect(find.text('North'), findsOneWidget);
      expect(find.text('South'), findsOneWidget);

      // Select a territory → the filter narrows; the trigger now names it.
      await tester.tap(find.text('North'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        _territoryPillLabel(tester, 'North').style?.color,
        isNotNull,
        reason: 'the trigger reflects the selected territory',
      );

      // Select "All territories" → the filter clears; the hint returns.
      await tester.tap(find.byKey(const ValueKey('filter-territory')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('All territories').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('North'), findsNothing);
      expect(_territoryPillLabel(tester, 'All territories'), isNotNull);

      // The hint label alone is not proof the filter cleared: an unknown/stale
      // id (or a leaked sentinel) falls back to that same label while still
      // riding into the ?territoryId= query. Read the real state — clearing
      // must land territoryId at null, not a sentinel.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardShellScreen)),
      );
      expect(container.read(dashboardFilterProvider).territoryId, isNull);
    },
  );

  testWidgets('range chips (light): the active chip is the dark primary pill', (
    tester,
  ) async {
    await _pump(tester, _app(theme: AppTheme.light()));

    // The default range is 30d, so its chip is the active pill.
    final active = _chipBox(tester, 'last30');
    expect(active.color, const Color(0xFF241F47)); // Lumen primary action
    expect(active.borderRadius, BorderRadius.circular(999));

    final activeLabel = _chipLabel(tester, 'last30', '30d');
    expect(activeLabel.style?.color, Colors.white);
    expect(activeLabel.style?.fontSize, 11);
    expect(activeLabel.style?.fontWeight, FontWeight.w600);

    // Inactive: white ground, hairline (light `line` token) border, muted ink.
    final inactive = _chipBox(tester, 'last7');
    expect(inactive.color, const Color(0xFFF7F6FB)); // Lumen surface1
    expect(inactive.borderRadius, BorderRadius.circular(999));
    expect((inactive.border! as Border).top.color, const Color(0xFFDCD8EA));

    final inactiveLabel = _chipLabel(tester, 'last7', '7d');
    expect(inactiveLabel.style?.color, const Color(0xFF3E3A5C));
    expect(inactiveLabel.style?.fontSize, 11);
    expect(inactiveLabel.style?.fontWeight, FontWeight.w600);

    // AA on both pairs, measured from the rendered tree, not the token table.
    expect(
      contrastRatio(activeLabel.style!.color!, active.color!),
      greaterThanOrEqualTo(4.5),
      reason: 'active label on the brand pill',
    );
    expect(
      contrastRatio(inactiveLabel.style!.color!, inactive.color!),
      greaterThanOrEqualTo(4.5),
      reason: 'inactive label on the white pill',
    );
  });

  testWidgets('range chips tell assistive tech which range is active', (
    tester,
  ) async {
    // The active pill is otherwise announced by nothing but its fill colour —
    // VoiceOver/TalkBack need the selected flag, and every chip must read as
    // a button. (isSemantics is a partial match: the merged node also carries
    // InkWell's tap/focus semantics, which this test has no opinion on.)
    final handle = tester.ensureSemantics();
    await _pump(tester, _app());

    expect(
      tester.getSemantics(find.byKey(const ValueKey('range-last30'))),
      isSemantics(isButton: true, isSelected: true),
    );
    for (final inactive in ['last7', 'last90', 'ytd', 'allTime']) {
      expect(
        tester.getSemantics(find.byKey(ValueKey('range-$inactive'))),
        isSemantics(isButton: true, isSelected: false),
        reason: 'inactive chip: $inactive',
      );
    }

    handle.dispose();
  });

  testWidgets('dark theme: every range pill stays a readable rendered pair', (
    tester,
  ) async {
    // The regression class this guards (Task 1 shipped it once): a hard-coded
    // light ground under theme-following ink. Each pill's text is asserted
    // against its own rendered ground, so the pair travels together.
    await _pump(tester, _app(theme: AppTheme.dark()));

    for (final (range, label) in [('last30', '30d'), ('last7', '7d')]) {
      final ground = _chipBox(tester, range).color;
      expect(ground, isNotNull, reason: 'pill ground: $label');
      expect(
        contrastRatio(_chipLabel(tester, range, label).style!.color!, ground!),
        greaterThanOrEqualTo(4.5),
        reason: '$label on its own pill ground',
      );
    }
    // And the active chip is the night primary action: a bright lavender pill
    // with dark words; the inactive one is the night surface1 pill.
    expect(_chipBox(tester, 'last30').color, TiqColors.night.action);
    expect(
      _chipLabel(tester, 'last30', '30d').style?.color,
      TiqColors.night.onAction,
    );
    expect(_chipBox(tester, 'last7').color, TiqColors.night.surface1);
    expect(
      _chipLabel(tester, 'last7', '7d').style?.color,
      TiqColors.night.ink2,
    );
  });

  testWidgets(
    'attention rows (light): the count in its status tile, bold title, muted subtitle',
    (tester) async {
      await _pump(
        tester,
        _app(
          theme: AppTheme.light(),
          alerts: [
            _alert(severity: 'critical'),
            _alert(severity: 'critical', metric: 'price_deviation'),
            _alert(severity: 'warning', metric: 'low_scorecard'),
          ],
        ),
      );

      final row = find.byKey(const ValueKey('attention-critical-alerts'));

      // Colour-coded leading numeral — the colour is never the only signal;
      // the words beside it name the state.
      final numeral = tester.widget<Text>(
        find.descendant(of: row, matching: find.text('2')),
      );
      // Glass sets the count in its status tile: mono, in the crit ink.
      expect(numeral.style?.fontSize, 15);
      expect(numeral.style?.fontWeight, FontWeight.w600);
      expect(numeral.style?.fontFamily, 'JetBrains Mono');
      expect(numeral.style?.color, const Color(0xFF8C1D17)); // crit ink

      // Title in the mockup's bold weight. (Spec says w650; Inter ships static
      // 400/500/600/700 faces, so w600 is the nearest weight that exists.)
      final title = tester.widget<Text>(
        find.descendant(of: row, matching: find.text('Critical alerts open')),
      );
      expect(title.style?.fontWeight, FontWeight.w600);

      // Muted subtitle under the title, in ink3.
      final subtitle = tester.widget<Text>(
        find.descendant(of: row, matching: find.textContaining('out of stock')),
      );
      expect(subtitle.style?.color, const Color(0xFF5B5F75)); // Lumen ink3
      expect(subtitle.style?.fontSize, 11);

      // The panel's escape hatch keeps its accent (theme primary) treatment.
      expect(find.widgetWithText(TextButton, 'View all'), findsOneWidget);
    },
  );

  testWidgets('tapping logout clears the session', (tester) async {
    await _pump(tester, _app());

    await tester.tap(find.byIcon(Icons.logout).first);
    await tester.pump();

    final context = tester.element(find.byType(DashboardShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });

  testWidgets('a KPI that rose shows a green up arrow, measured not invented', (
    tester,
  ) async {
    await _pump(tester, _app(dashboard: _ImprovingDashboardRepository()));

    // On-shelf availability went 88.0 -> 93.1 across the two windows: +5.1
    // points. The figure comes from a second real request for the preceding
    // window, not from a baseline we made up.
    final tile = find.byKey(const ValueKey('kpi-On-shelf availability'));
    expect(
      find.descendant(of: tile, matching: find.textContaining('5.1')),
      findsOneWidget,
    );
  });

  testWidgets('a KPI that fell shows a red down arrow', (tester) async {
    await _pump(tester, _app(dashboard: _ImprovingDashboardRepository()));

    // Perfect-store rate went 60.0 -> 55.6: a fall of 4.4 points.
    final tile = find.byKey(const ValueKey('kpi-Perfect-store rate'));
    expect(
      find.descendant(of: tile, matching: find.textContaining('4.4')),
      findsOneWidget,
    );
    // A fall wears the red wash — tone follows the sign.
    expect(
      tester
          .widget<DeltaPill>(
            find.descendant(of: tile, matching: find.byType(DeltaPill)),
          )
          .tone,
      DeltaTone.bad,
    );
  });

  testWidgets('with no previous window there is no arrow at all', (
    tester,
  ) async {
    await _pump(tester, _app());

    // The fake returns the same numbers for both windows, so nothing moved —
    // and a 0.0 delta is not movement. No pill is the honest rendering.
    expect(find.byType(DeltaPill), findsNothing);
  });

  group('entrance motion', () {
    // Pumps until the hero score is on screen, using only zero-duration
    // frames — the fakes' futures drain between pumps but the animation clock
    // never advances, so when this returns the entrance is still on its very
    // first frame.
    Future<void> pumpToFirstDataFrame(WidgetTester tester, Widget app) async {
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app);
      for (var i = 0; i < 10; i++) {
        await tester.pump(Duration.zero);
        if (tester.any(find.byKey(const ValueKey('kpi-execution-score')))) {
          return;
        }
      }
      fail('dashboard data never arrived');
    }

    testWidgets(
      'reduced motion: the score is final on its first frame and nothing animates',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );

        await pumpToFirstDataFrame(tester, _app());

        // No count-up frames at all: the final figure IS the first frame.
        expect(find.text('67.8'), findsOneWidget);
        expect(find.text('0.0'), findsNothing);

        // Sibling panels' fetches can still be in flight at this frame, and a
        // LOADING spinner is state, not motion — drain those on the same
        // unadvanced clock, then nothing at all may be animating: any
        // entrance that had started would still be running here.
        for (
          var i = 0;
          i < 10 && tester.any(find.byType(CircularProgressIndicator));
          i++
        ) {
          await tester.pump(Duration.zero);
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // One more zero pump: a reduceMotion-gated Duration.zero implicit
        // animation still owes the scheduler a single (contentless) tick,
        // and this flushes it. A REAL animation cannot be flushed this way —
        // zero elapsed time completes nothing — so the assertion below still
        // catches any entrance that actually ran.
        await tester.pump(Duration.zero);
        expect(tester.hasRunningAnimations, isFalse);

        // And settling is immediate — nothing was ever in flight.
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('the score counts up from zero, once, then goes quiet', (
      tester,
    ) async {
      await pumpToFirstDataFrame(tester, _app());

      // t≈0: mid-count-up, not yet the final figure.
      expect(find.text('0.0'), findsOneWidget);
      expect(find.text('67.8'), findsNothing);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('67.8'), findsOneWidget);

      // One-shot: after settling, extra frames find nothing still animating.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a range change does not replay the count-up', (tester) async {
      // The slow repository is the point: the reload's loading arm really
      // renders, tearing the hero row down and remounting it — the exact path
      // that replays an unlatched entrance. Fast fakes resolve before the
      // loading frame ever builds and would let a replay slip through green.
      // (Zero-duration pumps can't fire its timers, so the initial load has
      // to settle the ordinary way — the spinner keeps frames scheduled,
      // which keeps pumpAndSettle's clock moving.)
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(dashboard: _SlowDashboardRepository()));
      await tester.pumpAndSettle();
      expect(find.text('67.8'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('range-last7')));
      // Walk the reload through: loading frame(s), then both window fetches.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 51));
      await tester.pump(const Duration(milliseconds: 51));
      // Zero-duration pumps from here: a replayed count-up cannot advance on
      // an unadvancing clock, so the final figure could never appear.
      var finalFigureShown = false;
      for (var i = 0; i < 10 && !finalFigureShown; i++) {
        await tester.pump(Duration.zero);
        finalFigureShown = tester.any(find.text('67.8'));
      }
      expect(
        finalFigureShown,
        isTrue,
        reason: 'the reloaded figure must be final on its first data frame',
      );
      expect(find.text('0.0'), findsNothing);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a KPI figure counts up from zero, once, then goes quiet', (
      tester,
    ) async {
      await pumpToFirstDataFrame(tester, _app());

      final tile = find.byKey(const ValueKey('kpi-On-shelf availability'));
      // t≈0: mid-sweep, not yet the final figure. Scoped to the tile — the
      // KPI value string appears only inside this tile.
      expect(
        find.descendant(of: tile, matching: find.text('93.1%')),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.text('0.0%')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.descendant(of: tile, matching: find.text('93.1%')),
        findsOneWidget,
      );

      // One-shot: after settling nothing is still animating.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: a KPI figure is final on its first frame', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pumpToFirstDataFrame(tester, _app());

      final tile = find.byKey(const ValueKey('kpi-On-shelf availability'));
      expect(
        find.descendant(of: tile, matching: find.text('93.1%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text('0.0%')),
        findsNothing,
      );
    });

    testWidgets('a range change does not replay a KPI count-up', (
      tester,
    ) async {
      // Same remount path as the hero's no-replay test: the slow repo's loading
      // arm really renders on a range change, tearing the KPI tiles down and
      // rebuilding them — the exact path that replays an unlatched entrance.
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(dashboard: _SlowDashboardRepository()));
      await tester.pumpAndSettle();

      final tile = find.byKey(const ValueKey('kpi-On-shelf availability'));
      expect(
        find.descendant(of: tile, matching: find.text('93.1%')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('range-last7')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 51));
      await tester.pump(const Duration(milliseconds: 51));
      // Zero-duration pumps: a replayed count-up cannot advance on an
      // unadvancing clock, so the final figure could never re-appear.
      var finalShown = false;
      for (var i = 0; i < 10 && !finalShown; i++) {
        await tester.pump(Duration.zero);
        finalShown = tester.any(
          find.descendant(of: tile, matching: find.text('93.1%')),
        );
      }
      expect(
        finalShown,
        isTrue,
        reason: 'the reloaded KPI figure must be final on its first data frame',
      );
      expect(
        find.descendant(of: tile, matching: find.text('0.0%')),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the hero delta pill waits out its ~450ms delay, then lands', (
      tester,
    ) async {
      await pumpToFirstDataFrame(
        tester,
        _app(dashboard: _ImprovingDashboardRepository()),
      );

      final pill = find.widgetWithText(DeltaPill, '▲ 2.1');
      expect(pill, findsOneWidget);
      double pillOpacity() => tester
          .widget<Opacity>(
            find.ancestor(of: pill, matching: find.byType(Opacity)).first,
          )
          .opacity;

      expect(pillOpacity(), 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(pillOpacity(), 0, reason: 'still inside the 450ms delay');

      await tester.pumpAndSettle();
      expect(pillOpacity(), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('KPI sparklines fade in staggered 40ms apart', (tester) async {
      await pumpToFirstDataFrame(
        tester,
        _app(
          perfectStore: const [
            TrendPoint(period: '2026-W25', value: 54.2),
            TrendPoint(period: '2026-W26', value: 55.6),
          ],
        ),
      );
      // The two trend providers can land a zero-duration frame apart — keep
      // draining (clock still unadvanced) until both sparklines are mounted.
      for (
        var i = 0;
        i < 10 && tester.widgetList(find.byType(Sparkline)).length < 2;
        i++
      ) {
        await tester.pump(Duration.zero);
      }
      expect(find.byType(Sparkline), findsNWidgets(2));

      double sparkOpacity(String label) {
        final spark = find.descendant(
          of: find.byKey(ValueKey('kpi-$label')),
          matching: find.byType(Sparkline),
        );
        return tester
            .widget<Opacity>(
              find.ancestor(of: spark, matching: find.byType(Opacity)).first,
            )
            .opacity;
      }

      // 20ms in: tile 1's fade has begun; tile 2's 40ms offset has not.
      await tester.pump(const Duration(milliseconds: 20));
      expect(sparkOpacity('On-shelf availability'), greaterThan(0));
      expect(
        sparkOpacity('Perfect-store rate'),
        0,
        reason: 'the second tile starts one stagger step later',
      );

      await tester.pumpAndSettle();
      expect(sparkOpacity('On-shelf availability'), 1);
      expect(sparkOpacity('Perfect-store rate'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a scroll round-trip does not replay the entrance', (
      tester,
    ) async {
      // A short window: the dashboard ListView's sliver disposes children
      // scrolled past its cache extent, which is where an unprotected
      // entrance latch would die — and the whole entrance would replay on
      // the way back up.
      tester.view.physicalSize = const Size(900, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('67.8'), findsOneWidget);

      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Sanity: the page really is tall enough to carry the hero past the
      // cache extent — otherwise this test proves nothing.
      expect(scrollable.position.maxScrollExtent, greaterThan(800));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      scrollable.position.jumpTo(0);
      // Zero-duration pumps: a replayed count-up would sit at 0.0 forever on
      // an unadvancing clock.
      for (var i = 0; i < 4; i++) {
        await tester.pump(Duration.zero);
      }
      expect(find.text('0.0'), findsNothing);
      expect(find.text('67.8'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'flipping reduce-motion off mid-session does not play the entrance late',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await pumpToFirstDataFrame(tester, _app());
        await tester.pumpAndSettle();
        expect(find.text('67.8'), findsOneWidget);

        // The manager turns reduced motion off mid-session. The entrance
        // moment is long gone — it must not be performed now.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        for (var i = 0; i < 4; i++) {
          await tester.pump(Duration.zero);
        }
        expect(find.text('0.0'), findsNothing);
        expect(find.text('67.8'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a mid-count-up rebuild cannot cut the entrance short', (
      tester,
    ) async {
      // Pins the mount-time latch in _HeroScore: the refresh below delivers
      // animate:false into the SAME State while the count-up is running
      // (skipLoadingOnRefresh keeps the data arm alive), and the figure must
      // keep counting rather than snap to its final value.
      final repo = _MutableDashboardRepository();
      await pumpToFirstDataFrame(tester, _app(dashboard: repo));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('0.0'), findsNothing);
      expect(find.text('10.0'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('dashboard-refresh')));
      await tester.pump(Duration.zero);
      // Still mid-count — an un-latched wrapper would render 10.0 here.
      expect(find.text('10.0'), findsNothing);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('10.0'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a refreshed value lands directly — no tween toward it', (
      tester,
    ) async {
      // Pins the completed-entrance latch: once the count-up has run, a new
      // value must render as plain text, not animate from the old figure.
      final repo = _MutableDashboardRepository();
      await pumpToFirstDataFrame(tester, _app(dashboard: repo));
      await tester.pumpAndSettle();
      expect(find.text('10.0'), findsOneWidget);

      repo.score = 42.0;
      await tester.tap(find.byKey(const ValueKey('dashboard-refresh')));
      // Zero-duration pumps: a tween from 10.0 toward 42.0 could never reach
      // 42.0 on an unadvancing clock.
      var shown = false;
      for (var i = 0; i < 10 && !shown; i++) {
        await tester.pump(Duration.zero);
        shown = tester.any(find.text('42.0'));
      }
      expect(
        shown,
        isTrue,
        reason: 'the new figure must render directly, not count toward it',
      );
      await tester.pumpAndSettle();
    });
  });

  testWidgets('the refresh action refetches instead of replaying cache', (
    tester,
  ) async {
    // The regression this guards: dashboardSnapshotProvider is a plain
    // FutureProvider, so once it resolves it caches for the life of the app.
    // A manager watching agents sync work in would have seen the numbers from
    // whenever they opened the screen, with nothing on screen admitting it.
    final repo = _MutableDashboardRepository();
    await _pump(tester, _app(dashboard: repo));

    expect(find.text('10.0'), findsOneWidget);

    // The server's answer changes — an agent submitted a visit.
    repo.score = 42.0;

    await tester.tap(find.byKey(const ValueKey('dashboard-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('42.0'), findsOneWidget);
    expect(find.text('10.0'), findsNothing);
  });
}
