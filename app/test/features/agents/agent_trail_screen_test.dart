import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/basemap.dart';
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
  // The pins' glow-breathing is the design's ONLY looping animation — and an
  // infinite loop makes every `pumpAndSettle` below time out. Off for the
  // suite by default; the two motion tests at the bottom flip it back on to
  // prove the loop exists (normal motion) and stays off (reduced motion).
  setUp(() => AgentTrailScreen.debugDisableGlowBreathing = true);
  tearDown(() => AgentTrailScreen.debugDisableGlowBreathing = false);

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

  // The Tide Guide world (premium-ui sub3): dark tiles, a navy tint wash, then
  // the trail geometry ABOVE the tint so pins and lines keep full brightness,
  // and the licence attribution on top of everything.
  testWidgets('layers the navy tint between the tiles and the trail geometry', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.children, hasLength(5));
    expect(map.children[0], isA<TiqTileLayer>());
    expect(map.children[1], isA<TiqNavyTint>());
    expect(map.children[2], isA<PolylineLayer>());
    expect(map.children[3], isA<MarkerLayer>());
    expect(map.children[4], isA<TiqBasemapAttribution>());
  });

  testWidgets('draws the trail in luminous blue at .8 opacity', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    // 0xFF4D9BFF at .8 alpha (0.8 × 255 = 0xCC) — reads as light over the
    // navy world without shouting over the pins.
    expect(layer.polylines.first.color, const Color(0xCC4D9BFF));
  });

  // The label is new information the old map hid behind a hover tooltip:
  // outlet name + check-in time, visible on the map itself.
  testWidgets('each pin carries a luminous label with the outlet name and time', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sandton Spar'), findsOneWidget);
    expect(find.textContaining('Rosebank Pick n Pay'), findsOneWidget);
    expect(find.textContaining('08:00'), findsOneWidget);
    expect(find.textContaining('11:00'), findsOneWidget);

    final label = tester.widget<Text>(find.textContaining('Sandton Spar'));
    expect(label.style!.color, const Color(0xFFD9E6FF));
    expect(label.style!.shadows, isNotEmpty,
        reason: 'the dark text-shadow is what keeps the label legible over '
            'unpredictable tile detail');
    expect(label.maxLines, 2);
    expect(label.overflow, TextOverflow.ellipsis);
  });

  // The halo is enhancement, the numbering is the honesty rule: the last stop
  // may glow brightest, but the sequence must still read from the numerals
  // alone (greyscale, colour-blind, screenshot-in-an-email).
  testWidgets('only the last stop carries the brightest halo; numerals still carry the sequence', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    const halo = ValueKey<String>('agent-stop-last-halo');
    expect(find.byKey(halo), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('agent-stop-a1-1')),
        matching: find.byKey(halo),
      ),
      findsOneWidget,
      reason: 'the LAST stop is the one that glows brightest',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('agent-stop-a1-0')),
        matching: find.byKey(halo),
      ),
      findsNothing,
      reason: 'earlier stops must not claim the "where they ended up" glow',
    );

    // The numerals survive the restyle.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('the legend sits on translucent dark chrome', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final legendText = find.textContaining('Numbered pins');
    expect(tester.widget<Text>(legendText).style!.color, const Color(0xFF8FA5C6));
    final container = tester.widget<Container>(
      find.ancestor(of: legendText, matching: find.byType(Container)).first,
    );
    expect(container.color, const Color(0xCC050A16));
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

    BoxDecoration pinDecorationFor(String key) {
      final marker = find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byType(DecoratedBox),
      );
      return tester.widget<DecoratedBox>(marker.first).decoration
          as BoxDecoration;
    }

    final first = pinDecorationFor('agent-stop-a1-0');
    final last = pinDecorationFor('agent-stop-a1-1');

    // Both discs are now radial-gradient glows; the last stop's is brighter.
    final firstGradient = first.gradient! as RadialGradient;
    final lastGradient = last.gradient! as RadialGradient;
    expect(firstGradient.colors, isNot(equals(lastGradient.colors)));

    // And the last stop's halo is stronger, not just differently coloured.
    expect(
      last.boxShadow!.first.color.a,
      greaterThan(first.boxShadow!.first.color.a),
    );
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

  // The pin disc is deliberately theme-independent (it has to read against
  // map tiles, not the app's light/dark toggle) — and the numeral must be
  // legible against the deep-blue field it actually sits on, in BOTH themes.
  // The gradient's darkest colour (`colors.last`, the 0xFF1F7AE0 core) is the
  // dominant field under the numeral: the light highlight is deliberately
  // offset away from centre precisely so the numeral never sits on it (white
  // on 0xFF7CC0FF would be ~1.9:1). History: a theme-dependent numeral on a
  // theme-fixed disc once made every non-final stop a blank circle in dark
  // mode — hence the both-themes loop.
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
      final decoration = tester
          .widget<DecoratedBox>(
            find.descendant(of: pinKey, matching: find.byType(DecoratedBox)).first,
          )
          .decoration as BoxDecoration;
      // The core — the gradient's end colour — is the field the numeral
      // actually sits on (the highlight is offset away from centre).
      final discColor = decoration.gradient!.colors.last;
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

  // Unit-level guard for the `fitFor` fix, as far as a widget test can reach
  // it: flutter_map's OWN fit machinery — `initialCameraFit`, and the
  // `onMapReady`/`MapController.fitCamera` fix that came before this one —
  // both turned out to depend on flutter_map's internal camera size, which
  // a live debug overlay on the running web build showed was still zero at
  // the moment `onMapReady` fired. This proves none of that machinery is
  // wired up any more: no `mapController`, no `onMapReady`, no
  // `initialCameraFit` — just a plain, pre-computed `initialCenter`/
  // `initialZoom` flutter_map applies unconditionally. It does NOT prove
  // the web bug is fixed; that mechanism has no timing left to race, which
  // is a different (stronger) claim this suite can actually make, but the
  // browser is still the real verification.
  testWidgets('computes the camera itself via fitFor, not flutter_map\'s own fit machinery', (tester) async {
    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    await tester.pumpAndSettle();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCameraFit, isNull);
    expect(map.options.onMapReady, isNull);
    expect(map.mapController, isNull);
    // A sane, JHB-scale value — not flutter_map's own built-in default
    // (LatLng(50.5, 30.51), zoom 13) that would appear if nothing had wired
    // a real centre/zoom into `initialCenter`/`initialZoom` at all.
    expect(map.options.initialCenter.latitude, closeTo(-26.12, 1.0));
    expect(map.options.initialZoom, inInclusiveRange(8, 16));
  });

  // The glow-breathing is the design's ONLY looping animation. Two claims to
  // hold it to: it actually breathes when motion is allowed, and it is
  // completely static — no running controller at all — under reduced motion.
  testWidgets('the glow breathes when motion is allowed', (tester) async {
    // Production path: the test-only kill-switch off.
    AgentTrailScreen.debugDisableGlowBreathing = false;

    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    // No pumpAndSettle anywhere in this test — the breathing loops forever by
    // design, so settle would time out. Two plain pumps: build, then the
    // repository future's completion.
    await tester.pump();
    await tester.pump();

    double haloAlpha() {
      final decoration = tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byKey(const ValueKey<String>('agent-stop-a1-0')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      return decoration.boxShadow!.first.color.a;
    }

    final before = haloAlpha();
    // 600ms into a 2400ms reverse loop — far from any symmetric turnaround.
    await tester.pump(const Duration(milliseconds: 600));
    expect(haloAlpha(), isNot(closeTo(before, 0.001)));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('under reduced motion the glow is static — nothing loops', (tester) async {
    // Production path again — reduceMotion alone must stop the loop.
    AgentTrailScreen.debugDisableGlowBreathing = false;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(routedApp(
      const AgentTrailScreen(),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([_thabo])),
      ],
    ));
    // This is the assertion: with a looping controller alive, pumpAndSettle
    // would time out.
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('agent-stop-a1-0')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  // 3:1 is this codebase's bar for graphical marks (see tiq_colors_test.dart).
  // The numeral sits on the glow disc's deep core, so that pair is the one
  // that has to clear it — asserted here as a plain unit test against the
  // spec's literal colours, independent of any widget tree.
  test('white numeral on the glow-disc core clears the 3:1 graphical-mark bar', () {
    expect(
      contrastRatio(const Color(0xFF1F7AE0), Colors.white),
      greaterThanOrEqualTo(3.0),
    );
    // The last stop's brighter core must clear it too.
    expect(
      contrastRatio(const Color(0xFF3B93F5), Colors.white),
      greaterThanOrEqualTo(3.0),
    );
  });

  // #197: two stops at outlets ~20m apart drew their luminous labels over one
  // another as garbled text. The repro from the ticket, as a widget test.
  group('colliding labels (#197)', () {
    // ~20m apart — the ticket's reported distance.
    final coincident = AgentActivity(
      agentId: 'a9',
      name: 'lerato@example.com',
      state: AgentState.inTransit,
      lastSeenAt: DateTime(2026, 7, 22, 10),
      stops: [
        _stop('v1', '555 Media Tech', -26.1076, 28.0567, 9),
        _stop('v2', 'Ncondo Chambers', -26.1076, 28.0569, 10),
      ],
    );

    testWidgets('draws only one label when two stops nearly coincide', (
      tester,
    ) async {
      await tester.pumpWidget(routedApp(
        const AgentTrailScreen(),
        overrides: [
          agentsRepositoryProvider
              .overrideWithValue(_FakeAgentsRepository([coincident])),
        ],
      ));
      await tester.pumpAndSettle();

      // Both pins survive — only the caption is suppressed, never the stop.
      expect(find.byKey(const ValueKey<String>('agent-stop-a9-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('agent-stop-a9-1')), findsOneWidget);

      // The last stop is where the agent is now — the question this screen
      // exists to answer — so its label is the one that wins.
      expect(find.textContaining('Ncondo Chambers'), findsOneWidget);
      expect(find.textContaining('555 Media Tech'), findsNothing);
    });

    testWidgets('keeps both labels when the stops are far apart', (
      tester,
    ) async {
      // The guard against over-suppression: _thabo's two stops are ~4km
      // apart, and both labels must survive. Without this, a declutterer that
      // hid everything would pass the test above.
      await tester.pumpWidget(routedApp(
        const AgentTrailScreen(),
        overrides: [
          agentsRepositoryProvider
              .overrideWithValue(_FakeAgentsRepository([_thabo])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sandton Spar'), findsOneWidget);
      expect(find.textContaining('Rosebank Pick n Pay'), findsOneWidget);
    });
  });
}
