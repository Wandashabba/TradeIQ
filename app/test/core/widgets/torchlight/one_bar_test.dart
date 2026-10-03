import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/torch_press.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_frame.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/presentation/chat_screen.dart'
    show askOnlineProvider, askSessionEndedProvider;

import '../../../features/agent_harness.dart' show loadAgentFonts;
import '../../../features/assistant/ask_harness.dart' show LiveRepository;
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
    List<Override> overrides = const <Override>[],
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
      overrides: overrides,
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
  // ── THE PROPORTION PASS, MEASURED ─────────────────────────────────────
  //
  // > *"the bottom doesn't look proportioned"* — the owner, 3 October 2026,
  // > on a screenshot of this bar.
  //
  // The diagnosis was three drawn heights in one row of three objects — the
  // grid key at 44, the field at 54, the Send disc at 36 — and two corner
  // languages inside it, radius 16 on the field against a circle on Send. The
  // fix is one number, `QuestionComposer.barExtent`, read by all three.
  //
  // **This group is the pin, and "in every state" is the part worth having.**
  // A bar that is one height at rest and three heights while a turn streams
  // is the same defect with a delay on it, so the stop key, the offline key
  // and the dead-session key are all measured here and not only the resting
  // one.
  group('one height, one corner language', () {
    /// The trough's own painted box — not the field block, which used to
    /// carry a standing label above it and still carries the counter below.
    final trough = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.foregroundPainter is TroughRulePainter,
    );

    /// The trailing key: Send at rest, Stop while streaming. Depth-first
    /// order puts the grid's pressable first and this one last.
    final trailingKey = find
        .descendant(
          of: find.byType(QuestionComposer),
          matching: find.byType(TorchPressable),
        )
        .last;

    final gridKey = find.descendant(
      of: find.byType(TorchAskDestinations),
      matching: find.byType(TorchPressable),
    );

    /// The one `Container` each control paints itself with. `TorchPressable`
    /// contributes none, so there is exactly one under each key, and the
    /// trough's is the `CustomPaint`'s child.
    Finder boxIn(Finder of) =>
        find.descendant(of: of, matching: find.byType(Container)).first;

    BorderRadius radiusOf(WidgetTester tester, Finder of) =>
        ((tester.widget<Container>(boxIn(of)).decoration! as BoxDecoration)
                .borderRadius!
            as BorderRadius);

    /// What the row actually paints, in the state the frame is in.
    ({double grid, double field, double key, double bar}) drawn(
      WidgetTester tester,
    ) => (
      grid: tester.getRect(boxIn(gridKey)).height,
      field: tester.getRect(trough).height,
      key: tester.getRect(boxIn(trailingKey)).height,
      bar: tester.getRect(find.byType(ConsoleAskBar)).height,
    );

    // ── 1. AT REST, AND THE TABLE THE OWNER ASKED FOR ──────────────────
    testWidgets('the three objects are one height, both skins, both phones', (
      tester,
    ) async {
      final rows = <(String, double, double, double, double)>[];
      for (final (skinName, skin) in <(String, TiqSkin)>[
        ('night', TiqSkin.night(density: TiqDensity.console)),
        ('day', TiqSkin.day(density: TiqDensity.console)),
      ]) {
        for (final (frame, size) in const <(String, Size)>[
          ('390x844', Size(390, 844)),
          ('360x640', Size(360, 640)),
        ]) {
          for (final scale in const <double>[1.0, 1.3]) {
            await pumpFrame(tester, skin: skin, size: size, textScale: scale);
            final d = drawn(tester);
            rows.add(('$skinName $frame @ ${scale}x', d.grid, d.field, d.key, d.bar));
          }
        }
      }

      // ignore: avoid_print
      print(
        '\n  THE ASK BAR, DRAWN — was 44 / 54 / 36 and a standing label\n'
        '  ${'frame'.padRight(22)}${'grid'.padRight(8)}'
        '${'field'.padRight(8)}${'send'.padRight(8)}bar',
      );
      for (final (frame, grid, field, key, bar) in rows) {
        // ignore: avoid_print
        print(
          '  ${frame.padRight(22)}'
          '${'${grid.toStringAsFixed(1)}dp'.padRight(8)}'
          '${'${field.toStringAsFixed(1)}dp'.padRight(8)}'
          '${'${key.toStringAsFixed(1)}dp'.padRight(8)}'
          '${bar.toStringAsFixed(1)}dp',
        );
      }

      for (final (frame, grid, field, key, _) in rows) {
        for (final (what, value) in <(String, double)>[
          ('the grid key', grid),
          ('the field', field),
          ('the send disc', key),
        ]) {
          expect(
            value,
            closeTo(QuestionComposer.barExtent, 0.5),
            reason:
                '$frame: $what drew ${value.toStringAsFixed(1)}dp against the '
                'row\'s ${QuestionComposer.barExtent}dp. The whole point of '
                'this change is that nothing in the row disagrees.',
          );
        }
      }
    });

    // ── 2. AND THE SAME IN EVERY STATE, WHICH IS THE HARDER HALF ───────
    //
    // Split one state per test rather than looped: Riverpod refuses to change
    // the NUMBER of overrides inside one `pumpWidget` lifetime, and these
    // states are reached by overriding a different count of providers.

    void expectRow(WidgetTester tester, String state) {
      final d = drawn(tester);
      expect(d.grid, closeTo(48, 0.5), reason: '$state: the grid key');
      expect(d.field, closeTo(48, 0.5), reason: '$state: the field');
      expect(d.key, closeTo(48, 0.5), reason: '$state: the trailing key');
    }

    testWidgets('typing one line holds the row at 48', (tester) async {
      await pumpFrame(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        'why?',
      );
      await tester.pump();
      // The armed sentence, so this really is the typed state and not the
      // resting one measured twice.
      expect(_sendArmed, findsOneWidget);
      expectRow(tester, 'typing');
    });

    testWidgets('the Stop key — which was a radius-16 square — is the pill', (
      tester,
    ) async {
      final live = LiveRepository();
      await pumpFrame(
        tester,
        overrides: <Override>[
          assistantRepositoryProvider.overrideWithValue(live),
        ],
      );
      ProviderScope.containerOf(tester.element(find.byType(ConsoleAskBar)))
          .read(chatControllerProvider.notifier)
          .send('a question that is still running');
      await tester.pump();

      expect(find.bySemanticsLabel('Stop the answer'), findsOneWidget);
      expectRow(tester, 'streaming');
      expect(
        radiusOf(tester, trailingKey),
        BorderRadius.circular(24),
        reason:
            'Stop was `radii.control` — 16 — so the bar changed corner '
            'language the moment a turn started streaming.',
      );
      await live.close();
      await tester.pump();
    });

    // One test per override set. Riverpod refuses to swap WHICH provider a
    // scope overrides between pumps, not only how many.
    testWidgets('offline, where Send is disabled', (tester) async {
      await pumpFrame(
        tester,
        overrides: <Override>[askOnlineProvider.overrideWithValue(false)],
      );
      expect(
        find.bySemanticsLabel('Send, unavailable, needs a connection'),
        findsOneWidget,
        reason: 'Send has to actually be disabled for this to mean anything',
      );
      expectRow(tester, 'offline');
    });

    testWidgets('a dead session, where Send is disabled', (tester) async {
      await pumpFrame(
        tester,
        overrides: <Override>[askSessionEndedProvider.overrideWithValue(true)],
      );
      expect(
        find.bySemanticsLabel('Send, unavailable, needs a connection'),
        findsOneWidget,
      );
      expectRow(tester, 'session ended');
    });

    // ── 2b. A QUESTION THAT WRAPS, WHICH IS THE ONE STATE WHERE THE ROW
    //        IS NOT ONE HEIGHT, AND IS SUPPOSED NOT TO BE ─────────────────
    //
    // The field is `minLines: 1, maximumLines: 5` and that is older than this
    // bar: a composer that would not show a manager the question they are
    // typing is worse than one whose row grows. What the proportion pass
    // changes is where the growth starts — 48dp rather than 54 — and the
    // numbers are printed rather than claimed, because "the bar's height may
    // change" is the thing somebody will ask about.
    testWidgets('it grows with a wrapping question, and the keys do not', (
      tester,
    ) async {
      final rows = <(int, double, double, double)>[];
      for (final (lines, question) in const <(int, String)>[
        (1, 'why?'),
        (2, 'why is availability down in Gauteng North this week'),
        (
          5,
          'why is availability down in Gauteng North this week and which of '
              'the outlets in it have been out of Kalahari Cola for more than '
              'three days running, by route',
        ),
      ]) {
        await pumpFrame(tester);
        await tester.enterText(
          find.byKey(const ValueKey<String>('ask-composer-field')),
          question,
        );
        await tester.pump();
        final d = drawn(tester);
        rows.add((lines, d.field, d.key, d.bar));
      }

      // ignore: avoid_print
      print(
        '\n  THE PILL AS THE QUESTION WRAPS, 390x844 @ 1.0x\n'
        '  ${'lines'.padRight(8)}${'field'.padRight(10)}'
        '${'keys'.padRight(10)}bar',
      );
      for (final (lines, field, key, bar) in rows) {
        // ignore: avoid_print
        print(
          '  ${'$lines'.padRight(8)}'
          '${'${field.toStringAsFixed(1)}dp'.padRight(10)}'
          '${'${key.toStringAsFixed(1)}dp'.padRight(10)}'
          '${bar.toStringAsFixed(1)}dp',
        );
      }

      for (final (lines, field, key, _) in rows) {
        expect(key, closeTo(48, 0.5), reason: '$lines lines: the keys');
        expect(
          field,
          greaterThanOrEqualTo(48 - 0.5),
          reason: '$lines lines: the field never draws under its extent',
        );
      }
      // It grows, and it grows monotonically. A field that stopped at one
      // line would be hiding the question.
      expect(rows[1].$2, greaterThan(rows[0].$2));
      expect(rows[2].$2, greaterThan(rows[1].$2));
      // And the keys stay on the pill's bottom edge rather than its middle.
      await pumpFrame(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        'why is availability down in Gauteng North this week',
      );
      await tester.pump();
      expect(
        tester.getRect(boxIn(trailingKey)).bottom,
        closeTo(tester.getRect(trough).bottom, 0.5),
      );
      expect(
        tester.getRect(boxIn(gridKey)).bottom,
        closeTo(tester.getRect(trough).bottom, 0.5),
      );
    });

    // ── 3. ONE CORNER LANGUAGE ─────────────────────────────────────────
    //
    // Read off the tree rather than off the constants: the field's radius
    // arrives through `TroughGeometry.pill` and a parameter that stopped being
    // threaded would still leave the constants agreeing.
    testWidgets('every corner in the row is extent / 2', (tester) async {
      const pill = BorderRadius.all(Radius.circular(24));
      for (final skin in <TiqSkin>[
        TiqSkin.night(density: TiqDensity.console),
        TiqSkin.day(density: TiqDensity.console),
      ]) {
        await pumpFrame(tester, skin: skin);
        expect(
          radiusOf(tester, trough),
          pill,
          reason:
              'the field. `radii.control` is 16 and stays 16 — this comes '
              'from TroughGeometry.pill, which is the one trough in the app '
              'that is not radii.input.',
        );
        expect(radiusOf(tester, gridKey), pill, reason: 'the grid key');
        expect(radiusOf(tester, trailingKey), pill, reason: 'the Send disc');
      }
    });

    // ── 4. THE STANDING LABEL IS GONE, AND THE LEFT EDGE IS STRAIGHT ───
    //
    // The label was the reason the bar's left margin was ragged: it was
    // indented to the FIELD's left edge, 48dp in from the grid key's, and it
    // repeated the hint directly beneath it.
    testWidgets('no standing label, and nothing is indented past the grid', (
      tester,
    ) async {
      await pumpFrame(tester);
      expect(find.text('Ask a question'), findsNothing);

      final bar = tester.getRect(find.byType(ConsoleAskBar));
      final grid = tester.getRect(find.byType(TorchAskDestinations));
      expect(
        grid.left,
        closeTo(bar.left, 0.5),
        reason:
            'the grid key is the bar\'s left edge; anything left of it or '
            'indented from it is the ragged margin coming back',
      );
      // Every Text in the bar starts at or right of the trough's own text
      // inset. With the label gone there is exactly one: the hint.
      final texts = find.descendant(
        of: find.byType(ConsoleAskBar),
        matching: find.byType(Text),
      );
      expect(texts, findsOneWidget);
      expect(tester.widget<Text>(texts).data, 'Ask TradeIQ…');
    });

    // ── 5. THE TAP TARGETS, WHICH THIS CHANGE CANNOT COST ──────────────
    testWidgets('both keys still hit 44dp or more, at 1.0x and 1.3x', (
      tester,
    ) async {
      for (final scale in const <double>[1.0, 1.3]) {
        await pumpFrame(tester, size: const Size(360, 640), textScale: scale);
        for (final (what, key) in <(String, Finder)>[
          ('the grid key', gridKey),
          ('Send', trailingKey),
        ]) {
          final rect = tester.getRect(key);
          expect(rect.height, greaterThanOrEqualTo(44), reason: '$what @ ${scale}x');
          expect(rect.width, greaterThanOrEqualTo(44), reason: '$what @ ${scale}x');
        }
      }
    });
  });
}
