import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/agent_state_glyph.dart';
import 'package:tradeiq_app/features/agents/data/agent_locations_repository.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/agents/presentation/agent_trail_screen.dart';
import 'package:tradeiq_app/features/agents/presentation/live_location_layer.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

/// #153 T1 — the manager's live layer on the "Where are my agents" panel and
/// the trail map: four states by shape and word, age first, and "last updated".
final _serverTime = DateTime.utc(2026, 9, 15, 8, 30, 5);

Map<String, dynamic> _json() => {
  'serverTime': _serverTime.toIso8601String(),
  'intervalSeconds': 120,
  'staleAfterSeconds': 360,
  'offlineAfterSeconds': 1800,
  'nextCursor': null,
  'data': [
    {
      'agentId': 'a-store',
      'name': 'Thabo',
      'state': 'at_store',
      'lastPing': {'lat': -26.1, 'lng': 28.05, 'accuracyM': 8, 'recordedAt': '2026-09-15T08:29:20.000Z'},
      'ageSeconds': 45,
      'currentOutlet': {'id': 'o1', 'name': 'Sandton Spar'},
      'lastOutlet': {'id': 'o1', 'name': 'Sandton Spar', 'at': '2026-09-15T08:29:20.000Z', 'source': 'ping'},
    },
    {
      'agentId': 'a-transit',
      'name': 'Lerato',
      'state': 'in_transit',
      'lastPing': {'lat': -26.12, 'lng': 28.06, 'accuracyM': null, 'recordedAt': '2026-09-15T08:28:05.000Z'},
      'ageSeconds': 120,
      'currentOutlet': null,
      'lastOutlet': {'id': 'o2', 'name': 'Rosebank PnP', 'at': '2026-09-15T07:10:00.000Z', 'source': 'check_in'},
    },
    {
      'agentId': 'a-stale',
      'name': 'Sipho',
      'state': 'stale',
      'lastPing': {'lat': -26.14, 'lng': 28.07, 'recordedAt': '2026-09-15T08:18:05.000Z'},
      'ageSeconds': 720,
      'currentOutlet': null,
      'lastOutlet': null,
    },
    {
      'agentId': 'a-offline',
      'name': 'Naledi',
      'state': 'offline',
      'lastPing': {'lat': -26.16, 'lng': 28.08, 'recordedAt': '2026-09-15T06:25:05.000Z'},
      'ageSeconds': 7500,
      'currentOutlet': null,
      'lastOutlet': null,
    },
    {
      'agentId': 'a-never',
      'name': 'Pieter',
      'state': 'offline',
      'lastPing': null,
      'ageSeconds': null,
      'currentOutlet': null,
      'lastOutlet': null,
    },
  ],
};

class _FakeLocations implements AgentLocationsRepository {
  _FakeLocations(this.page);
  final AgentLocationsPage page;
  int calls = 0;

  @override
  Future<AgentLocationsPage> listLocations({String? territoryId}) async {
    calls++;
    return page;
  }
}

class _FakeActivity implements AgentsRepository {
  _FakeActivity(this.agents);
  final List<AgentActivity> agents;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async => AgentActivityPage(agents: agents, truncated: false);
}

final _checkedIn = AgentActivity(
  agentId: 'a-store',
  name: 'Thabo',
  state: AgentState.atStore,
  currentOutletName: 'Sandton Spar',
  lastSeenAt: DateTime(2026, 9, 15, 8),
  stops: [
    AgentStop(
      visitId: 'v1',
      outletId: 'o1',
      outletName: 'Sandton Spar',
      lat: -26.1,
      lng: 28.05,
      checkinTs: DateTime.now().subtract(const Duration(minutes: 30)),
      inProgress: true,
    ),
  ],
);

void main() {
  final page = AgentLocationsPage.fromJson(_json());

  group('AgentLocationsPage.fromJson', () {
    test('parses the four states and what each row carries', () {
      expect(page.serverTime, _serverTime);
      expect(page.truncated, isFalse);
      expect(page.agents.map((a) => a.state), [
        LiveAgentState.atStore,
        LiveAgentState.inTransit,
        LiveAgentState.stale,
        LiveAgentState.offline,
        LiveAgentState.offline,
      ]);
      final store = page.agents.first;
      expect(store.hasPosition, isTrue);
      expect(store.currentOutletName, 'Sandton Spar');
      expect(store.lastOutletFromPing, isTrue);
      expect(page.agents[1].lastOutletFromPing, isFalse);
      expect(page.agents[1].accuracyM, isNull);
      expect(page.agents.last.hasPosition, isFalse);
      expect(page.agents.last.ageSeconds, isNull);
    });

    test('an unknown state claims the least: offline', () {
      final json = _json();
      (json['data'] as List).first['state'] = 'teleporting';
      json['nextCursor'] = 'x';
      final parsed = AgentLocationsPage.fromJson(json);
      expect(parsed.agents.first.state, LiveAgentState.offline);
      expect(parsed.truncated, isTrue);
    });
  });

  test('formatAgeSeconds', () {
    expect(formatAgeSeconds(null), 'never shared');
    expect(formatAgeSeconds(45), '45s');
    expect(formatAgeSeconds(120), '2 min');
    expect(formatAgeSeconds(3600), '1 h');
    expect(formatAgeSeconds(7500), '2 h 5 min');
    expect(formatAgeSeconds(3 * 86400 + 5), '3 d');
  });

  test('descriptions lead with age and name where the place came from', () {
    expect(liveAgentDescription(page.agents[0]), '45s old · At store · Thabo · at Sandton Spar');
    expect(liveAgentDescription(page.agents[1]), '2 min old · In transit · Lerato · last check-in Rosebank PnP');
    expect(liveAgentDescription(page.agents[4]), 'never shared · Offline · Pieter');
  });

  test('the four live states differ by shape, not colour (#144)', () {
    final types = {for (final s in LiveAgentState.values) livePainterTypeFor(s)};
    expect(types, hasLength(4));
    // Stale and offline must not borrow the check-in "idle" silhouette.
    expect(types, isNot(contains(glyphPainterTypeFor(AgentState.idle))));
  });

  group('LiveLocationsSection', () {
    Widget section({ThemeData? theme}) => routedApp(
      const SingleChildScrollView(child: LiveLocationsSection()),
      theme: theme,
      overrides: [
        agentLocationsRepositoryProvider.overrideWithValue(_FakeLocations(page)),
        liveLocationsPollIntervalProvider.overrideWithValue(null),
      ],
    );

    for (final (name, theme) in [('light', AppTheme.light()), ('night', AppTheme.dark())]) {
      testWidgets('shows last updated, the legend, and rows age first ($name theme)', (tester) async {
        await tester.pumpWidget(section(theme: theme));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('live-last-updated')), findsOneWidget);
        expect(find.text('Last updated ${formatUpdatedAt(_serverTime)}'), findsOneWidget);
        for (final state in LiveAgentState.values) {
          expect(find.byKey(ValueKey('live-legend-${state.name}')), findsOneWidget);
        }
        for (final label in ['At store', 'In transit', 'Stale', 'Offline']) {
          expect(find.text(label), findsWidgets);
        }
        for (final (id, age) in [
          ('a-store', '45s old'),
          ('a-transit', '2 min old'),
          ('a-stale', '12 min old'),
          ('a-offline', '2 h 5 min old'),
          ('a-never', 'never shared'),
        ]) {
          final label = tester.getSemantics(find.byKey(ValueKey('live-row-$id'))).label;
          expect(label, startsWith(age));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the last update on screen when a poll fails', (tester) async {
      await tester.pumpWidget(section());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-refresh-failed')), findsNothing);
      expect(find.byKey(const ValueKey('live-row-a-store')), findsOneWidget);
    });
  });

  testWidgets('polls on the interval, and stops when nothing is watching', (tester) async {
    final repo = _FakeLocations(page);
    final container = ProviderContainer(
      overrides: [
        agentLocationsRepositoryProvider.overrideWithValue(repo),
        liveLocationsPollIntervalProvider.overrideWithValue(const Duration(seconds: 30)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(liveAgentLocationsProvider, (_, _) {});
    await tester.pump();
    expect(repo.calls, 1);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(repo.calls, 2);

    sub.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 90));
    expect(repo.calls, 2);
  });

  // Pumped as a Scaffold body in a tall view, as the T0 panel tests pump it. A
  // scroll view around the panel hands flutter_map's attribution row an
  // unbounded height and it overflows, which is the basemap's layout and not
  // this layer's; in the app the panel sits in the dashboard's ListView.
  for (final (name, theme) in [('light', AppTheme.light()), ('night', AppTheme.dark())]) {
    testWidgets('the dashboard panel draws live pins with age-first labels ($name theme)', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        routedApp(
          const Scaffold(body: AgentActivityPanel()),
          theme: theme,
          overrides: [
            agentsRepositoryProvider.overrideWithValue(_FakeActivity([_checkedIn])),
            outletsListProvider.overrideWith((ref) async => const <Outlet>[]),
            agentLocationsRepositoryProvider.overrideWithValue(_FakeLocations(page)),
            liveLocationsPollIntervalProvider.overrideWithValue(null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      for (final id in ['a-store', 'a-transit', 'a-stale', 'a-offline']) {
        expect(find.byKey(ValueKey('live-agent-pin-$id')), findsOneWidget);
      }
      // Never shared: no position, no pin — but still a row.
      expect(find.byKey(const ValueKey('live-agent-pin-a-never')), findsNothing);
      expect(find.byKey(const ValueKey('live-row-a-never')), findsOneWidget);
      expect(find.text('45s · At store'), findsOneWidget);
      expect(find.text('2 h 5 min · Offline'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-last-updated')), findsOneWidget);
      // T0's check-in pin is still there beside the live one.
      expect(find.byKey(const ValueKey('agent-pin-a-store')), findsOneWidget);
    });
  }

  testWidgets('today’s trail map carries the live layer and says when it was updated', (tester) async {
    AgentTrailScreen.debugDisableGlowBreathing = true;
    addTearDown(() => AgentTrailScreen.debugDisableGlowBreathing = false);

    await tester.pumpWidget(
      routedApp(
        const AgentTrailScreen(),
        overrides: [
          agentsRepositoryProvider.overrideWithValue(_FakeActivity([_checkedIn])),
          agentLocationsRepositoryProvider.overrideWithValue(_FakeLocations(page)),
          liveLocationsPollIntervalProvider.overrideWithValue(null),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trail-live-legend')), findsOneWidget);
    expect(find.textContaining('Last updated ${formatUpdatedAt(_serverTime)}'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-agent-pin-a-transit')), findsOneWidget);
    // The T0 trail stays.
    expect(find.byKey(const ValueKey('agent-stop-a-store-0')), findsOneWidget);
  });

  testWidgets('the trail map shows live positions even before anyone checks in', (tester) async {
    await tester.pumpWidget(
      routedApp(
        const AgentTrailScreen(),
        overrides: [
          agentsRepositoryProvider.overrideWithValue(_FakeActivity(const [])),
          agentLocationsRepositoryProvider.overrideWithValue(_FakeLocations(page)),
          liveLocationsPollIntervalProvider.overrideWithValue(null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No check-ins on this day.'), findsNothing);
    expect(find.byKey(const ValueKey('live-agent-pin-a-store')), findsOneWidget);
  });
}
