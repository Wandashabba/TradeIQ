import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/console_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

/// Both skins build a theme and paint a screen without throwing.
///
/// This is the cheapest test in the file and historically the one that catches
/// the most: a `ThemeExtension` that forgets a slot, a `lerp` that returns
/// null, an assert in a factory, a `TextStyle` whose height is zero.
void main() {
  final modes = <String, ThemeData Function()>{
    'night': AppTheme.night,
    'day': AppTheme.day,
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

    /// THERE ARE TWO SKINS AND A PREFERENCE, AND NOTHING ELSE RESOLVES.
    ///
    /// Veld was removed on 28 September 2026 (unify §4). Nothing in this app
    /// persists a skin — the agent's, the console's and the entry cycle are
    /// all session-scoped, and the one appearance preference that IS stored
    /// is `tiq.themeMode`, which holds `light`/`dark` and nothing else. So
    /// there is no `"veld"` on any disk to migrate. What there *is* is a
    /// resolver per surface, and the pin is that every one of them is total:
    /// a mode that reaches them produces a real, buildable skin rather than a
    /// crash or a blank frame.
    test('every SkinMode resolves to a buildable skin on every surface', () {
      expect(SkinMode.values, <SkinMode>[
        SkinMode.night,
        SkinMode.day,
        SkinMode.auto,
      ]);
      final ambient = TiqSkin.night();
      for (final mode in SkinMode.values) {
        for (final skin in <TiqSkin>[
          TiqSkin.of(mode),
          agentSkinFor(mode),
          entrySkinFor(mode),
          consoleSkinFor(mode, ambient),
        ]) {
          expect(
            skin.mode,
            isNot(SkinMode.auto),
            reason: '$mode: auto is a preference and must resolve before a '
                'skin is built',
          );
          expect(skin.palette.ground.a, 1.0, reason: '$mode: a real ground');
          expect(skin.text.body.size, greaterThan(0));
        }
      }
      // `null` on the console means "follow the app", and it does.
      expect(consoleSkinFor(null, ambient), same(ambient));
    });

    /// THE CASE THE TEST ABOVE NEVER ASKED, WHICH IS WHY IT WENT UNSEEN.
    ///
    /// Its `ambient` is `TiqSkin.night()`, and that is console density, so
    /// `consoleSkinFor(null, ambient)` handing the object straight back was
    /// both the right answer and a passing test. The ambient in the shipping
    /// app is not that: `main.dart` builds `theme:` from `AppTheme.day()`,
    /// whose density defaults to **field**, so a manager in light mode who has
    /// never touched the skin cycle had a FIELD skin as her ambient — and got
    /// the agent's geometry on every migrated console route.
    ///
    /// "Follow the app" is about brightness. It was never about density, and
    /// a console route is console density by definition.
    test('a console route never inherits field density from the app theme', () {
      // Exactly what `main.dart` registers on its light arm.
      final shipped = AppTheme.day();
      final ambient = shipped.extension<TiqSkin>()!;
      expect(
        ambient.space.density,
        TiqDensity.field,
        reason: "main.dart's light theme registers a field skin — if this "
            'ever stops being true, the defect below is gone at the source '
            'and this test is the place to say so',
      );

      final resolved = consoleSkinFor(null, ambient);
      expect(
        resolved.space.density,
        TiqDensity.console,
        reason: 'a manager who has never cycled the skin still gets the '
            "manager's geometry",
      );
      // The brightness she chose is untouched — only the density is corrected.
      expect(resolved.mode, SkinMode.day);
      expect(resolved.brightness, Brightness.light);
      expect(resolved.palette.ground, ambient.palette.ground);

      // And the console skin is a whole, consistent one rather than a field
      // skin with one field swapped.
      expect(resolved.space, same(TiqSpace.console));
      expect(resolved.text, same(TiqType.console));
    });

    test('the skin cycle is a closed two-state loop', () {
      expect(TorchSkinCycle.next(SkinMode.day), SkinMode.night);
      expect(TorchSkinCycle.next(SkinMode.night), SkinMode.day);
      // A preference is not a position: it lands on the agent default's
      // opposite, so the first tap from `auto` always changes something.
      expect(TorchSkinCycle.next(SkinMode.auto), SkinMode.night);
      for (final mode in SkinMode.values) {
        expect(
          TorchSkinCycle.next(TorchSkinCycle.next(mode)),
          isIn(<SkinMode>[SkinMode.night, SkinMode.day]),
          reason: '$mode: two taps land on a real skin, never on auto',
        );
      }
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
    });

    test('the spacing scale is base-4 and has no twelfth step', () {
      expect(TiqSpace.scale, <double>[4, 8, 12, 16, 20, 24, 32, 40, 56, 72, 96]);
      for (final step in TiqSpace.scale) {
        expect(step % 4, 0, reason: '$step is not on the base-4 grid.');
      }
      for (final space in <TiqSpace>[TiqSpace.console, TiqSpace.field]) {
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

    // OVERRIDDEN 29 September 2026. This asserted that the tap-target floor
    // *rises* with the density — console 44, field 48, "a thumb on a shelf is
    // less precise than one on a mouse". That is still true about thumbs; it
    // is no longer true about this product.
    //
    // > "Fix the spacing also please check if everything matches with the
    // > manager side" — the owner, after "literally everything" and "don't
    // > change the manager side, it looks perfect" the same day.
    //
    // So this is a design intention the owner has overridden, not a fact that
    // now measures differently, and the test says so rather than being
    // deleted. 44 is the WCAG 2.5.5 floor and is what the manager side has
    // always run. See `TiqSpace.field` and unify §1.25 for what it cost.
    test('there is one spacing scale, and it is the console\'s', () {
      expect(TiqSpace.console.tapTarget, 44);
      expect(
        TiqSpace.field.tapTarget,
        44,
        reason:
            'Owner override, 29 September 2026. The field scale no longer '
            'differs from the console anywhere; 48 is in the doc comment.',
      );
      for (final field in <(String, double, double)>[
        ('gutter', TiqSpace.console.gutter, TiqSpace.field.gutter),
        ('gutterWide', TiqSpace.console.gutterWide, TiqSpace.field.gutterWide),
        (
          'rowMinHeight',
          TiqSpace.console.rowMinHeight,
          TiqSpace.field.rowMinHeight,
        ),
        ('blockGap', TiqSpace.console.blockGap, TiqSpace.field.blockGap),
        ('intraBlock', TiqSpace.console.intraBlock, TiqSpace.field.intraBlock),
        ('tapTarget', TiqSpace.console.tapTarget, TiqSpace.field.tapTarget),
        (
          'primaryActionHeight',
          TiqSpace.console.primaryActionHeight,
          TiqSpace.field.primaryActionHeight,
        ),
        ('chipHeight', TiqSpace.console.chipHeight, TiqSpace.field.chipHeight),
      ]) {
        expect(
          field.$3,
          field.$2,
          reason:
              '${field.$1} differs between the two scales. There is one '
              'spacing scale; a new divergence needs an owner ruling and a '
              'line in unify §1.25, not a token edit.',
        );
      }
    });
  });

  group('the deprecated shims still work', () {
    test('TiqColors.fromSkin maps every slot onto a Torchlight token', () {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
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
                  // L4: emitted. A gradient, never a blur.
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
