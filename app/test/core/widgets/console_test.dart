import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/widgets/console.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('DeltaText', () {
    testWidgets('a rise carries an up arrow and the good hue', (tester) async {
      await tester.pumpWidget(_wrap(const DeltaText(2.1)));

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, '▲ 2.1');
      expect(text.style?.color, AppColors.good);
    });

    testWidgets('a fall carries a down arrow and the critical hue', (tester) async {
      await tester.pumpWidget(_wrap(const DeltaText(-1.2)));

      final text = tester.widget<Text>(find.byType(Text));
      // The magnitude is unsigned — the glyph carries the direction, so the
      // value never reads as "minus minus".
      expect(text.data, '▼ 1.2');
      expect(text.style?.color, AppColors.crit);
    });

    testWidgets('flat is neither coloured nor arrowed', (tester) async {
      await tester.pumpWidget(_wrap(const DeltaText(0)));

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, '– 0.0');
      expect(text.style?.color, AppColors.ink3);
    });

    testWidgets('direction survives greyscale — the glyph is not the colour', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DeltaText(3.4)));
      // Strip the colour and the sign is still readable.
      expect(find.textContaining('▲'), findsOneWidget);
    });
  });

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
    testWidgets('shows label, value, delta and note', (tester) async {
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
    });

    testWidgets('omits the delta when there is none to show', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 220,
            child: StatTile(label: 'Share of shelf', value: '34.8%'),
          ),
        ),
      );

      expect(find.byType(DeltaText), findsNothing);
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
  });
}
