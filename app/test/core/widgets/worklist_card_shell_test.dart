import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/worklist.dart';

/// Pumps [child] under a real app theme (light unless [theme] is given).
Widget _themed(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: ListView(children: [child])),
);

/// The card ground: the DecoratedBox carrying the panel-radius BoxDecoration.
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
    testWidgets('wears the card recipe: surface1 ground, line hairline, '
        'panel radius, no shadow', (tester) async {
      await tester.pumpWidget(
        _themed(
          const WorklistCardShell(
            edgeColor: Color(0xFF112233),
            child: SizedBox(height: 40, child: Text('body')),
          ),
        ),
      );

      final deco = _cardDecoration(tester);
      expect(deco.color, TiqColors.light.surface1);
      expect(deco.border, Border.all(color: TiqColors.light.line));
      expect(deco.borderRadius, BorderRadius.circular(AppColors.radiusPanel));
      // The row card is the flat-in-panel variant: no shadow of its own.
      expect(deco.boxShadow, isNull);
      // The child is rendered.
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('the concentric radiusPanel-1 clip is present, inside the '
        'card decoration', (tester) async {
      await tester.pumpWidget(
        _themed(
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

      final first = tester.getRect(_cardBox().at(0));
      final second = tester.getRect(_cardBox().at(1));
      expect(second.top - first.bottom, 8);
    });

    testWidgets('dark theme: the card wears dark tokens', (tester) async {
      await tester.pumpWidget(
        _themed(
          const WorklistCardShell(
            edgeColor: Color(0xFF112233),
            child: SizedBox(height: 40),
          ),
          theme: AppTheme.dark(),
        ),
      );

      final deco = _cardDecoration(tester);
      expect(deco.color, TiqColors.dark.surface1);
      expect(deco.border, Border.all(color: TiqColors.dark.line));
      expect(deco.borderRadius, BorderRadius.circular(AppColors.radiusPanel));
    });
  });
}
