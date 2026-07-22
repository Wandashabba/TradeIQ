import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/agents/presentation/agent_trail_screen.dart';

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
}
