import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/agents/data/agent_locations_repository.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/agents/presentation/agent_trail_screen.dart';
import 'package:tradeiq_app/features/agents/presentation/live_location_layer.dart'
    show formatUpdatedAt;
import 'package:tradeiq_app/features/agents/presentation/trail_map.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

AgentStop _stop(
  String id,
  String name,
  double lat,
  double lng,
  int hour, {
  bool inProgress = false,
}) => AgentStop(
  visitId: id,
  outletId: 'o-$id',
  outletName: name,
  lat: lat,
  lng: lng,
  checkinTs: DateTime(2026, 7, 22, hour),
  inProgress: inProgress,
);

AgentActivity _agent({
  String agentId = 'a1',
  String name = 'Thandi Mokoena',
  List<AgentStop>? stops,
  String? currentOutletName,
}) => AgentActivity(
  agentId: agentId,
  name: name,
  state: AgentState.inTransit,
  currentOutletName: currentOutletName,
  lastSeenAt: DateTime(2026, 7, 22, 11),
  stops:
      stops ??
      <AgentStop>[
        _stop('v1', 'Sandton Spar', -26.10, 28.05, 8),
        _stop('v2', 'Kasi Corner Spaza', -26.12, 28.07, 11),
      ],
);

class _FakeAgents implements AgentsRepository {
  _FakeAgents({
    this.agents = const <AgentActivity>[],
    this.truncated = false,
    this.failure,
    this.pending = false,
  });

  final List<AgentActivity> agents;
  final bool truncated;
  final Object? failure;
  final bool pending;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async {
    if (failure != null) throw failure!;
    if (pending) return Completer<AgentActivityPage>().future;
    return AgentActivityPage(agents: agents, truncated: truncated);
  }
}

final DateTime _serverTime = DateTime.utc(2026, 7, 22, 11, 30, 5);

/// A live page with one agent who is currently moving. Parsed from the wire
/// shape rather than constructed, so the fixture cannot drift from what the
/// server actually sends.
AgentLocationsPage _livePage({bool withAgent = true}) =>
    AgentLocationsPage.fromJson(<String, dynamic>{
      'serverTime': _serverTime.toIso8601String(),
      'intervalSeconds': 120,
      'staleAfterSeconds': 360,
      'offlineAfterSeconds': 1800,
      'maxAtStoreAccuracyM': 100,
      'nextCursor': null,
      'data': <dynamic>[
        if (withAgent)
          <String, dynamic>{
            'agentId': 'a-transit',
            'name': 'Busi Dlamini',
            'state': 'in_transit',
            'lastPing': <String, dynamic>{
              'lat': -26.11,
              'lng': 28.06,
              'accuracyM': 20,
              'recordedAt': '2026-07-22T11:29:00.000Z',
            },
            'ageSeconds': 65,
          },
      ],
    });

class _Locations implements AgentLocationsRepository {
  _Locations(this.page);

  final AgentLocationsPage page;

  @override
  Future<AgentLocationsPage> listLocations({String? territoryId}) async => page;
}

/// A phone tall enough that the trail list is on screen under the map band.
///
/// The census and the overflow cases keep the real 360x720 device; these are
/// assertions about what the list SAYS, and scrolling past a live basemap to
/// reach it tests flutter_map's gesture arena rather than the screen.
const Size _tall = Size(360, 1400);

Future<void> _pump(
  WidgetTester tester, {
  List<AgentActivity> agents = const <AgentActivity>[],
  bool truncated = false,
  Object? failure,
  bool pending = false,
  AgentLocationsPage? live,
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = _tall,
  Locale? locale,
}) => pumpWorklist(
  tester,
  const AgentTrailScreen(),
  skin: skin,
  size: size,
  textScale: textScale,
  locale: locale,
  path: '/agents/activity',
  settle: !pending,
  overrides: <Override>[
    agentsRepositoryProvider.overrideWithValue(
      _FakeAgents(
        agents: agents,
        truncated: truncated,
        failure: failure,
        pending: pending,
      ),
    ),
    agentLocationsRepositoryProvider.overrideWithValue(
      _Locations(live ?? _livePage(withAgent: false)),
    ),
    // The poll is a Timer, and a pending Timer fails the test that disposes
    // the tree — presenting as a hang two tests later rather than as the
    // poll's own fault.
    liveLocationsPollIntervalProvider.overrideWithValue(null),
  ],
);

/// Painted text, ignoring case.
///
/// The kit uppercases eyebrows and field labels for display while the ARB
/// holds sentence case, so a case-sensitive `textContaining` would pass on an
/// English eyebrow simply by failing to see it. Ignoring case makes the
/// absence assertions below stricter, not looser.
Finder paintedIgnoringCase(String text) {
  final needle = text.toUpperCase();
  return find.byWidgetPredicate(
    (Widget w) => w is Text && (w.data ?? '').toUpperCase().contains(needle),
    description: 'text containing "$text", ignoring case',
  );
}

void main() {
  setUp(() => TrailMap.debugFailureThreshold = 1 << 30);
  tearDown(() => TrailMap.debugFailureThreshold = 6);

  group('the trail is a list as well as a map', () {
    testWidgets('every stop is a row, in order, with its time', (tester) async {
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(find.textContaining('1. Sandton Spar'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
    });

    testWidgets('a row names the agent, never an agent id', (tester) async {
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(find.text('Thandi Mokoena'), findsOneWidget);
      expect(find.textContaining('a1'), findsNothing);
    });

    testWidgets('the stop count is spoken, not only painted', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(
        find.bySemanticsLabel(RegExp('Thandi Mokoena.*Field agent.*2 stops')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the last stop says so in words, not in a glow', (
      tester,
    ) async {
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(find.text('Last stop'), findsOneWidget);
    });

    testWidgets('an unfinished visit is not read as a finished one', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          _agent(
            stops: <AgentStop>[
              _stop('v1', 'Sandton Spar', -26.10, 28.05, 8, inProgress: true),
            ],
          ),
        ],
      );

      expect(find.text('Still in this shop'), findsOneWidget);
    });

    testWidgets('a stop opens its visit, by thumb and by reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      // The pin on the map carries the same outlet, so the finder is scoped
      // to the row — both are buttons, and both open the same visit.
      final node = tester.getSemantics(
        find.descendant(
          of: find.byType(SoftRow),
          matching: find.bySemanticsLabel(RegExp('1. Sandton Spar')),
        ),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.textContaining('1. Sandton Spar'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/visits/v1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the pin on the map opens the same visit as its row (#208)', (
      tester,
    ) async {
      // The migration carried the pin's `button: true` across and left its
      // callback behind, so for a screen reader the map was two hundred
      // buttons that announced a stop and did nothing — the very defect the
      // kit's button family was fixed for, rebuilt locally. The row beside
      // it kept working, which is why only a test that presses the PIN
      // catches this.
      final handle = tester.ensureSemantics();
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      final pin = find.byKey(const ValueKey<String>('agent-stop-a1-0'));
      expect(pin, findsOneWidget);
      expect(
        tester
            .getSemantics(pin)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'a pin that announces itself a button must be pressable',
      );

      // `warnIfMissed: false`: the pin sits on a live basemap, so the hit
      // test walks flutter_map's arena before it reaches the marker. The
      // assertion above is the one about the reader; this one is the thumb.
      await tester.tap(pin, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('stub:/visits/v1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an agent with no stops is not given an empty trail', (
      tester,
    ) async {
      await _pump(
        tester,
        agents: <AgentActivity>[
          _agent(),
          _agent(agentId: 'a2', name: 'Busi Dlamini', stops: <AgentStop>[]),
        ],
      );

      expect(find.text('Busi Dlamini'), findsNothing);
    });
  });

  group('the map', () {
    testWidgets('renders on a phone with room for it', (tester) async {
      await _pump(tester, agents: <AgentActivity>[_agent()]);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('does not render in Veld, and says why', (tester) async {
      // Maps do not render in the outdoor skin (unify §4). A dark basemap read
      // in direct sun at 40% backlight is a black rectangle.
      await _pump(
        tester,
        skin: TiqSkin.veld(),
        agents: <AgentActivity>[_agent()],
      );

      expect(find.byType(FlutterMap), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('trail-map-veld')),
        findsOneWidget,
      );
      // And the day is still a screen, not an absence.
      expect(find.textContaining('1. Sandton Spar'), findsOneWidget);
    });

    testWidgets('does not render on a phone with no room, without a note', (
      tester,
    ) async {
      // Below 200dp of budget the band does not render at all: 96dp of
      // basemap at street zoom is four buildings and no orientation.
      await _pump(
        tester,
        size: const Size(360, 560),
        agents: <AgentActivity>[_agent()],
      );

      expect(trailMapHeight(tester.element(find.byType(AgentTrailScreen))), 0);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('gives up on tiles that never arrive, and says so', (
      tester,
    ) async {
      TrailMap.debugFailureThreshold = 0;
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(
        find.byKey(const ValueKey<String>('trail-map-offline')),
        findsOneWidget,
      );
      expect(find.textContaining('1. Sandton Spar'), findsOneWidget);
    });

    testWidgets('the pins cast nothing and breathe nothing', (tester) async {
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      // The paint budget: Night casts ZERO shadows, and the pins this
      // replaced cast two each — plus a RadialGradient each — on a map that
      // draws up to two hundred of them. Scoped to the pins: the console
      // shell's own letterbox falloff is a declared LinearGradient in one
      // draw call and is not what this is about.
      final pins = find.descendant(
        of: find.byType(TrailStopPin),
        matching: find.byType(DecoratedBox),
      );
      expect(pins, findsWidgets);
      for (final element in pins.evaluate()) {
        final decoration = (element.widget as DecoratedBox).decoration;
        if (decoration is BoxDecoration) {
          expect(
            decoration.boxShadow ?? const <BoxShadow>[],
            isEmpty,
            reason: 'Night casts no shadow. $decoration',
          );
          expect(decoration.gradient, isNull, reason: '$decoration');
        }
      }
      // And nothing on this route is animating: the glow this replaced was
      // the design's only infinite loop, and it ran once per pin.
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a caption is dropped at 2.0x, never shrunk into a tile', (
      tester,
    ) async {
      await _pump(tester, textScale: 2.0, agents: <AgentActivity>[_agent()]);

      // A marker's box is a fixed 128x72 of ground and type that grows inside
      // one spills over the tiles. Every outlet and time is in the list
      // beneath at full scale, which is where a reader who needs 2.0x text is
      // actually served.
      expect(
        find.descendant(
          of: find.byType(TrailStopPin),
          matching: find.textContaining('Sandton Spar'),
        ),
        findsNothing,
      );
      expect(find.byType(TrailStopPin), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pin is a button a reader can name and activate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(
        find.bySemanticsLabel(
          RegExp('Thandi Mokoena, stop 1, Sandton Spar, 08:00'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton', (tester) async {
      await _pump(tester, pending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('a day with no check-ins says so and offers another', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        find.byKey(const ValueKey<String>('agent-trail-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('agent-trail-date')),
        findsOneWidget,
      );
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('an error is sanitised and carries one retry', (tester) async {
      await _pump(
        tester,
        failure: StateError('SocketException: api.tradeiq.co.za'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('agent-trail-retry')),
        findsOneWidget,
      );
    });

    testWidgets('a truncated page owns up to being truncated', (tester) async {
      await _pump(tester, agents: <AgentActivity>[_agent()], truncated: true);

      // A partial map that looks complete is worse than no map.
      expect(
        find.textContaining('Showing the first 200 agents only.'),
        findsOneWidget,
      );
    });
  });

  group('the live layer (#153 T1)', () {
    testWidgets('today carries the live layer and says when it was true', (
      tester,
    ) async {
      await _pump(tester, agents: <AgentActivity>[_agent()], live: _livePage());

      expect(
        find.byKey(const ValueKey<String>('trail-live-legend')),
        findsOneWidget,
      );
      // Ages are the server's measurement, so the time they are true AT is on
      // screen — an age with no "as at" is an age against the wrong clock.
      expect(
        find.textContaining('Last updated ${formatUpdatedAt(_serverTime)}'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('live-agent-pin-a-transit')),
        findsOneWidget,
      );
      // And the confirmed check-ins are still there beside them.
      expect(
        find.byKey(const ValueKey<String>('agent-stop-a1-0')),
        findsOneWidget,
      );
    });

    testWidgets('live positions render before anybody has checked in', (
      tester,
    ) async {
      await _pump(tester, live: _livePage());

      // A day with no check-ins and a moving agent is not an empty day.
      expect(
        find.byKey(const ValueKey<String>('agent-trail-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('live-agent-pin-a-transit')),
        findsOneWidget,
      );
    });
  });

  group('the legend says what the marks mean', () {
    testWidgets('the dashes are not claimed to be a route', (tester) async {
      await _pump(tester, agents: <AgentActivity>[_agent()]);

      expect(
        find.textContaining('they are not a recorded route'),
        findsOneWidget,
      );
    });
  });

  // ── Every button a reader announces, a reader can press ───────────────
  //
  // The kit once shipped a whole button family that announced itself and did
  // nothing when a screen reader activated it, and `SectionRuleAction` and
  // `PaginationFooter.action` were still shipping it when this group started.
  // This is that law on this screen, in every phase, so no local
  // `Semantics(button: true, ..., excludeSemantics: true)` around a bare
  // gesture detector can bring it back here.
  group('every button a screen reader announces can be activated', () {
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) => _pump(
        t,
        agents: <AgentActivity>[
          _agent(),
          _agent(agentId: 'a2', name: 'Busi Dlamini'),
        ],
        truncated: true,
      ),
      'empty': (t) => _pump(t),
      'error': (t) =>
          _pump(t, failure: StateError('SocketException: api.tradeiq.co.za')),
    };
    for (final phase in phases.entries) {
      testWidgets(phase.key, (tester) async {
        final handle = tester.ensureSemantics();
        await phase.value(tester);
        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, every phase in every skin', () {
    // A record of where somebody has been has no commit action and no chart
    // focus, so the route nominates nothing. Amber also leaves the map
    // entirely (§3.2) — on eleven stops it would be claimed eleven times.
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(
          t,
          skin: skin,
          size: const Size(360, 720),
          agents: <AgentActivity>[
            _agent(),
            _agent(agentId: 'a2', name: 'Busi Dlamini'),
          ],
          truncated: true,
        ),
        'empty': (t) => _pump(t, skin: skin, size: const Size(360, 720)),
        'loading': (t) async {
          await _pump(t, skin: skin, size: const Size(360, 720), pending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          size: const Size(360, 720),
          failure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'agent-trail',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });

  group('2.0x text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0x', (tester) async {
      await _pump(
        tester,
        size: const Size(360, 720),
        textScale: 2.0,
        agents: <AgentActivity>[_agent()],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing overflows at 320dp in Afrikaans', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        locale: const Locale('af'),
        agents: <AgentActivity>[_agent()],
      );
      expect(tester.takeException(), isNull);
    });
  });

  // The trail an Afrikaans manager opens. Its legend is the only thing on the
  // screen that stops the dashed lines reading as a recorded route, so an
  // English legend is an overstated map as well as an untranslated one.
  group('an Afrikaans manager opens the trail', () {
    testWidgets('no English is painted, and the Afrikaans is', (tester) async {
      final af = lookupAppLocalizations(const Locale('af'));
      await _pump(
        tester,
        agents: <AgentActivity>[_agent()],
        locale: const Locale('af'),
      );

      for (final english in <String>[
        'Agent trail',
        'Pick another day',
        'How to read it',
        'Numbered pins are confirmed check-ins',
        'Field agent',
        'Last stop',
        'stops',
      ]) {
        expect(paintedIgnoringCase(english), findsNothing, reason: english);
      }

      expect(paintedIgnoringCase(af.trailTitle), findsWidgets);
      expect(paintedIgnoringCase(af.trailPickDay), findsWidgets);
      expect(paintedIgnoringCase(af.trailHowToRead), findsWidgets);
      expect(paintedIgnoringCase(af.trailLegendPins), findsOneWidget);
      expect(paintedIgnoringCase(af.roleFieldAgent), findsWidgets);
      expect(paintedIgnoringCase(af.trailLastStop), findsWidgets);
    });
  });
}
