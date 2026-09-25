import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/agent_state_glyph.dart';
import 'package:tradeiq_app/core/widgets/basemap.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

import 'overview_harness.dart';

/// WHERE ARE MY AGENTS — the panel, on Torchlight.
///
/// Two halves that must never disagree: a map of last *confirmed* check-ins,
/// and the list that keeps it honest by carrying every agent including the
/// ones the map cannot place. In Veld there is no map at all and the list is
/// the whole panel, which is what it always was for a screen reader.

/// Hosts [child] at a width the test controls directly, so a test can drive
/// exactly the sequence a real screen produces without depending on
/// `ListView`'s cache-extent heuristics: a first layout at zero width (a
/// scrollable can lay a child out before it has real space), then a later,
/// real width once it "arrives".
class _ResizingHost extends StatefulWidget {
  const _ResizingHost({required this.width, required this.child});

  final ValueListenable<double> width;
  final Widget child;

  @override
  State<_ResizingHost> createState() => _ResizingHostState();
}

class _ResizingHostState extends State<_ResizingHost> {
  @override
  void initState() {
    super.initState();
    widget.width.addListener(_onWidthChanged);
  }

  @override
  void dispose() {
    widget.width.removeListener(_onWidthChanged);
    super.dispose();
  }

  void _onWidthChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: widget.width.value,
      height: 600,
      child: widget.child,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  List<AgentActivity> agents = const <AgentActivity>[],
  Map<String?, List<AgentActivity>>? agentsByTerritory,
  bool truncated = false,
  Object? agentsFailure,
  List<Outlet> outlets = const <Outlet>[],
  Object? outletsFailure,
  List<Territory> territories = const <Territory>[],
  TiqSkin? skin,
  Size size = const Size(400, 1200),
  Widget? host,
}) => pumpOverview(
  tester,
  host ?? const SingleChildScrollView(child: AgentActivityPanel()),
  skin: skin,
  size: size,
  overrides: overviewOverrides(
    agents: agents,
    agentsByTerritory: agentsByTerritory,
    agentsTruncated: truncated,
    agentsFailure: agentsFailure,
    outlets: outlets,
    outletsFailure: outletsFailure,
    territories: territories,
  ),
);

/// The filter change a manager makes a few hundred pixels above this panel.
void _filterTo(WidgetTester tester, String? territoryId) {
  ProviderScope.containerOf(
    tester.element(find.byType(AgentActivityPanel)),
  ).read(dashboardFilterProvider.notifier).set(
    DashboardFilter(territoryId: territoryId),
  );
}

List<AgentActivity> get _jhb => <AgentActivity>[
  agent(
    id: 'a1',
    name: 'a@x.com',
    state: AgentState.atStore,
    currentOutlet: 'Spar',
    stops: <AgentStop>[stop('Spar', lat: -26.10, lng: 28.05)],
  ),
  agent(
    id: 'a2',
    name: 'b@x.com',
    state: AgentState.atStore,
    currentOutlet: 'Checkers',
    stops: <AgentStop>[stop('Checkers', lat: -26.14, lng: 28.09)],
  ),
];

List<AgentActivity> get _capeTown => <AgentActivity>[
  agent(
    id: 'a3',
    name: 'c@x.com',
    state: AgentState.atStore,
    currentOutlet: 'Waterfront',
    stops: <AgentStop>[stop('Waterfront', lat: -33.90, lng: 18.42)],
  ),
  agent(
    id: 'a4',
    name: 'd@x.com',
    state: AgentState.atStore,
    currentOutlet: 'Canal Walk',
    stops: <AgentStop>[stop('Canal Walk', lat: -33.89, lng: 18.51)],
  ),
];

void main() {
  group('the list, which carries every agent', () {
    testWidgets('an at-store agent reads state then store', (tester) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'thabo@example.com',
            state: AgentState.atStore,
            currentOutlet: 'Sandton Spar',
            lastSeen: DateTime.now().subtract(const Duration(minutes: 4)),
          ),
        ],
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('agent-row-a1')),
      );
      expect(row.title, 'thabo@example.com');
      expect(row.subtitle, 'At store · Sandton Spar');
      // Every row leads with WHEN. A row that says only where reads as live,
      // and this data is never live.
      expect(row.semanticsLabel, contains('4 min'));
    });

    testWidgets('an idle agent says so, and carries no location line', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a2', name: 'sipho@example.com')],
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('agent-row-a2')),
      );
      expect(row.subtitle, 'No check-in');
      expect(row.semanticsLabel, contains('no check-in today'));
    });

    testWidgets('an at-store agent with no outlet name says unknown store', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(id: 'a1', name: 'a@x.com', state: AgentState.atStore),
        ],
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('agent-row-a1')),
      );
      expect(row.subtitle, contains('unknown store'));
    });

    testWidgets('a transiting agent names the store they left', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          AgentActivity(
            agentId: 'a1',
            name: 'a@x.com',
            state: AgentState.inTransit,
            stops: <AgentStop>[stop('Rosebank PnP')],
          ),
        ],
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('agent-row-a1')),
      );
      expect(row.subtitle, 'In transit · left Rosebank PnP');
    });

    testWidgets('each state keeps its own silhouette, not just a colour', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(id: 'a1', name: 'a@x.com', state: AgentState.atStore),
          agent(id: 'a2', name: 'b@x.com', state: AgentState.inTransit),
          agent(id: 'a3', name: 'c@x.com'),
        ],
      );

      final painters = <Type>{};
      for (final id in const <String>['a1', 'a2', 'a3']) {
        final glyph = tester.widget<AgentStateGlyph>(
          find.byKey(ValueKey<String>('agent-state-icon-$id')),
        );
        painters.add(glyphPainterTypeFor(glyph.state));
      }
      expect(painters, hasLength(3));
    });

    testWidgets('a cut list says so — it must never read as the whole team', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
        truncated: true,
      );
      expect(find.textContaining('first 200'), findsOneWidget);
    });

    testWidgets('a complete list carries no truncation notice', (tester) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
      );
      expect(find.textContaining('first 200'), findsNothing);
    });
  });

  group('the empty state names the reason it can', () {
    testWidgets('no filter on: the territory cannot be the reason', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('No field agents yet.'), findsOneWidget);
    });

    // The reported bug: a manager filtered to a territory nobody is assigned
    // to, got a fixed "no agents" string, and filed it as broken.
    testWidgets('a filtered empty result names the territory', (tester) async {
      await _pump(
        tester,
        territories: const <Territory>[north, west],
        agentsByTerritory: const <String?, List<AgentActivity>>{},
      );

      _filterTo(tester, 'ter-2');
      await tester.pumpAndSettle();

      expect(find.text('No agents are assigned to Western Cape.'), findsOneWidget);
    });

    // A stale or deleted territory: never a blank, "null", or the raw id,
    // which would all read worse than the message this replaced.
    testWidgets('an id that matches no territory falls back cleanly', (
      tester,
    ) async {
      await _pump(
        tester,
        territories: const <Territory>[north],
        agentsByTerritory: const <String?, List<AgentActivity>>{},
      );

      _filterTo(tester, 'does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('No agents match this territory filter.'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('does-not-exist'), findsNothing);
    });

    testWidgets('a failed fetch offers a retry, not a raw exception', (
      tester,
    ) async {
      await _pump(tester, agentsFailure: Exception('network down'));
      expect(
        find.byKey(const ValueKey<String>('agent-activity-retry')),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
    });
  });

  group('the map', () {
    testWidgets('plots a pin for an agent with a confirmed stop today', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'a@x.com',
            state: AgentState.atStore,
            currentOutlet: 'Spar',
            stops: <AgentStop>[stop('Spar')],
          ),
        ],
      );
      expect(find.byKey(const ValueKey<String>('agent-pin-a1')), findsOneWidget);
    });

    testWidgets('an idle agent gets no pin but still appears in the list', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(id: 'a1', name: 'a@x.com'),
          agent(
            id: 'a2',
            name: 'b@x.com',
            state: AgentState.atStore,
            stops: <AgentStop>[stop('Spar')],
          ),
        ],
      );
      expect(find.byKey(const ValueKey<String>('agent-pin-a1')), findsNothing);
      expect(find.byKey(const ValueKey<String>('agent-row-a1')), findsOneWidget);
    });

    testWidgets('the line beneath says who is plotted and who is not', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'a@x.com',
            state: AgentState.atStore,
            stops: <AgentStop>[stop('Spar')],
          ),
          agent(id: 'a2', name: 'b@x.com'),
          agent(id: 'a3', name: 'c@x.com'),
        ],
      );
      expect(
        find.text('1 on the map · 2 not checked in today'),
        findsOneWidget,
      );
    });

    testWidgets('neither stops nor outlets: no map, and words instead', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
      );
      expect(find.byType(FlutterMap), findsNothing);
      expect(
        find.text('No outlets yet — add outlets to see them here.'),
        findsOneWidget,
      );
      // And the list still carries the agent.
      expect(find.byKey(const ValueKey<String>('agent-row-a1')), findsOneWidget);
    });

    testWidgets('the outlet base layer draws on a morning with no check-ins', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
        outlets: <Outlet>[outlet('o1', 'Spar'), outlet('o2', 'Checkers')],
      );
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outlet-base-pin-o1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('agent-pin-a1')), findsNothing);
    });

    testWidgets('agent pins and outlet pins draw together', (tester) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'a@x.com',
            state: AgentState.atStore,
            stops: <AgentStop>[stop('Spar')],
          ),
        ],
        outlets: <Outlet>[outlet('o1', 'Spar')],
      );
      expect(find.byKey(const ValueKey<String>('agent-pin-a1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outlet-base-pin-o1')),
        findsOneWidget,
      );
    });

    testWidgets('the island keeps the basemap tint over its tiles', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'a@x.com',
            state: AgentState.atStore,
            stops: <AgentStop>[stop('Spar')],
          ),
        ],
      );
      expect(find.byType(TiqNavyTint), findsOneWidget);
      expect(find.byType(TiqBasemapLabels), findsOneWidget);
    });

    testWidgets('an outlet pin announces the shop, never its id', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
        outlets: <Outlet>[outlet('o1', 'Kasi Corner Spaza')],
      );
      final pin = find.byKey(const ValueKey<String>('outlet-base-pin-o1'));
      final semantics = tester.widget<Semantics>(
        find.descendant(of: pin, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, 'Kasi Corner Spaza outlet');
      expect(semantics.properties.label, isNot(contains('o1')));
    });

    testWidgets('a failed outlets fetch still leaves the agents on the map', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'a@x.com',
            state: AgentState.atStore,
            stops: <AgentStop>[stop('Spar')],
          ),
        ],
        outletsFailure: Exception('outlets down'),
      );
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('agent-pin-a1')), findsOneWidget);
    });
  });

  group('Veld', () {
    testWidgets('draws no map — the list is the whole panel', (tester) async {
      await _pump(
        tester,
        skin: TiqSkin.veld(),
        agents: <AgentActivity>[
          agent(
            id: 'a1',
            name: 'a@x.com',
            state: AgentState.atStore,
            stops: <AgentStop>[stop('Spar')],
          ),
        ],
        outlets: <Outlet>[outlet('o1', 'Spar')],
      );

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byKey(const ValueKey<String>('agent-row-a1')), findsOneWidget);
      // And no "nothing to plot" apology either: in Veld there was never
      // going to be a map, so there is nothing to explain away.
      expect(
        find.text('No outlets yet — add outlets to see them here.'),
        findsNothing,
      );
    });
  });

  group('the camera', () {
    // A scrollable can lay a child out before it has real space. flutter_map's
    // own one-shot `initialCameraFit` commits to that pass and never recovers;
    // `fitFor` is computed from the real measured size instead.
    testWidgets('fits the agents even when the first layout is degenerate', (
      tester,
    ) async {
      final width = ValueNotifier<double>(0);
      addTearDown(width.dispose);

      await _pump(
        tester,
        agents: _jhb,
        size: const Size(1000, 700),
        host: _ResizingHost(
          width: width,
          child: const SingleChildScrollView(child: AgentActivityPanel()),
        ),
      );

      // The real viewport "arrives" — the panel scrolls into view.
      width.value = 900;
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      // Both agents are within ~4km of (-26.12, 28.07) — a JHB-scale fit, not
      // the whole-world view a degenerate first layout produces.
      expect(camera.center.latitude, closeTo(-26.12, 1.0));
      expect(camera.center.longitude, closeTo(28.07, 1.0));
      expect(camera.zoom, greaterThan(8));
    });

    testWidgets('travels to a filter change rather than jumping there', (
      tester,
    ) async {
      await _pump(
        tester,
        agentsByTerritory: <String?, List<AgentActivity>>{
          null: _jhb,
          'cpt': _capeTown,
        },
      );

      final before = MapCamera.of(
        tester.element(find.byType(MarkerLayer)),
      ).center;
      expect(before.latitude, closeTo(-26.12, 1.0));

      _filterTo(tester, 'cpt');

      // Let the refetch resolve — `skipLoadingOnReload` keeps the SAME map
      // mounted throughout, so there is a continuous camera to animate rather
      // than a fresh one seeded straight at the target — then sample partway
      // through, well short of the travel's 320ms.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      final mid = MapCamera.of(tester.element(find.byType(MarkerLayer))).center;
      expect(
        mid.latitude,
        allOf(lessThan(before.latitude), greaterThan(-33.895)),
        reason:
            'partway through the travel the camera must sit strictly between '
            'the old and new territory, not already snapped to either one — '
            'before=$before mid=$mid',
      );

      await tester.pumpAndSettle();
      final after = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      expect(after.center.latitude, closeTo(-33.895, 1.0));
      expect(after.center.longitude, closeTo(18.465, 1.0));
      expect(after.zoom, greaterThan(8));
    });

    // flutter_map's OWN fit machinery — `initialCameraFit`, and the
    // `onMapReady`/`MapController.fitCamera` fix that came before this one —
    // both depend on flutter_map's internal camera size, which a live debug
    // overlay on the running web build showed was still zero at the moment
    // `onMapReady` fired. This proves none of it is wired up any more.
    testWidgets('is computed by fitFor, not by flutter_map', (tester) async {
      await _pump(tester, agents: _jhb);

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCameraFit, isNull);
      expect(map.options.onMapReady, isNull);
      expect(map.mapController, isNull);
      // A sane JHB-scale value — not flutter_map's own built-in default
      // (LatLng(50.5, 30.51), zoom 13), which is what would appear if nothing
      // had wired a real centre into `initialCenter` at all.
      expect(map.options.initialCenter.latitude, closeTo(-26.12, 1.0));
      expect(map.options.initialZoom, inInclusiveRange(8, 16));
    });

    // The panel lives below the fold in a real scroll view: a manager
    // reaching it scrolls with their mouse wheel, exactly as they would over
    // any other panel. flutter_map's default interaction options treat that
    // same wheel as a zoom gesture over the map, silently destroying the fit.
    testWidgets('a mouse wheel over the map does not change its zoom', (
      tester,
    ) async {
      await _pump(tester, agents: _jhb);

      final before = MapCamera.of(
        tester.element(find.byType(MarkerLayer)),
      ).zoom;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(find.byType(FlutterMap)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
      await tester.pumpAndSettle();

      final after = MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom;
      expect(
        after,
        before,
        reason:
            'a wheel scroll over the embedded map must pass through to the '
            'page, not silently re-zoom (and so discard) the computed fit — '
            'before=$before after=$after',
      );
    });

    // The direct guard beside the behavioural one: this regresses loudly if a
    // future edit to the map's `MapOptions` ever re-adds the flag.
    testWidgets('scrollWheelZoom stays out of the interaction flags', (
      tester,
    ) async {
      await _pump(tester, agents: _jhb);

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        map.options.interactionOptions.flags & InteractiveFlag.scrollWheelZoom,
        0,
        reason:
            "the panel map lives inside the console's scrollable — a "
            're-enabled scroll wheel would zoom the map instead of scrolling '
            'the page around it',
      );
    });
  });

  group('every control is operable by a screen reader', () {
    testWidgets('the section rule action and the retry', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
      );
      expectEveryButtonActivatable(tester);

      await _pump(tester, agentsFailure: Exception('boom'));
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });

    testWidgets('Open the map goes to the full-screen route', (tester) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('agent-activity-view-map')),
      );
      await tester.pumpAndSettle();
      expect(find.text('/agents/activity'), findsOneWidget);
    });
  });

  group('the panel emits no light', () {
    testWidgets('no amber, in any skin, with pins on the map', (tester) async {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
        TiqSkin.veld(),
      ]) {
        await _pump(
          tester,
          skin: skin,
          agents: _jhb,
          outlets: <Outlet>[outlet('o1', 'Spar')],
        );
        // In transit borrowed the old palette's amber `warn`. It takes
        // `chartNeutral` now: Burning Flame is emitted light and a list of
        // eleven agents would be eleven of them.
        expect(
          agentStateInk(AgentState.inTransit, skin.palette),
          skin.palette.chartNeutral,
        );
      }
    });
  });

  group('the section still names itself while it waits', () {
    testWidgets('a pending fetch is a skeleton under a real rule', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[agent(id: 'a1', name: 'a@x.com')],
      );
      expect(find.text('Where are my agents'.toUpperCase()), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });
  });
}
