import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/core/widgets/delta_pill.dart';
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
    final isPrevious =
        from != null && DateTime.parse(from).isBefore(DateTime(2026, 6, 14));
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
    final isPrevious =
        from != null && DateTime.parse(from).isBefore(DateTime(2026, 6, 14));
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
  Future<List<Territory>> listTerritories() async => territories;

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
  Future<List<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async => tasks;

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

  testWidgets('the hero card wears the glass gradient wash', (tester) async {
    await _pump(tester, _app(theme: AppTheme.light()));

    final glass = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          listEquals(
            ((w.decoration! as BoxDecoration).gradient as LinearGradient?)
                ?.colors,
            const [Color(0xFFF2F7FF), Color(0xFFFFFFFF)],
          ),
    );
    expect(glass, findsOneWidget);
    // The washed card is the score's card, not some other panel's.
    expect(
      find.descendant(
        of: glass,
        matching: find.byKey(const ValueKey('kpi-execution-score')),
      ),
      findsOneWidget,
    );
    final border =
        (tester.widget<Container>(glass).decoration! as BoxDecoration).border!;
    expect((border as Border).top.color, const Color(0xFFDBE7FA));

    // The score itself is the 30–32px w700 headline figure of the spec.
    final score = tester.widget<Text>(find.text('67.8'));
    expect(score.style?.fontWeight, FontWeight.w700);
    expect(score.style?.fontSize, inInclusiveRange(30, 32));

    // And it must clear AA on every stop of its own wash.
    for (final ground in const [Color(0xFFF2F7FF), Color(0xFFFFFFFF)]) {
      expect(
        contrastRatio(score.style!.color!, ground),
        greaterThanOrEqualTo(4.5),
        reason: 'light score on $ground',
      );
    }
  });

  testWidgets('dark theme: the hero score stays readable on its wash', (
    tester,
  ) async {
    // The regression this guards: the glass wash shipped as hard-coded light
    // hexes while the score used theme-aware ink1 — in dark that composed
    // near-white on white (~1.1:1), one theme-toggle click away.
    await _pump(tester, _app(theme: AppTheme.dark()));

    final glass = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient != null,
    );
    expect(glass, findsOneWidget);
    expect(
      find.descendant(
        of: glass,
        matching: find.byKey(const ValueKey('kpi-execution-score')),
      ),
      findsOneWidget,
    );

    final gradient =
        (tester.widget<Container>(glass).decoration! as BoxDecoration).gradient!
            as LinearGradient;
    final score = tester.widget<Text>(find.text('67.8'));
    for (final ground in gradient.colors) {
      expect(
        contrastRatio(score.style!.color!, ground),
        greaterThanOrEqualTo(4.5),
        reason: 'dark score on $ground',
      );
    }
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

  testWidgets('renders the KPI filter bar (territory + date range)', (
    tester,
  ) async {
    await _pump(tester, _app());

    expect(find.byKey(const ValueKey('filter-territory')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-daterange')), findsOneWidget);
  });

  testWidgets('range chips are white pills; the active chip is solid brand', (
    tester,
  ) async {
    await _pump(tester, _app(theme: AppTheme.light()));

    // The default range is 30d, so its chip is the active pill.
    final active = _chipBox(tester, 'last30');
    expect(active.color, const Color(0xFF0A6CF0));
    expect(active.borderRadius, BorderRadius.circular(999));

    final activeLabel = _chipLabel(tester, 'last30', '30d');
    expect(activeLabel.style?.color, Colors.white);
    expect(activeLabel.style?.fontSize, 11);
    expect(activeLabel.style?.fontWeight, FontWeight.w600);

    // Inactive: white ground, hairline (light `line` token) border, muted ink.
    final inactive = _chipBox(tester, 'last7');
    expect(inactive.color, const Color(0xFFFFFFFF));
    expect(inactive.borderRadius, BorderRadius.circular(999));
    expect((inactive.border! as Border).top.color, const Color(0xFFE3E5EA));

    final inactiveLabel = _chipLabel(tester, 'last7', '7d');
    expect(inactiveLabel.style?.color, const Color(0xFF4C5560));
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
    // And the active chip is the solid-brand pill in dark too.
    expect(_chipBox(tester, 'last30').color, const Color(0xFF0A6CF0));
  });

  testWidgets(
    'attention rows: 14px colour-coded numeral, bold title, muted subtitle',
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
      expect(numeral.style?.fontSize, 14);
      expect(numeral.style?.fontWeight, FontWeight.w700);
      expect(numeral.style?.color, const Color(0xFFB32E2E)); // light crit

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
      expect(subtitle.style?.color, const Color(0xFF5F6875)); // light ink3
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
