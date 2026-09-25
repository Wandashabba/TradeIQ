import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/curve.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart'
    show FigureSlot, MetricKind;

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
  // Afrikaans by default in the tests that care: the kit takes these words
  // from the caller, and a test that only ever passes English cannot tell a
  // threaded string from a hardcoded one.
  String dashedWord = 'gestippel',
  MetricKind? sampleKind,
}) => Padding(
  padding: const EdgeInsets.all(16),
  child: TrendChart(
    series: series ?? <ChartSeries>[_subject()],
    unit: TiqUnit.percent,
    semanticsLabel: 'Scorecard trend, three weeks',
    notMeasuredWord: 'Not measured',
    dashedWord: dashedWord,
    sampleKind: sampleKind,
    lowSampleWord: sampleKind == null ? null : 'Klein steekproef',
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

    testWidgets('the comparison swatch is announced as dashed, in the '
        'caller\'s language', (tester) async {
      // Colour is never the only signal: a reader who cannot separate Truffle
      // from chart-neutral gets the word. The dash is the second channel the
      // whole legend exists to carry, so it is the LAST word that may be left
      // in English — this used to read `'\$label, dashed'` in the kit, and an
      // Afrikaans manager on TalkBack heard "Kliëntgemiddeld, dashed".
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(
          series: <ChartSeries>[_subject(), _comparison],
          dashedWord: 'gestippel',
        ),
      );

      expect(
        find.bySemanticsLabel('Client average, gestippel'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Client average, dashed'), findsNothing);
      // The subject is solid, so it carries no dash word at all.
      expect(find.bySemanticsLabel('Gauteng North'), findsOneWidget);
    });

    testWidgets('a threshold is dashed too, and says so in the same word', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(
          dashedWord: 'gestippel',
          threshold: const ChartThreshold(value: 70, label: 'Standaard 70'),
        ),
      );

      expect(find.bySemanticsLabel('Standaard 70, gestippel'), findsOneWidget);
    });

    test('no file in the chart kit hardcodes an English word for a reader', () {
      // `chart_series.dart` says "Localised by the caller — nothing in this
      // folder hardcodes English", and this is what holds the WHOLE folder to
      // it rather than the one line that was caught. A string literal is the
      // only way English reaches a reader from here; doc comments are for us.
      final offenders = <String>[];
      final english = RegExp(
        r'\b(dashed|dotted|solid|not measured|small sample|average|'
        r'target|period|week|month)\b',
        caseSensitive: false,
      );
      // Dart string literals, single- and double-quoted, on one line.
      final literals = RegExp(
        '\'(?:[^\'\\\\\\n]|\\\\.)*\'|"(?:[^"\\\\\\n]|\\\\.)*"',
      );
      for (final entity in Directory(
        'lib/core/widgets/torchlight/figure/chart',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final line in entity.readAsLinesSync()) {
          final code = line.trimLeft();
          // A doc comment or a comment is not something a reader hears.
          if (code.startsWith('//')) continue;
          for (final match in literals.allMatches(line)) {
            final text = match.group(0)!;
            // An import URI is not something a reader hears.
            if (text.contains('/') || text.contains('package:')) continue;
            if (english.hasMatch(text)) {
              offenders.add('${entity.uri.pathSegments.last}: $text');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Every word a reader hears comes from the caller, never from the '
            'kit — the kit has no l10n and cannot get one.',
      );
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

  group('a thin bucket is not a confident one', () {
    // unify line 271: "Low sample keeps the figure at ink-2, outlines the
    // fill, and removes the delta." `ChartReading.sampleSize` was collected by
    // every caller and read by nothing, which is a field that reads as
    // implemented and is not.
    const List<ChartReading> thin = <ChartReading>[
      ChartReading(
        label: 'W26',
        longLabel: '2026-W26',
        value: 40,
        sampleSize: 2,
      ),
      ChartReading(
        label: 'W27',
        longLabel: '2026-W27',
        value: 80,
        sampleSize: 30,
      ),
    ];

    testWidgets('the table twin steps a two-row bucket down to ink-2', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TableTwin(
            series: <ChartSeries>[
              ChartSeries(name: 'Gauteng North', readings: thin),
            ],
            unit: TiqUnit.percent,
            periodHeading: 'Period',
            notMeasuredWord: 'Not measured',
            // A rate: n >= 5.
            sampleKind: MetricKind.rate,
            lowSampleWord: 'Klein steekproef',
          ),
        ),
      );

      final slots = tester
          .widgetList<FigureSlot>(find.byType(FigureSlot))
          .toList();
      final byValue = <double?, FigureState>{
        for (final slot in slots) slot.value?.toDouble(): slot.state,
      };
      expect(byValue[40], FigureState.lowSample);
      expect(byValue[80], FigureState.measured);
    });

    testWidgets('and leaves every bucket alone when the caller names no kind', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TableTwin(
            series: <ChartSeries>[
              ChartSeries(name: 'Gauteng North', readings: thin),
            ],
            unit: TiqUnit.percent,
            periodHeading: 'Period',
            notMeasuredWord: 'Not measured',
          ),
        ),
      );

      expect(
        tester
            .widgetList<FigureSlot>(find.byType(FigureSlot))
            .where((s) => s.state == FigureState.lowSample),
        isEmpty,
      );
    });

    testWidgets('the scrub readout says so under the thumb', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(
          series: <ChartSeries>[
            ChartSeries(name: 'Gauteng North', readings: thin),
          ],
          sampleKind: MetricKind.rate,
        ),
      );

      // Land the thumb on the first bucket — the one with two rows behind it
      // — and hold it there.
      final plot = tester.getRect(find.byType(CustomPaint).last);
      final gesture = await tester.startGesture(plot.center);
      await gesture.moveTo(plot.centerLeft);
      await tester.pump();
      addTearDown(() async => gesture.up());

      final readout = find.byType(ScrubReadout);
      expect(readout, findsOneWidget);
      final slot = tester.widget<FigureSlot>(
        find.descendant(of: readout, matching: find.byType(FigureSlot)),
      );
      expect(slot.state, FigureState.lowSample);
    });
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

  group('the curve may not invent a reading', () {
    /// Every point the rendered path actually passes through, sampled finely
    /// enough that an overshoot between two knots cannot hide between samples.
    List<Offset> walk(Path path) {
      final out = <Offset>[];
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d <= metric.length; d += 0.5) {
          final t = metric.getTangentForOffset(d);
          if (t != null) out.add(t.position);
        }
      }
      return out;
    }

    /// The knots' own bounds on the interval containing [x].
    (double, double) bandAt(List<Offset> knots, double x) {
      for (var i = 0; i < knots.length - 1; i++) {
        if (x >= knots[i].dx - 1e-6 && x <= knots[i + 1].dx + 1e-6) {
          return (
            math.min(knots[i].dy, knots[i + 1].dy),
            math.max(knots[i].dy, knots[i + 1].dy),
          );
        }
      }
      return (
        knots.map((p) => p.dy).reduce(math.min),
        knots.map((p) => p.dy).reduce(math.max),
      );
    }

    // The shapes that break a naive spline: a local minimum, a local maximum,
    // a plateau, a single spike, and a monotone run.
    const runs = <(String, List<double>)>[
      ('a dip', <double>[64, 61, 68, 66, 74, 71, 79, 83]),
      ('a spike', <double>[10, 10, 10, 90, 10, 10, 10]),
      ('a plateau then a rise', <double>[40, 40, 40, 40, 80]),
      ('monotone up', <double>[1, 2, 3, 5, 8, 13]),
      ('monotone down', <double>[99, 80, 61, 44, 20]),
      ('a sawtooth', <double>[30, 62, 38, 71, 44, 66, 40, 58]),
    ];

    for (final (name, values) in runs) {
      test('$name: the path never leaves the band its two readings bound', () {
        final knots = <Offset>[
          for (var i = 0; i < values.length; i++)
            Offset(i * 40.0, 200 - values[i]),
        ];
        final sampled = walk(monotonePath(knots));
        // Or the loop below passes by drawing nothing at all.
        expect(sampled.length, greaterThan(knots.length * 10));
        for (final p in sampled) {
          final (low, high) = bandAt(knots, p.dx);
          // Half a logical pixel of slack for the rasteriser's own arithmetic
          // — an overshoot worth seeing is whole pixels, and a Catmull-Rom on
          // 'a spike' misses this by more than forty.
          expect(
            p.dy,
            inInclusiveRange(low - 0.5, high + 0.5),
            reason:
                '$name overshoots at x=${p.dx.toStringAsFixed(1)}: '
                '${p.dy.toStringAsFixed(2)} is outside '
                '[${low.toStringAsFixed(2)}, ${high.toStringAsFixed(2)}]. '
                'A curve that leaves the band invents a week nobody measured.',
          );
        }
      });
    }

    test('two readings are joined by the straight line between them', () {
      final path = monotonePath(const <Offset>[Offset(0, 0), Offset(40, 20)]);
      final sampled = walk(path);
      expect(sampled.length, greaterThan(10));
      for (final p in sampled) {
        expect(p.dy, closeTo(p.dx / 2, 0.01));
      }
    });

    test('one reading is a move and nothing else', () {
      expect(monotonePath(const <Offset>[Offset(5, 5)]).computeMetrics(),
          isEmpty);
    });

    test('no readings is an empty path', () {
      expect(monotonePath(const <Offset>[]).computeMetrics(), isEmpty);
    });
  });

  group('the plot has a frame', () {
    TrendChartPainter painterFor({
      ChartSeries? subject,
      ChartThreshold? threshold,
    }) => TrendChartPainter(
      skin: TiqSkin.night(),
      subject: subject ?? _subject(),
      comparison: null,
      threshold: threshold,
      scrub: null,
      unit: TiqUnit.percent,
      decimals: null,
      number: TiqNumber.en,
      axisStyle: TiqSkin.night().text.axisLabel.style(),
      figureStyle: TiqSkin.night().text.figureS.style(),
      axisScale: 1,
      textDirection: TextDirection.ltr,
    );

    test('a left gutter is reserved, and it is the widest tick label wide', () {
      final painter = painterFor();
      // Not a guess and not a constant: the old chart set hardcoded 38dp and
      // clipped a four-digit axis. The value labels are measured.
      expect(painter.gutter, greaterThan(TrendChartPainter.tickGap));
      expect(painter.ticks.length, greaterThan(1));
    });

    test('the first and last readings sit inside the canvas, not on it', () {
      final painter = painterFor();
      const width = 320.0;
      expect(painter.xFor(0, width), painter.gutter);
      expect(
        painter.xFor(_weeks.length - 1, width),
        lessThan(width),
        reason:
            'The end dot is drawn at the last reading. A plot that runs to '
            'the canvas edge draws half a dot.',
      );
    });

    test('a single reading is centred rather than pinned to the left', () {
      final painter = painterFor(
        subject: _subject(const <ChartReading>[
          ChartReading(label: 'W26', value: 40),
        ]),
      );
      expect(painter.xFor(0, 320), closeTo(160, 40));
    });

    test('the thumb in the value gutter reads the first bucket', () {
      final painter = painterFor();
      expect(painter.indexAt(0, 320), 0);
      expect(painter.indexAt(-50, 320), 0);
      expect(painter.indexAt(999, 320), _weeks.length - 1);
    });

    test('a threshold outside the plot widens the scale rather than clipping',
        () {
      final painter = painterFor(
        threshold: const ChartThreshold(value: 120, label: 'Target 120'),
      );
      expect(painter.scale.max, greaterThanOrEqualTo(120));
    });
  });

  group('nothing measured is not a chart', () {
    const empty = <ChartReading>[
      ChartReading(label: 'W26', value: null),
      ChartReading(label: 'W27', value: null),
    ];

    testWidgets('the plot is dropped and the legend carries it', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(
          series: <ChartSeries>[_subject(empty)],
          gapNote: '2 weke nie gemeet nie',
        ),
      );

      // A `niceScale` of an empty set is 0 to 1, and drawing it is five
      // gridlines and a baseline under an axis nobody measured.
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((p) => p.painter is TrendChartPainter),
        isEmpty,
      );
      expect(find.text('Gauteng North'), findsOneWidget);
      expect(find.text('2 weke nie gemeet nie'), findsOneWidget);
    });

    testWidgets('a comparison with readings still draws', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.night(),
        child: _chart(series: <ChartSeries>[_subject(empty), _comparison]),
      );

      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((p) => p.painter is TrendChartPainter),
        isNotEmpty,
      );
    });
  });
}
