import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/agent_state_glyph.dart';
import 'package:tradeiq_app/features/agents/data/agent_locations_repository.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/agents/presentation/live_location_layer.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

/// #153 T1 — the manager's live layer on the "Where are my agents" panel and
/// the trail map: six states by shape and word, age first, and "last updated".
final _serverTime = DateTime.utc(2026, 9, 15, 8, 30, 5);

Map<String, dynamic> _json() => {
  'serverTime': _serverTime.toIso8601String(),
  'intervalSeconds': 120,
  'staleAfterSeconds': 360,
  'offlineAfterSeconds': 1800,
  'maxAtStoreAccuracyM': 100,
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
    {
      'agentId': 'a-near',
      'name': 'Ayanda',
      'state': 'near_store',
      'lastPing': {'lat': -26.11, 'lng': 28.09, 'accuracyM': 180, 'recordedAt': '2026-09-15T08:29:05.000Z'},
      'ageSeconds': 60,
      'currentOutlet': null,
      'lastOutlet': {'id': 'o1', 'name': 'Sandton Spar', 'at': '2026-09-15T08:29:05.000Z', 'source': 'ping'},
    },
    {
      'agentId': 'a-declined',
      'name': 'Zanele',
      'state': 'not_sharing',
      'lastPing': null,
      'ageSeconds': null,
      'currentOutlet': null,
      'lastOutlet': {'id': 'o2', 'name': 'Rosebank PnP', 'at': '2026-09-15T07:00:00.000Z', 'source': 'check_in'},
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
    test('parses the six states and what each row carries', () {
      expect(page.serverTime, _serverTime);
      expect(page.truncated, isFalse);
      expect(page.maxAtStoreAccuracyM, 100);
      expect(page.agents.map((a) => a.state), [
        LiveAgentState.atStore,
        LiveAgentState.inTransit,
        LiveAgentState.stale,
        LiveAgentState.offline,
        LiveAgentState.offline,
        LiveAgentState.nearStore,
        LiveAgentState.notSharing,
      ]);
      final store = page.agents.first;
      expect(store.hasPosition, isTrue);
      expect(store.currentOutletName, 'Sandton Spar');
      expect(store.lastOutletFromPing, isTrue);
      expect(page.agents[1].lastOutletFromPing, isFalse);
      expect(page.agents[1].accuracyM, isNull);
      expect(page.agents[4].hasPosition, isFalse);
      expect(page.agents[4].ageSeconds, isNull);
      final near = page.agents[5];
      expect(near.hasPosition, isTrue);
      expect(near.accuracyM, 180);
      expect(near.currentOutletName, isNull);
      expect(near.lastOutletName, 'Sandton Spar');
      expect(page.agents[6].hasPosition, isFalse);
    });

    test('a declined agent is never pinned, even if a position slipped through', () {
      final json = _json();
      (json['data'] as List).last['lastPing'] = {
        'lat': -26.2,
        'lng': 28.1,
        'accuracyM': 5,
        'recordedAt': '2026-09-15T08:29:00.000Z',
      };
      final declined = AgentLocationsPage.fromJson(json).agents.last;
      expect(declined.state, LiveAgentState.notSharing);
      expect(declined.hasPosition, isFalse);
      expect(liveAgentMarkers([declined]), isEmpty);
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
    expect(liveAgentDescription(page.agents[5]), '1 min old · Near store · Ayanda · near Sandton Spar');
    // Not sharing has no position to age, so the state leads.
    expect(liveAgentDescription(page.agents[6]), 'Not sharing · Zanele · last check-in Rosebank PnP');
  });

  test('pin and age text for the new states', () {
    expect(livePinStateText(page.agents[5]), 'Near Sandton Spar');
    expect(livePinStateText(page.agents[0]), 'At store');
    expect(liveAgeText(page.agents[6]), '—');
    expect(liveAgeText(page.agents[4]), 'never shared');
    expect(liveStateLabel(LiveAgentState.nearStore), 'Near store');
    expect(liveStateLabel(LiveAgentState.notSharing), 'Not sharing');
  });

  test('the six live states differ by shape, not colour (#144)', () {
    final types = {for (final s in LiveAgentState.values) livePainterTypeFor(s)};
    expect(types, hasLength(6));
    // None of the live-only states may borrow the check-in "idle" silhouette.
    expect(types, isNot(contains(glyphPainterTypeFor(AgentState.idle))));
    // Near store claims neither the store nor the road.
    expect(livePainterTypeFor(LiveAgentState.nearStore), isNot(livePainterTypeFor(LiveAgentState.atStore)));
    expect(livePainterTypeFor(LiveAgentState.nearStore), isNot(livePainterTypeFor(LiveAgentState.inTransit)));
    // Not sharing is not offline.
    expect(livePainterTypeFor(LiveAgentState.notSharing), isNot(livePainterTypeFor(LiveAgentState.offline)));
  });

  for (final (name, theme) in [('light', AppTheme.light()), ('night', AppTheme.dark())]) {
    for (final onDark in [false, true]) {
      testWidgets('the legend names every state by glyph and word ($name theme, onDark: $onDark)', (tester) async {
        await tester.pumpWidget(
          routedApp(Scaffold(body: LiveStateLegend(onDark: onDark)), theme: theme),
        );
        await tester.pumpAndSettle();
        for (final state in LiveAgentState.values) {
          final entry = find.byKey(ValueKey('live-legend-${state.name}'));
          expect(entry, findsOneWidget);
          expect(find.descendant(of: entry, matching: find.text(liveStateLabel(state))), findsOneWidget);
          final glyph = tester.widget<LiveAgentStateGlyph>(
            find.descendant(of: entry, matching: find.byType(LiveAgentStateGlyph)),
          );
          expect(glyph.state, state);
          final paint = tester.widget<CustomPaint>(
            find.descendant(of: entry, matching: find.byType(CustomPaint)).first,
          );
          expect(paint.painter.runtimeType, livePainterTypeFor(state));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

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
        for (final label in ['At store', 'Near store', 'In transit', 'Stale', 'Offline', 'Not sharing']) {
          expect(find.text(label), findsWidgets);
        }
        for (final (id, age) in [
          ('a-store', '45s old'),
          ('a-transit', '2 min old'),
          ('a-stale', '12 min old'),
          ('a-offline', '2 h 5 min old'),
          ('a-never', 'never shared'),
          ('a-near', '1 min old · Near store'),
          ('a-declined', 'Not sharing'),
        ]) {
          final label = tester.getSemantics(find.byKey(ValueKey('live-row-$id'))).label;
          expect(label, startsWith(age));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('rows for near store and not sharing carry glyph, word and place ($name theme)', (tester) async {
        await tester.pumpWidget(section(theme: theme));
        await tester.pumpAndSettle();

        final near = find.byKey(const ValueKey('live-row-a-near'));
        expect(find.descendant(of: near, matching: find.text('1 min')), findsOneWidget);
        expect(find.descendant(of: near, matching: find.text('Near store')), findsOneWidget);
        expect(find.descendant(of: near, matching: find.text('Ayanda · near Sandton Spar')), findsOneWidget);
        expect(
          tester.widget<LiveAgentStateGlyph>(find.descendant(of: near, matching: find.byType(LiveAgentStateGlyph))).state,
          LiveAgentState.nearStore,
        );

        final declined = find.byKey(const ValueKey('live-row-a-declined'));
        expect(find.descendant(of: declined, matching: find.text('—')), findsOneWidget);
        expect(find.descendant(of: declined, matching: find.text('Not sharing')), findsOneWidget);
        expect(find.descendant(of: declined, matching: find.text('Zanele · last check-in Rosebank PnP')), findsOneWidget);
        expect(
          tester
              .widget<LiveAgentStateGlyph>(find.descendant(of: declined, matching: find.byType(LiveAgentStateGlyph)))
              .state,
          LiveAgentState.notSharing,
        );
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
      // Near store: its own pin, labelled with the store it is near.
      final nearPin = find.byKey(const ValueKey('live-agent-pin-a-near'));
      expect(nearPin, findsOneWidget);
      expect(find.descendant(of: nearPin, matching: find.text('1 min · Near Sandton Spar')), findsOneWidget);
      expect(
        tester.widget<LiveAgentStateGlyph>(find.descendant(of: nearPin, matching: find.byType(LiveAgentStateGlyph))).state,
        LiveAgentState.nearStore,
      );
      // Read off the pin's own Semantics widget: on the map, overlapping pins
      // share a merged semantics node, so getSemantics would find a neighbour.
      expect(
        tester.widget<Semantics>(find.descendant(of: nearPin, matching: find.byType(Semantics)).first).properties.label,
        'Live location: 1 min old · Near store · Ayanda · near Sandton Spar',
      );
      // Not sharing: no pin at all — but still a row that says so.
      expect(find.byKey(const ValueKey('live-agent-pin-a-declined')), findsNothing);
      expect(find.byKey(const ValueKey('live-row-a-declined')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('live-last-updated')), findsOneWidget);
      // T0's check-in pin is still there beside the live one.
      expect(find.byKey(const ValueKey('agent-pin-a-store')), findsOneWidget);
    });
  }

  // The two trail-map cases that used to live here moved to
  // `agent_trail_screen_test.dart` with the screen itself: the trail is a
  // Torchlight route now and its harness is the worklist one, while this file
  // stays about the live layer that the console dashboard also draws.
}
