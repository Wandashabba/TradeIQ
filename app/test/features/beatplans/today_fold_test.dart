import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../agent_harness.dart';

/// THE FOLD, MEASURED IN THE TYPEFACE THE APP SHIPS.
///
/// Today answers one question at 06:30 — *where am I going, and how much is
/// left* — and the answer ends in a commit action. The owner opened the
/// running app and found it did not: the header spent a row on the sync chip,
/// the stop number was set at 22, and the card had collected gaps, so on a
/// 360dp phone "Check in here" sat under the nav pill. Nothing in the suite
/// said so, because nothing measured a height.
///
/// This file does, and it loads Onest and JetBrains Mono first. `flutter_test`
/// otherwise renders every glyph in its own fixed-advance test font, which is
/// wider than Onest: every label wraps sooner and every screen measures
/// taller. That is right for a test about a role, a token or a count, and
/// wrong for one about whether something fits — a fold is a fact about the
/// typeface, and this app bundles its typeface precisely so that fact is
/// knowable. Every assertion in here is a geometry assertion for that reason.
const _khumalo = Outlet(
  id: 'o1',
  name: 'Khumalo Superette',
  code: 'KS-014',
  lat: -26.2,
  lng: 28.0,
);

const _kasi = Outlet(
  id: 'o2',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.3,
  lng: 28.1,
);

/// A real day: nine stores, four done, the fifth up next.
TodayRoute _route() => TodayRoute(
  planName: 'Tembisa run',
  hasLocation: true,
  stops: <RouteStop>[
    for (var i = 0; i < 3; i++)
      RouteStop(
        sequence: 1 + i,
        outlet: Outlet(
          id: 'done$i',
          name: 'Khumalo Superette $i',
          code: 'KS-01$i',
          lat: 0,
          lng: 0,
        ),
        visited: true,
        distanceMeters: 900.0 + i * 300,
      ),
    const RouteStop(
      sequence: 4,
      outlet: _khumalo,
      visited: true,
      distanceMeters: 1200,
    ),
    const RouteStop(
      sequence: 5,
      outlet: _kasi,
      visited: false,
      distanceMeters: 420,
    ),
    for (var i = 0; i < 4; i++)
      RouteStop(
        sequence: 6 + i,
        outlet: Outlet(
          id: 'rest$i',
          name: 'Sunrise Spaza $i',
          code: 'SS-22$i',
          lat: 0,
          lng: 0,
        ),
        visited: false,
        distanceMeters: 1500.0 + i * 700,
      ),
  ],
);

/// A field agent who has not answered the location notice yet — the first
/// session, and the state the owner was looking at.
class _UnansweredNotice extends LocationSharingController {
  @override
  LocationSharingState build() => LocationSharingState(
    isAgent: true,
    settings: LocationSettings(intervalSeconds: 300, noticeVersion: 'v1'),
  );

  @override
  Future<void> acknowledge() async {}

  @override
  Future<void> decline() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  SkinMode skin = SkinMode.night,
  Locale locale = const Locale('en'),
  bool noticeUnanswered = false,
}) => pumpAgentScreen(
  tester,
  const TodayScreen(),
  locale: locale,
  overrides: <Override>[
    ...agentBaseOverrides(db: agentTestDb(), skin: skin),
    if (noticeUnanswered)
      locationSharingControllerProvider.overrideWith(_UnansweredNotice.new),
    todayRouteProvider.overrideWith((ref) async => _route()),
  ],
  extraRoutes: <GoRoute>[
    GoRoute(path: '/audit', builder: (c, s) => const Text('picker')),
    GoRoute(path: '/audit/:outletId', builder: (c, s) => const Text('visit')),
    GoRoute(path: '/my-work', builder: (c, s) => const Text('my work')),
    GoRoute(path: '/map', builder: (c, s) => const Text('map')),
    GoRoute(path: '/me', builder: (c, s) => const Text('me')),
  ],
);

/// The same screen with no plan at all — the whole-screen empty state.
Future<void> _pumpEmpty(WidgetTester tester) => pumpAgentScreen(
  tester,
  const TodayScreen(),
  overrides: <Override>[
    ...agentBaseOverrides(db: agentTestDb()),
    todayRouteProvider.overrideWith((ref) async => null),
  ],
  extraRoutes: <GoRoute>[
    GoRoute(path: '/audit', builder: (c, s) => const Text('picker')),
    GoRoute(path: '/my-work', builder: (c, s) => const Text('my work')),
    GoRoute(path: '/map', builder: (c, s) => const Text('map')),
    GoRoute(path: '/me', builder: (c, s) => const Text('me')),
  ],
);

/// Where the scrolling body ends.
///
/// The bottom region is a SIBLING of the scroll view rather than an overlay,
/// so the fold is the scroll view's own bottom edge — no token arithmetic, no
/// guess about the safe area, and no assumption about which of the three
/// bottom-region shapes this route is wearing.
double _fold(WidgetTester tester) =>
    tester.getRect(find.byType(Scrollable).first).bottom;

void main() {
  setUpAll(loadAgentFonts);

  group('a populated Today is one fold on a 360×640 phone', () {
    // Night and Day, which are the two skins an agent works in indoors and in
    // daylight. Veld is measured separately below, because its arithmetic is
    // genuinely different.
    for (final skin in <SkinMode>[SkinMode.night, SkinMode.day]) {
      testWidgets('${skin.name}: "Check in here" is above the fold', (
        tester,
      ) async {
        await _pump(tester, skin: skin);

        final primary = tester.getRect(
          find.byKey(const ValueKey<String>('check-in-next')),
        );
        expect(
          primary.bottom,
          lessThanOrEqualTo(_fold(tester)),
          reason:
              '${skin.name}: the whole reason this screen exists is the store '
              'the agent is about to walk into and the button that starts the '
              'visit there. It measured ${primary.bottom} against a fold at '
              '${_fold(tester)}.',
        );
      });
    }

    testWidgets('Veld gets the day and the store, and scrolls to the verb', (
      tester,
    ) async {
      // VELD IS DIFFERENT ON PURPOSE, and this is the arithmetic rather than
      // an excuse. Outdoors the nav DOCKS — a full-bleed 72dp bar — and the
      // action circle floats 12dp above it, so the bottom region is 148dp
      // against Night's 84. Every type role steps up, the gutter goes to 24
      // and the block gap to 40. Veld is declared as "fewer things, further
      // apart"; it cannot also be the skin that fits the most on a fold.
      //
      // What it must still do is answer the question: how much of the day is
      // left, and which store is next. Both are above the fold; the verb is
      // one flick, and it is a 64dp target when it arrives.
      await _pump(tester, skin: SkinMode.veld);
      final fold = _fold(tester);

      for (final (what, finder) in <(String, Finder)>[
        ('the day block', find.byKey(const ValueKey<String>('day-block'))),
        ('the next store', find.text('Kasi Corner Spaza')),
      ]) {
        expect(
          tester.getRect(finder).bottom,
          lessThanOrEqualTo(fold),
          reason: 'Veld: $what is below the fold',
        );
      }

      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('check-in-next')),
      );
      expect(
        find.byKey(const ValueKey<String>('check-in-next')),
        findsOneWidget,
      );
    });

    testWidgets('and so is everything above it, in order', (tester) async {
      await _pump(tester);
      final fold = _fold(tester);

      // The header, the day block, the Next-up rule and the card: the four
      // things the surface's anatomy lists before the rest of the day.
      for (final (what, finder) in <(String, Finder)>[
        ('the date and the route name', find.textContaining('Tembisa run')),
        ('the sync chip', find.text('All sent')),
        ('the day block', find.byKey(const ValueKey<String>('day-block'))),
        ('the route figure', find.text('4')),
        ('the stores left', find.text('5 left')),
        ('the Next up rule', find.text('Next up')),
        ('the next store', find.text('Kasi Corner Spaza')),
        ('its code', find.text('KC-0412')),
        (
          'the check-in',
          find.byKey(const ValueKey<String>('check-in-next')),
        ),
      ]) {
        expect(finder, findsOneWidget, reason: '$what is not on the screen');
        expect(
          tester.getRect(finder).bottom,
          lessThanOrEqualTo(fold),
          reason: '$what is below the fold',
        );
      }
    });

    testWidgets('the rest of the day has started, not merely arrived', (
      tester,
    ) async {
      await _pump(tester);
      // The section rule beneath the card is visible, so the screen reads as
      // a day rather than as a single card with something under it.
      expect(find.text('The rest of the day'), findsOneWidget);
      expect(
        tester.getRect(find.text('The rest of the day')).top,
        lessThan(_fold(tester)),
      );
    });

    testWidgets('an unanswered POPIA notice still leaves the day visible', (
      tester,
    ) async {
      // The first session, which is the state the owner opened. The notice is
      // a banner now, so the screen beneath it is still a screen: the day
      // block and the store the agent is going to are both on the fold.
      await _pump(tester, noticeUnanswered: true);
      final fold = _fold(tester);

      expect(find.byKey(const ValueKey<String>('location-notice')), findsOneWidget);
      expect(find.text('Nothing is sent in the background.'), findsOneWidget);
      for (final (what, finder) in <(String, Finder)>[
        ('the notice', find.byKey(const ValueKey<String>('location-notice'))),
        ('the day block', find.byKey(const ValueKey<String>('day-block'))),
        ('the next store', find.text('Kasi Corner Spaza')),
      ]) {
        expect(
          tester.getRect(finder).bottom,
          lessThanOrEqualTo(fold),
          reason:
              '$what is under the nav pill on an agent\'s first session. The '
              'notice used to be a wall of text and this screen used to be '
              'the notice and nothing else.',
        );
      }
    });

    testWidgets('the empty state\'s action is a ghost at its natural width', (
      tester,
    ) async {
      // A geometry assertion, so it belongs in the file that renders in the
      // real face: "Pick a store to visit" set in the test font is wider than
      // a 360dp phone, and a button clamped to the screen is not evidence
      // either way.
      await _pumpEmpty(tester);
      final button = tester.getRect(find.byType(TorchSecondaryButton));
      expect(
        button.width,
        lessThan(240),
        reason:
            'The empty-state grammar puts one secondary at its NATURAL width '
            'on the gutter. Stretched across the screen a ghost reads as the '
            'commit this state deliberately does not have. It measured '
            '${button.width} on a 360dp phone.',
      );
      expect(button.left, lessThanOrEqualTo(TiqSpace.s5));
    });

    testWidgets('the empty state is one fold, drawing to action', (
      tester,
    ) async {
      await _pumpEmpty(tester);
      final fold = _fold(tester);
      for (final (what, finder) in <(String, Finder)>[
        ('the headline', find.text('No route today')),
        ('the action', find.byType(TorchSecondaryButton)),
      ]) {
        expect(
          tester.getRect(finder).bottom,
          lessThanOrEqualTo(fold),
          reason: '$what is below the fold on an empty day',
        );
      }
    });

    testWidgets('Afrikaans holds the same fold', (tester) async {
      await _pump(tester, locale: const Locale('af'));
      final primary = tester.getRect(
        find.byKey(const ValueKey<String>('check-in-next')),
      );
      expect(
        primary.bottom,
        lessThanOrEqualTo(_fold(tester)),
        reason:
            'Afrikaans runs about 1,4× the width of English. The fold budget '
            'is not an English-only budget.',
      );
    });
  });
}
