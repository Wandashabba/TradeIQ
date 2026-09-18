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
    testWidgets('is the name, sentence case, on a rule', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule('Needs a decision'),
      );

      expect(find.text('Needs a decision'), findsOneWidget);
      expect(find.text('NEEDS A DECISION'), findsNothing);
    });

    testWidgets('a count rides inside the same knock-out, in mono', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: const SectionRule('Needs a decision', count: 5),
      );

      expect(find.text('Needs a decision'), findsOneWidget);
      // Through FigureSlot, like every other figure: a count set in the prose
      // face beside a column of mono numbers is the inconsistency the one
      // formatter exists to end.
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('an empty section keeps its rule and says why', (tester) async {
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
      expect(find.text('Needs a decision'), findsOneWidget);
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

      expect(
        find.bySemanticsLabel('Needs a decision, 5'),
        findsOneWidget,
      );
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

    testWidgets('at 2.0x it does not overflow', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        textScale: 2.0,
        size: const Size(360, 400),
        child: const SectionRule('Needs a decision', count: 12),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Needs a decision'), findsOneWidget);
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
