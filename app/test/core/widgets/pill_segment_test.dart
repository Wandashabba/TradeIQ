import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/pill_segment.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _wrap(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

/// The pill's rendered fill/border/text — read back from the tree, so a
/// mutated token fails here rather than being mirrored by a copied constant.
({BoxDecoration deco, TextStyle text, AnimatedContainer box}) _read(
  WidgetTester tester,
) {
  final box = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(PillSegment),
      matching: find.byType(AnimatedContainer),
    ),
  );
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(PillSegment), matching: find.byType(Text)),
  );
  return (deco: box.decoration! as BoxDecoration, text: text.style!, box: box);
}

void main() {
  final themes = <(String, ThemeData, TiqColors)>[
    ('light', AppTheme.light(), TiqColors.light),
    ('dark', AppTheme.dark(), TiqColors.dark),
  ];

  group('PillSegment', () {
    for (final (name, theme, palette) in themes) {
      testWidgets('$name active = solid brand under white', (tester) async {
        await tester.pumpWidget(
          _wrap(
            PillSegment(label: 'Last 30', selected: true, onTap: () {}),
            theme,
          ),
        );

        final r = _read(tester);
        expect(r.deco.color, palette.brand, reason: '$name active bg');
        expect(
          (r.deco.border! as Border).top.color,
          palette.brand,
          reason: '$name active border',
        );
        expect(r.text.color, Colors.white, reason: '$name active text');
      });

      testWidgets('$name inactive = surface1 + hairline under ink2', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            PillSegment(label: 'Last 7', selected: false, onTap: () {}),
            theme,
          ),
        );

        final r = _read(tester);
        expect(r.deco.color, palette.surface1, reason: '$name inactive bg');
        expect(
          (r.deco.border! as Border).top.color,
          palette.line,
          reason: '$name inactive border',
        );
        expect(r.text.color, palette.ink2, reason: '$name inactive text');
      });

      testWidgets('$name radiusPill, 11px w600, 160ms motion', (tester) async {
        await tester.pumpWidget(
          _wrap(PillSegment(label: 'X', selected: true, onTap: () {}), theme),
        );

        final r = _read(tester);
        expect(
          r.deco.borderRadius,
          BorderRadius.circular(AppColors.radiusPill),
          reason: '$name radius',
        );
        expect(r.text.fontSize, 11, reason: '$name font size');
        expect(r.text.fontWeight, FontWeight.w600, reason: '$name weight');
        expect(
          r.box.duration,
          const Duration(milliseconds: 160),
          reason: '$name motion',
        );
      });

      testWidgets(
        '$name self-contained AA pairs (white/brand, ink2/surface1)',
        (tester) async {
          expect(
            contrastRatio(Colors.white, palette.brand),
            greaterThanOrEqualTo(4.5),
            reason: '$name white-on-brand',
          );
          expect(
            contrastRatio(palette.ink2, palette.surface1),
            greaterThanOrEqualTo(4.5),
            reason: '$name ink2-on-surface1',
          );
        },
      );

      testWidgets('$name is a button carrying its selected state', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(PillSegment(label: 'Sel', selected: true, onTap: () {}), theme),
        );
        expect(
          tester.getSemantics(find.byType(PillSegment)),
          isSemantics(isButton: true, isSelected: true),
        );

        await tester.pumpWidget(
          _wrap(
            PillSegment(label: 'Unsel', selected: false, onTap: () {}),
            theme,
          ),
        );
        expect(
          tester.getSemantics(find.byType(PillSegment)),
          isSemantics(isButton: true, isSelected: false),
        );
        handle.dispose();
      });
    }

    testWidgets('onTap fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          PillSegment(label: 'Tap', selected: false, onTap: () => taps++),
          AppTheme.light(),
        ),
      );
      await tester.tap(find.byType(PillSegment));
      expect(taps, 1);
    });

    testWidgets('the passed key lands on the tap target', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PillSegment(
            key: const ValueKey('range-last7'),
            label: 'Last 7',
            selected: false,
            onTap: () {},
          ),
          AppTheme.light(),
        ),
      );
      expect(find.byKey(const ValueKey('range-last7')), findsOneWidget);
    });

    testWidgets('expand:true wraps the segment in Expanded (Row layout)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              PillSegment(
                label: 'Mine',
                selected: true,
                onTap: () {},
                expand: true,
                height: 48,
              ),
            ],
          ),
          AppTheme.light(),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PillSegment),
          matching: find.byType(Expanded),
        ),
        findsOneWidget,
      );
      final box = _read(tester).box;
      expect(box.constraints?.maxHeight, 48, reason: 'fixed-height segment');
    });

    testWidgets('unexpanded pill has no forced height (Wrap layout)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PillSegment(label: 'Pill', selected: false, onTap: () {}),
          AppTheme.light(),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PillSegment),
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
      final box = _read(tester).box;
      expect(box.constraints?.hasBoundedHeight ?? false, isFalse);
    });
  });
}
