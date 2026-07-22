import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

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

/// Returns different agents depending on the requested territory — just
/// enough to prove the map re-fits when the territory filter changes,
/// without a full backend fake.
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

class _FailingAgentsRepository implements AgentsRepository {
  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async =>
      throw Exception('network down');
}

AgentActivity _agent({
  required String id,
  required String name,
  required AgentState state,
  String? currentOutlet,
  DateTime? lastSeen,
  List<AgentStop> stops = const [],
}) =>
    AgentActivity(
      agentId: id,
      name: name,
      state: state,
      currentOutletName: currentOutlet,
      lastSeenAt: lastSeen,
      stops: stops,
    );

AgentStop _stop(String outletName, {double lat = -26.10, double lng = 28.05}) =>
    AgentStop(
      visitId: 'v1',
      outletId: 'o1',
      outletName: outletName,
      lat: lat,
      lng: lng,
      checkinTs: DateTime.now().subtract(const Duration(minutes: 20)),
      inProgress: false,
    );

/// Hosts [child] at a width the test controls directly, so a test can drive
/// exactly the sequence a real screen produces without depending on
/// `ListView`'s cache-extent heuristics: first layout at zero width (a
/// scrollable can lay a child out before it has real space — see the
/// regression test below), then a later, real width once it "arrives".
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
        child: SizedBox(width: widget.width.value, height: 600, child: widget.child),
      );
}

void main() {
  testWidgets('renders an at-store agent with their outlet', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'thabo@example.com',
              state: AgentState.atStore,
              currentOutlet: 'Sandton Spar',
              lastSeen: DateTime.now().subtract(const Duration(minutes: 4)),
            ),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('thabo@example.com'), findsOneWidget);
    expect(find.textContaining('Sandton Spar'), findsOneWidget);
    expect(find.textContaining('At store'), findsOneWidget);
  });

  testWidgets('renders an idle agent as not checked in', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(id: 'a2', name: 'sipho@example.com', state: AgentState.idle),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No check-in'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no agents', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository([])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No agents'), findsOneWidget);
  });

  // A cut list must never read as the whole team. Without this notice a
  // manager sees 200 rows and concludes that is everyone.
  testWidgets('says so when the server had more agents than it returned', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository(
            [_agent(id: 'a1', name: 'a@x.com', state: AgentState.idle)],
            truncated: true,
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('first 200'), findsOneWidget);
  });

  testWidgets('shows no truncation notice when the list is complete', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository(
            [_agent(id: 'a1', name: 'a@x.com', state: AgentState.idle)],
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('first 200'), findsNothing);
  });

  // State must never be carried by colour alone (#144's N4 rule). Each state
  // has a distinct icon AND a text label.
  testWidgets('gives each state a distinct icon as well as a label', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(id: 'a1', name: 'a@x.com', state: AgentState.atStore, currentOutlet: 'Spar'),
            _agent(id: 'a2', name: 'b@x.com', state: AgentState.inTransit),
            _agent(id: 'a3', name: 'c@x.com', state: AgentState.idle),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('agent-state-icon-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-state-icon-a2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-state-icon-a3')), findsOneWidget);

    final icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .map((i) => i.icon)
        .toSet();
    // Three states rendered → at least three distinct glyphs.
    expect(icons.length, greaterThanOrEqualTo(3));
  });

  testWidgets('shows the outlet a transiting agent left, from their stops', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'a@x.com',
              state: AgentState.inTransit,
              stops: [
                AgentStop(
                  visitId: 'v1',
                  outletId: 'o1',
                  outletName: 'Pick n Pay Hyper Boksburg North',
                  lat: -26.0,
                  lng: 28.0,
                  checkinTs: DateTime.now().subtract(const Duration(hours: 1)),
                  inProgress: false,
                ),
              ],
            ),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('left Pick n Pay Hyper Boksburg North'),
      findsOneWidget,
    );
  });

  testWidgets('falls back to "unknown store" for an at-store agent with no outlet name', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'a@x.com',
              state: AgentState.atStore,
              currentOutlet: null,
            ),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('unknown store'), findsOneWidget);
  });

  testWidgets('shows a Retry affordance when the fetch fails', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(_FailingAgentsRepository()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('plots a pin for an agent with a confirmed stop today', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'thabo@example.com',
              state: AgentState.atStore,
              currentOutlet: 'Sandton Spar',
              stops: [_stop('Sandton Spar')],
            ),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agent-pin-a1')), findsOneWidget);
  });

  // The list is what stops an agent with no confirmed stop from vanishing:
  // they cannot be plotted, so the row is the only place they still appear.
  testWidgets('an idle agent gets no pin but still appears in the list', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'thabo@example.com',
              state: AgentState.atStore,
              currentOutlet: 'Sandton Spar',
              stops: [_stop('Sandton Spar')],
            ),
            _agent(id: 'a2', name: 'sipho@example.com', state: AgentState.idle),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('agent-pin-a2')), findsNothing);
    expect(find.text('sipho@example.com'), findsOneWidget);
  });

  testWidgets('the footer reports how many are plotted versus not', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'a@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Spar',
              stops: [_stop('Spar')],
            ),
            _agent(
              id: 'a2',
              name: 'b@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Checkers',
              stops: [_stop('Checkers')],
            ),
            _agent(id: 'a3', name: 'c@x.com', state: AgentState.idle),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 on the map · 1 not checked in today'), findsOneWidget);
  });

  // A grey, pinless map would read as broken rather than honest — so when
  // nobody has a confirmed stop, no map renders at all.
  testWidgets('renders no map when no agent has a confirmed stop today', (tester) async {
    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(id: 'a1', name: 'a@x.com', state: AgentState.idle),
            _agent(id: 'a2', name: 'b@x.com', state: AgentState.inTransit),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('Nobody has checked in yet today'), findsOneWidget);
  });

  // Regression test for the "map stuck at world zoom" bug: the panel lives
  // inside DashboardShellScreen's ListView, below the fold on a typical
  // screen — so it can be laid out once, with a degenerate viewport, before
  // it is ever scrolled into view. flutter_map applies `initialCameraFit`
  // exactly ONCE per State and never retries, so a bad first fit sticks even
  // once the real viewport arrives.
  //
  // Pumping this inside an actual `ListView` and scrolling it into view does
  // NOT reproduce the bug: flutter's sliver layout simply skips laying the
  // panel out at all until it nears the viewport, so it never gets a
  // degenerate first pass in a plain widget test. `_ResizingHost` reproduces
  // the mechanism the bug actually depends on directly and deterministically
  // — a first layout at zero width, then a later, real one — without relying
  // on sliver caching internals a widget test can't reliably control.
  testWidgets('camera fits the agents even when the first layout is degenerate', (tester) async {
    final width = ValueNotifier<double>(0);
    addTearDown(width.dispose);

    await tester.pumpWidget(routedApp(
      _ResizingHost(
        width: width,
        child: const Scaffold(body: AgentActivityPanel()),
      ),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'a@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Spar',
              stops: [_stop('Spar', lat: -26.10, lng: 28.05)],
            ),
            _agent(
              id: 'a2',
              name: 'b@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Checkers',
              stops: [_stop('Checkers', lat: -26.14, lng: 28.09)],
            ),
          ]),
        ),
      ],
    ));

    // First layout: zero width, before the data or the real viewport exist —
    // this is the pass flutter_map's one-shot `initialCameraFit` must NOT be
    // allowed to commit to.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The real viewport "arrives" — e.g. the panel scrolls into view.
    width.value = 900;
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
    // Both agents are within ~4km of (-26.12, 28.07) — a sane, JHB-scale fit,
    // not the whole-world view a degenerate first layout produces.
    expect(camera.center.latitude, closeTo(-26.12, 1.0));
    expect(camera.center.longitude, closeTo(28.07, 1.0));
    expect(camera.zoom, greaterThan(8));
  });

  // Same one-shot-fit failure as the degenerate-viewport test above, reached
  // a different way: the dashboard's territory filter sits a few hundred
  // pixels above this panel, and switching it is an ordinary click that
  // re-fetches with different agents in a different place — with the
  // panel's own size unchanged throughout. Without a coordinate fingerprint
  // in the map's key, the camera would stay pointed at the old territory.
  testWidgets('re-fits the camera when a territory-filter change moves the pins', (tester) async {
    final jhb = [
      _agent(
        id: 'a1',
        name: 'a@x.com',
        state: AgentState.atStore,
        currentOutlet: 'Spar',
        stops: [_stop('Spar', lat: -26.10, lng: 28.05)],
      ),
      _agent(
        id: 'a2',
        name: 'b@x.com',
        state: AgentState.atStore,
        currentOutlet: 'Checkers',
        stops: [_stop('Checkers', lat: -26.14, lng: 28.09)],
      ),
    ];
    final capeTown = [
      _agent(
        id: 'a3',
        name: 'c@x.com',
        state: AgentState.atStore,
        currentOutlet: 'Waterfront',
        stops: [_stop('Waterfront', lat: -33.90, lng: 18.42)],
      ),
      _agent(
        id: 'a4',
        name: 'd@x.com',
        state: AgentState.atStore,
        currentOutlet: 'Canal Walk',
        stops: [_stop('Canal Walk', lat: -33.89, lng: 18.51)],
      ),
    ];

    await tester.pumpWidget(routedApp(
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _TerritoryAwareAgentsRepository({null: jhb, 'cpt': capeTown}),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final before = MapCamera.of(tester.element(find.byType(MarkerLayer))).center;
    expect(before.latitude, closeTo(-26.12, 1.0));

    // The territory-filter click: same provider, same panel size, a
    // completely different set of coordinates.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AgentActivityPanel)),
    );
    container.read(dashboardFilterProvider.notifier).set(
          const DashboardFilter(territoryId: 'cpt'),
        );
    await tester.pumpAndSettle();

    final after = MapCamera.of(tester.element(find.byType(MarkerLayer)));
    expect(after.center.latitude, closeTo(-33.895, 1.0));
    expect(after.center.longitude, closeTo(18.465, 1.0));
    expect(after.zoom, greaterThan(8));
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
      const Scaffold(body: AgentActivityPanel()),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'a@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Spar',
              stops: [_stop('Spar', lat: -26.10, lng: 28.05)],
            ),
            _agent(
              id: 'a2',
              name: 'b@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Checkers',
              stops: [_stop('Checkers', lat: -26.14, lng: 28.09)],
            ),
          ]),
        ),
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

  // The panel lives below the fold in DashboardShellScreen's real ListView —
  // a manager reaching it scrolls with their mouse wheel, exactly as they
  // would over any other panel. flutter_map's default interactionOptions
  // treat that same wheel as a zoom gesture over the map, silently
  // destroying the fit `fitFor` computed. Reproduced here with a real
  // ListView ancestor and a genuine PointerScrollEvent over the map's own
  // rectangle — not just a unit check of the options object — because a
  // test that could pass by accident is worse than none, given how many
  // wrong diagnoses this bug has already absorbed.
  testWidgets('a mouse wheel over the map does not change its zoom', (tester) async {
    await tester.pumpWidget(routedApp(
      Scaffold(body: ListView(children: const [AgentActivityPanel()])),
      overrides: [
        agentsRepositoryProvider.overrideWithValue(
          _FakeAgentsRepository([
            _agent(
              id: 'a1',
              name: 'a@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Spar',
              stops: [_stop('Spar', lat: -26.10, lng: 28.05)],
            ),
            _agent(
              id: 'a2',
              name: 'b@x.com',
              state: AgentState.atStore,
              currentOutlet: 'Checkers',
              stops: [_stop('Checkers', lat: -26.14, lng: 28.09)],
            ),
          ]),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final before = MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final mapCenter = tester.getCenter(find.byType(FlutterMap));
    pointer.hover(mapCenter);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
    await tester.pumpAndSettle();

    final after = MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom;
    expect(
      after,
      before,
      reason: 'a wheel scroll over the embedded map must pass through to the '
          'page, not silently re-zoom (and so discard) the computed fit — '
          'before=$before after=$after',
    );
  });
}
