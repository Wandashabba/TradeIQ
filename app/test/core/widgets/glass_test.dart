import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _app(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('GlassPane', () {
    testWidgets('light: a blurred pane with the content on top', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const GlassPane(child: Text('x')), AppTheme.light()),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('light: blur false never builds a BackdropFilter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const GlassPane(kind: GlassKind.tile, blur: false, child: Text('x')),
          AppTheme.light(),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('no theme: the flat fallback — no blur, surface1, '
        'hairline, flat radius', (tester) async {
      // Both app themes are glass; the flat recipe only backs a widget pumped
      // without one.
      await tester.pumpWidget(
        _app(const GlassPane(child: Text('x')), ThemeData()),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('x'), matching: find.byType(Container))
            .first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, TiqColors.dark.surface1);
      expect(deco.border, Border.all(color: TiqColors.dark.line));
      expect(
        deco.borderRadius,
        BorderRadius.circular(TiqColors.dark.radiusPanel),
      );
    });

    testWidgets('no theme: the ground is just the flat plane', (tester) async {
      await tester.pumpWidget(_app(const LitGround(), ThemeData()));
      // No bloom painter under the ground (the Material itself paints its own
      // CustomPaint, so scope the finder to the ground).
      expect(
        find.descendant(
          of: find.byType(LitGround),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      final ground = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(LitGround),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(ground.color, TiqColors.dark.plane);
    });

    testWidgets('dark: night glass — blurred, a faint white fill, a cool rim', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const GlassPane(child: Text('x')), AppTheme.dark()),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      final pane = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0x17FFFFFF) &&
            (w.decoration as BoxDecoration).border ==
                Border.all(color: const Color(0x2EFFFFFF)),
      );
      expect(pane, findsOneWidget);
    });

    testWidgets('dark: the ground is the indigo night', (tester) async {
      await tester.pumpWidget(_app(const LitGround(), AppTheme.dark()));
      final ground = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(LitGround),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient =
          (ground.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [
        LumenPalette.dark.groundTop,
        LumenPalette.dark.groundBottom,
      ]);
    });
  });

  group('AmbientMotion', () {
    testWidgets('off (the suite default): loops rest and the tree settles', (
      tester,
    ) async {
      expect(AmbientMotion.enabled, isFalse);
      await tester.pumpWidget(
        _app(
          const GlassSweep(child: SizedBox(width: 120, height: 40)),
          AppTheme.light(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('on: the sweep runs; reduce-motion stops it', (tester) async {
      AmbientMotion.enabled = true;
      addTearDown(() => AmbientMotion.enabled = false);

      await tester.pumpWidget(
        _app(
          const GlassSweep(child: SizedBox(width: 120, height: 40)),
          AppTheme.light(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('LumenStatus', () {
    test('every status word clears 4.5:1 on its own tint over the ground', () {
      // The tint is translucent, so measure it composited over the lightest
      // and darkest points of the lit ground and over a glass pane.
      final grounds = <String, Color>{
        'groundTop': LumenGlass.groundTop,
        'groundBottom': LumenGlass.groundBottom,
        'surface1': TiqColors.light.surface1,
      };
      for (final status in LumenStatus.values) {
        final sw = status.swatchOf(TiqColors.light);
        for (final MapEntry(key: name, value: ground) in grounds.entries) {
          final wash = Color.alphaBlend(sw.tint, ground);
          final ratio = contrastRatio(sw.ink, wash);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$status ink is $ratio:1 on its tint over $name',
          );
        }
      }
    });

    test('the on-dark status words clear 4.5:1 on the dark pane', () {
      for (final ink in const [
        LumenGlass.onDarkGood,
        LumenGlass.onDarkWarn,
        LumenGlass.onDarkCrit,
        LumenGlass.onDarkMuted,
      ]) {
        final fg = Color.alphaBlend(ink, LumenGlass.darkPaneGround);
        expect(
          contrastRatio(fg, LumenGlass.darkPaneGround),
          greaterThanOrEqualTo(4.5),
          reason: '$ink on the dark pane',
        );
      }
    });

    test('every status carries a word', () {
      for (final status in LumenStatus.values) {
        expect(status.word, isNotEmpty);
      }
    });
  });

  test('night status words clear AA on their own opaque washes', () {
    const c = TiqColors.night;
    for (final status in LumenStatus.values) {
      final sw = status.swatchOf(c);
      for (final ground in [c.surface1, c.surface3]) {
        final ratio = contrastRatio(sw.ink, Color.alphaBlend(sw.tint, ground));
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$status is $ratio:1');
      }
    }
  });

  group('BenchmarkBar', () {
    testWidgets('draws the 2px tick at the target', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            child: BenchmarkBar(
              value: 92.1,
              target: 95,
              status: LumenStatus.warn,
            ),
          ),
          AppTheme.light(),
        ),
      );
      final tick = find.byWidgetPredicate(
        (w) => w is Positioned && w.width == 2,
      );
      expect(tick, findsOneWidget);
      expect(
        tester.widget<Positioned>(tick).left,
        closeTo(200 * 0.95 - 1, 0.01),
      );
    });

    testWidgets('no target, no tick', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            child: BenchmarkBar(value: 40, status: LumenStatus.crit),
          ),
          AppTheme.light(),
        ),
      );
      expect(
        find.byWidgetPredicate((w) => w is Positioned && w.width == 2),
        findsNothing,
      );
    });
  });
}
