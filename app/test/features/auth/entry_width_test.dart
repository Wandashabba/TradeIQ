import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/display_headline.dart';
import 'package:tradeiq_app/features/auth/presentation/entry_frame.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';

import '../agent_harness.dart' show loadAgentFonts;
import 'entry_harness.dart';

/// THE WAY IN AT EVERY WIDTH — the measurements behind
/// `TiqSpace.readingWidth` and `EntryFrame`'s two shapes.
///
/// > *"Thats not good please fix spacing"* — the owner, 30 September 2026,
/// > looking at the redesigned sign-in screen in a desktop browser at about
/// > 1200 logical pixels.
///
/// `entry_look_test.dart` is the picture; this is the pin. It answers three
/// questions a picture cannot:
///
/// 1. **Is 480 a measure, or a taste?** It is a measure. Onest at body
///    14/1.55 is measured here with a `TextPainter` against the entry
///    screens' own copy, and the cap is asserted to land inside the 45–75
///    characters-per-line band. If the type scale moves again the way it did
///    in #488, this fails rather than drifting.
/// 2. **Did the phone screen survive?** At 390×844 and 360×640 the fields
///    still run gutter to gutter and the commit bar is still a pinned
///    [TorchThumbZone]. #494's layout is good and nobody complained about it.
/// 3. **Is the browser actually fixed?** At 1280×1800 the field is exactly
///    the reading width, the column is centred in the viewport, there is no
///    thumb zone, and the commit action is inside the column rather than
///    1200dp below it.
///
/// It loads the real fonts, because every number in it is a fact about the
/// typeface the app ships and `flutter_test`'s own font is nothing like it.
void main() {
  setUpAll(loadAgentFonts);

  Finder key(String k) => find.byKey(ValueKey<String>(k));

  group('the measure', () {
    // The entry screens' own body copy, which is what the cap is a cap on.
    const prose = <String>[
      'Use your work email and password.',
      'Ask your manager for a reset code. They make it in TradeIQ and read '
          'it out to you. It works once, for 15 minutes.',
      'At least 12 characters. Three ordinary words are easy to type and '
          'hard to guess.',
      'Signing in again on this phone is the only thing that sends them.',
    ];

    test('480dp is 45–75 characters of Onest at body 14', () {
      final skin = entrySkinFor(SkinMode.night);
      final body = skin.text.body;
      expect(body.size, 14, reason: 'the cap is arithmetic on this number');

      var characters = 0;
      var width = 0.0;
      for (final sentence in prose) {
        final painter = TextPainter(
          text: TextSpan(text: sentence, style: body.style()),
          textDirection: TextDirection.ltr,
        )..layout();
        characters += sentence.length;
        width += painter.width;
        painter.dispose();
      }

      final perCharacter = width / characters;
      final perLine = TiqSpace.readingWidth / perCharacter;
      // Printed so the next person to move the type scale can read the new
      // number straight off the failure instead of deriving it again.
      // ignore: avoid_print
      print(
        'Onest body 14: ${perCharacter.toStringAsFixed(3)}dp per character; '
        '${TiqSpace.readingWidth.toStringAsFixed(0)}dp holds '
        '${perLine.toStringAsFixed(1)} characters.',
      );
      expect(
        perLine,
        inInclusiveRange(45, 75),
        reason:
            'A column of prose is legible between 45 and 75 characters. '
            'TiqSpace.readingWidth is outside that band at this type scale.',
      );
    });

    test('the page threshold is derived from the cap, not a second number', () {
      final skin = entrySkinFor(SkinMode.night);
      expect(
        EntryFrame.pageMinWidth(skin),
        TiqSpace.readingWidth + 2 * skin.space.gutterWide,
      );
      // A phone in landscape is wide and is still a phone.
      expect(EntryFrame.isPage(skin, const Size(852, 393)), isFalse);
      expect(EntryFrame.isPage(skin, const Size(932, 430)), isFalse);
      expect(EntryFrame.isPage(skin, const Size(390, 844)), isFalse);
      expect(EntryFrame.isPage(skin, const Size(360, 640)), isFalse);
      expect(EntryFrame.isPage(skin, const Size(834, 1112)), isTrue);
      expect(EntryFrame.isPage(skin, const Size(1280, 1800)), isTrue);
    });
  });

  group('the phone shape is the one #494 shipped', () {
    for (final size in <Size>[Size(390, 844), Size(360, 640)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('$name: the fields still run gutter to gutter', (
        tester,
      ) async {
        await _pumpLogin(tester, size);
        final skin = entrySkinFor(SkinMode.night);
        final field = tester.getRect(key('login-email'));
        expect(field.left, skin.space.gutter);
        expect(field.right, size.width - skin.space.gutter);
      });

      testWidgets('$name: the commit bar is still pinned in the thumb zone', (
        tester,
      ) async {
        await _pumpLogin(tester, size);
        expect(find.byType(TorchThumbZone), findsOneWidget);
        final zone = tester.getRect(find.byType(TorchThumbZone));
        expect(
          zone.bottom,
          size.height,
          reason: 'the thumb zone is at the bottom edge, where the thumb is',
        );
      });
    }
  });

  group('the browser shape', () {
    const size = Size(1280, 1800);

    testWidgets('the field is exactly the reading width, and centred', (
      tester,
    ) async {
      await _pumpLogin(tester, size);
      final field = tester.getRect(key('login-email'));
      expect(field.width, TiqSpace.readingWidth);
      expect(field.center.dx, size.width / 2);
    });

    testWidgets('there is no thumb zone, and the action joins the form', (
      tester,
    ) async {
      await _pumpLogin(tester, size);
      expect(find.byType(TorchThumbZone), findsNothing);

      final forgot = tester.getRect(key('login-forgot-password'));
      final submit = tester.getRect(key('login-submit'));
      final gap = submit.top - forgot.bottom;
      expect(
        gap,
        lessThan(200),
        reason:
            'the commit action belongs to the form above it. Before this '
            'change the gap on this viewport was over a thousand logical '
            'pixels.',
      );
      expect(submit.top, greaterThan(forgot.bottom));
    });

    testWidgets('the skin cycle stays beside the button', (tester) async {
      await _pumpLogin(tester, size);
      final cycle = tester.getRect(find.byType(TorchSkinCycle));
      final submit = tester.getRect(key('login-submit'));
      expect(cycle.right, lessThanOrEqualTo(submit.left));
      expect(
        (cycle.center.dy - submit.center.dy).abs(),
        lessThan(2),
        reason: 'the same row it is in on a phone, at a different address',
      );
    });

    testWidgets('the form is centred vertically, and its height is what the '
        'page threshold is set against', (tester) async {
      await _pumpLogin(tester, size);
      final top = tester.getRect(find.byType(TorchDisplayHeadline)).top;
      final bottom = tester.getRect(key('login-submit')).bottom;

      // The space above the headline and below the action are within a block
      // gap of each other: the column is centred, not top-anchored.
      final above = top;
      final below = size.height - bottom;
      expect(
        (above - below).abs(),
        lessThan(120),
        reason: 'above=$above below=$below — the column is not centred',
      );

      // ignore: avoid_print
      print(
        'sign-in column at 1280x1800: headline top $top, action bottom '
        '$bottom, height ${bottom - top}.',
      );
      expect(
        bottom - top,
        lessThan(EntryFrame.pageMinHeight),
        reason:
            'EntryFrame.pageMinHeight is the claim that a viewport this tall '
            'has room to spare around this column',
      );
    });
  });
}

Future<void> _pumpLogin(WidgetTester tester, Size size) => pumpEntryScreen(
  tester,
  const LoginScreen(),
  size: size,
  overrides: entryBaseOverrides(db: entryTestDb(), skin: SkinMode.night),
  extraRoutes: <GoRoute>[
    namedRoute('/forgot-password', 'FORGOT'),
    namedRoute('/today', 'TODAY'),
  ],
);
