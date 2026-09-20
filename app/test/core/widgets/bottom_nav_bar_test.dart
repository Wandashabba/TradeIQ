import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_palette.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/bottom_nav_bar.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

/// The bar is injected by ManagerScaffold below 1080 — here we pump it
/// directly to test its own contract. The ProviderScope exists for the menu
/// sheet, whose theme-toggle and sign-out rows are riverpod Consumers.
Widget _app({
  String activeRoute = '/dashboard',
  ThemeData? theme,
  Locale? locale,
  double textScale = 1,
}) => ProviderScope(
  child: MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Stack(
            children: [
              // The geometry ManagerScaffold gives it: 12 of gutter each side,
              // floating 12 above the bottom. A slot is therefore
              // (width - 24 - 10) / 5 wide, which is what makes the Afrikaans
              // measurement below a measurement of the real thing.
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: TiqBottomNavBar(activeRoute: activeRoute),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// THE THEMES `main.dart` ACTUALLY SHIPS.
///
/// The four contrast tests this file used to carry pumped `AppTheme.dark()`
/// and `AppTheme.light()` — the Lumen themes, which nothing routes to. That
/// is why nobody saw that on Day the active slot was `flame600` at **1.30:1**
/// on the bar and the "active pill" was the bar's own colour. Every
/// appearance test below runs against `day()`, `night()` and `veld()`, and
/// Veld is built here rather than declared.
final _shipped = <({String name, ThemeData theme, TiqPalette palette})>[
  (name: 'night', theme: AppTheme.night(), palette: TiqPalette.night),
  (name: 'day', theme: AppTheme.day(), palette: TiqPalette.day),
  (name: 'veld', theme: AppTheme.veld(), palette: TiqPalette.veld),
];

void main() {
  // The open-sheet count is an app-wide static, and the menu tests here end
  // with the menu up. Without this the NEXT test's `showTorchSheet` asserts
  // that a second sheet was opened over an existing one.
  setUp(TorchSheets.resetForTest);
  tearDown(TorchSheets.resetForTest);

  testWidgets('shows the five slots with the active tab marked', (
    tester,
  ) async {
    await tester.pumpWidget(_app(activeRoute: '/dashboard'));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      findsOneWidget,
    );
  });

  /// The five slots were five hardcoded English strings — 'Home', 'Tasks',
  /// 'Alerts', 'Map', 'Menu' — read straight off a `const` record and printed.
  /// The menu sheet this same bar opens has been translated since #437, so an
  /// Afrikaans manager got a translated sheet hanging off an English bar.
  testWidgets('the slots are translated, not five English constants', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: const Locale('af')));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();

    for (final af in <String>[
      'Tuis',
      'Take',
      'Waarskuwings',
      'Kaart',
      'Kieslys',
    ]) {
      expect(
        find.bySemanticsLabel(af),
        findsOneWidget,
        reason: '"$af" must reach the bar, painted or announced',
      );
    }

    for (final english in <String>['Home', 'Tasks', 'Alerts', 'Map', 'Menu']) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" is untranslated English on an Afrikaans bar',
      );
    }
    handle.dispose();
  });

  testWidgets('the mark sits on the slot matching the active route', (
    tester,
  ) async {
    await tester.pumpWidget(_app(activeRoute: '/agents/activity'));

    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/agents/activity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
      findsNothing,
    );
  });

  testWidgets('menu slot opens the one Torchlight menu, sign-out included', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    // Sentence case: the section rule replaced the uppercase eyebrow, and
    // "OPERATE" read out letter by letter is not a word.
    expect(find.text('Operate'), findsOneWidget);
    expect(find.text('Insight'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-sign-out')), findsOneWidget);
  });

  testWidgets('the bar opens the SAME sheet the console frame does', (
    tester,
  ) async {
    await tester.pumpWidget(_app(theme: AppTheme.night()));

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    expect(find.byType(TorchSheet), findsOneWidget);
    expect(find.byType(GlassPane), findsNothing);
    expect(find.byKey(const ValueKey('menu-/dashboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-sign-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-theme')), findsOneWidget);
  });

  // ── The active slot, in the skins the app ships ─────────────────────────
  // All read off the RENDERED tree, not the token table — so a widget that
  // stops consuming the tokens fails these even if the table stays right.

  for (final skin in _shipped) {
    group('${skin.name}:', () {
      /// The bar's own fill: the DecoratedBox the Container builds.
      BoxDecoration barDecoration(WidgetTester tester) {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(TiqBottomNavBar),
                matching: find.byType(Container),
              )
              .first,
        );
        return box.decoration! as BoxDecoration;
      }

      /// THE FAILURE, WRITTEN AS ITSELF.
      ///
      /// On Day this read 1.30:1 — `flame600` on Palladian well — and the
      /// "active pill" was `navActivePillBg`, which `TiqColors.fromSkin` maps
      /// to `p.well`, the bar's own colour. A manager who tapped "Light theme"
      /// in the menu could not tell which tab she was on.
      testWidgets('the active slot clears AA on the bar it sits on', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(activeRoute: '/dashboard', theme: skin.theme),
        );

        final bar = barDecoration(tester).color!;
        expect(
          bar.a,
          1.0,
          reason: 'the bar is opaque — nothing composites through it',
        );

        final active = tester.widget<Text>(find.text('Home')).style!.color!;
        expect(
          contrastRatio(active, bar),
          greaterThanOrEqualTo(4.5),
          reason: 'the active label is 10.5px text on the bar',
        );

        final inactive = tester.widget<Text>(find.text('Tasks')).style!.color!;
        expect(
          contrastRatio(inactive, bar),
          greaterThanOrEqualTo(4.5),
          reason: 'inactive labels are 10.5px text on the bar',
        );

        // The two are not the same ink, or "active" is carried by nothing.
        expect(active, isNot(inactive));

        // Icons carry the same ink as their labels — never colour drift.
        expect(
          tester.widget<Icon>(find.byIcon(Icons.home)).color,
          active,
          reason: 'the active slot wears the FILLED silhouette',
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.task_alt)).color,
          inactive,
        );
      });

      /// Colour is never the only signal. Strip the hue and the active slot
      /// is still the only one with an underbar, a filled glyph and a 600.
      testWidgets('active is carried by shape and weight, not only ink', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(activeRoute: '/dashboard', theme: skin.theme),
        );

        final underbar = tester.widget<Container>(
          find.byKey(const ValueKey('bottom-nav-pill-/dashboard')),
        );
        expect(
          (underbar.decoration! as BoxDecoration).color,
          skin.palette.ink1,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('bottom-nav-pill-/dashboard')))
              .height,
          greaterThan(0),
        );

        // Filled on the active slot, outlined on every other one.
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.byIcon(Icons.home_outlined), findsNothing);
        expect(find.byIcon(Icons.task_alt), findsOneWidget);

        expect(
          tester.widget<Text>(find.text('Home')).style!.fontWeight,
          FontWeight.w600,
        );
        expect(
          tester.widget<Text>(find.text('Tasks')).style!.fontWeight,
          FontWeight.w500,
        );
      });

      /// THE LAW: amber is claimed through `TorchScope`, never painted. The
      /// bar has no scope above it — ManagerScaffold is still the Lumen shell
      /// — so it must emit no amber at all. It used to emit `flame600` on
      /// seven live manager routes that no census could see.
      testWidgets('no amber anywhere on the bar', (tester) async {
        await tester.pumpWidget(
          _app(activeRoute: '/dashboard', theme: skin.theme),
        );

        final p = skin.palette;
        final ambers = <Color>{
          p.flame300,
          p.flame500,
          p.flame600,
          p.flame700,
          p.flame900,
        };

        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(TiqBottomNavBar),
            matching: find.byType(Text),
          ),
        )) {
          expect(
            ambers,
            isNot(contains(text.style?.color)),
            reason: '"${text.data}" paints an unclaimed amber',
          );
        }
        for (final icon in tester.widgetList<Icon>(
          find.descendant(
            of: find.byType(TiqBottomNavBar),
            matching: find.byType(Icon),
          ),
        )) {
          expect(ambers, isNot(contains(icon.color)));
        }
        for (final container in tester.widgetList<Container>(
          find.descendant(
            of: find.byType(TiqBottomNavBar),
            matching: find.byType(Container),
          ),
        )) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            expect(ambers, isNot(contains(decoration.color)));
          }
        }
      });

      /// The paint budget. This is the widget that is never off screen; a
      /// sigma-14 `BackdropFilter` on it is a full-screen `saveLayer` on every
      /// frame of every scroll of every unmigrated manager route.
      testWidgets('no blur, no shadow, no gradient', (tester) async {
        await tester.pumpWidget(
          _app(activeRoute: '/dashboard', theme: skin.theme),
        );

        expect(
          find.descendant(
            of: find.byType(TiqBottomNavBar),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        for (final container in tester.widgetList<Container>(
          find.descendant(
            of: find.byType(TiqBottomNavBar),
            matching: find.byType(Container),
          ),
        )) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            expect(decoration.boxShadow, anyOf(isNull, isEmpty));
            expect(decoration.gradient, isNull);
          }
        }
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(TiqBottomNavBar),
            matching: find.byType(DecoratedBox),
          ),
        )) {
          final decoration = box.decoration;
          if (decoration is BoxDecoration) {
            expect(decoration.boxShadow, anyOf(isNull, isEmpty));
            expect(decoration.gradient, isNull);
          }
        }
      });

      /// Every interactive element must be operable by a screen reader, and
      /// the name must survive the bar going icon-only.
      testWidgets('every slot is named, flagged and activatable', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(activeRoute: '/dashboard', theme: skin.theme),
        );
        final handle = tester.ensureSemantics();

        for (final name in <String>['Home', 'Tasks', 'Alerts', 'Map', 'Menu']) {
          expect(
            tester.getSemantics(find.bySemanticsLabel(name)),
            isSemantics(
              isButton: true,
              isSelected: name == 'Home',
              hasTapAction: true,
            ),
            reason:
                '"$name" must be named, flagged, correctly selected AND '
                'activatable — a button that announces itself and does '
                'nothing is the #436 bug',
          );
        }
        handle.dispose();
      });
    });
  }

  // ── Afrikaans, measured rather than asserted ────────────────────────────

  /// THE FAILURE, WRITTEN AS ITSELF.
  ///
  /// `expect(find.text('Waarskuwings'), findsOneWidget)` matches the `Text`
  /// widget's `data` and passes while the phone renders "Waarsk…". On a 360dp
  /// phone at 1.0× the string needs 126px in a 64px slot; at 1.3× four of the
  /// five clip; at 2.0× all five do.
  ///
  /// So measure: lay the string out with a `TextPainter` in the style the slot
  /// renders, and compare against the slot the bar actually gave it. A label
  /// that cannot fit must not be painted at all — the bar drops to glyphs and
  /// keeps the name on the semantics node.
  for (final locale in <String>['en', 'af']) {
    for (final scale in <double>[1.0, 1.3, 2.0]) {
      for (final width in <double>[320, 360, 412]) {
        testWidgets(
          '$locale @${width.toInt()}dp ×$scale: no label is ever clipped',
          (tester) async {
            tester.view.physicalSize = Size(width, 780);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _app(
                theme: AppTheme.day(),
                locale: Locale(locale),
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            final labels = tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byType(TiqBottomNavBar),
                    matching: find.byType(Text),
                  ),
                )
                .toList();

            // All five or none — a bar with two words and three glyphs reads
            // as a rendering fault, not as a layout decision.
            expect(
              labels.length,
              anyOf(0, 5),
              reason: 'the bar drops every label together or keeps them all',
            );

            for (final label in labels) {
              final finder = find.text(label.data!);
              final painter = TextPainter(
                text: TextSpan(text: label.data, style: label.style),
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.linear(scale),
                maxLines: 1,
              )..layout();
              final needed = painter.width;
              painter.dispose();
              expect(
                tester.getSize(finder).width + 0.5,
                greaterThanOrEqualTo(needed),
                reason:
                    '"${label.data}" needs ${needed.toStringAsFixed(1)}px and '
                    'was given ${tester.getSize(finder).width.toStringAsFixed(1)}px '
                    '— it renders ellipsised on a $locale phone',
              );
            }
          },
        );
      }
    }
  }

  /// Dropping the label is only legal because the name goes somewhere a
  /// reader can still reach it.
  testWidgets('icon-only at 2.0× still names every slot to a reader', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(theme: AppTheme.day(), locale: const Locale('af'), textScale: 2),
    );
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();

    expect(
      find.descendant(
        of: find.byType(TiqBottomNavBar),
        matching: find.byType(Text),
      ),
      findsNothing,
      reason: 'at 2.0× Afrikaans no label fits, so none is painted',
    );
    for (final af in <String>[
      'Tuis',
      'Take',
      'Waarskuwings',
      'Kaart',
      'Kieslys',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(af)),
        isSemantics(isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });

  /// The bar must still work when the labels are gone: the Menu slot is the
  /// only way to sign out on a phone.
  testWidgets('icon-only, the Menu slot still opens the menu', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(theme: AppTheme.day(), textScale: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-sign-out')), findsOneWidget);
  });
}
