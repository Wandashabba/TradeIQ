import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/worklist.dart';

/// Pumps [child] under a real app theme — dark (Lumen Glass at night) unless
/// [theme] is given. Both real themes render the row as a glass tile.
Widget _themed(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark(),
  home: Scaffold(body: ListView(children: [child])),
);

/// No theme at all: `context.colors` falls back to the flat [TiqColors.dark]
/// palette, the only place the flat card recipe still renders.
Widget _themeless(Widget child) => MaterialApp(
  home: Scaffold(body: ListView(children: [child])),
);

/// The flat card ground: the DecoratedBox carrying the panel-radius
/// BoxDecoration.
Finder _cardBox() => find.descendant(
  of: find.byType(WorklistCardShell),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius ==
            BorderRadius.circular(AppColors.radiusPanel),
  ),
);

BoxDecoration _cardDecoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_cardBox().first).decoration as BoxDecoration;

void main() {
  group('WorklistCardShell', () {
    testWidgets('flat fallback (no theme): surface1 ground, line hairline, '
        'panel radius, no shadow', (tester) async {
      await tester.pumpWidget(
        _themeless(
          const WorklistCardShell(
            edgeColor: Color(0xFF112233),
            child: SizedBox(height: 40, child: Text('body')),
          ),
        ),
      );

      final deco = _cardDecoration(tester);
      expect(deco.color, TiqColors.dark.surface1);
      expect(deco.border, Border.all(color: TiqColors.dark.line));
      expect(deco.borderRadius, BorderRadius.circular(AppColors.radiusPanel));
      // The row card is the flat-in-panel variant: no shadow of its own.
      expect(deco.boxShadow, isNull);
      // The child is rendered.
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('flat fallback (no theme): the concentric radiusPanel-1 clip '
        'is present, inside the card decoration', (tester) async {
      await tester.pumpWidget(
        _themeless(
          const WorklistCardShell(
            edgeColor: Color(0xFF112233),
            child: SizedBox(height: 40),
          ),
        ),
      );

      final clip = find.descendant(
        of: find.byType(WorklistCardShell),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ClipRRect &&
              w.borderRadius ==
                  BorderRadius.circular(AppColors.radiusPanel - 1),
        ),
      );
      expect(clip, findsOneWidget);
      // The clip lives inside the card decoration.
      expect(find.ancestor(of: clip, matching: _cardBox()), findsOneWidget);
    });

    testWidgets('the left edge is a 3px Container in the edgeColor, under the '
        'clip', (tester) async {
      const edgeColor = Color(0xFF445566);
      await tester.pumpWidget(
        _themed(
          const WorklistCardShell(
            edgeColor: edgeColor,
            child: SizedBox(height: 40),
          ),
        ),
      );

      final edge = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.color == edgeColor &&
            w.constraints == const BoxConstraints.tightFor(width: 3),
      );
      expect(edge, findsOneWidget);

      // It sits under the rounded clip so the square bar can never poke out
      // of the card's rounded corners.
      expect(
        find.ancestor(
          of: edge,
          matching: find.byWidgetPredicate(
            (w) => w is ClipRRect && w.borderRadius != BorderRadius.zero,
          ),
        ),
        findsWidgets,
      );
    });

    testWidgets('edgeWidth overrides the 3px default', (tester) async {
      const edgeColor = Color(0xFF778899);
      await tester.pumpWidget(
        _themed(
          const WorklistCardShell(
            edgeColor: edgeColor,
            edgeWidth: 5,
            child: SizedBox(height: 40),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.color == edgeColor &&
              w.constraints == const BoxConstraints.tightFor(width: 5),
        ),
        findsOneWidget,
      );
    });

    testWidgets('margin defaults are honoured — an override sets the outer '
        'gap', (tester) async {
      await tester.pumpWidget(
        _themed(
          Column(
            children: const [
              WorklistCardShell(
                edgeColor: Color(0xFF112233),
                margin: EdgeInsets.only(bottom: 8),
                child: SizedBox(height: 40, child: Text('a')),
              ),
              WorklistCardShell(
                edgeColor: Color(0xFF112233),
                margin: EdgeInsets.zero,
                child: SizedBox(height: 40, child: Text('b')),
              ),
            ],
          ),
        ),
      );

      final first = tester.getRect(find.byType(GlassPane).at(0));
      final second = tester.getRect(find.byType(GlassPane).at(1));
      expect(second.top - first.bottom, 8);
    });

    testWidgets('light theme: the row is a glass tile — no blur, no shadow, '
        'card radius', (tester) async {
      await tester.pumpWidget(
        _themed(
          const WorklistCardShell(
            edgeColor: Color(0xFF112233),
            child: SizedBox(height: 40, child: Text('body')),
          ),
          theme: AppTheme.light(),
        ),
      );

      final pane = tester.widget<GlassPane>(find.byType(GlassPane));
      expect(pane.kind, GlassKind.tile);
      // A list item never pays for a BackdropFilter per row.
      expect(pane.blur, isFalse);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(pane.shadow, isFalse);
      expect(pane.radius, TiqColors.light.radiusCard);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('dark theme: night glass tile — no blur, no shadow, card '
        'radius, the night tile rim over the solid fill', (tester) async {
      await tester.pumpWidget(
        _themed(
          const WorklistCardShell(
            edgeColor: Color(0xFF112233),
            child: SizedBox(height: 40, child: Text('body')),
          ),
          theme: AppTheme.dark(),
        ),
      );

      final pane = tester.widget<GlassPane>(find.byType(GlassPane));
      expect(pane.kind, GlassKind.tile);
      expect(pane.blur, isFalse);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(pane.shadow, isFalse);
      expect(pane.radius, TiqColors.night.radiusCard);

      // The rendered ground: an unblurred tile takes the night solid fill
      // under the night tile rim.
      final ground = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GlassPane),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null && d.border != null);
      expect(ground.color, LumenPalette.dark.solidFill);
      expect(ground.border, Border.all(color: LumenPalette.dark.tileRim));
      expect(find.text('body'), findsOneWidget);
    });
  });
}
