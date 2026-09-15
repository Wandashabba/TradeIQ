import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

/// Pumps [child] under BOTH real themes registered — [mode] selects which one
/// renders, so `context.colors` resolves to the matching [TiqColors]. Bounded
/// width so the label/control Row lays out; the transparent controls sit on the
/// scaffold's [TiqColors.plane] ground.
Widget _app(Widget child, ThemeMode mode) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: mode,
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

final _themes = <String, ({ThemeMode mode, TiqColors colors})>{
  'light': (mode: ThemeMode.light, colors: TiqColors.light),
  'dark': (mode: ThemeMode.dark, colors: TiqColors.night),
};

/// The single [AnimatedContainer] each primitive paints its state onto (the
/// toggle track / the check box) — read its target decoration directly.
BoxDecoration _stateDeco(WidgetTester tester, Type primitive) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: find.byType(primitive),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  for (final MapEntry(key: name, value: (:mode, :colors)) in _themes.entries) {
    group('AgentToggle · $name', () {
      testWidgets('ON track is brand', (tester) async {
        await tester.pumpWidget(
          _app(
            AgentToggle(label: 'High traffic', value: true, onChanged: (_) {}),
            mode,
          ),
        );
        expect(_stateDeco(tester, AgentToggle).color, colors.brand);
      });

      testWidgets(
        'OFF track is surface3 (glass: the Lumen track) with a lineStrong border',
        (tester) async {
          await tester.pumpWidget(
            _app(
              AgentToggle(
                label: 'High traffic',
                value: false,
                onChanged: (_) {},
              ),
              mode,
            ),
          );
          final deco = _stateDeco(tester, AgentToggle);
          expect(
            deco.color,
            colors.glass
                ? (colors.isNight ? LumenPalette.dark : LumenPalette.light).track
                : colors.surface3,
          );
          expect((deco.border! as Border).top.color, colors.lineStrong);
          // ON and OFF must be visibly different states, not colour twins.
          expect(deco.color, isNot(colors.brand));
        },
      );

      testWidgets('label is ink1 and clears 4.5:1 on its ground', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            AgentToggle(label: 'High traffic', value: false, onChanged: (_) {}),
            mode,
          ),
        );
        final label = tester.widget<Text>(find.text('High traffic'));
        expect(label.style!.color, colors.ink1);
        expect(
          contrastRatio(label.style!.color!, colors.plane),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('tapping calls onChanged(!value)', (tester) async {
        bool? got;
        await tester.pumpWidget(
          _app(
            AgentToggle(
              label: 'High traffic',
              value: false,
              onChanged: (v) => got = v,
            ),
            mode,
          ),
        );
        await tester.tap(find.byType(AgentToggle));
        expect(got, isTrue);
      });

      testWidgets('carries Semantics(toggled: value)', (tester) async {
        await tester.pumpWidget(
          _app(
            AgentToggle(label: 'High traffic', value: true, onChanged: (_) {}),
            mode,
          ),
        );
        final sem = tester.widget<Semantics>(
          find.descendant(
            of: find.byType(AgentToggle),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.toggled != null,
            ),
          ),
        );
        expect(sem.properties.toggled, isTrue);
      });

      testWidgets('row is at least kTapTarget tall', (tester) async {
        await tester.pumpWidget(
          _app(
            AgentToggle(label: 'High traffic', value: false, onChanged: (_) {}),
            mode,
          ),
        );
        expect(
          tester.getSize(find.byType(AgentToggle)).height,
          greaterThanOrEqualTo(kTapTarget),
        );
      });
    });

    group('AgentCheck · $name', () {
      testWidgets('checked box fills brand', (tester) async {
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: true,
              onChanged: (_) {},
            ),
            mode,
          ),
        );
        expect(_stateDeco(tester, AgentCheck).color, colors.brand);
      });

      testWidgets(
        'unchecked box is surface2 (glass: a pill fill) with a lineStrong border',
        (tester) async {
          await tester.pumpWidget(
            _app(
              AgentCheck(
                label: 'Branding present',
                value: false,
                onChanged: (_) {},
              ),
              mode,
            ),
          );
          final deco = _stateDeco(tester, AgentCheck);
          expect(
            deco.color,
            colors.glass
                ? (colors.isNight ? LumenPalette.dark : LumenPalette.light)
                      .pillFill
                : colors.surface2,
          );
          expect((deco.border! as Border).top.color, colors.lineStrong);
        },
      );

      testWidgets('checked state carries a tick that clears 4.5:1 on brand', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: true,
              onChanged: (_) {},
            ),
            mode,
          ),
        );
        final tick = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(
          contrastRatio(tick.color!, colors.brand),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('unchecked state shows no tick (state is not colour-alone)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: false,
              onChanged: (_) {},
            ),
            mode,
          ),
        );
        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('label is ink1 and clears 4.5:1 on its ground', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: false,
              onChanged: (_) {},
            ),
            mode,
          ),
        );
        final label = tester.widget<Text>(find.text('Branding present'));
        expect(label.style!.color, colors.ink1);
        expect(
          contrastRatio(label.style!.color!, colors.plane),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('tapping calls onChanged(!value)', (tester) async {
        bool? got;
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: true,
              onChanged: (v) => got = v,
            ),
            mode,
          ),
        );
        await tester.tap(find.byType(AgentCheck));
        expect(got, isFalse);
      });

      testWidgets('carries Semantics(checked: value)', (tester) async {
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: true,
              onChanged: (_) {},
            ),
            mode,
          ),
        );
        final sem = tester.widget<Semantics>(
          find.descendant(
            of: find.byType(AgentCheck),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.checked != null,
            ),
          ),
        );
        expect(sem.properties.checked, isTrue);
      });

      testWidgets('row is at least kTapTarget tall', (tester) async {
        await tester.pumpWidget(
          _app(
            AgentCheck(
              label: 'Branding present',
              value: false,
              onChanged: (_) {},
            ),
            mode,
          ),
        );
        expect(
          tester.getSize(find.byType(AgentCheck)).height,
          greaterThanOrEqualTo(kTapTarget),
        );
      });
    });
  }

  // A11y merge: label + state + tap must collapse onto ONE node (theme-agnostic,
  // so asserted once). Mutation check: dropping the MergeSemantics/
  // ExcludeSemantics splits state onto a different node from the tap action and
  // announces the label twice — both assertions below then fail.
  group('merged semantics', () {
    testWidgets('AgentToggle is one node: label + toggled + tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          AgentToggle(label: 'High traffic', value: true, onChanged: (_) {}),
          ThemeMode.light,
        ),
      );
      expect(
        tester.getSemantics(find.byType(AgentToggle)),
        isSemantics(
          label: 'High traffic',
          isToggled: true,
          hasToggledState: true,
          hasTapAction: true,
        ),
      );
      // The label lives on exactly one node — the excluded Text does not re-emit.
      expect(find.bySemanticsLabel('High traffic'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('AgentCheck is one node: label + checked + tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          AgentCheck(label: 'Branding present', value: true, onChanged: (_) {}),
          ThemeMode.light,
        ),
      );
      expect(
        tester.getSemantics(find.byType(AgentCheck)),
        isSemantics(
          label: 'Branding present',
          isChecked: true,
          hasCheckedState: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Branding present'), findsOneWidget);
      handle.dispose();
    });
  });
}
