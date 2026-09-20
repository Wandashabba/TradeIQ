import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The text-scaling policy, at the two sizes that matter.
///
/// The audit found no `textScale` handling anywhere in the app. That is not
/// "the default behaviour is fine" — it means nobody had looked, and a reader
/// at the OS's largest setting was getting whatever the layouts happened to
/// do. 1.3 is roughly the largest Android setting a lot of people actually
/// use; 2.0 is the ceiling this policy declares.
void main() {
  const scales = <double>[1.0, 1.3, 2.0];

  group('the clamp', () {
    test('holds between 1.0 and 2.0', () {
      expect(TiqTextScale.clamp(TextScaler.noScaling).scale(16), 16);
      expect(
        TiqTextScale.clamp(const TextScaler.linear(1.3)).scale(10),
        closeTo(13, 0.001),
      );
      expect(
        TiqTextScale.clamp(const TextScaler.linear(3.4)).scale(10),
        closeTo(20, 0.001),
        reason: 'Above 2.0 the clamp holds; 3.4x body text has no layout.',
      );
      expect(
        TiqTextScale.clamp(const TextScaler.linear(0.5)).scale(10),
        closeTo(10, 0.001),
        reason: 'Below 1.0 the scale\'s own optical sizing stops holding.',
      );
    });

    test('is 2.0, not 1.3 or 1.6', () {
      // Pinned, because the first draft of this direction locked figures at
      // 1.0 and clamped the app at 1.3 — a WCAG 1.4.4 failure dressed as a
      // layout policy. If someone lowers this, they have to lower it here.
      expect(TiqTextScale.maxScale, 2.0);
      expect(TiqTextScale.minScale, 1.0);
    });
  });

  group('the one documented exception', () {
    test('hero.figure caps at 1.6 and nothing else caps at all', () {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
        TiqSkin.veld(),
      ]) {
        final capped = skin.text.all
            .where((t) => t.maxTextScale != null)
            .toList();
        expect(
          capped.map((t) => t.name).toList(),
          <String>['hero.figure'],
          reason:
              '${skin.mode.name}: exactly one role may cap below the app '
              'clamp, and it is documented on the token rather than hidden in '
              'a wrapper. Adding a second is a policy change.',
        );
        expect(capped.single.maxTextScale, 1.6);
      }
    });

    test('hero.figure stops growing at 1.6 while body keeps going', () {
      final skin = TiqSkin.night();
      final hero = skin.text.heroFigure;
      final body = skin.text.body;

      final heroAt2 = TiqTextScale.sizeOf(const TextScaler.linear(2.0), hero);
      final heroAt16 = TiqTextScale.sizeOf(const TextScaler.linear(1.6), hero);
      expect(heroAt2, closeTo(heroAt16, 0.001));
      expect(heroAt2, closeTo(72 * 1.6, 0.001));

      final bodyAt2 = TiqTextScale.sizeOf(const TextScaler.linear(2.0), body);
      expect(bodyAt2, closeTo(body.size * 2.0, 0.001));
      expect(
        bodyAt2,
        greaterThan(TiqTextScale.sizeOf(const TextScaler.linear(1.3), body)),
      );
    });

    test('at 1.3 nothing is capped — the exception only bites above 1.6', () {
      final hero = TiqSkin.night().text.heroFigure;
      expect(
        TiqTextScale.sizeOf(const TextScaler.linear(1.3), hero),
        closeTo(72 * 1.3, 0.001),
      );
    });
  });

  group('the scope applies the policy to a real tree', () {
    for (final scale in scales) {
      testWidgets('TiqTextScaleScope clamps at ${scale}x', (tester) async {
        late TextScaler inner;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: TiqTextScaleScope(
              child: Builder(
                builder: (context) {
                  inner = MediaQuery.textScalerOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        expect(inner.scale(10), closeTo(10 * scale.clamp(1.0, 2.0), 0.001));
      });
    }

    testWidgets('3.0x from the OS arrives as 2.0x', (tester) async {
      late TextScaler inner;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: TiqTextScaleScope(
            child: Builder(
              builder: (context) {
                inner = MediaQuery.textScalerOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(inner.scale(10), closeTo(20, 0.001));
    });

    testWidgets('TiqRoleTextScale caps the hero inside a 2.0x app', (
      tester,
    ) async {
      late double painted;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: TiqTextScaleScope(
            child: TiqRoleTextScale(
              token: TiqSkin.night().text.heroFigure,
              child: Builder(
                builder: (context) {
                  painted = MediaQuery.textScalerOf(context).scale(72);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(painted, closeTo(72 * 1.6, 0.001));
    });
  });

  group('the layouts absorb it', () {
    for (final scale in scales) {
      for (final MapEntry(key: name, value: build)
          in <String, ThemeData Function()>{
            'night': AppTheme.night,
            'day': AppTheme.day,
            'veld': AppTheme.veld,
          }.entries) {
        testWidgets('$name survives ${scale}x on a 360dp phone', (
          tester,
        ) async {
          tester.view
            ..physicalSize = const Size(360 * 3, 800 * 3)
            ..devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          final skin = build().extension<TiqSkin>()!;
          await tester.pumpWidget(
            MaterialApp(
              theme: build(),
              builder: (context, child) =>
                  TiqTextScaleScope(child: child ?? const SizedBox()),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(skin.space.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // The hero cluster is a Wrap, so the delta drops to
                        // its own line instead of overflowing beside a 72px
                        // number.
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: TiqSpace.s3,
                          children: <Widget>[
                            TiqRoleTextScale(
                              token: skin.text.heroFigure,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '72',
                                  maxLines: 1,
                                  style: skin.text.heroFigure.style(
                                    color: skin.palette.ink1,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '−19',
                              style: skin.text.figureM.style(
                                color: skin.palette.bad,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Three Gauteng North outlets lost on-shelf '
                          'availability faster than the territory did.',
                          style: skin.text.headlineAnswer.style(
                            color: skin.palette.ink1,
                          ),
                        ),
                        Text(
                          'OSA 34%, down 19 pts — 3 visits, no order',
                          style: skin.text.body.style(color: skin.palette.ink2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason:
                '$name overflowed at ${scale}x. The layout absorbs the scale '
                '— it does not lock it.',
          );
        });
      }
    }
  });
}
