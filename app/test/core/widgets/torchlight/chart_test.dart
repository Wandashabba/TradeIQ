import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';

import '../../design/amber_golden.dart';
import 'torch_harness.dart';

const List<ChartReading> _weeks = <ChartReading>[
  ChartReading(label: 'W26', longLabel: '2026-W26', value: 40),
  ChartReading(label: 'W27', longLabel: '2026-W27', value: null),
  ChartReading(label: 'W28', longLabel: '2026-W28', value: 80),
];

ChartSeries _subject([List<ChartReading> readings = _weeks]) =>
    ChartSeries(name: 'Gauteng North', readings: readings);

final ChartSeries _comparison = const ChartSeries(
  name: 'Client average',
  role: ChartSeriesRole.comparison,
  readings: <ChartReading>[
    ChartReading(label: 'W26', value: 55),
    ChartReading(label: 'W27', value: 56),
    ChartReading(label: 'W28', value: 57),
  ],
);

Widget _chart({
  List<ChartSeries>? series,
  ChartThreshold? threshold,
  String? gapNote,
  Widget? veldReplacement,
}) => Padding(
  padding: const EdgeInsets.all(16),
  child: TrendChart(
    series: series ?? <ChartSeries>[_subject()],
    unit: TiqUnit.percent,
    semanticsLabel: 'Scorecard trend, three weeks',
    notMeasuredWord: 'Not measured',
    threshold: threshold,
    gapNote: gapNote,
    veldReplacement: veldReplacement,
  ),
);

void main() {
  group('the legend is not optional', () {
    testWidgets('every series it was handed is named', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(series: <ChartSeries>[_subject(), _comparison]),
      );

      expect(find.text('Gauteng North'), findsOneWidget);
      expect(find.text('Client average'), findsOneWidget);
    });

    testWidgets('a threshold is named as well as drawn', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(
          threshold: const ChartThreshold(value: 70, label: 'Target 70'),
        ),
      );

      expect(find.text('Target 70'), findsOneWidget);
    });

    testWidgets('the comparison swatch is announced as dashed', (tester) async {
      // Colour is never the only signal: a reader who cannot separate Truffle
      // from chart-neutral gets the word.
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(series: <ChartSeries>[_subject(), _comparison]),
      );

      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Client average, dashed'),
      );
      expect(semantics, isNotNull);
    });
  });

  group('unknown is not zero', () {
    testWidgets('a gap note rides under the legend', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(gapNote: '1 week not measured'),
      );

      expect(find.text('1 week not measured'), findsOneWidget);
    });

    testWidgets('the scrub readout shows an em dash, not a nought', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(series: <ChartSeries>[_subject(), _comparison]),
      );

      // Land the thumb on the middle bucket — the one nobody measured — and
      // HOLD it there: the readout is a transient, and a tap that has already
      // been released has nothing left under it.
      final plot = tester.getRect(find.byType(CustomPaint).last);
      final gesture = await tester.startGesture(plot.centerLeft);
      await gesture.moveTo(plot.center);
      await tester.pump();
      addTearDown(() async => gesture.up());

      expect(find.text('2026-W27'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      // The comparison measured that week, so its figure is still a figure.
      expect(find.textContaining('56'), findsOneWidget);
    });

    testWidgets('the table twin spells the absence out in words', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TableTwin(
            series: <ChartSeries>[_subject()],
            unit: TiqUnit.percent,
            periodHeading: 'Period',
            notMeasuredWord: 'Not measured',
          ),
        ),
      );

      expect(find.text('2026-W26'), findsOneWidget);
      expect(find.text('Not measured'), findsOneWidget);
      // The unabbreviated period, not the axis form.
      expect(find.text('W26'), findsNothing);
    });
  });

  group('Veld', () {
    testWidgets('draws no plot and shows the figure list instead', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.veld(),
        child: _chart(veldReplacement: const Text('the figures, as rows')),
      );

      expect(find.text('the figures, as rows'), findsOneWidget);
      // The legend still renders: it names what the rows are.
      expect(find.text('Gauteng North'), findsOneWidget);
      // Nothing is painting a plot.
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((p) => p.painter is TrendChartPainter),
        isEmpty,
      );
    });
  });

  group('the amber law', () {
    for (final skin in torchSkins) {
      testWidgets('${skin.mode.name}: a chart emits nothing', (tester) async {
        await pumpTorch(
          tester,
          skin: skin,
          child: _chart(
            series: <ChartSeries>[_subject(), _comparison],
            threshold: const ChartThreshold(value: 70, label: 'Target 70'),
          ),
        );

        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'The chart-focus rung exists on the ladder and this kit '
              'declines it. ${census.describe()}',
        );
      });
    }
  });

  group('the scale', () {
    test('a flat run still gets a band to sit in', () {
      final scale = niceScale(<double>[50, 50, 50]);
      expect(scale.max, greaterThan(scale.min));
    });

    test('a threshold outside the data widens the scale to hold it', () {
      final scale = niceScale(<double>[10, 20], include: 90);
      expect(scale.max, greaterThanOrEqualTo(90));
    });

    test('an empty run does not divide by zero', () {
      final scale = niceScale(const <double>[]);
      expect(scale.step, greaterThan(0));
    });
  });
}
