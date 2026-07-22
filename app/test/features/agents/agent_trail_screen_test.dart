import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/agents/presentation/agent_trail_screen.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

class _FakeAgentsRepository implements AgentsRepository {
  _FakeAgentsRepository(this.agents, {this.truncated = false});
  final List<AgentActivity> agents;
  final bool truncated;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      AgentActivityPage(agents: agents, truncated: truncated);
}

/// Returns different agents depending on the requested day, keyed by the
/// `from` bound's day-of-month — just enough to prove the map re-centres
/// when [agentTrailDayProvider] changes, without a full calendar model.
class _DayDependentAgentsRepository implements AgentsRepository {
  _DayDependentAgentsRepository(this.byDay);
  final Map<int, List<AgentActivity>> byDay;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      AgentActivityPage(agents: byDay[from.day] ?? const [], truncated: false);
}

/// Returns different agents depending on the requested territory (same day
/// throughout) — just enough to prove the map re-fits when the territory
/// filter changes, without a full backend fake.
class _TerritoryAwareAgentsRepository implements AgentsRepository {
  _TerritoryAwareAgentsRepository(this.byTerritory);
  final Map<String?, List<AgentActivity>> byTerritory;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      AgentActivityPage(agents: byTerritory[territoryId] ?? const [], truncated: false);
}

class _ThrowingRepository implements AgentsRepository {
  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      throw Exception('boom');
}

AgentStop _stop(String id, String name, double lat, double lng, int hour) => AgentStop(
      visitId: id,
      outletId: 'o-$id',
      outletName: name,
      lat: lat,
      lng: lng,
      checkinTs: DateTime(2026, 7, 22, hour),
      inProgress: false,
    );

final _thabo = AgentActivity(
  agentId: 'a1',
  name: 'thabo@example.com',
  state: AgentState.inTransit,
  currentOutletName: null,
  lastSeenAt: DateTime(2026, 7, 22, 11),
  stops: [
    _stop('v1', 'Sandton Spar', -26.10, 28.05, 8),
    _stop('v2', 'Rosebank Pick n Pay', -26.14, 28.04, 11),
  ],
);

void main() {
  testWidgets('renders a marker per stop', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-stop-a1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-stop-a1-1')), findsOneWidget);
  });

  testWidgets('shows an empty state for a day with no stops', (tester) async {
    final idle = AgentActivity(
      agentId: 'a2',
      name: 'sipho@example.com',
      state: AgentState.idle,
      stops: const [],
    );
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([idle])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No check-ins'), findsOneWidget);
  });

  // The dashes are load-bearing: a solid line would assert a route between two
  // check-ins that we did not observe.
  testWidgets('draws the trail as a dashed polyline', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(layer.polylines, hasLength(1));
    // `segments` is non-null only on StrokePattern.dashed — asserting on it
    // actually proves the line is dashed. Comparing against
    // `StrokePattern.solid()` would not: StrokePattern has no value equality,
    // so that assertion passes even against a solid line.
    expect(layer.polylines.first.pattern.segments, isNotNull);
  });

  testWidgets('draws no polyline for an agent with a single stop', (tester) async {
    final oneStop = AgentActivity(
      agentId: 'a3',
      name: 'nomsa@example.com',
      state: AgentState.atStore,
      currentOutletName: 'Sandton Spar',
      stops: [_stop('v9', 'Sandton Spar', -26.10, 28.05, 9)],
    );
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([oneStop])),
      ],
    ));
    await tester.pumpAndSettle();

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(layer.polylines, isEmpty);
  });

  testWidgets('says so when the server had more agents than it returned', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([_thabo], truncated: true),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('first 200'), findsOneWidget);
  });

  testWidgets('surfaces an error with a retry', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_ThrowingRepository()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  // Zero coverage before this: three agents on the same day previously drew
  // three identical "1" pins in the same brand colour with nothing but a
  // screen-reader-only label telling them apart (FIX 3).
  testWidgets('renders a marker for each of two agents on the same day', (tester) async {
    final nomsa = AgentActivity(
      agentId: 'a4',
      name: 'nomsa@example.com',
      state: AgentState.inTransit,
      stops: [
        _stop('v10', 'Fourways Checkers', -26.02, 28.01, 9),
        _stop('v11', 'Bryanston Woolworths', -26.05, 28.03, 12),
      ],
    );
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([_thabo, nomsa]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('agent-stop-a1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-stop-a4-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-stop-a4-1')), findsOneWidget);
  });

  // "State is never colour alone" is the file's own claim (see the doc
  // comment on _StopPin) — this is the test that actually holds it to that.
  testWidgets('the last stop is styled differently from an earlier stop', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    DecoratedBox pinDecorationFor(String key) {
      final marker = find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byType(DecoratedBox),
      );
      return tester.widget<DecoratedBox>(marker.first);
    }

    final firstFill =
        (pinDecorationFor('agent-stop-a1-0').decoration as BoxDecoration).color;
    final lastFill =
        (pinDecorationFor('agent-stop-a1-1').decoration as BoxDecoration).color;

    expect(firstFill, isNot(equals(lastFill)));
  });

  // Guards flutter_map's own one-shot `_initialCameraFitApplied` flag (see
  // its widget.dart): the map must end up centred on each day's own data,
  // and the FlutterMap driving it must be keyed per day so a future refactor
  // that removes AsyncSection's loading interstitial (which today forces a
  // fresh FlutterMap mount on every family-provider switch, independently of
  // any key) doesn't silently reintroduce a stuck camera. Verified by
  // temporarily deleting the day+coordinate key on `FlutterMap`: the camera
  // assertion below still passed (the loading branch already remounts
  // FlutterMap on every day change here), so the key assertion is what
  // actually pins the fix — the camera check is real end-state coverage, not
  // proof of the mechanism, and is kept because it doubles as the FIX-3
  // scenario's map-shows-different-data guarantee.
  testWidgets('the camera re-fits when the selected day changes', (tester) async {
    final johannesburg = AgentActivity(
      agentId: 'a1',
      name: 'thabo@example.com',
      state: AgentState.inTransit,
      stops: [_stop('v1', 'Sandton Spar', -26.10, 28.05, 8)],
    );
    final capeTown = AgentActivity(
      agentId: 'a5',
      name: 'zola@example.com',
      state: AgentState.inTransit,
      stops: [_stop('v20', 'V&A Waterfront', -33.90, 18.42, 9)],
    );

    late final ProviderContainer container;
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _DayDependentAgentsRepository({
            22: [johannesburg],
            23: [capeTown],
          }),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(AgentTrailScreen)),
    );
    container.read(agentTrailDayProvider.notifier).state = DateTime(2026, 7, 22);
    await tester.pumpAndSettle();

    final cameraBefore =
        MapCamera.of(tester.element(find.byType(TileLayer))).center;
    expect(cameraBefore.latitude, closeTo(-26.10, 0.5));
    expect(
      tester.widget<FlutterMap>(find.byType(FlutterMap)).key,
      ValueKey<(DateTime, String)>((DateTime(2026, 7, 22), '-26.1000,28.0500')),
    );

    container.read(agentTrailDayProvider.notifier).state = DateTime(2026, 7, 23);
    await tester.pumpAndSettle();

    final cameraAfter =
        MapCamera.of(tester.element(find.byType(TileLayer))).center;
    expect(cameraAfter.latitude, closeTo(-33.90, 0.5));
    expect(cameraAfter.latitude, isNot(closeTo(cameraBefore.latitude, 1)));
    expect(
      tester.widget<FlutterMap>(find.byType(FlutterMap)).key,
      ValueKey<(DateTime, String)>((DateTime(2026, 7, 23), '-33.9000,18.4200')),
    );
  });

  // The pin disc is deliberately fixed white (it has to read against
  // unpredictable map tiles, not the app's light/dark toggle) — so a numeral
  // pulled from the ambient theme (`colors.ink1`) is nearly invisible in dark
  // mode, ~1.2:1 on white, even though it looks fine in light mode where
  // ink1 happens to be dark. A test that only pumps the default theme is
  // exactly how this shipped — so this one checks both.
  testWidgets('the non-last numeral stays legible on its disc in both themes', (tester) async {
    Future<void> pumpThemed(ThemeData theme) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
          ],
          child: MaterialApp.router(
            theme: theme,
            routerConfig: GoRouter(
              initialLocation: '/screen',
              routes: [
                GoRoute(path: '/screen', builder: (context, state) => const AgentTrailScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpThemed(theme);

      final pinKey = find.byKey(const ValueKey<String>('agent-stop-a1-0'));
      final discColor = (tester
              .widget<DecoratedBox>(
                find.descendant(of: pinKey, matching: find.byType(DecoratedBox)).first,
              )
              .decoration as BoxDecoration)
          .color!;
      final numeralColor = tester
          .widget<Text>(find.descendant(of: pinKey, matching: find.byType(Text)).first)
          .style!
          .color!;

      // 3:1 is this codebase's own bar for graphical marks (ink4's doc
      // comment, tiq_colors_test.dart) — a numeral is exactly that.
      expect(
        contrastRatio(discColor, numeralColor),
        greaterThanOrEqualTo(3.0),
        reason: 'disc $discColor vs numeral $numeralColor under ${theme.brightness}',
      );
    }
  });

  // Same one-shot-fit gap as the dashboard panel's territory-filter test:
  // this screen's own provider (`agentActivityForDayProvider`) also watches
  // `dashboardFilterProvider`, so switching territories without changing the
  // date re-fetches a different set of pins on the SAME day — the day-only
  // key would leave the camera pointed at the old territory.
  testWidgets('re-fits the camera when a territory-filter change moves the pins, same day', (tester) async {
    final jhb = [
      AgentActivity(
        agentId: 'a1',
        name: 'thabo@example.com',
        state: AgentState.inTransit,
        stops: [_stop('v1', 'Sandton Spar', -26.10, 28.05, 8)],
      ),
    ];
    final capeTown = [
      AgentActivity(
        agentId: 'a5',
        name: 'zola@example.com',
        state: AgentState.inTransit,
        stops: [_stop('v20', 'V&A Waterfront', -33.90, 18.42, 9)],
      ),
    ];

    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _TerritoryAwareAgentsRepository({null: jhb, 'cpt': capeTown}),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final before = MapCamera.of(tester.element(find.byType(TileLayer))).center;
    expect(before.latitude, closeTo(-26.10, 0.5));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AgentTrailScreen)),
    );
    container.read(dashboardFilterProvider.notifier).set(
          const DashboardFilter(territoryId: 'cpt'),
        );
    await tester.pumpAndSettle();

    final after = MapCamera.of(tester.element(find.byType(TileLayer))).center;
    expect(after.latitude, closeTo(-33.90, 0.5));
    expect(after.latitude, isNot(closeTo(before.latitude, 1)));
  });

  // Unit-level guard for the `onMapReady` fix, as far as a widget test can
  // reach it: `initialCameraFit` is fragile against Flutter web's first
  // real layout (a race no widget test can reproduce — the Dart VM never
  // reports the degenerate size web does), so the fit must be driven from
  // `onMapReady`/`MapController.fitCamera` instead. This only proves the
  // fragile option isn't wired up any more, and that our own controller is
  // the one actually driving the map — not that the fix works on web. See
  // the coordinator's diagnosis; the real verification for that is a
  // browser run, not this suite.
  testWidgets('drives the fit via onMapReady/MapController, not initialCameraFit', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCameraFit, isNull);
    expect(map.options.onMapReady, isNotNull);
    expect(map.mapController, isNotNull);
  });
}
