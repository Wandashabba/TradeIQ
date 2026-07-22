import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
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

AgentStop _stop(String outletName) => AgentStop(
      visitId: 'v1',
      outletId: 'o1',
      outletName: outletName,
      lat: -26.10,
      lng: 28.05,
      checkinTs: DateTime.now().subtract(const Duration(minutes: 20)),
      inProgress: false,
    );

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
}
