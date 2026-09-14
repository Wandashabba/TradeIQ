import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/agent_motion.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _wrap(
  Widget child, {
  bool reduceMotion = false,
  ThemeData? theme,
}) => MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('reduce motion', () {
    testWidgets('is honoured — a person who turned motion off has told us something',
        (tester) async {
      late bool reduced;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              reduced = reduceMotion(context);
              return const SizedBox();
            },
          ),
          reduceMotion: true,
        ),
      );

      expect(reduced, isTrue);
    });

    testWidgets('a pulsing dot does not animate when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PulseDot(color: Colors.blue, active: true),
          reduceMotion: true,
        ),
      );

      // If it were still looping, this would never return — which is exactly the
      // failure mode a repeating animation causes in every test above it.
      await tester.pumpAndSettle();
      expect(find.byType(PulseDot), findsOneWidget);
    });

    testWidgets('an inactive pulse never starts a ticker at all', (tester) async {
      await tester.pumpWidget(
        _wrap(const PulseDot(color: Colors.blue, active: false)),
      );
      await tester.pumpAndSettle();

      // Regression guard: the controller used to be `late final`, so disposing a
      // widget whose build never touched it made *dispose* construct it — and
      // building a Ticker against a dead element throws.
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });

  group('TickMark', () {
    BoxDecoration disc(WidgetTester tester) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byType(TickMark),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;

    testWidgets('dark: the bright good disc under a dark-green tick', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const TickMark(done: true)));

      expect(disc(tester).color, AppColors.good);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check)).color,
        const Color(0xFF04210B),
      );
    });

    testWidgets('glass: the deep good disc under a white tick that stands off '
        'it', (tester) async {
      await tester.pumpWidget(
        _wrap(const TickMark(done: true), theme: AppTheme.light()),
      );

      final fill = disc(tester).color!;
      expect(fill, TiqColors.light.good);
      final tick = tester.widget<Icon>(find.byIcon(Icons.check)).color!;
      expect(tick, Colors.white);
      expect(contrastRatio(tick, fill), greaterThanOrEqualTo(4.5));
    });

    testWidgets('glass: an undone mark is a hollow ink4 ring', (tester) async {
      await tester.pumpWidget(
        _wrap(const TickMark(done: false), theme: AppTheme.light()),
      );

      final deco = disc(tester);
      expect(deco.color, Colors.transparent);
      expect((deco.border! as Border).top.color, TiqColors.light.ink4);
    });
  });

  group('AnimatedCount', () {
    testWidgets('shows the value', (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCount(value: 18, style: TextStyle())),
      );
      await tester.pumpAndSettle();

      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('a null count reads as "—", never as zero', (tester) async {
      await tester.pumpWidget(
        _wrap(const AnimatedCount(value: null, style: TextStyle())),
      );

      // "Not counted" and "none on the shelf" are different facts, and only one
      // of them raises a task.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('CountStepper', () {
    testWidgets('settles after a change — no animation is left running', (
      tester,
    ) async {
      var value = 3;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => CountStepper(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(value, 4);
      expect(find.text('4'), findsOneWidget);
    });
  });
}
