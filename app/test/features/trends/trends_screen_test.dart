import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import '../territory_harness.dart';

/// Gauteng North lost week 27 to a strike; the client average has all three.
/// That gap is the whole reason this screen aligns on the union of periods
/// rather than by position.
TerritoryBenchmarkReport _report({
  double? clientAverage = 55,
  bool percent = false,
  double? target,
  int unassigned = 0,
  List<TerritoryBenchmark>? territories,
}) => TerritoryBenchmarkReport(
  metric: BenchmarkMetric.scorecards,
  isPercent: percent,
  target: target,
  targetLabel: target == null ? null : 'Standard',
  unassignedCount: unassigned,
  client: BenchmarkSeries(
    average: clientAverage,
    count: 40,
    points: const <TrendPoint>[
      TrendPoint(period: '2026-W26', value: 55),
      TrendPoint(period: '2026-W27', value: 56),
      TrendPoint(period: '2026-W28', value: 57),
    ],
  ),
  territories:
      territories ??
      const <TerritoryBenchmark>[
        TerritoryBenchmark(
          territoryId: 'ter-1',
          territoryName: 'Gauteng North',
          territoryCode: 'GP-N',
          average: 71,
          count: 12,
          points: <TrendPoint>[
            TrendPoint(period: '2026-W26', value: 70),
            TrendPoint(period: '2026-W28', value: 72),
          ],
          rank: 1,
          deltaFromClient: 16,
          position: BenchmarkPosition.above,
        ),
        // Nothing measured, no rank, no delta — and no invented zero.
        TerritoryBenchmark(
          territoryId: 'ter-2',
          territoryName: 'Western Cape',
          territoryCode: 'WC',
          average: null,
          count: 0,
          points: <TrendPoint>[],
          rank: null,
          deltaFromClient: null,
          position: null,
        ),
      ],
);

Future<FakeTrendsRepository> _pump(
  WidgetTester tester, {
  List<TrendPoint> points = const <TrendPoint>[w26, w27],
  TerritoryBenchmarkReport? report,
  Object? failure,
  bool pending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 1400),
}) async {
  final repository = FakeTrendsRepository(
    points: points,
    report: report,
    failure: failure,
    pending: pending,
  );
  await pumpConsole(
    tester,
    const TrendsScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    settle: !pending,
    overrides: <Override>[
      trendsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return repository;
}

Future<void> _compare(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('trends-view-compareTerritories')),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('over time', () {
    testWidgets('three series, each with a chart and a legend', (tester) async {
      await _pump(tester);

      expect(find.text('Scorecard trend'), findsOneWidget);
      expect(find.text('Availability trend'), findsOneWidget);
      expect(find.text('Perfect store trend'), findsOneWidget);
      expect(find.byType(TrendChart), findsNWidgets(3));
      // The legend is not optional: TrendChart builds one from the series it
      // was handed, so a caller cannot ship a chart without a key.
      expect(find.byType(ChartLegend), findsNWidgets(3));
      expect(find.text('Weighted execution score'), findsOneWidget);
      expect(find.text('On-shelf availability'), findsOneWidget);
      expect(find.text('Outlets passing every gate'), findsOneWidget);
    });

    testWidgets('every chart has a table twin carrying the exact figures', (
      tester,
    ) async {
      await _pump(tester);

      // The axis abbreviates to W26; the table carries the year.
      expect(find.text('2026-W26'), findsNothing);

      for (final section in const <String>[
        'trend-scorecards',
        'trend-availability',
        'trend-perfect-store',
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey<String>(section)),
            matching: find.byKey(const ValueKey<String>('view-table')),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(find.byType(TableTwin), findsNWidgets(3));
      expect(find.text('2026-W26'), findsNWidgets(3));
      // The scorecard trend is a score and carries no unit; the other two are
      // rates and say so.
      expect(find.text('80'), findsOneWidget);
      expect(find.text('80%'), findsNWidgets(2));
    });

    testWidgets('an empty window is a designed state, not a flat line', (
      tester,
    ) async {
      await _pump(tester, points: const <TrendPoint>[]);

      expect(find.text('No data in range'), findsNWidgets(3));
      expect(find.byType(TrendChart), findsNothing);
      // Never a zero: the server omits an empty bucket rather than sending 0.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a failed series offers its own retry, and only one', (
      tester,
    ) async {
      await _pump(tester, failure: Exception('boom'));

      expect(find.byType(ErrorState), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading is a skeleton the size of the plot', (tester) async {
      await _pump(tester, pending: true);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(SkeletonShell), findsWidgets);
      expect(find.byType(TrendChart), findsNothing);
    });
  });

  group('the filter rail scopes every chart', () {
    testWidgets('it defaults to weekly and the server default window', (
      tester,
    ) async {
      final repository = await _pump(tester);

      expect(repository.queries.first.interval, TrendInterval.week);
      // Null is not "all time" — it is the server's own lookback, and the
      // control says so rather than implying a range nobody asked for.
      expect(repository.queries.first.from, isNull);
      expect(repository.queries.first.to, isNull);
      await scrollRailTo(
        tester,
        find.byType(TorchFilterRail).first,
        find.byKey(const ValueKey<String>('trend-daterange')),
      );
      expect(find.text('Server default'), findsOneWidget);
    });

    testWidgets('switching to daily re-queries the API, not just the paint', (
      tester,
    ) async {
      final repository = await _pump(tester);

      // Five chips do not fit a 360dp rail, so the bucket chips genuinely are
      // off the edge — as they are for a manager.
      await scrollRailTo(
        tester,
        find.byType(TorchFilterRail).first,
        find.byKey(const ValueKey<String>('interval-day')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('interval-day')));
      await tester.pumpAndSettle();

      expect(repository.queries.last.interval, TrendInterval.day);
    });

    testWidgets('switching the metric re-queries the benchmark', (
      tester,
    ) async {
      final repository = await _pump(tester, report: _report());
      await _compare(tester);

      await scrollRailTo(
        tester,
        find.byType(TorchFilterRail).last,
        find.byKey(const ValueKey<String>('benchmark-metric-availability')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('benchmark-metric-availability')),
      );
      await tester.pumpAndSettle();

      expect(repository.metrics.last, BenchmarkMetric.availability);
    });
  });

  group('compare territories', () {
    testWidgets('the client average, its territories and their standing', (
      tester,
    ) async {
      await _pump(tester, report: _report(target: 70, unassigned: 4));
      await _compare(tester);

      expect(find.text('55'), findsWidgets);
      expect(find.text('Above average'), findsOneWidget);
      expect(
        find.text('16 points above the client average · 12 scorecards'),
        findsOneWidget,
      );
      // The unassigned rows are named rather than quietly folded in.
      expect(
        find.textContaining('outlets outside every territory'),
        findsOneWidget,
      );
    });

    testWidgets('a territory with nothing measured invents neither a figure '
        'nor a rank', (tester) async {
      await _pump(tester, report: _report());
      await _compare(tester);

      final row = find.byKey(const ValueKey<String>('benchmark-row-ter-2'));
      expect(find.descendant(of: row, matching: find.text('0')), findsNothing);
      expect(find.descendant(of: row, matching: find.text('—')), findsWidgets);
      expect(
        find.descendant(
          of: row,
          matching: find.text('Nothing measured in this window'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no client average at all is an absence, not a nought', (
      tester,
    ) async {
      await _pump(tester, report: _report(clientAverage: null));
      await _compare(tester);

      expect(find.text('No data in range'), findsOneWidget);
      expect(find.byType(TrendChart), findsNothing);
    });

    testWidgets('a percentage metric carries its unit, and no target tile '
        'is invented', (tester) async {
      await _pump(tester, report: _report(clientAverage: 83.3, percent: true));
      await _compare(tester);

      expect(find.text('83.3%'), findsWidgets);
      // The client configured no standard for this metric, so no tile claims
      // one. A target nobody set is not a target of zero.
      expect(
        find.byKey(const ValueKey<String>('benchmark-target')),
        findsNothing,
      );
    });

    testWidgets('no territories at all says what to do about it', (
      tester,
    ) async {
      await _pump(
        tester,
        report: _report(territories: const <TerritoryBenchmark>[]),
      );
      await _compare(tester);

      expect(find.text('No territories set up'), findsOneWidget);
    });

    testWidgets('the comparison chart aligns on the UNION of periods', (
      tester,
    ) async {
      // Gauteng North has W26 and W28; the client has all three. Aligning by
      // position would draw the territory's W28 against the client's W27 — a
      // comparison against the wrong week, drawn as if it were the right one.
      await _pump(tester, report: _report());
      await _compare(tester);

      final chart = tester.widget<TrendChart>(
        find.byKey(const ValueKey<String>('benchmark-chart')),
      );
      expect(chart.series, hasLength(2));
      final subject = chart.series.first;
      final comparison = chart.series.last;
      expect(comparison.role, ChartSeriesRole.comparison);
      expect(subject.readings.map((r) => r.longLabel), <String>[
        '2026-W26',
        '2026-W27',
        '2026-W28',
      ]);
      expect(comparison.readings.map((r) => r.longLabel), <String>[
        '2026-W26',
        '2026-W27',
        '2026-W28',
      ]);
      // The strike week is a hole in the subject and a reading in the client
      // line — which is exactly what happened.
      expect(subject.readings.map((r) => r.value), <double?>[70, null, 72]);
      expect(comparison.readings.map((r) => r.value), <double?>[55, 56, 57]);
      expect(chart.gapNote, '1 bucket not measured');
    });

    testWidgets('picking a territory redraws the chart against it', (
      tester,
    ) async {
      await _pump(
        tester,
        report: _report(
          territories: <TerritoryBenchmark>[
            const TerritoryBenchmark(
              territoryId: 'ter-1',
              territoryName: 'Gauteng North',
              territoryCode: 'GP-N',
              average: 71,
              count: 12,
              points: <TrendPoint>[TrendPoint(period: '2026-W26', value: 70)],
              rank: 1,
              deltaFromClient: 16,
              position: BenchmarkPosition.above,
            ),
            const TerritoryBenchmark(
              territoryId: 'ter-2',
              territoryName: 'Western Cape',
              territoryCode: 'WC',
              average: 41,
              count: 8,
              points: <TrendPoint>[TrendPoint(period: '2026-W26', value: 41)],
              rank: 2,
              deltaFromClient: -14,
              position: BenchmarkPosition.below,
            ),
          ],
        ),
      );
      await _compare(tester);

      expect(
        find.text('Gauteng North against the client average'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('benchmark-row-ter-2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Western Cape against the client average'),
        findsOneWidget,
      );
      // Selection is a word on the row, never a fill: a list of fifteen fills
      // with one different is not a selection anybody can see.
      expect(find.text('Showing'), findsOneWidget);
    });

    testWidgets('rows are SoftRows with a meter and no invented bar', (
      tester,
    ) async {
      await _pump(tester, report: _report());
      await _compare(tester);

      expect(find.byType(SoftRow), findsNWidgets(2));
      // A territory with no value draws no track: an empty bar reads as zero.
      final measured = tester.widget<SoftRow>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('benchmark-row-ter-1')),
          matching: find.byType(SoftRow),
        ),
      );
      final unmeasured = tester.widget<SoftRow>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('benchmark-row-ter-2')),
          matching: find.byType(SoftRow),
        ),
      );
      expect(measured.meta, isNotNull);
      expect(unmeasured.meta, isNull);
    });
  });

  group('Veld', () {
    testWidgets('draws no chart at all; the table twin is the screen', (
      tester,
    ) async {
      await _pump(tester, skin: TiqSkin.veld());

      expect(find.byType(TrendChart), findsNothing);
      expect(find.byType(TableTwin), findsNWidgets(3));
      // And no toggle, because a control with one working position is chrome.
      expect(find.byKey(const ValueKey<String>('view-chart')), findsNothing);
    });

    testWidgets('the comparison is a table too, both series in it', (
      tester,
    ) async {
      await _pump(tester, skin: TiqSkin.veld(), report: _report());
      await _compare(tester);

      expect(find.byType(TrendChart), findsNothing);
      expect(find.text('Gauteng North'), findsWidgets);
      expect(find.text('Client average'), findsWidgets);
    });
  });

  group('every button is operable by a screen reader', () {
    testWidgets('the filter rail, the toggles and the benchmark rows', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, report: _report());
      expectEveryButtonActivatable(tester);

      await _compare(tester);
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>[
        'over-time',
        'empty',
        'error',
        'compare',
      ]) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await _pump(
            tester,
            skin: skin,
            points: phase == 'empty'
                ? const <TrendPoint>[]
                : const <TrendPoint>[w26, w27],
            failure: phase == 'error' ? Exception('boom') : null,
            report: _report(),
          );
          if (phase == 'compare') await _compare(tester);

          final census = await amberCensus(tester);
          expectWithinAmberBudget(census, skin, route: 'trends', phase: phase);
          // Three charts on one route is three focus objects asking, and the
          // budget is counted per route. Every phase declines.
          expect(
            census.objectCount,
            skin.mode == SkinMode.night ? 1 : 0,
            reason: census.describe(),
          );
        });
      }
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await _pump(tester, textScale: 2.0, size: const Size(320, 2400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans, over time', (tester) async {
      await _pump(tester, locale: const Locale('af'));

      expect(find.text('Tendense'), findsWidgets);
      expect(find.text('Telkaart-tendens'), findsOneWidget);
      await scrollRailTo(
        tester,
        find.byType(TorchFilterRail).first,
        find.byKey(const ValueKey<String>('trend-daterange')),
      );
      expect(find.text('Bediener se verstek'), findsOneWidget);
      expect(find.text('Scorecard trend'), findsNothing);
    });

    testWidgets('Afrikaans, comparing territories', (tester) async {
      await _pump(tester, locale: const Locale('af'), report: _report());
      await _compare(tester);

      expect(find.text('Kliëntgemiddeld'), findsWidgets);
      expect(find.text('Bo gemiddeld'), findsOneWidget);
      expect(find.text('Niks gemeet in hierdie venster nie'), findsOneWidget);
      expect(find.text('Above average'), findsNothing);
    });
  });
}
