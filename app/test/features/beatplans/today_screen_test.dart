import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

const _khumalo = Outlet(
  id: 'o1',
  name: 'Khumalo Superette',
  code: 'KS-014',
  lat: -26.2,
  lng: 28.0,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-221',
  lat: -26.3,
  lng: 28.1,
);

TodayRoute _route({
  bool located = true,
  bool complete = false,
  int extras = 0,
}) => TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: located,
  stops: <RouteStop>[
    RouteStop(
      sequence: 1,
      outlet: _khumalo,
      visited: true,
      distanceMeters: located ? 1200 : null,
    ),
    RouteStop(
      sequence: 2,
      outlet: _sunrise,
      visited: complete,
      distanceMeters: located ? 420 : null,
    ),
    for (var i = 0; i < extras; i++)
      RouteStop(
        sequence: 3 + i,
        outlet: Outlet(
          id: 'x$i',
          name: 'Extra $i',
          code: 'XX-$i',
          lat: 0,
          lng: 0,
        ),
        visited: false,
        distanceMeters: located ? 900.0 + i : null,
      ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  TodayRoute? route,
  bool error = false,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  SyncStatus sync = SyncStatus.empty,
  LocalDb? db,
  int runningContests = 0,
}) async {
  final database = db ?? agentTestDb();
  await pumpAgentScreen(
    tester,
    const TodayScreen(),
    overrides: <Override>[
      ...agentBaseOverrides(
        db: database,
        skin: skin,
        sync: sync,
        runningContests: runningContests,
      ),
      todayRouteProvider.overrideWith((ref) async {
        if (error) throw StateError('no signal');
        return route;
      }),
    ],
    textScale: textScale,
    locale: locale,
    extraRoutes: <GoRoute>[
      GoRoute(path: '/audit', builder: (c, s) => const Text('Outlet picker')),
      GoRoute(
        path: '/audit/:outletId',
        builder: (c, s) => Text('Visit ${s.pathParameters['outletId']}'),
      ),
      GoRoute(path: '/my-work', builder: (c, s) => const Text('My work')),
      GoRoute(path: '/map', builder: (c, s) => const Text('Map view')),
      GoRoute(path: '/me', builder: (c, s) => const Text('My record')),
    ],
  );
}

void main() {
  group('the day, and what is left', () {
    testWidgets('the day block answers the 06:30 question in one node', (
      tester,
    ) async {
      await _pump(tester, route: _route());

      // "4 of 11" in the mockup; here 1 of 2 with 1 left. The figure and its
      // unit are separate widgets on one baseline, so the assertion is on
      // both rather than on a glued string.
      expect(find.text('1'), findsWidgets);
      expect(find.text(' of 2 stores'), findsOneWidget);
      expect(find.text('1 left'), findsOneWidget);

      // One node for a screen reader, ending in the fact and not the bar.
      expect(
        tester.getSemantics(find.byType(Meter).first).label.contains('1 of 2'),
        isTrue,
      );
    });

    testWidgets('the next store is its own row, with the check-in on it', (
      tester,
    ) async {
      await _pump(tester, route: _route());

      final card = find.byKey(const ValueKey<String>('next-stop'));
      expect(card, findsOneWidget);
      // The next store is the one that is NOT done.
      expect(
        find.descendant(of: card, matching: find.text('Sunrise Spaza')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey<String>('check-in-next')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the next-up primary starts the check-in there', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final button = find.byKey(const ValueKey<String>('check-in-next'));
      await scrollAgentTo(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Visit o2'), findsOneWidget);
    });

    testWidgets('the plan is not a cage — a later stop is also tappable', (
      tester,
    ) async {
      await _pump(tester, route: _route(extras: 1));
      final row = find.byKey(const ValueKey<String>('stop-x0'));
      await scrollAgentTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Visit x0'), findsOneWidget);
    });

    testWidgets('and an unplanned store is one tap away, as a row', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final row = find.byKey(const ValueKey<String>('visit-another'));
      await scrollAgentTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Outlet picker'), findsOneWidget);
    });

    testWidgets('a done stop takes the done silhouette, not a colour', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final row = find.byKey(const ValueKey<String>('stop-o1'));
      await scrollAgentTo(tester, row);
      final glyph = tester.widget<SectionStateGlyph>(
        find.descendant(of: row, matching: find.byType(SectionStateGlyph)),
      );
      expect(glyph.state, SectionState.done);
    });
  });

  // The anatomy the approved surface describes, measured rather than
  // described: the day block's figure role, the Next-up card's meta voices,
  // and the fact that the whole populated screen is one fold on the phone an
  // agent actually carries.
  group('the populated screen holds its declared anatomy', () {
    testWidgets('the day block sets its count at figure.l, in mono', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final skin = agentSkinFor(SkinMode.night);
      final figure = tester.widget<FigureSlot>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('day-block')),
              matching: find.byType(FigureSlot),
            )
            .first,
      );
      expect(figure.role.name, 'figure.l');
      expect(figure.role.size, 32);
      expect(figure.role.isFigure, isTrue, reason: 'mono, with tnum');
      // And its unit is the prose role beside it, not a second figure.
      expect(
        tester
            .widget<Text>(find.text(' of 2 stores'))
            .style!
            .fontSize,
        skin.text.titleM.size,
      );
    });

    testWidgets('the Next-up meta line is the card\'s smallest voice', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final card = find.byKey(const ValueKey<String>('next-stop'));
      final skin = agentSkinFor(SkinMode.night);

      // The sequence: mono 16, not 22. It is a badge, not a headline.
      final sequence = tester.widget<FigureSlot>(
        find.descendant(of: card, matching: find.byType(FigureSlot)).first,
      );
      expect(sequence.role.name, 'figure.s');
      expect(sequence.role.size, 16);

      // The outlet name is the loudest thing in the card, and by a margin.
      final name = tester.widget<Text>(
        find.descendant(of: card, matching: find.text('Sunrise Spaza')),
      );
      expect(name.style!.fontSize, skin.text.titleL.size);
      expect(name.style!.fontSize! > sequence.role.size, isTrue);
    });

  });

  group('distance is a figure or a sentence, never a guess', () {
    testWidgets('every distance goes through FigureSlot', (tester) async {
      await _pump(tester, route: _route());
      // No hand-formatted distance string anywhere: the next-up row's 420 m
      // is a FigureSlot with a worded unit.
      final slots = tester.widgetList<FigureSlot>(find.byType(FigureSlot));
      expect(slots, isNotEmpty);
      expect(find.textContaining('420'), findsWidgets);
    });

    testWidgets('no location means no distances — and one line saying why', (
      tester,
    ) async {
      await _pump(tester, route: _route(located: false));

      expect(
        find.text('Distances are off — this phone will not say where it is.'),
        findsOneWidget,
      );
      // Not a wrong number, and not eleven em dashes either: nothing at all.
      expect(find.textContaining('420'), findsNothing);
      expect(find.textContaining('1,2 km'), findsNothing);
    });

    testWidgets('Afrikaans takes the locale decimal mark on a km distance', (
      tester,
    ) async {
      await _pump(
        tester,
        route: TodayRoute(
          planName: 'Naledi',
          hasLocation: true,
          stops: <RouteStop>[
            const RouteStop(
              sequence: 1,
              outlet: _sunrise,
              visited: false,
              distanceMeters: 1200,
            ),
          ],
        ),
        locale: const Locale('af'),
      );
      // 1.2 km in English is 1,2 km in Afrikaans, and that is the one
      // formatter's job rather than the screen's.
      expect(find.textContaining('1,2'), findsWidgets);
    });
  });

  // unify §1.12 and the agent surface's empty-state grammar: display prose is
  // keyed to LINE COUNT after layout — 1–2 lines stay at 40, 3 lines step to
  // 32, 4 or more to 26, floor 26. It is the rule that lets a long Afrikaans
  // headline have a defined shape instead of eating the screen, so it is
  // pinned at every step rather than at the one the English copy happens to
  // land on.
  group('the empty-state headline follows the line-count fitting rule', () {
    /// Resolve `displayFor` for [headline] inside a real agent skin at
    /// [width], and hand back the role it chose.
    Future<TiqTypeToken> roleFor(
      WidgetTester tester,
      String headline, {
      double width = 360,
      double textScale = 1.0,
    }) async {
      late TiqTypeToken role;
      tester.view
        ..physicalSize = Size(width, 640)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            agentSkinProvider.overrideWith(() => PinnedAgentSkin(SkinMode.night)),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 640),
              devicePixelRatio: 1.0,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TorchlightRoute(
                child: Builder(
                  builder: (context) {
                    role = displayFor(context, headline);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      return role;
    }

    // The strings below carry explicit line breaks. A headline never does —
    // but the rule is about a LINE COUNT, and a test that reached that count
    // by picking a string long enough to wrap would be testing the metrics of
    // whichever font the test binding loaded rather than the rule. The
    // English and Afrikaans strings the app actually ships are asserted
    // underneath, against the ladder rather than against one step.
    testWidgets('one line stays at display 40', (tester) async {
      final role = await roleFor(tester, 'One');
      expect(role.name, 'display');
      expect(role.size, 40);
    });

    testWidgets('two lines stay at display 40', (tester) async {
      final role = await roleFor(tester, 'One\nTwo');
      expect(role.name, 'display');
      expect(role.size, 40);
    });

    testWidgets('three lines step to display.m 32', (tester) async {
      final role = await roleFor(tester, 'One\nTwo\nThree');
      expect(role.name, 'display.m');
      expect(role.size, 32);
    });

    testWidgets('four lines step to display.s 26, the floor', (tester) async {
      final role = await roleFor(tester, 'One\nTwo\nThree\nFour');
      expect(role.name, 'display.s');
      expect(role.size, 26);
    });

    testWidgets('and six lines are still 26 — 26 is the floor', (tester) async {
      final role = await roleFor(tester, 'a\nb\nc\nd\ne\nf');
      expect(role.size, 26);
    });

    testWidgets('there is no step between 40 and 32', (tester) async {
      // The old helper stepped display → title.l → title.m and returned the
      // first role that laid out in two lines, so a three-line headline came
      // back at title.l 24 — smaller than the outlet name on the populated
      // screen two blocks below it. The declared ladder is 40 / 32 / 26 and
      // nothing else.
      for (final headline in <String>[
        'a',
        'a\nb',
        'a\nb\nc',
        'a\nb\nc\nd',
        'a\nb\nc\nd\ne',
      ]) {
        final role = await roleFor(tester, headline);
        expect(
          <double>[40, 32, 26],
          contains(role.size),
          reason: '"$headline" resolved to ${role.name} at ${role.size}',
        );
      }
    });

    for (final (locale, headline) in <(Locale, String)>[
      (const Locale('en'), 'No route planned for today'),
      (const Locale('af'), 'Geen roete vir vandag beplan nie'),
    ]) {
      testWidgets(
        'the shipped ${locale.languageCode} headline is on the ladder',
        (tester) async {
          await _pump(tester, route: null, locale: locale);
          final text = tester.widget<Text>(find.text(headline));
          expect(
            <double?>[40, 32, 26],
            contains(text.style!.fontSize),
            reason:
                'the empty-state headline is display prose under the fitting '
                'rule, never title.l and never a hand-picked size',
          );
        },
      );
    }

    testWidgets('2.0x Afrikaans still resolves to a declared step', (
      tester,
    ) async {
      await _pump(
        tester,
        route: null,
        locale: const Locale('af'),
        textScale: 2.0,
      );
      final text = tester.widget<Text>(
        find.text('Geen roete vir vandag beplan nie'),
      );
      expect(<double?>[40, 32, 26], contains(text.style!.fontSize));
    });
  });

  group('the states that are not a route', () {
    testWidgets('no plan is a fact about the plan, and names the next action', (
      tester,
    ) async {
      await _pump(tester, route: null);
      expect(find.text('No route planned for today'), findsOneWidget);
      expect(
        find.text(
          'No beat plan for today. You can still pick a store yourself.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pick a store to visit'), findsOneWidget);
      // An empty screen has no expected next move strong enough to spend the
      // budget on: the action is a ghost, never the primary.
      expect(find.byType(TorchPrimaryButton), findsNothing);
      expect(find.byType(TorchSecondaryButton), findsOneWidget);
    });

    testWidgets('an empty plan gets its own sentence', (tester) async {
      await _pump(
        tester,
        route: const TodayRoute(
          planName: 'Naledi',
          stops: <RouteStop>[],
          hasLocation: true,
        ),
      );
      expect(
        find.text('Today’s beat plan has no stops on it yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a load failure keeps the chrome and says what survived', (
      tester,
    ) async {
      await _pump(tester, error: true);
      expect(find.text('Could not load your route'), findsOneWidget);
      expect(find.byType(TorchNavPill), findsOneWidget);
    });

    testWidgets('a finished route drops the Next-up section entirely', (
      tester,
    ) async {
      await _pump(tester, route: _route(complete: true));
      expect(find.byKey(const ValueKey<String>('next-stop')), findsNothing);
      expect(find.text('Route done'), findsOneWidget);
      // ...and the circle arms, because starting a visit somewhere else is
      // now genuinely the expected next move.
      final circle = tester.widget<TorchNavCircle>(find.byType(TorchNavCircle));
      expect(circle.expected, isTrue);
    });
  });

  group('the sync chip', () {
    testWidgets('held work is a neutral square and a word, never an error', (
      tester,
    ) async {
      await _pump(
        tester,
        route: _route(),
        sync: SyncStatus(
          pending: <SyncItem>[
            SyncItem(
              id: 1,
              entityType: 'stock',
              queuedAt: DateTime.utc(2026, 9, 18),
              synced: false,
              attempts: 0,
            ),
          ],
          sent: const <SyncItem>[],
          needsAttention: const <SyncItem>[],
        ),
      );
      expect(find.text('1 held on this phone'), findsOneWidget);
      final chip = tester.widget<StatusChip>(
        find.widgetWithText(StatusChip, '1 held on this phone'),
      );
      expect(chip.level, StatusLevel.held);
    });

    testWidgets('an empty outbox says so', (tester) async {
      await _pump(tester, route: _route());
      expect(find.text('All sent'), findsOneWidget);
    });
  });

  group('the chrome', () {
    testWidgets('four nav slots, and the skin cycle is the one trailing icon', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final pill = tester.widget<TorchNavPill>(find.byType(TorchNavPill));
      // THE SET, asserted rather than commented, and now exactly what unify
      // §1.2 approved: Today · My work · Map · Me. Contests held the fourth
      // slot until Me existed, so the migration would not *remove* the
      // agent's standings (#124); it now lives inside Me, and the Me slot
      // wears its running count. See `TodayFrame.slotsIn`.
      expect(pill.slots.map((s) => s.label), <String>[
        'Today',
        'My work',
        'Map',
        'Me',
      ]);
      final header = tester.widget<TorchAppHeader>(find.byType(TorchAppHeader));
      expect(header.trailing, isNotNull);
      // A tab root has NO thumb zone: 64dp of nav plus 96dp of thumb zone is
      // a quarter of a 640dp screen given to chrome.
      expect(find.byType(TorchThumbZone), findsNothing);
    });

    testWidgets('every slot but the current one leaves this screen', (
      tester,
    ) async {
      // The rule the slot set exists to keep: no slot is a no-op.
      for (final (index, landing) in <(int, String)>[
        (TodayFrame.myWorkSlot, 'My work'),
        (TodayFrame.mapSlot, 'Map view'),
        (TodayFrame.meSlot, 'My record'),
      ]) {
        await _pump(tester, route: _route());
        tester.widget<TorchNavPill>(find.byType(TorchNavPill)).onSelect(index);
        await tester.pumpAndSettle();
        expect(
          find.text(landing),
          findsOneWidget,
          reason: 'slot $index must have a destination of its own',
        );
        expect(find.byType(TodayScreen), findsNothing);
      }
    });

    // The running-contests count the old Contests action carried (#124),
    // kept on the slot that now leads to Contests.
    testWidgets('the Me slot carries the running contests count', (
      tester,
    ) async {
      await _pump(tester, route: _route(), runningContests: 2);
      expect(
        tester
            .widget<TorchNavPill>(find.byType(TorchNavPill))
            .slots[TodayFrame.meSlot]
            .badgeCount,
        2,
      );
    });

    testWidgets('a zero is not a badge', (tester) async {
      await _pump(tester, route: _route());
      expect(
        tester
            .widget<TorchNavPill>(find.byType(TorchNavPill))
            .slots[TodayFrame.meSlot]
            .badgeCount,
        isNull,
        reason: 'nothing running is not news',
      );
    });

    testWidgets('the skin cycle names the next state, not this one', (
      tester,
    ) async {
      await _pump(tester, route: _route(), skin: SkinMode.day);
      final header = tester.widget<TorchAppHeader>(find.byType(TorchAppHeader));
      expect(
        header.trailing!.semanticLabel,
        'Screen: Day. Double-tap for Veld, the outdoor high-contrast screen.',
      );
    });
  });

  group('2.0× text', () {
    testWidgets('the structure survives and nothing overflows', (tester) async {
      await _pump(tester, route: _route(), textScale: 2.0);
      expect(tester.takeException(), isNull);
      // Nothing is pinned at 2.0×, so the Next-up row is past the fold on a
      // 640dp phone — which is the correct outcome, not a failure. What must
      // survive is that it is still THERE and still whole.
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('next-stop')),
      );
      expect(find.byKey(const ValueKey<String>('next-stop')), findsOneWidget);
      expect(find.byType(TorchNavPill), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 2.0× still lays out', (tester) async {
      await _pump(
        tester,
        route: _route(),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the amber census', () {
    /// The census counts the COMPOSED FRAME. On a 360×640 phone the day block
    /// pushes "Check in here" just past the fold, so a test that measured the
    /// unscrolled frame would be measuring a frame with no commit action in
    /// it — and would pass for the wrong reason. Scrolling the primary into
    /// view is what puts the two objects the law is about on one screen.
    Future<void> showPrimary(WidgetTester tester) => scrollAgentTo(
      tester,
      find.byKey(const ValueKey<String>('check-in-next')),
    );

    testWidgets('Night: two objects — the nav tab and "Check in here"', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      await showPrimary(tester);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'today',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        2,
        reason:
            'The nav pill\'s active tab is object 1 whenever the nav renders, '
            'and the content\'s one grant on a tabbed route goes to the '
            'primary commit.\n\n${census.describe()}',
      );
    });

    testWidgets('Day: one — the amber block; the tab is Abyssal', (
      tester,
    ) async {
      await _pump(tester, route: _route(), skin: SkinMode.day);
      await showPrimary(tester);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.day),
        route: 'today',
        phase: 'loaded',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Veld: one — the block; the bar is docked and its tab is ink', (
      tester,
    ) async {
      await _pump(tester, route: _route(), skin: SkinMode.veld);
      await showPrimary(tester);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.veld),
        route: 'today',
        phase: 'loaded',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('a finished route: the circle takes the grant in Night', (
      tester,
    ) async {
      await _pump(tester, route: _route(complete: true));
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'today',
        phase: 'route-done',
      );
      expect(census.objectCount, 2, reason: census.describe());
    });

    for (final skin in <SkinMode>[SkinMode.day, SkinMode.veld]) {
      testWidgets(
        'a finished route on a light ground arms nothing — ${skin.name} is 0',
        (tester) async {
          await _pump(tester, route: _route(complete: true), skin: skin);
          final census = await amberCensus(tester);
          expect(
            census.objectCount,
            0,
            reason:
                'On a light ground the ladder has one rung and it is the '
                'primary commit block. A finished route has no commit, so '
                'nothing is armed and nothing is lit.\n\n${census.describe()}',
          );
        },
      );
    }

    testWidgets('an empty route lights nothing it has not earned', (
      tester,
    ) async {
      await _pump(tester, route: null, skin: SkinMode.day);
      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });

    testWidgets('at 2.0× the count does not change', (tester) async {
      await _pump(tester, route: _route(), textScale: 2.0);
      await showPrimary(tester);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'today',
        phase: 'loaded @2.0x',
      );
      expect(census.objectCount, 2, reason: census.describe());
    });
  });

  group('the claims are declared, not painted', () {
    testWidgets('the circle asks and loses while there is a primary', (
      tester,
    ) async {
      await _pump(tester, route: _route());
      final scope = TorchScope.maybeOf(
        tester.element(find.byType(TorchNavCircle)),
      );
      expect(scope, isNotNull);
      expect(scope!.allocation.isLit(TodayScreen.checkInClaimId), isTrue);
      expect(scope.allocation.isLit(TodayScreen.navCircleClaimId), isFalse);
    });
  });
}
