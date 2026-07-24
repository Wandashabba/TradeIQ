import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/delta_pill.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// The wash and text colour as actually rendered, read back from the tree —
/// so a mutated colour in the widget fails here rather than being mirrored
/// by a copied constant.
Future<(Color bg, Color fg)> _pumpAndRead(
  WidgetTester tester,
  DeltaPill pill,
) async {
  await tester.pumpWidget(_wrap(pill));
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(DeltaPill),
      matching: find.byType(Container),
    ),
  );
  final decoration = box.decoration! as BoxDecoration;
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(DeltaPill), matching: find.byType(Text)),
  );
  return (decoration.color!, text.style!.color!);
}

void main() {
  group('DeltaPill', () {
    testWidgets('good tone renders "▲ 4.2" on the green wash', (tester) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        const DeltaPill(delta: 4.2, tone: DeltaTone.good),
      );

      expect(find.text('▲ 4.2'), findsOneWidget);
      expect(bg, const Color(0xFFE7F5E7));
      expect(fg, const Color(0xFF0B6B0B));
    });

    testWidgets('warn tone takes the amber wash', (tester) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        const DeltaPill(delta: 1.3, tone: DeltaTone.warn),
      );

      expect(find.text('▲ 1.3'), findsOneWidget);
      expect(bg, const Color(0xFFFDF3E2));
      expect(fg, const Color(0xFF8A5A00));
    });

    testWidgets('bad tone takes the red wash', (tester) async {
      final (bg, fg) = await _pumpAndRead(
        tester,
        const DeltaPill(delta: -2.0, tone: DeltaTone.bad),
      );

      expect(find.text('▼ 2.0'), findsOneWidget);
      expect(bg, const Color(0xFFFDEEEE));
      expect(fg, const Color(0xFFA52A2A));
    });

    testWidgets('a negative delta renders the down glyph in any tone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DeltaPill(delta: -0.8, tone: DeltaTone.warn)),
      );

      expect(find.text('▼ 0.8'), findsOneWidget);
    });

    testWidgets('the wash is a fully rounded pill with 10–11px w700 text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DeltaPill(delta: 4.2, tone: DeltaTone.good)),
      );

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(DeltaPill),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(999));

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(DeltaPill),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.fontSize, inInclusiveRange(10, 11));
    });

    // Every wash pair must clear WCAG AA for its own text (spec,
    // Accessibility section) — measured off the rendered widget, so a colour
    // regression fails with the real ratio in the message.
    for (final tone in DeltaTone.values) {
      testWidgets('$tone text clears 4.5:1 over its wash', (tester) async {
        final (bg, fg) = await _pumpAndRead(
          tester,
          DeltaPill(delta: 1.0, tone: tone),
        );

        final ratio = contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$tone is $ratio:1 over its wash — pill text is 10–11px, '
              'so AA demands 4.5:1. Darken the text or lighten the wash.',
        );
      });
    }
  });
}
