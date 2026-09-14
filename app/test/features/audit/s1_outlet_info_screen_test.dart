import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s1_outlet_info_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;

const _bothThemes = [('light', TiqColors.light), ('dark', TiqColors.night)];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen({ThemeData? theme, Key? key, DateTime? ts}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: S1OutletInfoScreen(key: key, checkinTs: ts),
    ),
  ),
);

void main() {
  testWidgets(
    'renders the read-only check-in confirmation on its theme container — '
    'a console PanelCard, or a glass tile in Lumen Glass',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _screen(
            theme: _themeFor(name),
            key: ValueKey(name),
            ts: DateTime(2026, 7, 25, 14, 30),
          ),
        );
        await tester.pumpAndSettle();

        // Never a raw Card, in either theme.
        expect(find.byType(Card), findsNothing, reason: '$name no Card');
        if (palette.glass) {
          // Lumen Glass: the check-in is one no-blur glass tile.
          expect(
            find.ancestor(
              of: find.text('Confirmed at check-in'),
              matching: find.byWidgetPredicate(
                (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
              ),
            ),
            findsOneWidget,
            reason: '$name glass tile',
          );
        } else {
          // The read-only info sits in the console's only container.
          expect(find.byType(PanelCard), findsOneWidget, reason: '$name panel');
        }

        // Honest wording preserved: this is confirmed at check-in, not agent
        // input.
        expect(
          find.text('Confirmed at check-in'),
          findsOneWidget,
          reason: name,
        );
        expect(find.text('2026-07-25 14:30'), findsOneWidget, reason: name);
        expect(
          find.byKey(const ValueKey('checkin-timestamp')),
          findsOneWidget,
          reason: '$name timestamp key',
        );
        expect(find.text('Passed'), findsOneWidget, reason: name);
      }
    },
  );

  testWidgets(
    'Lumen Glass: the time is a mono figure and the geofence pass is a ✓ tile '
    'beside its word, AA-safe',
    (tester) async {
      const palette = TiqColors.light;
      await tester.pumpWidget(
        _screen(theme: AppTheme.light(), ts: DateTime(2026, 7, 25, 14, 30)),
      );
      await tester.pumpAndSettle();

      final time = tester.widget<Text>(
        find.byKey(const ValueKey('checkin-timestamp')),
      );
      expect(time.style?.fontFamily, LumenGlass.mono);

      // Never colour alone: the ✓ glyph and the word travel together.
      final mark = tester.widget<StatusTile>(find.byType(StatusTile));
      expect(mark.status, LumenStatus.good);
      expect(mark.glyph, '✓');

      final good = LumenStatus.good.swatchOf(palette);
      final passed = tester.widget<Text>(find.text('Passed')).style!.color!;
      expect(passed, good.ink);
      expect(contrastRatio(passed, palette.surface1), greaterThanOrEqualTo(4.5));
      // The glyph on its own wash, composited opaque over the pane.
      expect(
        contrastRatio(good.ink, Color.alphaBlend(good.tint, palette.surface1)),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets('degrades honestly when no check-in timestamp is present', (
    tester,
  ) async {
    for (final (name, _) in _bothThemes) {
      await tester.pumpWidget(
        _screen(theme: _themeFor(name), key: ValueKey(name)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirmed at check-in'), findsOneWidget, reason: name);
      // Never a fabricated timestamp — an absent check-in reads as such.
      expect(find.text('Not recorded'), findsOneWidget, reason: name);
    }
  });
}
