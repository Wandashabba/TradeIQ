import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/display_headline.dart';
import 'package:tradeiq_app/features/auth/presentation/entry_aside.dart';
import 'package:tradeiq_app/features/auth/presentation/entry_brand.dart';
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
/// 1. **Is 440 a measure, or a taste?** It is a measure. The prose face at
///    `body` is measured here with a `TextPainter` against the entry screens'
///    own copy, and the cap is asserted to land inside the 45–75
///    characters-per-line band. It has already done its job twice: #488 moved
///    the scale and this caught it, and the 1 October 2026 reduction took
///    `body` from 14 to 13 — which put 480dp at 80.0 characters, outside the
///    band — and this failed with the number to replace it with.
/// 2. **Did the phone screen survive?** At 390×844 and 360×640 the fields
///    still run gutter to gutter and the commit bar is still a pinned
///    [TorchThumbZone]. #494's layout is good and nobody complained about it.
/// 3. **Is the browser actually fixed?** At 1280×1800 the field is exactly
///    the reading width, there is no thumb zone, and the commit action is
///    inside the column rather than 1200dp below it. The column is centred in
///    its own PANE rather than in the window since 5 October 2026, when the
///    owner chose "D — the form first" and the picture took the right 2/5 —
///    the second complaint about this screen in a browser, and the one the
///    first fix's centred column turned out to invite.
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

    test('the reading width is 45–75 characters of the prose face at body',
        () {
      final skin = entrySkinFor(SkinMode.night);
      final body = skin.text.body;
      expect(body.size, 13, reason: 'the cap is arithmetic on this number');

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
        'prose body ${skin.text.body.size}: '
        '${perCharacter.toStringAsFixed(3)}dp per character; '
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

    // CENTRED IN THE FORM PANE, NOT IN THE WINDOW — and that is the whole of
    // what "D — the form first" changed here (owner, 5 October 2026).
    //
    // Until then this screen put the plate across the top and centred one
    // column under it, so the field's centre was the window's centre. The
    // owner's objection was that it read as "mobile login on desktop": a
    // letterbox over a 440dp column marooned in 1400dp of ground.
    //
    // The field is still EXACTLY the reading width — that number is a measure
    // and is argued above, and nothing about a wider window changes how many
    // characters a line should hold. What moved is where the column sits: the
    // picture takes the right 2/5 and the form keeps the left 3/5, centred in
    // its own pane.
    testWidgets('the field is exactly the reading width, centred in the form '
        'pane rather than the window', (tester) async {
      await _pumpLogin(tester, size);
      final field = tester.getRect(key('login-email'));
      expect(field.width, TiqSpace.readingWidth);

      final pane = size.width * 3 / 5;
      expect(
        field.center.dx,
        moreOrLessEquals(pane / 2, epsilon: 1),
        reason:
            'the form is centred in its own pane. Centred in the WINDOW it '
            'would sit at ${size.width / 2}, which is under the picture.',
      );

      // And the picture has the rest, full bleed to three edges.
      final aside = tester.getRect(find.byType(EntryAside));
      expect(aside.left, moreOrLessEquals(pane, epsilon: 1));
      expect(aside.right, moreOrLessEquals(size.width, epsilon: 1));
      expect(aside.height, moreOrLessEquals(size.height, epsilon: 1));
      expect(
        field.right,
        lessThan(aside.left),
        reason: 'no field may run under the picture',
      );
    });

    testWidgets('there is no thumb zone, and the action joins the form', (
      tester,
    ) async {
      await _pumpLogin(tester, size);
      expect(find.byType(TorchThumbZone), findsNothing);

      // FORGOT PASSWORD IS NOW *UNDER* THE COMMIT, not above it — owner
      // instruction of 30 September 2026, pointing at the approved mockup.
      // The claim this test defends is unchanged: the commit belongs to the
      // form rather than being marooned at the bottom of a browser window.
      // What moved is which of the two is last.
      final forgot = tester.getRect(key('login-forgot-password'));
      final submit = tester.getRect(key('login-submit'));
      final lastField = tester.getRect(key('login-remember-me'));
      final gap = submit.top - lastField.bottom;
      expect(
        gap,
        lessThan(200),
        reason:
            'the commit action belongs to the form above it. Before this '
            'change the gap on this viewport was over a thousand logical '
            'pixels.',
      );
      expect(
        forgot.top,
        greaterThan(submit.bottom),
        reason:
            'the way out of the form sits under the way through it, which is '
            'the order a person reaches for them in.',
      );
    });

    // NO CYCLE BEFORE THE DOOR — owner instruction, 30 September 2026:
    // *"That change of theme on the sign in we can remove it. Let's only make
    // the change of theme only on settings."*
    //
    // This test has had three shapes in one day and the history is the point.
    // It began as "the skin cycle stays beside the button", which is why the
    // commit was not edge to edge. When the mockup's full-width button was
    // asked for, the cycle moved to the plate rather than going, because
    // "never a screen without the cycle" was a standing rule. The owner then
    // ruled that the rule was written for people who are signed IN.
    //
    // What survives all three is the claim worth keeping: the commit owns its
    // row alone.
    testWidgets('the commit owns its row, and no cycle shares it', (
      tester,
    ) async {
      await _pumpLogin(tester, size);
      expect(
        find.byType(TorchSkinCycle),
        findsNothing,
        reason: 'the theme is changed in settings, not on the way in',
      );

      final submit = tester.getRect(key('login-submit'));
      // Measured against the FIELD rather than the plate. On a desk the plate
      // is not in this column at all — the picture is the pane beside it — so
      // the column's width is the width of the things in it.
      final column = tester.getRect(key('login-email'));
      expect(
        (submit.width - column.width).abs(),
        lessThan(2),
        reason:
            'the commit is as wide as the column it commits — nothing shares '
            'its row any more',
      );
    });

    testWidgets('2.0x Afrikaans does not overflow the page, and the page '
        'gives way to a scroll when the column stops fitting', (tester) async {
      await _pumpLogin(
        tester,
        size,
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
      // The column grows past the free height and the Center stops centring;
      // nothing is pinned, so the page simply becomes a long page.
      expect(find.byType(TorchThumbZone), findsNothing);
      expect(find.text('Teken in'), findsWidgets);
    });

    testWidgets('the form is centred vertically, and its height is what the '
        'page threshold is set against', (tester) async {
      await _pumpLogin(tester, size);
      // THE TOP OF THE COLUMN IS THE TOP OF THE PLATE, NOT OF THE HEADLINE.
      //
      // This measured `TorchDisplayHeadline` because the headline WAS the
      // first thing in the column. Since the plate went on the door it is the
      // second: the picture is above it and the headline sits near the
      // picture's foot, about 120dp in. Measuring from the headline therefore
      // stopped measuring the column and started measuring "the column, less
      // its first object" — which fails this assertion at 152 while the column
      // is in fact centred to within a pixel.
      //
      // The claim being made is about the COLUMN, so the column's own top edge
      // is what it has to be made against. The headline's own place is pinned
      // by `entry_plate_test.dart`, which is where it belongs.
      // On a desk the first object in the column is the wordmark, not the
      // plate: the picture moved to its own pane and the three pieces of type
      // came off it onto the ground. The claim is unchanged — it is about the
      // COLUMN's own top edge — so it is made against whatever is genuinely
      // first in the column.
      final top = tester.getRect(find.byType(EntryBrand)).top;
      final headline = tester.getRect(find.byType(TorchDisplayHeadline)).top;
      final bottom = tester.getRect(key('login-submit')).bottom;

      // The space above the column and below the action are within a block
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
        'sign-in column at 1280x1800: brand top $top, headline top $headline, '
        'action bottom $bottom, height ${bottom - top}.',
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

Future<void> _pumpLogin(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) => pumpEntryScreen(
  tester,
  const LoginScreen(),
  size: size,
  textScale: textScale,
  locale: locale,
  overrides: entryBaseOverrides(db: entryTestDb(), skin: SkinMode.night),
  extraRoutes: <GoRoute>[
    namedRoute('/forgot-password', 'FORGOT'),
    namedRoute('/today', 'TODAY'),
  ],
);
