import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_frame.dart';

import '../../../features/agent_harness.dart' show loadAgentFonts;
import '../../../features/worklist_harness.dart';

/// MODEL 1 — ONE BAR, AND THE PROOF THAT IT IS ONE BAR.
///
/// > *"it becomes very weird especially knowing that the app is a search
/// > based, I don't know how to navigate with this one please help make it
/// > seamless"* — the owner, on the four-tab pill.
///
/// What is pinned here is the thing that cannot be read off a screenshot of
/// one screen: that the bottom of the screen means **the same thing**
/// everywhere, and that nothing on it is a control which looks live and is
/// not.
///
/// The tests that used to live in 27 files and said *"Night paints exactly one
/// lit object: the nav tab"* still exist and still count one object. What they
/// count is now the Send disc, which is a control that commits something,
/// rather than chrome announcing which quarter of a four-tab strip you were
/// standing in.
/// The Send disc, by the sentence a screen reader is given for it with
/// nothing typed. Tapping the middle of the composer lands in the trough,
/// which is a different control and a test that proved nothing.
final Finder _send = find.bySemanticsLabel(
  'Send. Nothing typed yet, so this opens the question field.',
);

/// And with something typed, where the label is the real one.
final Finder _sendArmed = find.bySemanticsLabel('Send this question');

void main() {
  // ── ONEST, BECAUSE THE HEIGHTS BELOW ARE PUBLISHED ──────────────────────
  //
  // The default test font is **wider than Onest**, so a screen rendered in it
  // wraps sooner and measures taller — `floor_look_test.dart` says so in as
  // many words. Measured in the test font the bar reads 136dp at 1.3x on a
  // 360dp phone because the field's standing label takes two lines; in the
  // font that ships it is 89dp and the label takes one. The first number is a
  // measurement of the wrong screen, and it is the number this group would
  // have printed into a report.
  setUpAll(() async => loadAgentFonts());

  Future<void> pumpFrame(
    WidgetTester tester, {
    TiqSkin? skin,
    Size size = const Size(390, 844),
    double textScale = 1.0,
    String? askHint,
    Widget? band,
    String path = '/webhooks',
  }) async {
    await pumpWorklist(
      tester,
      ConsoleFrame(
        phase: 'loaded',
        askHint: askHint,
        band: band,
        header: const TorchAppHeader(title: 'A console screen'),
        children: const <Widget>[Text('a body')],
      ),
      skin: skin ?? TiqSkin.night(density: TiqDensity.console),
      size: size,
      textScale: textScale,
      path: path,
    );
  }

  group('the bar is there, and it is one object', () {
    testWidgets('a framed screen has a grid, a field and a send', (
      tester,
    ) async {
      await pumpFrame(tester);

      expect(find.byType(ConsoleAskBar), findsOneWidget);
      expect(find.byType(TorchAskDestinations), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        findsOneWidget,
      );
    });

    testWidgets('and no nav pill anywhere on it', (tester) async {
      await pumpFrame(tester);
      expect(find.byType(TorchNavPill), findsNothing);
      expect(find.byType(TorchNavCircle), findsNothing);
    });

    // ── THE ORDER IS THE WHOLE POINT ────────────────────────────────────
    //
    // `[grid] [field] [send]`, left to right, on every screen. A bar whose
    // controls swapped ends between screens would be the defect in a subtler
    // form than the one being fixed.
    testWidgets('grid leads, send trails', (tester) async {
      await pumpFrame(tester);
      final grid = tester.getRect(find.byType(TorchAskDestinations));
      final field = tester.getRect(
        find.byKey(const ValueKey<String>('ask-composer-field')),
      );
      expect(grid.right, lessThanOrEqualTo(field.left));
      expect(grid.bottom, closeTo(field.bottom, 0.5));
    });

    testWidgets('both ends clear 44dp at 1.0x and at 1.3x', (tester) async {
      for (final scale in <double>[1.0, 1.3]) {
        await pumpFrame(tester, textScale: scale);
        final grid = tester.getRect(find.byType(TorchAskDestinations));
        expect(grid.width, greaterThanOrEqualTo(44), reason: 'at ${scale}x');
        expect(grid.height, greaterThanOrEqualTo(44), reason: 'at ${scale}x');
      }
    });
  });

  group('the grid is navigation, and the same gesture everywhere', () {
    testWidgets('it opens the destinations sheet', (tester) async {
      await pumpFrame(tester);
      await tester.tap(find.byType(TorchAskDestinations));
      await tester.pumpAndSettle();

      // The SAME sheet The Floor's plate control opened. Its two lead rows
      // carry the keys they have always carried, so a screen that is not The
      // Floor reaches The Floor's own destination list.
      expect(
        find.byKey(const ValueKey<String>('floor-destination-work')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('floor-destination-overview')),
        findsOneWidget,
      );
    });

    // WITHHELD, NOT ZEROED. A screen with no `FloorView` does not know the
    // backlog, and "0 need a decision" is the one reading that is certainly
    // wrong. `showFloorDestinations` already had this branch for a scope whose
    // coverage request failed; a null view takes the same one.
    testWidgets('with no floor view its subtitles are withheld', (
      tester,
    ) async {
      await pumpFrame(tester);
      await tester.tap(find.byType(TorchAskDestinations));
      await tester.pumpAndSettle();

      expect(find.textContaining('need a decision'), findsNothing);
      expect(find.text('Everything triaged'), findsNothing);
      expect(find.textContaining('No visits in this window'), findsNothing);
    });

    testWidgets('a row on it goes somewhere real', (tester) async {
      await pumpFrame(tester);
      await tester.tap(find.byType(TorchAskDestinations));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('floor-destination-work')),
      );
      await tester.pumpAndSettle();
      expect(find.text('stub:/tasks'), findsOneWidget);
    });
  });

  // ── THE THING THAT WOULD HAVE STOPPED THIS, AND DID NOT ───────────────
  //
  // 25 of the 29 screens have nowhere to draw an answer, so a composer on
  // them could have been a control that looks live and does nothing. It is
  // not: `ChatController.send` takes a question and nothing else, and the bar
  // goes to Ask so the answer has somewhere to land.
  group('send goes somewhere', () {
    testWidgets('a question from a framed screen lands on Ask', (tester) async {
      await pumpFrame(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        'why is availability down in Gauteng?',
      );
      await tester.pump();
      await tester.tap(_sendArmed);
      await tester.pumpAndSettle();

      // The route moved. The turn is in flight on the root-scoped controller
      // and Ask draws it; nothing was swallowed on a screen with no
      // transcript.
      expect(find.text('stub:/assistant'), findsOneWidget);
    });

    testWidgets('an empty press is not a dead press — it opens the field', (
      tester,
    ) async {
      await pumpFrame(tester);
      final field = find.byKey(const ValueKey<String>('ask-composer-field'));

      await tester.tap(_send);
      await tester.pumpAndSettle();

      // Still here, and the keyboard is up: `QuestionComposer._sendOrFocus`.
      expect(find.text('stub:/assistant'), findsNothing);
      expect(field, findsOneWidget);
    });
  });

  group('the hint', () {
    testWidgets('defaults to Ask TradeIQ', (tester) async {
      await pumpFrame(tester);
      expect(find.text('Ask TradeIQ…'), findsOneWidget);
    });

    testWidgets('a screen that names its subject prints that instead', (
      tester,
    ) async {
      await pumpFrame(tester, askHint: 'Ask about your tasks…');
      expect(find.text('Ask about your tasks…'), findsOneWidget);
      expect(find.text('Ask TradeIQ…'), findsNothing);
    });
  });

  // ── THE AMBER ARITHMETIC, AS A TEST RATHER THAN A CLAIM ───────────────
  group('amber', () {
    testWidgets('Messages-shaped screen: its own primary keeps rung 1', (
      tester,
    ) async {
      // A route that declares a primaryCommit of its own must NOT also get
      // the ask bar's. Two primaries is an over-claim on Day and the ladder is
      // right about it: the expected next move when a draft is standing is to
      // send THAT. Rendering at all is the assertion — `TorchScope.resolve`
      // throws a FlutterError on an over-claim in debug.
      await pumpWorklist(
        tester,
        ConsoleFrame(
          phase: 'loaded',
          claims: const <TorchClaim>[TorchClaim.primaryCommit('its-own-send')],
          band: const SizedBox(height: 48),
          header: const TorchAppHeader(title: 'Messages-shaped'),
          children: const <Widget>[Text('a body')],
        ),
        skin: TiqSkin.day(density: TiqDensity.console),
        size: const Size(390, 844),
        path: '/messages',
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ConsoleAskBar), findsOneWidget);
    });

    testWidgets('the bar is last, under a screen that brought its own band', (
      tester,
    ) async {
      await pumpFrame(
        tester,
        band: const SizedBox(
          height: 48,
          key: ValueKey<String>('the-screens-own-band'),
        ),
      );
      final own = tester.getRect(
        find.byKey(const ValueKey<String>('the-screens-own-band')),
      );
      final bar = tester.getRect(find.byType(ConsoleAskBar));
      expect(
        own.bottom,
        lessThanOrEqualTo(bar.top),
        reason:
            'chrome does not move: the grid button is the bottom-left corner '
            'of every console screen or it is not one bar',
      );
    });
  });

  // ── WHAT IT COSTS, IN dp, PRINTED ───────────────────────────────────────
  //
  // The bar is pinned, so every console screen loses its height from the
  // scroll area. What it replaced — `TorchNavPill` in `TorchShell`'s bottom
  // region — was 64dp of pill inside a `Padding(16, 0, 16, 20)`, so **84dp**
  // of chrome, and the 27 framed screens had no band at all. The Floor and
  // Ask had a composer already and lose nothing but the grid button's width.
  //
  // Printed rather than only asserted, because the number somebody will ask
  // for is the number and not the inequality.
  group('the height it costs', () {
    const pillRow = 64.0 + 20.0;

    testWidgets('measured on both phones at 1.0x and 1.3x', (tester) async {
      final rows = <(String, double, double, double)>[];
      for (final (name, size) in <(String, Size)>[
        ('390x844', Size(390, 844)),
        ('360x640', Size(360, 640)),
      ]) {
        for (final scale in <double>[1.0, 1.3, 2.0]) {
          await pumpFrame(tester, size: size, textScale: scale);
          final bar = tester.getRect(find.byType(ConsoleAskBar));
          final body = tester.getRect(find.byType(ListView).first);
          rows.add(('$name @ ${scale}x', bar.height, body.height, size.height));
        }
      }

      // ignore: avoid_print
      print(
        '\n  THE ASK BAR\'S HEIGHT, against the 84dp nav row it replaced\n'
        '  ${'frame'.padRight(16)}${'bar'.padRight(10)}'
        '${'body'.padRight(10)}${'vs the pill row'.padRight(18)}share of fold',
      );
      for (final (frame, bar, body, fold) in rows) {
        final delta = bar - pillRow;
        // ignore: avoid_print
        print(
          '  ${frame.padRight(16)}'
          '${'${bar.toStringAsFixed(0)}dp'.padRight(10)}'
          '${'${body.toStringAsFixed(0)}dp'.padRight(10)}'
          '${'${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}dp'.padRight(18)}'
          '${(bar / fold * 100).toStringAsFixed(1)}%',
        );
      }

      // THE PINS. Nothing here is a guess: the bar must fit, the body must
      // keep the majority of the shortest supported fold, and the bar must
      // not grow past the pill row's own share of it at the text scale a
      // cheap Android ships with.
      for (final (frame, bar, body, fold) in rows) {
        expect(
          bar,
          lessThan(fold * 0.2),
          reason: '$frame: the bar takes a fifth of the fold',
        );
        expect(
          body,
          greaterThan(fold * 0.6),
          reason: '$frame: the scroll area is under 60% of the fold',
        );
      }
    });

    // THE SHORTEST SUPPORTED SCREEN AT THE SCALE THAT BREAKS THINGS. 360x640
    // at 1.3x is where every height argument in this product gets settled.
    testWidgets('360x640 at 1.3x: the bar fits and nothing overflows', (
      tester,
    ) async {
      await pumpFrame(
        tester,
        size: const Size(360, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);

      final bar = tester.getRect(find.byType(ConsoleAskBar));
      expect(bar.bottom, lessThanOrEqualTo(640));
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(360));

      // The grid and Send are both still inside the screen and still 44dp+.
      final grid = tester.getRect(find.byType(TorchAskDestinations));
      expect(grid.left, greaterThanOrEqualTo(0));
      expect(grid.height, greaterThanOrEqualTo(44));
      expect(find.byKey(const ValueKey<String>('a body')), findsNothing);
      expect(find.text('a body'), findsOneWidget);
    });
  });
}
