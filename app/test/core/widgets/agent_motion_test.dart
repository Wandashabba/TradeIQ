import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/agent_motion.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
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
