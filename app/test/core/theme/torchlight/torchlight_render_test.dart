import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// All three skins build a theme and paint a screen without throwing.
///
/// This is the cheapest test in the file and historically the one that catches
/// the most: a `ThemeExtension` that forgets a slot, a `lerp` that returns
/// null, an assert in a factory, a `TextStyle` whose height is zero.
void main() {
  final modes = <String, ThemeData Function()>{
    'night': AppTheme.night,
    'day': AppTheme.day,
    'veld': AppTheme.veld,
  };

  group('every skin renders', () {
    for (final MapEntry(key: name, value: build) in modes.entries) {
      testWidgets('$name paints a screen with every token on it', (
        tester,
      ) async {
        final theme = build();
        await tester.pumpWidget(
          MaterialApp(theme: theme, home: const _TokenSampler()),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(_TokenSampler), findsOneWidget);
      });

      testWidgets('$name registers exactly one TiqSkin', (tester) async {
        final theme = build();
        final skin = theme.extension<TiqSkin>();
        expect(skin, isNotNull, reason: '$name did not register a TiqSkin.');
        expect(
          theme.extension<TiqColors>(),
          isNotNull,
          reason:
              'The deprecated TiqColors shim has to stay registered until the '
              'last screen is migrated, or 60 screens lose their colours.',
        );
        expect(theme.brightness, skin!.brightness);
      });
    }

    testWidgets('a mode change lerps without throwing', (tester) async {
      // ThemeData animates between themes; a ThemeExtension.lerp that returns
      // null or throws takes the whole app down mid-transition.
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.night(), home: const _TokenSampler()),
      );
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.day(), home: const _TokenSampler()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the skin value set', () {
    test('lerp holds the endpoints and snaps the non-interpolable half', () {
      final night = TiqSkin.night();
      final day = TiqSkin.day();
      expect(night.lerp(day, 0).palette.ground, night.palette.ground);
      expect(night.lerp(day, 1).palette.ground, day.palette.ground);
      expect(night.lerp(day, 0.4).mode, SkinMode.night);
      expect(night.lerp(day, 0.6).mode, SkinMode.day);
      expect(
        night.lerp(day, 0.6).space.tapTarget,
        day.space.tapTarget,
        reason: 'Half a tap target is not a tap target.',
      );
      expect(night.lerp(null, 0.5), night);
    });

    test('copyWith replaces one field and leaves the rest', () {
      final night = TiqSkin.night();
      final copied = night.copyWith(motion: TiqMotion.off);
      expect(copied.motion.enabled, isFalse);
      expect(copied.palette, night.palette);
      expect(copied.mode, night.mode);
    });

    test('Veld cannot be constructed at Console density', () {
      final veld = TiqSkin.veld();
      expect(veld.density, TiqDensity.veld);
      expect(veld.space, TiqSpace.veld);
      // The type system carries the rule: TiqSkin.veld() has no density
      // parameter, so `Veld × Console` has no spelling. The assert below is
      // the other half — Night and Day may not borrow Veld's density either.
      expect(
        () => TiqSkin.night(density: TiqDensity.veld),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TiqSkin.day(density: TiqDensity.veld),
        throwsA(isA<AssertionError>()),
      );
    });

    test('SkinMode.of resolves auto from the platform brightness', () {
      expect(
        TiqSkin.of(SkinMode.auto, platformBrightness: Brightness.dark).mode,
        SkinMode.night,
      );
      expect(
        TiqSkin.of(SkinMode.auto, platformBrightness: Brightness.light).mode,
        SkinMode.day,
      );
      expect(TiqSkin.of(SkinMode.veld).mode, SkinMode.veld);
    });

    test('the spacing scale is base-4 and has no twelfth step', () {
      expect(TiqSpace.scale, <double>[4, 8, 12, 16, 20, 24, 32, 40, 56, 72, 96]);
      for (final step in TiqSpace.scale) {
        expect(step % 4, 0, reason: '$step is not on the base-4 grid.');
      }
      for (final space in <TiqSpace>[
        TiqSpace.console,
        TiqSpace.field,
        TiqSpace.veld,
      ]) {
        for (final value in <double>[
          space.gutter,
          space.gutterWide,
          space.blockGap,
          space.intraBlock,
        ]) {
          expect(
            TiqSpace.scale,
            contains(value),
            reason:
                '${space.density.name} uses $value, which is not on the '
                'scale. No other value exists.',
          );
        }
      }
    });

    test('the pill radius is gone and five materials remain', () {
      expect(TiqRadii.lit.chip, 6);
      // `control` moved 10 → 16 on 26 September 2026. At 10 a 56dp field and
      // a 48dp button read as rectangles beside radius-22 cards, which is
      // what the owner meant by "the login as well". 16 is a visible
      // round-rect at both heights and still reads apart from a card.
      expect(TiqRadii.lit.control, 16);
      expect(TiqRadii.lit.panel, 14);
      // `card` 22 and `plate` 28 arrived with the owner's card override of
      // 25 September 2026 (torchlight-aisle §9c): a list row a person acts
      // on, and the plate that stopped being a full-bleed band. A panel is a
      // container and a card is an object, and the mockup reads the two
      // apart by exactly this difference.
      expect(TiqRadii.lit.card, 22);
      expect(TiqRadii.lit.plate, 28);
      expect(TiqRadii.lit.rule, 0);
      for (final r in <double>[
        TiqRadii.lit.chip,
        TiqRadii.lit.control,
        TiqRadii.lit.panel,
        TiqRadii.lit.card,
        TiqRadii.lit.plate,
      ]) {
        expect(
          r,
          lessThan(999),
          reason: 'The 999 stadium radius died with the active-tab pill.',
        );
      }
      // MOVED 26 September 2026: an input is a control, round on all four
      // corners, and it is `control` on every one of them. The trough — square
      // at the top, rounded at the bottom — said a true thing about an input
      // in the one channel this product uses to say *soft object*, and two
      // square corners on a 56dp box is the rectangle the owner objected to
      // on the sign-in screen. The holding is carried by the fill and the
      // resting edge, which `input_test.dart` asserts.
      final input = TiqRadii.lit.input;
      expect(input.topLeft, const Radius.circular(16));
      expect(input.bottomLeft, const Radius.circular(16));
      expect(
        input.topLeft,
        Radius.circular(TiqRadii.lit.control),
        reason: 'an input takes the control radius, not a number of its own',
      );
    });

    test('the tap-target floor rises with the density', () {
      expect(TiqSpace.console.tapTarget, 44);
      expect(TiqSpace.field.tapTarget, 48);
      expect(
        TiqSpace.veld.tapTarget,
        56,
        reason: 'A thumb in the sun is imprecise.',
      );
    });
  });

  group('the deprecated shims still work', () {
    test('TiqColors.fromSkin maps every slot onto a Torchlight token', () {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
        TiqSkin.veld(),
      ]) {
        final c = TiqColors.fromSkin(skin);
        final p = skin.palette;
        expect(c.plane, p.ground);
        expect(c.surface1, p.surface);
        expect(c.ink1, p.ink1);
        expect(c.brand, p.flame600);
        expect(
          c.warn,
          p.bad,
          reason:
              'There is no amber warning in TradeIQ. The old warn slot has to '
              'land on a severity token, not on a colour that merely looks '
              'like the old one.',
        );
        expect(c.radiusPanel, skin.radii.panel);
      }
    });

    testWidgets('context.colors and context.skin both resolve', (
      tester,
    ) async {
      late TiqSkin skin;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.night(),
          home: Builder(
            builder: (context) {
              skin = context.skin;
              // ignore: deprecated_member_use_from_same_package
              final legacy = context.colors;
              expect(legacy.plane, skin.palette.ground);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(skin.mode, SkinMode.night);
    });
  });
}

/// A screen that touches every token, so "it renders" means something.
class _TokenSampler extends StatelessWidget {
  const _TokenSampler();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Scaffold(
      backgroundColor: p.ground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(skin.space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final token in skin.text.all)
              Padding(
                padding: EdgeInsets.only(bottom: TiqSpace.s1),
                child: Text(token.name, style: token.style(color: p.ink1)),
              ),
            // L2: the one panel surface, with its compliant edge.
            Container(
              padding: EdgeInsets.all(skin.space.intraBlock),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(skin.radii.panel),
                border: Border.all(
                  color: p.edgeStructure,
                  width: skin.depth.borderWidth,
                ),
                boxShadow: skin.depth.shadows,
              ),
              child: Column(
                children: <Widget>[
                  Text('ink-2', style: skin.text.body.style(color: p.ink2)),
                  Text('ink-3', style: skin.text.meta.style(color: p.ink3)),
                  Text(
                    '0123456789',
                    style: skin.text.monoIdent.style(color: p.ink1),
                  ),
                  Divider(color: p.hairline, height: TiqSpace.s3),
                  // L4: emitted. A gradient, never a blur, and never in Veld.
                  Container(
                    height: TiqSpace.s2,
                    decoration: skin.depth.allowsGradients
                        ? const BoxDecoration(
                            gradient: LinearGradient(
                              colors: TiqPalette.glowAmber,
                            ),
                          )
                        : BoxDecoration(color: p.ground),
                  ),
                ],
              ),
            ),
            SizedBox(height: skin.space.blockGap),
            // The one amber block, carrying dark ink.
            SizedBox(
              height: skin.space.primaryActionHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.flame600,
                  borderRadius: BorderRadius.circular(skin.radii.control),
                ),
                child: Center(
                  child: Text(
                    'Commit',
                    style: skin.text.label.style(color: skin.onFill(p.flame600)),
                  ),
                ),
              ),
            ),
            SizedBox(height: skin.space.intraBlock),
            Row(
              children: <Widget>[
                _Swatch(color: p.good, label: 'On target'),
                _Swatch(color: p.bad, label: 'Critical'),
                _Swatch(color: p.comparison, label: 'Comparison'),
                _Swatch(color: p.chartNeutral, label: 'Neutral'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(right: TiqSpace.s2),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: TiqSpace.s6,
            height: TiqSpace.s3,
            child: ColoredBox(color: color),
          ),
          Text(
            label,
            style: skin.text.eyebrow.style(color: skin.palette.ink2),
          ),
        ],
      ),
    );
  }
}
