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
import 'package:tradeiq_app/features/dispatch/data/dispatch_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// Everything territories, trends and dispatch need to stand a screen up
/// without a server.
///
/// The fakes override **repositories**, never the view providers above them,
/// so the coverage state machine, the union-of-periods alignment and the
/// ranking are all exercised for real. A test that overrode
/// `territoryCoverageProvider` would prove only that a widget can render a
/// record.
///
/// None of these repositories is drift-backed, so nothing here watches a
/// database and `pumpAndSettle` is safe (§12.7). The one thing that is not
/// safe is a toast's timer, which is why [settleToasts] exists.

// ── Fixtures ──────────────────────────────────────────────────────────

const Territory north = Territory(
  id: 'ter-1',
  name: 'Gauteng North',
  code: 'GP-N',
  region: 'Gauteng',
);

const Territory west = Territory(id: 'ter-2', name: 'Western Cape', code: 'WC');

Outlet outlet(
  String id,
  String name, {
  bool visited = false,
  double lat = -26.2,
  double lng = 28.0,
}) => Outlet(
  id: id,
  name: name,
  code: id.toUpperCase(),
  lat: lat,
  lng: lng,
  visited: visited,
);

AppUser person(
  String id,
  String email, {
  String? name,
  String role = 'field_agent',
  bool active = true,
}) => AppUser(
  id: id,
  email: email,
  role: role,
  active: active,
  displayName: name,
);

/// A measured coverage block: three outlets, two of them visited.
TerritoryCoverage coverage({
  int outletCount = 3,
  int agentCount = 2,
  List<Outlet> outlets = const <Outlet>[],
  int? visited = 2,
  int? total = 3,
  double? rate = 66.67,
}) => TerritoryCoverage(
  outletCount: outletCount,
  agentCount: agentCount,
  outlets: outlets,
  outletsVisited: visited,
  outletsTotal: total,
  coverageRate: rate,
);

/// A territory with nothing filed under it. The wire sends `coverageRate: 0`
/// here and that nought is the thing the screen must not print.
TerritoryCoverage emptyCoverage({int agentCount = 0}) => TerritoryCoverage(
  outletCount: 0,
  agentCount: agentCount,
  outletsVisited: 0,
  outletsTotal: 0,
  coverageRate: 0,
);

const TrendPoint w26 = TrendPoint(period: '2026-W26', value: 40, count: 12);
const TrendPoint w27 = TrendPoint(period: '2026-W27', value: 80, count: 14);

// ── Fakes ─────────────────────────────────────────────────────────────

class FakeTerritoriesRepository implements TerritoriesRepository {
  FakeTerritoriesRepository({
    this.territories = const <Territory>[north, west],
    this.coverageFor = const <String, TerritoryCoverage>{},
    this.listFailure,
    this.coverageFailure,
    this.assignFailure,
    this.createFailure,
    this.listPending = false,
    this.coveragePending = false,
  });

  final List<Territory> territories;
  final Map<String, TerritoryCoverage> coverageFor;
  final Object? listFailure;
  final Object? coverageFailure;
  final Object? assignFailure;
  final Object? createFailure;
  final bool listPending;
  final bool coveragePending;

  String? assignedTerritoryId;
  String? assignedUserId;
  String? createdName;
  String? createdCode;
  String? createdRegion;
  int createCount = 0;

  @override
  Future<PaginatedResponse<Territory>> listTerritories() async {
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<Territory>>().future;
    return PaginatedResponse(data: territories, nextCursor: null);
  }

  @override
  Future<TerritoryCoverage> getCoverage(String id) async {
    if (coverageFailure != null) throw coverageFailure!;
    if (coveragePending) return Completer<TerritoryCoverage>().future;
    return coverageFor[id] ?? coverage();
  }

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async {
    createCount++;
    createdName = name;
    createdCode = code;
    createdRegion = region;
    if (createFailure != null) throw createFailure!;
    return Territory(id: 'new', name: name, code: code, region: region);
  }

  @override
  Future<void> assignAgent(String territoryId, String userId) async {
    assignedTerritoryId = territoryId;
    assignedUserId = userId;
    if (assignFailure != null) throw assignFailure!;
  }
}

class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository([this.users = const <AppUser>[]]);

  final List<AppUser> users;

  @override
  Future<PaginatedResponse<AppUser>> listUsers() async =>
      PaginatedResponse(data: users, nextCursor: null);

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async => throw UnimplementedError();

  @override
  Future<AppUser> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> updateDisplayName(String id, String? displayName) async =>
      throw UnimplementedError();
}

class FakeOutletsRepository implements OutletsRepository {
  FakeOutletsRepository({this.outlets = const <Outlet>[], this.failure});

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

class FakeDispatchRepository implements DispatchRepository {
  FakeDispatchRepository({this.result, this.failure, this.pending = false});

  final DispatchResult? result;
  final Object? failure;
  final bool pending;

  final List<String> asked = <String>[];

  @override
  Future<DispatchResult> dispatch(String outletId) async {
    asked.add(outletId);
    if (failure != null) throw failure!;
    if (pending) return Completer<DispatchResult>().future;
    return result ?? const DispatchResult(candidates: <DispatchCandidate>[]);
  }
}

class FakeTrendsRepository implements TrendsRepository {
  FakeTrendsRepository({
    this.points = const <TrendPoint>[w26, w27],
    this.report,
    this.failure,
    this.pending = false,
  });

  final List<TrendPoint> points;
  final TerritoryBenchmarkReport? report;
  final Object? failure;
  final bool pending;

  /// Every query the screen actually issued — so a test can prove a control
  /// reaches the API rather than merely repainting itself.
  final List<TrendQuery> queries = <TrendQuery>[];
  final List<BenchmarkMetric> metrics = <BenchmarkMetric>[];

  Future<List<TrendPoint>> _answer(TrendQuery query) async {
    queries.add(query);
    if (failure != null) throw failure!;
    if (pending) return Completer<List<TrendPoint>>().future;
    return points;
  }

  @override
  Future<List<TrendPoint>> scorecards([
    TrendQuery query = const TrendQuery(),
  ]) => _answer(query);

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) => _answer(query);

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) => _answer(query);

  @override
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query = const TrendQuery(),
  ]) async {
    metrics.add(metric);
    queries.add(query);
    if (failure != null) throw failure!;
    if (pending) return Completer<TerritoryBenchmarkReport>().future;
    return report ??
        TerritoryBenchmarkReport(
          metric: metric,
          isPercent: false,
          client: const BenchmarkSeries(
            average: null,
            count: 0,
            points: <TrendPoint>[],
          ),
          territories: const <TerritoryBenchmark>[],
        );
  }
}

/// A session fixed to one role, so role-gated UI is deterministic.
class RoleSession extends SessionController {
  RoleSession(this.role);

  final String? role;

  @override
  Future<SessionState> build() async => SessionState(role: role, token: 't');
}

// ── The pump ──────────────────────────────────────────────────────────

/// Where a `context.push` or `context.go` from one of these screens can land.
/// Stubs, because the assertion is that the screen navigated — but real
/// routes, because `go_router` throws on a destination that does not exist
/// and that throw is worth keeping.
List<GoRoute> _stubRoutes(Set<String> taken) => <GoRoute>[
  for (final path in <String>[
    '/dashboard',
    '/tasks',
    '/assistant',
    '/territories',
    '/territories/new',
    '/territories/:territoryId/map',
  ])
    if (!taken.contains(path))
      GoRoute(
        path: path,
        builder: (context, state) => Align(
          alignment: Alignment.topLeft,
          child: Text('stub:${state.matchedLocation}'),
        ),
      ),
];

/// A 360×720 console phone, in [skin], under a real router.
///
/// The whole app sits inside the amber census's repaint boundary, so a census
/// taken after this pump measures the composed frame — chrome included, which
/// is the only way to count the nav's active tab.
Future<void> pumpConsole(
  WidgetTester tester,
  Widget screen, {
  TiqSkin? skin,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  Locale? locale,
  String role = 'manager',
  List<AppUser> users = const <AppUser>[],
  List<Override> overrides = const <Override>[],
  List<GoRoute> extraRoutes = const <GoRoute>[],
  String path = '/screen',
  bool settle = true,
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
          overrides: <Override>[
            sessionControllerProvider.overrideWith(() => RoleSession(role)),
            usersRepositoryProvider.overrideWithValue(
              FakeUsersRepository(users),
            ),
            ...overrides,
          ],
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
              initialLocation: path,
              routes: <GoRoute>[
                GoRoute(path: path, builder: (context, state) => screen),
                ...extraRoutes,
                ..._stubRoutes(<String>{
                  path,
                  for (final route in extraRoutes) route.path,
                }),
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
    // A phase that never resolves — a skeleton with its travelling rule
    // running — has no settled frame to wait for, and `pumpAndSettle` on a
    // repeating animation never returns.
    await tester.pump();
  }
}

/// Let a toast live out its dwell and take its timer with it.
///
/// A toast holds a `Timer`, and flutter_test fails a test whose tree is
/// disposed with one still pending — which presents as a hang two tests later
/// rather than as the toast's own fault.
Future<void> settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 20));
  await tester.pumpAndSettle();
}

/// Scroll the console body until [finder] is built and on screen.
Future<void> scrollConsoleTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

/// Scroll inside an open sheet until [finder] is on screen.
///
/// A sheet's body scrolls when it outgrows 88% of the viewport, and at 2.0x
/// on a 320dp phone a roster does exactly that — which is the point of the
/// ceiling, and the reason a test cannot assume a commit button is in view.
Future<void> scrollSheetTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty &&
      tester.any(find.byType(Scrollable)) == false) {
    return;
  }
  await tester.dragUntilVisible(
    finder,
    find
        .descendant(
          of: find.byType(TorchSheet),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
}

/// Drag the filter rail sideways until [finder] is on screen.
Future<void> scrollRailTo(
  WidgetTester tester,
  Finder rail,
  Finder finder,
) async {
  await tester.dragUntilVisible(
    finder,
    find.descendant(of: rail, matching: find.byType(Scrollable)).first,
    const Offset(-120, 0),
  );
  await tester.pumpAndSettle();
}
