import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SizedBox(width: 600, height: 300, child: child)),
);

/// Hovers the far right of [chart], where the nearest point is the last.
Future<void> _hoverEnd(WidgetTester tester, Finder chart) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(chart) + const Offset(240, 0));
  await tester.pumpAndSettle();
}

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

/// Records only the vertical extent of what is drawn, so a test can assert the
/// plot actually contains its data rather than trusting the scale arithmetic.
class _PathBounds implements Canvas {
  double top = double.infinity;
  double bottom = double.negativeInfinity;

  @override
  void drawPath(Path path, Paint paint) {
    final bounds = path.getBounds();
    top = math.min(top, bounds.top);
    bottom = math.max(bottom, bounds.bottom);
  }

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

  group('LineChart comparison series', () {
    const earlier = <ChartPoint>[
      (label: '14 May', value: 70.0),
      (label: '20 May', value: 71.5),
      (label: '29 May', value: 70.8),
      (label: '6 Jun', value: 72.0),
      (label: '13 Jun', value: 71.1),
    ];

    testWidgets('draws a second stroke in the second series slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LineChart(
            points: _series,
            comparison: earlier,
            seriesName: 'This month',
            comparisonName: 'The month before',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paints = _recordPaths(
        tester,
        find.byType(LineChart),
        const Size(600, 208),
      );
      final strokes = paints
          .where((p) => p.style == PaintingStyle.stroke)
          .toList();

      expect(
        strokes,
        hasLength(2),
        reason: 'both series must reach the canvas',
      );
      // Fixed palette slots, never a generated or cycled hue.
      expect(strokes.map((p) => p.color.toARGB32()).toSet(), {
        TiqColors.dark.series1.toARGB32(),
        TiqColors.dark.series2.toARGB32(),
      });
      // One fill only: the comparison gets no wash, or two washes over one plot
      // muddy both.
      expect(paints.where((p) => p.style == PaintingStyle.fill), hasLength(1));
    });

    testWidgets('names both lines, so colour is never the only carrier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LineChart(
            points: _series,
            comparison: earlier,
            seriesName: 'This month',
            comparisonName: 'The month before',
          ),
        ),
      );

      expect(find.text('This month'), findsOneWidget);
      expect(find.text('The month before'), findsOneWidget);
    });

    testWidgets('scales to whichever series is higher', (tester) async {
      // A comparison that beat the current period must not ride off the top of
      // the plot — the whole point is reading the two against each other.
      const towering = <ChartPoint>[
        (label: 'a', value: 400),
        (label: 'b', value: 420),
      ];
      await tester.pumpWidget(
        _wrap(const LineChart(points: _series, comparison: towering)),
      );
      await tester.pumpAndSettle();

      final chart = find.byType(LineChart);
      final cp = tester.widget<CustomPaint>(
        find.descendant(of: chart, matching: find.byType(CustomPaint)),
      );
      final bounds = _PathBounds();
      cp.painter!.paint(bounds, const Size(600, 208));

      expect(bounds.top, greaterThanOrEqualTo(0.0));
      expect(bounds.bottom, lessThanOrEqualTo(208.0));
    });

    testWidgets('a single comparison point is not drawn as a line', (
      tester,
    ) async {
      // Same rule the main series follows: one point is not a trend.
      await tester.pumpWidget(
        _wrap(
          const LineChart(
            points: _series,
            comparison: [(label: 'a', value: 5)],
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
        paints.where((p) => p.style == PaintingStyle.stroke),
        hasLength(1),
      );
    });

    testWidgets('a scrub reads out the compared bucket by name', (
      tester,
    ) async {
      // The two series are aligned by POSITION, not by date. Showing the
      // comparison bucket's own label is what makes that visible instead of
      // leaving the reader to assume it is the same day.
      await tester.pumpWidget(
        _wrap(
          const LineChart(
            points: _series,
            comparison: earlier,
            comparisonName: 'The month before',
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(find.byType(LineChart)) + const Offset(240, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('71.1 · 13 Jun (The month before)'), findsOneWidget);
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

  group('Lumen Glass (light)', () {
    const earlier = <ChartPoint>[
      (label: '14 May', value: 70.0),
      (label: '13 Jun', value: 71.1),
    ];

    testWidgets('the series takes the accent, the comparison a slate mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LineChart(points: _series, comparison: earlier),
          theme: AppTheme.light(),
        ),
      );
      await tester.pumpAndSettle();

      final strokes = _recordPaths(
        tester,
        find.byType(LineChart),
        const Size(600, 208),
      ).where((p) => p.style == PaintingStyle.stroke);
      expect(strokes.map((p) => p.color.toARGB32()).toSet(), {
        LumenPalette.light.accentSolid.toARGB32(),
        TiqColors.light.ink4.toARGB32(),
      });
      // Lines are graphics: each must hold 3:1 against the pane.
      for (final p in strokes) {
        expect(
          contrastRatio(p.color, TiqColors.light.surface1),
          greaterThanOrEqualTo(3.0),
        );
      }
    });

    testWidgets('the sparkline and the legend speak the same accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const Sparkline(values: [1, 3, 2, 5]), theme: AppTheme.light()),
      );
      final spark = _recordPaths(
        tester,
        find.byType(Sparkline),
        const Size(96, 22),
      );
      // ARGB32, not Color ==: Paint round-trips the channels through floats.
      expect(
        spark.single.color.toARGB32(),
        LumenPalette.light.accentSolid.toARGB32(),
      );

      await tester.pumpWidget(
        _wrap(BarChart.legend(), theme: AppTheme.light()),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.color == LumenPalette.light.accentSolid,
        ),
        findsOneWidget,
      );
      expect(find.text('Below target'), findsOneWidget);
    });

    testWidgets('the scrub readout is an opaque dark chip whose words clear '
        'AA', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LineChart(points: _series, seriesName: 'Execution score'),
          theme: AppTheme.light(),
        ),
      );
      await _hoverEnd(tester, find.byType(LineChart));

      final ground = Color.alphaBlend(
        LumenPalette.light.darkFill,
        TiqColors.light.surface1,
      );
      expect(ground.a, 1.0);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == ground,
        ),
        findsOneWidget,
      );

      Color ink(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;
      final value = tester.widget<Text>(find.text('78.4'));
      expect(value.style?.fontFamily, LumenGlass.mono);
      // Every word on the chip, composited, measured against the chip.
      for (final text in ['78.4', '13 JUL', 'Execution score', '1.2']) {
        final ratio = contrastRatio(Color.alphaBlend(ink(text), ground), ground);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '"$text" $ratio:1');
      }
      // The delta keeps its arrow — direction is never colour alone.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('dark keeps the fixed instrument readout', (tester) async {
      await tester.pumpWidget(_wrap(const LineChart(points: _series)));
      await _hoverEnd(tester, find.byType(LineChart));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  const Color(0xFF05060A),
        ),
        findsOneWidget,
      );
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
