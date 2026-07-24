import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/delta_pill.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('StatusChip', () {
    testWidgets('renders a word, not just a mark', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusChip(label: 'Critical', level: StatusLevel.critical)),
      );

      expect(find.text('CRITICAL'), findsOneWidget);
    });

    testWidgets('each level takes its reserved status hue', (tester) async {
      expect(StatusLevel.critical.color, AppColors.crit);
      expect(StatusLevel.warning.color, AppColors.warn);
      expect(StatusLevel.good.color, AppColors.good);
      expect(StatusLevel.neutral.color, AppColors.ink3);
    });
  });

  group('StatTile', () {
    testWidgets('shows label, value, delta pill and note', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(
              label: 'On-shelf availability',
              value: '92.1%',
              delta: 0.8,
              note: 'of 6,420 SKU checks',
            ),
          ),
        ),
      );

      expect(find.text('On-shelf availability'), findsOneWidget);
      expect(find.text('92.1%'), findsOneWidget);
      expect(find.text('▲ 0.8'), findsOneWidget);
      expect(find.text('of 6,420 SKU checks'), findsOneWidget);
      // A rise wears the green wash; the pill IS the tile's delta rendering.
      expect(
        tester.widget<DeltaPill>(find.byType(DeltaPill)).tone,
        DeltaTone.good,
      );
    });

    testWidgets('a falling delta wears the red wash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(
              label: 'Perfect-store rate',
              value: '55.6%',
              delta: -4.4,
            ),
          ),
        ),
      );

      expect(find.text('▼ 4.4'), findsOneWidget);
      expect(
        tester.widget<DeltaPill>(find.byType(DeltaPill)).tone,
        DeltaTone.bad,
      );
    });

    testWidgets('omits the pill when there is no delta to show', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(label: 'Share of shelf', value: '34.8%'),
          ),
        ),
      );

      expect(find.byType(DeltaPill), findsNothing);
    });

    testWidgets('never renders an icon — the user removed them twice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(
              label: 'On-shelf availability',
              value: '92.1%',
              delta: 0.8,
              note: 'of 6,420 SKU checks',
            ),
          ),
        ),
      );

      expect(
        find.descendant(of: find.byType(StatTile), matching: find.byType(Icon)),
        findsNothing,
      );
    });

    testWidgets('the delta pill is static unless the entrance is opted in', (
      tester,
    ) async {
      // The pill is shared chrome — screens that never asked for entrance
      // motion must get none, and nothing may be left running unsettled.
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(
              label: 'On-shelf availability',
              value: '92.1%',
              delta: 0.8,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DeltaPill), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatTile),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animateDelta: the pill enters once, then goes quiet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(
              label: 'On-shelf availability',
              value: '92.1%',
              delta: 0.8,
              animateDelta: true,
            ),
          ),
        ),
      );

      final gate = find.descendant(
        of: find.byType(StatTile),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(gate).opacity, 0);

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(gate).opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animateDelta under reduced motion renders statically', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(
              label: 'On-shelf availability',
              value: '92.1%',
              delta: 0.8,
              animateDelta: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DeltaPill), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatTile),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AttentionRow', () {
    testWidgets('a tap runs the callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            child: AttentionRow(
              count: 3,
              title: 'Critical alerts open',
              meta: '2 stockouts',
              level: StatusLevel.critical,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Critical alerts open'));
      expect(tapped, isTrue);
    });

    testWidgets('the count takes the level hue', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            child: AttentionRow(
              count: 4,
              title: 'Tasks still open',
              meta: 'none critical',
              level: StatusLevel.warning,
            ),
          ),
        ),
      );

      final count = tester.widget<Text>(find.text('4'));
      expect(count.style?.color, AppColors.warn);
    });
  });

  group('PanelCard', () {
    testWidgets('renders its title, subtitle and child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            child: PanelCard(
              title: 'Execution score',
              subtitle: 'Weighted S2–S8',
              child: Text('body'),
            ),
          ),
        ),
      );

      expect(find.text('Execution score'), findsOneWidget);
      expect(find.text('Weighted S2–S8'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('rests on a fixed, barely-there Stripe-soft shadow', (
      tester,
    ) async {
      // Hover-lift shadow removed by the 2026-07-24 premium-ui redesign —
      // PanelCard's elevation is now a single static value (Task 1).
      await tester.pumpWidget(
        _wrap(
          const SizedBox(width: 320, child: PanelCard(child: Text('body'))),
        ),
      );

      BoxDecoration decorationOf() {
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text('body'),
            matching: find.byType(Container),
          ),
        );
        return container.decoration! as BoxDecoration;
      }

      final rest = decorationOf().boxShadow!.single;
      expect(rest.offset, const Offset(0, 1));
      expect(rest.blurRadius, 2);
      expect(rest.color, const Color(0x0D14161C));

      // Moving the mouse over the card no longer changes the shadow.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(PanelCard)));
      await tester.pumpAndSettle();

      final stillRest = decorationOf().boxShadow!.single;
      expect(stillRest.offset, const Offset(0, 1));
      expect(stillRest.blurRadius, 2);
      expect(stillRest.color, const Color(0x0D14161C));
    });
  });
}
