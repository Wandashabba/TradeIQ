import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 600, height: 300, child: child)),
);

/// Records every Path the painter draws so tests can pin the actual [Paint] —
/// widget-config assertions alone would let a painter silently ignore its
/// knobs (a mutation review proved exactly that).
class _PaintLog implements Canvas {
  final pathPaints = <Paint>[];

  @override
  void drawPath(Path path, Paint paint) => pathPaints.add(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Runs [chart]'s one [CustomPaint] painter against a recording canvas.
List<Paint> _recordPaths(WidgetTester tester, Finder chart, Size size) {
  final cp = tester.widget<CustomPaint>(
    find.descendant(of: chart, matching: find.byType(CustomPaint)),
  );
  final log = _PaintLog();
  cp.painter!.paint(log, size);
  return log.pathPaints;
}

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
      await tester.pumpWidget(
        _wrap(const LineChart(points: _series, target: 75)),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('degrades to a message rather than a broken plot', (
      tester,
    ) async {
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
      await gesture.moveTo(
        tester.getCenter(find.byType(LineChart)) + const Offset(240, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('78.4'), findsOneWidget);
      expect(find.text('Execution score'), findsOneWidget);
    });
  });

  group('glass fill', () {
    test('the shared recipe fades brand 28% → 0%, top to bottom', () {
      final g = glassAreaGradient(const Color(0xFF0A6CF0));

      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.colors, hasLength(2));
      expect(g.colors.first.a, closeTo(0.28, 0.005));
      expect(g.colors.last.a, closeTo(0.0, 0.005));
      // Both stops stay the brand hue — only the opacity moves.
      expect(g.colors.first.toARGB32() & 0x00FFFFFF, 0x0A6CF0);
      expect(g.colors.last.toARGB32() & 0x00FFFFFF, 0x0A6CF0);
    });

    testWidgets(
      'gradientFill paints a shader-backed area and lineWidth reaches the stroke',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const LineChart(
              points: _series,
              lineWidth: 2.5,
              gradientFill: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final paints = _recordPaths(
          tester,
          find.byType(LineChart),
          const Size(600, 208),
        );
        expect(
          paints.where(
            (p) => p.style == PaintingStyle.fill && p.shader != null,
          ),
          hasLength(1),
          reason: 'the glass area must actually reach the canvas',
        );
        expect(
          paints.where(
            (p) => p.style == PaintingStyle.stroke && p.strokeWidth == 2.5,
          ),
          hasLength(1),
          reason: 'the widget lineWidth must be the painted stroke width',
        );
      },
    );

    testWidgets('a plain LineChart keeps the flat wash and 2px stroke', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LineChart(points: _series)));
      await tester.pumpAndSettle();

      final paints = _recordPaths(
        tester,
        find.byType(LineChart),
        const Size(600, 208),
      );
      expect(paints.where((p) => p.shader != null), isEmpty);
      expect(
        paints.where(
          (p) => p.style == PaintingStyle.stroke && p.strokeWidth == 2,
        ),
        hasLength(1),
      );
    });

    testWidgets('a gradient sparkline paints the area; a plain one does not', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const Sparkline(values: [1, 3, 2, 5], gradient: true)),
      );
      var paints = _recordPaths(
        tester,
        find.byType(Sparkline),
        const Size(96, 22),
      );
      expect(
        paints.where((p) => p.style == PaintingStyle.fill && p.shader != null),
        hasLength(1),
        reason: 'gradient: true must fill under the line',
      );

      await tester.pumpWidget(_wrap(const Sparkline(values: [1, 3, 2, 5])));
      paints = _recordPaths(tester, find.byType(Sparkline), const Size(96, 22));
      expect(paints.where((p) => p.shader != null), isEmpty);
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

    testWidgets('fill-width mode holds its lane even with too few points', (
      tester,
    ) async {
      // width: null means "fill the available width" — the too-few-points
      // branch must honour the same contract, or a KPI tile's layout would
      // jump the day its series shrinks below two points.
      await tester.pumpWidget(
        _wrap(const Align(child: Sparkline(values: [1], width: null))),
      );

      expect(tester.getSize(find.byType(Sparkline)).width, 600);
    });
  });
}
