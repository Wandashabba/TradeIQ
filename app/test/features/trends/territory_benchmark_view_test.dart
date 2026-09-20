import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _weekA = '2026-03-02T00:00:00.000Z';
const _weekB = '2026-03-09T00:00:00.000Z';

TerritoryBenchmarkReport _report(
  BenchmarkMetric metric, {
  List<TerritoryBenchmark>? territories,
  double? clientAverage = 64,
}) =>
    TerritoryBenchmarkReport(
      metric: metric,
      isPercent: metric != BenchmarkMetric.scorecards,
      target: metric == BenchmarkMetric.scorecards ? 75 : null,
      targetLabel:
          metric == BenchmarkMetric.scorecards ? 'Green threshold' : null,
      unassignedCount: 1,
      client: BenchmarkSeries(
        average: clientAverage,
        count: clientAverage == null ? 0 : 5,
        points: clientAverage == null
            ? const []
            : const [
                TrendPoint(period: _weekA, value: 55, count: 4),
                TrendPoint(period: _weekB, value: 100, count: 1),
              ],
      ),
      territories: territories ??
          const [
            TerritoryBenchmark(
              territoryId: 'north',
              territoryName: 'North',
              territoryCode: 'n',
              average: 83.33,
              count: 3,
              points: [
                TrendPoint(period: _weekA, value: 75, count: 2),
                TrendPoint(period: _weekB, value: 100, count: 1),
              ],
              rank: 1,
              deltaFromClient: 19.33,
              position: BenchmarkPosition.above,
            ),
            TerritoryBenchmark(
              territoryId: 'south',
              territoryName: 'South',
              territoryCode: 's',
              average: 50,
              count: 1,
              points: [TrendPoint(period: _weekA, value: 50, count: 1)],
              rank: 2,
              deltaFromClient: -14,
              position: BenchmarkPosition.below,
            ),
            TerritoryBenchmark(
              territoryId: 'empty',
              territoryName: 'Empty',
              territoryCode: 'e',
              average: null,
              count: 0,
              points: [],
              rank: null,
              deltaFromClient: null,
              position: null,
            ),
          ],
    );

class _FakeRepo implements TrendsRepository {
  _FakeRepo({this.onBenchmark});

  final Future<TerritoryBenchmarkReport> Function(BenchmarkMetric)? onBenchmark;
  final metrics = <BenchmarkMetric>[];

  @override
  Future<List<TrendPoint>> scorecards([TrendQuery q = const TrendQuery()]) async => const [];

  @override
  Future<List<TrendPoint>> availability([TrendQuery q = const TrendQuery()]) async => const [];

  @override
  Future<List<TrendPoint>> perfectStore([TrendQuery q = const TrendQuery()]) async => const [];

  @override
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query = const TrendQuery(),
  ]) {
    metrics.add(metric);
    return onBenchmark?.call(metric) ?? Future.value(_report(metric));
  }
}

Future<void> _openCompare(
  WidgetTester tester,
  TrendsRepository repo, {
  ThemeData? theme,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    routedApp(
      const TrendsScreen(),
      theme: theme,
      overrides: [trendsRepositoryProvider.overrideWithValue(repo)],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('trends-view-compareTerritories')),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// A territory's name inside its own row — the chart legend repeats it.
Finder _rowName(String id, String name) => find.descendant(
      of: find.byKey(ValueKey('benchmark-row-$id')),
      matching: find.text(name),
    );

/// The ground a pill's words actually sit on: its wash over the panel.
Color _pillGround(WidgetTester tester, String word, TiqColors colors) {
  final box = tester.widget<Container>(
    find
        .ancestor(of: find.text(word), matching: find.byType(Container))
        .first,
  );
  return Color.alphaBlend(
    (box.decoration! as BoxDecoration).color!,
    colors.surface1,
  );
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    group(name, () {
      testWidgets('ranks territories against the client average, in words',
          (tester) async {
        await _openCompare(tester, _FakeRepo(), theme: theme);

        // The view switch and the panel title both say it; the panel is the
        // one that replaced the three over-time charts.
        expect(find.byKey(const ValueKey('trend-benchmark')), findsOneWidget);
        expect(find.byKey(const ValueKey('trend-scorecards')), findsNothing);
        expect(
          tester.widget<Text>(
            find.byKey(const ValueKey('benchmark-client-average')),
          ).data,
          '64',
        );
        expect(find.text('· Green threshold 75'), findsOneWidget);

        // Server order is the ranking; the list must not reshuffle it.
        final northY = tester.getTopLeft(_rowName('north', 'North')).dy;
        final southY = tester.getTopLeft(_rowName('south', 'South')).dy;
        final emptyY = tester.getTopLeft(_rowName('empty', 'Empty')).dy;
        expect(northY, lessThan(southY));
        expect(southY, lessThan(emptyY));

        // Position is a word, never colour alone.
        expect(find.text('ABOVE AVERAGE'), findsOneWidget);
        expect(find.text('BELOW AVERAGE'), findsOneWidget);
        expect(find.text('NO DATA'), findsOneWidget);
        expect(
          find.text('19.3 pts above the client average · 3 scorecards'),
          findsOneWidget,
        );
        expect(
          find.text('14 pts below the client average · 1 scorecard'),
          findsOneWidget,
        );
        expect(find.text('Nothing measured in this window'), findsOneWidget);

        // Every bar is ticked at the client average; the territory without
        // data has no bar, because an empty track reads as a zero.
        final bars = tester.widgetList<BenchmarkBar>(find.byType(BenchmarkBar));
        expect(bars.length, 2);
        expect(bars.map((b) => b.target), everyElement(64));
        expect(bars.map((b) => b.status), [LumenStatus.good, LumenStatus.warn]);

        final figure = tester.widget<Text>(
          find.byKey(const ValueKey('benchmark-average-north')),
        );
        expect(figure.data, '83.3');
        expect(figure.style!.fontFamily, LumenGlass.mono);
        expect(
          tester.widget<Text>(
            find.byKey(const ValueKey('benchmark-average-empty')),
          ).data,
          '—',
        );
      });

      testWidgets('every word and figure clears AA on its ground',
          (tester) async {
        await _openCompare(tester, _FakeRepo(), theme: theme);
        final colors = tester.element(find.byType(TrendsScreen)).colors;

        for (final word in ['ABOVE AVERAGE', 'BELOW AVERAGE', 'NO DATA']) {
          final ink = tester.widget<Text>(find.text(word)).style!.color!;
          final ratio = contrastRatio(ink, _pillGround(tester, word, colors));
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$word $ratio:1');
        }

        for (final finder in [
          find.byKey(const ValueKey('benchmark-average-north')),
          find.byKey(const ValueKey('benchmark-client-average')),
          find.byKey(const ValueKey('benchmark-target')),
          _rowName('north', 'North'),
          find.text('14 pts below the client average · 1 scorecard'),
        ]) {
          final ink = tester.widget<Text>(finder).style!.color!;
          final ratio = contrastRatio(ink, colors.surface1);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$finder $ratio:1');
        }
      });
    });
  }

  testWidgets('charts the selected territory over the aligned client line',
      (tester) async {
    await _openCompare(tester, _FakeRepo(), theme: AppTheme.light());

    LineChart chart() =>
        tester.widget<LineChart>(find.byKey(const ValueKey('benchmark-chart')));
    expect(chart().seriesName, 'North');
    expect(chart().comparisonName, 'Client average');
    expect(chart().target, 75);
    expect(chart().comparison.map((p) => p.value), [55, 100]);

    await tester.tap(find.byKey(const ValueKey('benchmark-row-south')));
    await tester.pumpAndSettle();
    expect(chart().seriesName, 'South');
    // South has only week A, so the client line is cut to week A as well.
    expect(chart().points.map((p) => p.value), [50]);
    expect(chart().comparison.map((p) => p.value), [55]);
    expect(find.text('South against the client average'), findsOneWidget);
  });

  testWidgets('switching metric re-queries and shows percentages',
      (tester) async {
    final repo = _FakeRepo();
    await _openCompare(tester, repo, theme: AppTheme.light());
    expect(repo.metrics.last, BenchmarkMetric.scorecards);

    await tester.tap(
      find.byKey(const ValueKey('benchmark-metric-availability')),
    );
    await tester.pumpAndSettle();

    expect(repo.metrics.last, BenchmarkMetric.availability);
    expect(find.text('83.3%'), findsOneWidget);
    expect(find.byKey(const ValueKey('benchmark-target')), findsNothing);
  });

  testWidgets('loading shows a spinner in the panel', (tester) async {
    final pending = Completer<TerritoryBenchmarkReport>();
    await _openCompare(
      tester,
      _FakeRepo(onBenchmark: (_) => pending.future),
      theme: AppTheme.light(),
      settle: false,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trend-benchmark')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('says so when the client has no territories', (tester) async {
    await _openCompare(
      tester,
      _FakeRepo(
        onBenchmark: (m) async => _report(m, territories: const []),
      ),
      theme: AppTheme.dark(),
    );
    expect(find.text('No territories set up'), findsOneWidget);
    expect(find.byType(BenchmarkBar), findsNothing);
  });

  testWidgets('says so when nothing was measured in the window',
      (tester) async {
    await _openCompare(
      tester,
      _FakeRepo(onBenchmark: (m) async => _report(m, clientAverage: null)),
      theme: AppTheme.light(),
    );
    expect(find.text('No data in range'), findsOneWidget);
    expect(find.byType(BenchmarkBar), findsNothing);
  });

  testWidgets('shows a failure message with a retry', (tester) async {
    await _openCompare(
      tester,
      _FakeRepo(onBenchmark: (_) async => throw Exception('boom')),
      theme: AppTheme.light(),
    );
    expect(
      find.textContaining('Failed to load territory comparison'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
