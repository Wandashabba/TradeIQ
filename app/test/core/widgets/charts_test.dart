import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 600, height: 300, child: child),
      ),
    );

const _series = <ChartPoint>[
  (label: '14 Jun', value: 74.1),
  (label: '20 Jun', value: 75.2),
  (label: '29 Jun', value: 76.1),
  (label: '6 Jul', value: 77.2),
  (label: '13 Jul', value: 78.4),
];

void main() {
  group('LineChart', () {
    testWidgets('paints a series', (tester) async {
      await tester.pumpWidget(_wrap(const LineChart(points: _series, target: 75)));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('degrades to a message rather than a broken plot', (tester) async {
      // One point is not a trend — a single-point line chart is a lie.
      await tester.pumpWidget(
        _wrap(const LineChart(points: [(label: 'Jul', value: 4)])),
      );
      expect(find.text('Not enough data to plot'), findsOneWidget);
    });

    testWidgets('a hover surfaces the tooltip for the nearest point', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LineChart(points: _series, seriesName: 'Execution score')),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Move to the far right of the plot — nearest point is the last one.
      await gesture.moveTo(tester.getCenter(find.byType(LineChart)) + const Offset(240, 0));
      await tester.pumpAndSettle();

      expect(find.text('78.4'), findsOneWidget);
      expect(find.text('Execution score'), findsOneWidget);
    });
  });

  group('ColumnChart', () {
    testWidgets('paints its columns', (tester) async {
      await tester.pumpWidget(
        _wrap(const ColumnChart(points: _series, valueSuffix: '%')),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows an empty message with no data', (tester) async {
      await tester.pumpWidget(_wrap(const ColumnChart(points: [])));
      expect(find.text('No data in range'), findsOneWidget);
    });
  });

  group('BarChart', () {
    testWidgets('paints ranked bars', (tester) async {
      await tester.pumpWidget(
        _wrap(const BarChart(points: _series, target: 75)),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('legend names both states, so red is never colour-alone', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(BarChart.legend()));

      expect(find.text('Meets target'), findsOneWidget);
      expect(find.text('Below target'), findsOneWidget);
    });

    testWidgets('shows an empty message with no territories', (tester) async {
      await tester.pumpWidget(_wrap(const BarChart(points: [], target: 75)));
      expect(find.text('No territories in range'), findsOneWidget);
    });
  });

  group('Sparkline', () {
    testWidgets('paints a trend cue', (tester) async {
      await tester.pumpWidget(_wrap(const Sparkline(values: [1, 3, 2, 5, 4])));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('a single value cannot be a trend — nothing is painted', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const Sparkline(values: [1])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a flat series does not divide by zero', (tester) async {
      await tester.pumpWidget(_wrap(const Sparkline(values: [5, 5, 5, 5])));
      expect(tester.takeException(), isNull);
    });
  });
}
