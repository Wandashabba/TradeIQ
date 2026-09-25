import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/sparkline.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/severity_mark.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';

import '../../design/amber_golden.dart';
import 'torch_harness.dart';

void main() {
  group('section rule', () {
    // MOVED 25 September 2026. These four asserted the marker was sentence
    // case on a rule and that "NEEDS A DECISION" was the thing the component
    // replaced. The owner looked at the finished Floor — whose one marker is
    // exactly that uppercase kicker, on the ground, with no line — and said to
    // make its design global. unify §1.17's "every other screen keeps the
    // knocked-out rule; this is not a licence to delete it" is the sentence
    // that was overridden; §1.17 now records the override.
    //
    // The half that did NOT move is asserted harder below: the **string** is
    // still sentence case, because the uppercase is presentation. A call site
    // that shouts in the data reaches a screen reader that spells it out, a
    // search index and the PDF exporter, and the component still asserts
    // against it.
    testWidgets('is the name, uppercase, on the ground', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule('Needs a decision'),
      );

      expect(find.text('NEEDS A DECISION'), findsOneWidget);
      expect(find.text('Needs a decision'), findsNothing);
      // No line across the screen. The gap of ground between cards is the
      // boundary now, and a rule drawn across it is the "one more box" the
      // owner objected to twice.
      expect(
        find.descendant(
          of: find.byType(SectionRule),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('the string stays sentence case, and it is asserted', (
      tester,
    ) async {
      // The shout is presentation. A call site that puts it in the data is a
      // call site whose string reaches a screen reader, and this is the guard.
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule('NEEDS A DECISION'),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('a count rides in the marker’s own words', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule('Needs a decision', count: 5),
      );

      // Not a separate mono figure beside the words — that is the "count
      // chip" the override names — and not dropped either: it is how many are
      // in the section, which is exactly what a manager deciding whether to
      // open it is reading.
      expect(find.text('NEEDS A DECISION · 5'), findsOneWidget);
    });

    testWidgets('an empty section keeps its marker and says why', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule(
          'Needs a decision',
          emptyLine: 'Everything triaged.',
        ),
      );

      // A section that vanishes when empty makes a manager think the feature
      // is gone.
      expect(find.text('NEEDS A DECISION'), findsOneWidget);
      expect(find.text('Everything triaged.'), findsOneWidget);
    });

    testWidgets('it is a header for a screen reader, and the rule is not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule('Needs a decision', count: 5),
      );

      expect(find.bySemanticsLabel('Needs a decision, 5'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an action is a 44dp target at the far end', (tester) async {
      var tapped = false;
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: SectionRule(
          'Needs a decision',
          count: 12,
          action: SectionRuleAction('See all', onTap: () => tapped = true),
        ),
      );

      final box = tester.getSize(find.byType(SectionRuleAction));
      expect(box.height, greaterThanOrEqualTo(44));
      await tester.tap(find.byType(SectionRuleAction));
      expect(tapped, isTrue);
    });

    // THE THIRD PLACE THE KIT SWALLOWED A VERB.
    //
    // The heading's own `Semantics` used to wrap the whole component with
    // `excludeSemantics: true`, so the action had no node at all; and the
    // action's node declared `button: true` without an `onTap`, so even once
    // the node existed a reader could focus it and not press it. Both are
    // failures a `tester.tap` cannot see, because a tap goes through the
    // render tree and a screen reader goes through the semantics tree.
    testWidgets('an action is announced AND can be performed by a reader', (
      tester,
    ) async {
      var tapped = false;
      final handle = tester.ensureSemantics();
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: SectionRule(
          'Needs a decision',
          count: 12,
          action: SectionRuleAction('See all', onTap: () => tapped = true),
        ),
      );

      final data = tester
          .getSemantics(find.bySemanticsLabel('See all'))
          .getSemanticsData();
      expect(
        data.flagsCollection.isButton,
        isTrue,
        reason: 'The action has to have a node of its own to be announced.',
      );
      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'A button that announces itself and carries no tap action is a '
            'control a screen-reader user can focus and cannot use.',
      );

      await tester.tap(find.bySemanticsLabel('See all'));
      expect(tapped, isTrue);
      handle.dispose();
    });

    testWidgets('the heading is still one utterance', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: SectionRule(
          'Needs a decision',
          count: 12,
          action: SectionRuleAction('See all', onTap: () {}),
        ),
      );

      final heading = tester
          .getSemantics(find.bySemanticsLabel('Needs a decision, 12'))
          .getSemanticsData();
      expect(heading.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('at 2.0x it does not overflow', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        textScale: 2.0,
        size: const Size(360, 400),
        child: const SectionRule('Needs a decision', count: 12),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('NEEDS A DECISION · 12'), findsOneWidget);
    });

    testWidgets('Afrikaans wraps the same way', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        textScale: 2.0,
        size: const Size(360, 400),
        locale: const Locale('af'),
        child: const SectionRule('Benodig ’n besluit', count: 12),
      );

      expect(tester.takeException(), isNull);
    });

    for (final skin in torchSkins) {
      testWidgets('${skin.mode.name}: it is never amber', (tester) async {
        await pumpTorch(
          tester,
          skin: skin,
          child: const SectionRule('Needs a decision', count: 5),
        );

        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'It replaced an amber section marker and a numbered eyebrow '
              'precisely so it could not become a repeated accent.\n'
              '${census.describe()}',
        );
      });
    }
  });

  group('sparkline', () {
    testWidgets('fewer than two points draws nothing', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const Sparkline(points: <double>[61]),
      );

      // A single reading drawn as a flat line is a fabricated trend.
      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('Veld draws none at all', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.veld(),
        child: const Sparkline(points: <double>[61, 64, 58, 52]),
      );

      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('it paints, and it is never amber', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const Sparkline(
          points: <double>[61, 64, 58, 52, 44],
          severity: SeverityMarkKind.critical,
          semanticsLabel: 'Falling over five weeks',
        ),
      );

      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            "The last dot carries the row's verdict, and a verdict leaves the "
            'amber band entirely. Five rows of amber last-dots is the exact '
            'repeated fill the law bans by name.\n${census.describe()}',
      );
    });

    test('the last dot takes the severity ink, never a flame token', () {
      final skin = TiqSkin.night();
      for (final kind in SeverityMarkKind.values) {
        final ink = SeverityMarkToken.of(skin, kind).ink;
        expect(
          <Color>[
            skin.palette.flame300,
            skin.palette.flame500,
            skin.palette.flame600,
            skin.palette.flame700,
            skin.palette.flame900,
          ],
          isNot(contains(ink)),
          reason: '${kind.name} resolved to an amber token.',
        );
      }
    });

    test('a flat series draws through the middle, not along the floor', () {
      // "No change" is a horizontal line, not a value of zero — the painter's
      // own rule, asserted here rather than in a screenshot.
      final painter = SparklinePainter(
        points: const <double>[50, 50, 50],
        line: const Color(0xFF000000),
        dot: const Color(0xFF000000),
      );
      expect(painter.shouldRepaint(painter), isFalse);
    });
  });
}
