import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// One boolean, three inputs, and the one that is not wired yet.
void main() {
  group('the arithmetic', () {
    test('still is the OR of the three inputs', () {
      expect(MotionBudget.moving.still, isFalse);
      expect(
        const MotionBudget(
          disableAnimations: true,
          veld: false,
          powerSave: false,
        ).still,
        isTrue,
      );
      expect(
        const MotionBudget(
          disableAnimations: false,
          veld: true,
          powerSave: false,
        ).still,
        isTrue,
      );
      expect(
        const MotionBudget(
          disableAnimations: false,
          veld: false,
          powerSave: true,
        ).still,
        isTrue,
      );
    });

    test('the reason names every input that is stopping the frame', () {
      expect(MotionBudget.moving.reason, 'motion on');
      expect(
        const MotionBudget(
          disableAnimations: true,
          veld: true,
          powerSave: true,
        ).reason,
        'reduce-motion + Veld + battery saver',
      );
    });
  });

  group('resolution from the ambient context', () {
    Future<MotionBudget> resolve(
      WidgetTester tester, {
      required TiqSkin skin,
      bool disableAnimations = false,
    }) async {
      late MotionBudget budget;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MaterialApp(
            theme: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
            home: Builder(
              builder: (context) {
                budget = MotionBudget.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return budget;
    }

    testWidgets('Night with animations on moves', (tester) async {
      final budget = await resolve(tester, skin: TiqSkin.night());
      expect(budget.still, isFalse);
    });

    testWidgets('reduce-motion stops it in any skin', (tester) async {
      for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
        final budget = await resolve(
          tester,
          skin: skin,
          disableAnimations: true,
        );
        expect(budget.still, isTrue);
        expect(budget.disableAnimations, isTrue);
      }
    });

    testWidgets('Veld is still without anyone asking', (tester) async {
      final budget = await resolve(tester, skin: TiqSkin.veld());
      expect(budget.veld, isTrue);
      expect(
        budget.still,
        isTrue,
        reason:
            'Outdoors, motion is glare that moves. Veld kills every ambient '
            'loop and it does not need a platform switch to do it.',
      );
    });

    testWidgets('a scope pins the budget for a golden', (tester) async {
      late MotionBudget budget;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[TiqSkin.night()],
          ),
          home: MotionBudgetScope(
            budget: MotionBudget.frozen,
            child: Builder(
              builder: (context) {
                budget = MotionBudget.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(budget, MotionBudget.frozen);
      expect(budget.still, isTrue);
    });
  });

  group('the power-save gap', () {
    testWidgets('powerSave is false because there is no channel yet', (
      tester,
    ) async {
      // #407. This is asserted rather than left implicit so that the day the
      // channel lands, this test is the thing that fails and says "now wire
      // it" — instead of the promise sitting unfulfilled in a design document
      // for another year.
      late MotionBudget budget;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[TiqSkin.night()],
          ),
          home: Builder(
            builder: (context) {
              budget = MotionBudget.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        budget.powerSave,
        isFalse,
        reason:
            'There is no power-save channel on either platform yet (#407). '
            'The input is wired as false, in the open, so the sentence '
            '"motion stops in battery saver" is a promise with a ticket '
            'number rather than a lie.',
      );
    });

    test('the TODO names the ticket', () {
      // A TODO without a number is a wish. `flutter test` runs with the
      // package root as cwd.
      final source = File(
        'lib/core/design/motion_budget.dart',
      ).readAsStringSync();
      expect(source, contains('TODO(#407)'));
      expect(source, contains('powerSave: false'));
    });
  });
}
