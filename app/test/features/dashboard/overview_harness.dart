import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/agents/data/agent_locations_repository.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/sales_targets/data/sales_targets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

export '../a11y_guard.dart'
    show expectEveryButtonActivatable, semanticsDump, semanticsNodes;
// The record types every overview test names. Re-exported so a test file
// imports the harness and nothing else to describe a fixture.
export 'package:tradeiq_app/features/agents/data/agent_locations_repository.dart';
export 'package:tradeiq_app/features/agents/data/agents_repository.dart';
export 'package:tradeiq_app/features/alerts/data/alerts_repository.dart'
    show AlertItem, alertsListProvider;
export 'package:tradeiq_app/features/outlets/data/outlets_repository.dart'
    show Outlet, outletsListProvider;
export 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart'
    show TaskItem, tasksListProvider;
export 'package:tradeiq_app/features/territories/data/territories_repository.dart'
    show Territory, territoriesListProvider;
export 'package:tradeiq_app/features/trends/data/trends_repository.dart'
    show TrendPoint;

/// Everything the execution overview's tests need to stand the route up
/// without a server.
///
/// The fakes override **repositories**, never the view providers above them,
/// so the window arithmetic, the two-request delta, the per-territory merge
/// and the sample-size plumbing are all exercised for real. A test that
/// overrode `dashboardSnapshotProvider` would prove only that a widget can
/// render a record.
///
/// None of these repositories is drift-backed, so nothing here watches a
/// database and `pumpAndSettle` is safe (§12.7).

// ── Fixtures ──────────────────────────────────────────────────────────

const Territory north = Territory(
  id: 'ter-1',
  name: 'Gauteng North',
  code: 'GP-N',
  region: 'Gauteng',
);

const Territory west = Territory(id: 'ter-2', name: 'Western Cape', code: 'WC');

/// A measured window. `totals` is what makes it measured — not the figures.
DashboardKpis kpis({
  double osa = 93.1,
  double execution = 67.8,
  double perfect = 55.6,
  double price = 88,
  double visibility = 76.4,
  double sos = 41.2,
  double weighted = 81.3,
  double numeric = 72.5,
  int? osaSample = 240,
  int? executionSample = 18,
  int visits = 42,
  int outletsVisited = 33,
  int outletsTotal = 42,
  List<ScoreBand> bands = const <ScoreBand>[],
}) => DashboardKpis(
  numericDistribution: numeric,
  weightedDistribution: weighted,
  osaPct: osa,
  executionScore: execution,
  priceCompliancePct: price,
  visibilityCompliancePct: visibility,
  shareOfShelf: sos,
  perfectStoreRate: perfect,
  scoreBands: bands,
  sampleSizes: DashboardSampleSizes(
    osaPct: osaSample,
    executionScore: executionSample,
  ),
  visits: visits,
  outletsVisited: outletsVisited,
  outletsTotal: outletsTotal,
);

/// A tenant with outlets and no visits in this window. NOT first-run.
DashboardKpis emptyWindowKpis({int outletsTotal = 42}) => DashboardKpis(
  numericDistribution: 0,
  weightedDistribution: 0,
  osaPct: 0,
  executionScore: 0,
  priceCompliancePct: 0,
  visibilityCompliancePct: 0,
  shareOfShelf: 0,
  perfectStoreRate: 0,
  visits: 0,
  outletsVisited: 0,
  outletsTotal: outletsTotal,
);

/// A brand-new tenant: nothing on the books at all.
DashboardKpis firstRunKpis() => emptyWindowKpis(outletsTotal: 0);

AlertItem alert({
  String id = 'a1',
  String severity = 'critical',
  String metric = 'out_of_stock',
  String message = 'Out of stock since Tuesday',
  bool acknowledged = false,
}) => AlertItem(
  id: id,
  metric: metric,
  message: message,
  severity: severity,
  acknowledged: acknowledged,
  outletId: 'o1',
  createdAt: DateTime.utc(2026, 9, 18, 6, 40),
);

TaskItem task({
  String id = 't1',
  String priority = 'high',
  String status = 'open',
}) => TaskItem(
  id: id,
  findingType: 'stockout',
  requiredFix: 'Restock the end cap',
  priority: priority,
  status: status,
  closureVerified: false,
  outletId: 'o2',
  slaDueAt: DateTime.utc(2026, 9, 20),
  createdAt: DateTime.utc(2026, 9, 18, 9),
);

Outlet outlet(
  String id,
  String name, {
  double lat = -26.2,
  double lng = 28.0,
}) => Outlet(id: id, name: name, code: id.toUpperCase(), lat: lat, lng: lng);

AgentActivity agent({
  required String id,
  required String name,
  AgentState state = AgentState.idle,
  String? currentOutlet,
  String? lastOutlet,
  DateTime? lastSeen,
  List<AgentStop> stops = const <AgentStop>[],
}) => AgentActivity(
  agentId: id,
  name: name,
  state: state,
  currentOutletName: currentOutlet,
  lastSeenAt: lastSeen,
  stops: stops,
);

AgentStop stop(
  String outletName, {
  double lat = -26.10,
  double lng = 28.05,
}) => AgentStop(
  visitId: 'v1',
  outletId: 'o1',
  outletName: outletName,
  lat: lat,
  lng: lng,
  checkinTs: DateTime.now().subtract(const Duration(minutes: 20)),
  inProgress: false,
);

const TrendPoint w26 = TrendPoint(period: '2026-W26', value: 40, count: 12);
const TrendPoint w27 = TrendPoint(period: '2026-W27', value: 80, count: 14);

/// A month with nothing configured, so the sales panel renders its own
/// designed state instead of a spinner nobody can settle.
SalesAttainmentReport emptyAttainment() => const SalesAttainmentReport(
  month: '2026-09',
  timeZone: 'Africa/Johannesburg',
  skus: <SkuAttainment>[],
);

// ── Fakes ─────────────────────────────────────────────────────────────

/// Which of the dashboard's two fetches this is — the current window, or the
/// like-for-like one before it.
///
/// The console asks for the current window and the equally long one before it,
/// so any threshold strictly between the two separates them. Expressed
/// relatively rather than as a fixed date: a pinned date sits between them only
/// while the calendar cooperates, and a suite that has not changed a line
/// should not start failing because a month rolled over.
bool isPreviousWindow(String? from) =>
    from != null &&
    DateTime.parse(
      from,
    ).isBefore(DateTime.now().subtract(const Duration(days: 45)));

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({
    DashboardKpis? current,
    this.previous,
    this.byTerritory = const <TerritoryDashboardKpis>[],
    this.failure,
    this.byTerritoryFailure,
    this.pending = false,
  }) : current = current ?? kpis();

  DashboardKpis current;
  final DashboardKpis? previous;
  final List<TerritoryDashboardKpis> byTerritory;
  final Object? failure;
  final Object? byTerritoryFailure;
  final bool pending;

  /// Every window the screen actually asked for — so a test can prove a
  /// control reaches the API rather than merely repainting itself.
  final List<String?> windows = <String?>[];
  int calls = 0;

  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async {
    calls++;
    windows.add(from);
    if (failure != null) throw failure!;
    if (pending) return Completer<DashboardKpis>().future;
    if (isPreviousWindow(from)) {
      if (previous == null) throw StateError('no previous window');
      return previous!;
    }
    return current;
  }

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async {
    if (byTerritoryFailure != null) throw byTerritoryFailure!;
    return byTerritory;
  }
}

class FakeAlertsRepository implements AlertsRepository {
  FakeAlertsRepository([this.alerts = const <AlertItem>[], this.failure]);

  final List<AlertItem> alerts;
  final Object? failure;

  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async {
    if (failure != null) throw failure!;
    return PaginatedResponse(data: alerts, nextCursor: null);
  }

  @override
  Future<AlertItem> acknowledge(String id) async => throw UnimplementedError();
}

class FakeTasksRepository implements TasksAdminRepository {
  FakeTasksRepository([this.tasks = const <TaskItem>[]]);

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

class FakeOutletsRepository implements OutletsRepository {
  FakeOutletsRepository([this.outlets = const <Outlet>[], this.failure]);

  final List<Outlet> outlets;
  final Object? failure;

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async {
    if (failure != null) throw failure!;
    return PaginatedResponse(data: outlets, nextCursor: null);
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

class FakeTerritoriesRepository implements TerritoriesRepository {
  FakeTerritoriesRepository([
    this.territories = const <Territory>[],
    this.failure,
  ]);

  final List<Territory> territories;
  final Object? failure;

  @override
  Future<PaginatedResponse<Territory>> listTerritories() async {
    if (failure != null) throw failure!;
    return PaginatedResponse(data: territories, nextCursor: null);
  }

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      throw UnimplementedError();

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

class FakeAgentsRepository implements AgentsRepository {
  FakeAgentsRepository({
    this.agents = const <AgentActivity>[],
    this.byTerritory,
    this.truncated = false,
    this.failure,
  });

  final List<AgentActivity> agents;

  /// Different agents per territory — enough to prove the map re-fits when
  /// the filter moves the pins.
  final Map<String?, List<AgentActivity>>? byTerritory;
  final bool truncated;
  final Object? failure;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async {
    if (failure != null) throw failure!;
    return AgentActivityPage(
      agents: byTerritory == null
          ? agents
          : (byTerritory![territoryId] ?? const <AgentActivity>[]),
      truncated: truncated,
    );
  }
}

class FakeAgentLocationsRepository implements AgentLocationsRepository {
  FakeAgentLocationsRepository([this.page]);

  final AgentLocationsPage? page;
  int calls = 0;

  @override
  Future<AgentLocationsPage> listLocations({String? territoryId}) async {
    calls++;
    if (page == null) throw StateError('no live layer in this test');
    return page!;
  }
}

class FakeTrendsRepository implements TrendsRepository {
  FakeTrendsRepository({
    this.points = const <TrendPoint>[w26, w27],
    this.failure,
  });

  final List<TrendPoint> points;
  final Object? failure;

  Future<List<TrendPoint>> _answer() async {
    if (failure != null) throw failure!;
    return points;
  }

  @override
  Future<List<TrendPoint>> scorecards([
    TrendQuery query = const TrendQuery(),
  ]) => _answer();

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) => _answer();

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) => _answer();

  @override
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query = const TrendQuery(),
  ]) async => throw UnimplementedError();
}

class FakeSalesTargetsRepository implements SalesTargetsRepository {
  FakeSalesTargetsRepository([this.report]);

  final SalesAttainmentReport? report;

  @override
  Future<SalesAttainmentReport> attainment(String? month) async =>
      report ?? emptyAttainment();

  @override
  Future<void> upsert({
    required String skuId,
    required String month,
    required int targetUnits,
    String? territoryId,
    String? outletId,
  }) async => throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();

  @override
  Future<SalesTargetImportResult> importCsv(
    String csv, {
    required bool dryRun,
  }) async => throw UnimplementedError();
}

/// A session that answers with [role] rather than reaching for a token.
class RoleSession extends SessionController {
  RoleSession(this.role);

  final String? role;

  @override
  Future<SessionState> build() async => SessionState(role: role, token: 't');
}

// ── The pump ──────────────────────────────────────────────────────────

/// Every override the route needs, with each fake's fixtures in hand.
List<Override> overviewOverrides({
  FakeDashboardRepository? dashboard,
  DashboardKpis? current,
  DashboardKpis? previous,
  List<TerritoryDashboardKpis> byTerritory = const <TerritoryDashboardKpis>[],
  Object? dashboardFailure,
  Object? byTerritoryFailure,
  bool dashboardPending = false,
  List<AlertItem> alerts = const <AlertItem>[],
  Object? alertsFailure,
  List<TaskItem> tasks = const <TaskItem>[],
  List<Territory> territories = const <Territory>[],
  Object? territoriesFailure,
  List<Outlet> outlets = const <Outlet>[],
  Object? outletsFailure,
  List<AgentActivity> agents = const <AgentActivity>[],
  Map<String?, List<AgentActivity>>? agentsByTerritory,
  bool agentsTruncated = false,
  Object? agentsFailure,
  AgentLocationsPage? live,
  List<TrendPoint> trend = const <TrendPoint>[w26, w27],
  Object? trendFailure,
  SalesAttainmentReport? attainment,
}) => <Override>[
  sessionControllerProvider.overrideWith(() => RoleSession('manager')),
  dashboardRepositoryProvider.overrideWithValue(
    dashboard ??
        FakeDashboardRepository(
          current: current,
          previous: previous,
          byTerritory: byTerritory,
          failure: dashboardFailure,
          byTerritoryFailure: byTerritoryFailure,
          pending: dashboardPending,
        ),
  ),
  alertsRepositoryProvider.overrideWithValue(
    FakeAlertsRepository(alerts, alertsFailure),
  ),
  tasksAdminRepositoryProvider.overrideWithValue(FakeTasksRepository(tasks)),
  territoriesRepositoryProvider.overrideWithValue(
    FakeTerritoriesRepository(territories, territoriesFailure),
  ),
  outletsRepositoryProvider.overrideWithValue(
    FakeOutletsRepository(outlets, outletsFailure),
  ),
  agentsRepositoryProvider.overrideWithValue(
    FakeAgentsRepository(
      agents: agents,
      byTerritory: agentsByTerritory,
      truncated: agentsTruncated,
      failure: agentsFailure,
    ),
  ),
  agentLocationsRepositoryProvider.overrideWithValue(
    FakeAgentLocationsRepository(live),
  ),
  // Off by default: a repeating poll is a timer the fake clock never drains,
  // and §12.7 is what that costs.
  liveLocationsPollIntervalProvider.overrideWithValue(null),
  trendsRepositoryProvider.overrideWithValue(
    FakeTrendsRepository(points: trend, failure: trendFailure),
  ),
  salesTargetsRepositoryProvider.overrideWithValue(
    FakeSalesTargetsRepository(attainment),
  ),
];

/// Pump [screen] as a console route, in [skin], at a size a manager holds.
///
/// Tall by default: the overview is a long scroll and a test that had to
/// scroll to every assertion would be a test about `ListView`, not about the
/// screen. The amber census pumps its own size.
Future<void> pumpOverview(
  WidgetTester tester,
  Widget screen, {
  TiqSkin? skin,
  Size size = const Size(400, 3000),
  double textScale = 1.0,
  Locale? locale,
  bool settle = true,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // A leaked sheet count from a previous test would extinguish this one's
  // amber, and the failure would name the wrong component.
  TorchSheets.resetForTest();
  addTearDown(TorchSheets.resetForTest);

  final resolved = skin ?? TiqSkin.night();

  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey<String>('amber-golden-boundary'),
      child: ColoredBox(
        color: resolved.palette.ground,
        child: ProviderScope(
          overrides: overrides,
          // Riverpod 3 retries a failed provider on an exponential backoff by
          // default, so a repository that always throws leaves the screen in
          // `AsyncLoading` carrying an error — a skeleton, for ever. That is
          // the app's real behaviour on a flaky link and it is fine there; in
          // a test it means the designed error state is simply unreachable and
          // a failure asserts against a spinner. One attempt, no retry, so
          // `ErrorState` is what a failed fetch renders here.
          retry: (int count, Object error) => null,
          child: MaterialApp.router(
            theme: ThemeData(extensions: <ThemeExtension<dynamic>>[resolved]),
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeListResolutionCallback: resolveAppLocale,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            routerConfig: GoRouter(
              initialLocation: '/dashboard/overview',
              routes: <GoRoute>[
                GoRoute(
                  path: '/dashboard/overview',
                  builder: (context, state) => screen,
                ),
                for (final path in const <String>[
                  '/dashboard',
                  '/alerts',
                  '/tasks',
                  '/assistant',
                  '/agents/activity',
                ])
                  GoRoute(
                    path: path,
                    builder: (context, state) =>
                        ColoredBox(color: resolved.palette.ground, child: Text(path)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Drag a horizontally scrolling filter rail until [finder] is on screen.
///
/// The rail bleeds past the gutter by design — it is meant to visibly
/// continue — so on a 400dp phone the territory chip at its end genuinely is
/// off screen until a thumb moves it. A test that widened the viewport to
/// avoid the drag would be testing a rail nobody has.
Future<void> scrollRailTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  await tester.dragUntilVisible(
    finder,
    find.byType(Scrollable).at(1),
    const Offset(-120, 0),
  );
  await tester.pumpAndSettle();
}

/// Scroll the console body until [finder] is built and on screen.
///
/// The overview is a long scroll and its body is a lazy `ListView`: on a phone
/// the agent panel genuinely is past the fold, and in Afrikaans it is further
/// past it than in English. A test that pumped a 6000dp viewport to avoid the
/// scroll would be testing a screen nobody has.
Future<void> scrollOverviewTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}
