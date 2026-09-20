import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

import '../../helpers/routed_app.dart';

const _points = <TrendPoint>[
  TrendPoint(period: '2026-W26', value: 40),
  TrendPoint(period: '2026-W27', value: 80),
];

class _FakeTrendsRepository implements TrendsRepository {
  /// Every query the screen actually issued — so a test can prove the control
  /// reaches the API, rather than merely repainting itself.
  final queries = <TrendQuery>[];

  @override
  Future<List<TrendPoint>> scorecards([
    TrendQuery query = const TrendQuery(),
  ]) async {
    queries.add(query);
    return _points;
  }

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) async => _points;

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) async => _points;

  @override
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query = const TrendQuery(),
  ]) async => TerritoryBenchmarkReport(
    metric: metric,
    isPercent: false,
    client: const BenchmarkSeries(average: null, count: 0, points: []),
    territories: const [],
  );
}

class _ThrowingTrendsRepository implements TrendsRepository {
  @override
  Future<List<TrendPoint>> scorecards([
    TrendQuery query = const TrendQuery(),
  ]) async => throw Exception('boom');

  @override
  Future<List<TrendPoint>> availability([
    TrendQuery query = const TrendQuery(),
  ]) async => throw Exception('boom');

  @override
  Future<List<TrendPoint>> perfectStore([
    TrendQuery query = const TrendQuery(),
  ]) async => throw Exception('boom');

  @override
  Future<TerritoryBenchmarkReport> benchmark(
    BenchmarkMetric metric, [
    TrendQuery query = const TrendQuery(),
  ]) async => throw Exception('boom');
}

Widget _app(TrendsRepository repo, {ThemeData? theme}) => routedApp(
  const TrendsScreen(),
  theme: theme,
  overrides: [trendsRepositoryProvider.overrideWithValue(repo)],
);

/// The body is a lazy [ListView]; at the default 800×600 surface the third
/// panel is never built. Drive it at a viewport tall enough to hold all three.
Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'light: both switches ride a glass pill; table figures are mono',
    (tester) async {
      await _pump(
        tester,
        _app(_FakeTrendsRepository(), theme: AppTheme.light()),
      );

      // The selected segment is lifted onto a pill; the rest are bare words.
      GlassPane? pillIn(Finder segment) {
        final f = find.descendant(
          of: segment,
          matching: find.byType(GlassPane),
        );
        return f.evaluate().isEmpty ? null : tester.widget<GlassPane>(f);
      }

      expect(
        pillIn(find.byKey(const ValueKey('interval-week')))?.kind,
        GlassKind.pill,
      );
      expect(pillIn(find.byKey(const ValueKey('interval-day'))), isNull);

      final scorecards = find.byKey(const ValueKey('trend-scorecards'));
      Finder inPanel(Finder f) => find.descendant(of: scorecards, matching: f);
      expect(
        pillIn(inPanel(find.byKey(const ValueKey('view-chart'))))?.kind,
        GlassKind.pill,
      );

      await tester.tap(inPanel(find.byKey(const ValueKey('view-table'))));
      await tester.pumpAndSettle();
      expect(
        pillIn(inPanel(find.byKey(const ValueKey('view-table'))))?.kind,
        GlassKind.pill,
      );
      expect(pillIn(inPanel(find.byKey(const ValueKey('view-chart')))), isNull);

      expect(
        tester.widget<Text>(inPanel(find.text('80'))).style!.fontFamily,
        LumenGlass.mono,
      );
    },
  );

  testWidgets('renders the three trend sections as charts', (tester) async {
    await _pump(tester, _app(_FakeTrendsRepository()));

    expect(find.text('Scorecard trend'), findsOneWidget);
    expect(find.text('Availability trend'), findsOneWidget);
    expect(find.text('Perfect store trend'), findsOneWidget);

    expect(find.byType(ColumnChart), findsNWidgets(3));
  });

  testWidgets('every chart has a table-view twin holding the exact figures', (
    tester,
  ) async {
    // A chart must never be the only way to read a value — the table is the
    // WCAG-clean equivalent, and it carries the unabbreviated period.
    await _pump(tester, _app(_FakeTrendsRepository()));

    // Chart view abbreviates the axis tick to "W26"; the full period lives in
    // the table.
    expect(find.text('2026-W26'), findsNothing);

    for (final section in const [
      'trend-scorecards',
      'trend-availability',
      'trend-perfect-store',
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(section)),
          matching: find.byKey(const ValueKey('view-table')),
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('2026-W26'), findsNWidgets(3));
    // The scorecard trend is a score (no unit); availability and perfect-store
    // are rates, so they carry the % — the table says which is which.
    expect(find.text('80'), findsOneWidget);
    expect(find.text('80%'), findsNWidgets(2));
  });

  testWidgets('shows a failure message when a trend fails to load', (
    tester,
  ) async {
    await _pump(tester, _app(_ThrowingTrendsRepository()));

    expect(find.textContaining('Failed to load'), findsWidgets);
  });

  testWidgets('defaults to weekly buckets and the server default window', (
    tester,
  ) async {
    final repo = _FakeTrendsRepository();
    await _pump(tester, _app(repo));

    expect(repo.queries.first.interval, TrendInterval.week);
    // Null is not "all time" — it is the server's own lookback. The control must
    // not claim a range we never asked for.
    expect(repo.queries.first.from, isNull);
    expect(repo.queries.first.to, isNull);
    expect(find.text('Server default'), findsOneWidget);
  });

  testWidgets('switching to daily re-queries with interval=day', (
    tester,
  ) async {
    final repo = _FakeTrendsRepository();
    await _pump(tester, _app(repo));

    await tester.tap(find.byKey(const ValueKey('interval-day')));
    await tester.pumpAndSettle();

    // One filter row scopes every panel, so the new interval has to reach the
    // API — not just repaint the segment.
    expect(repo.queries.last.interval, TrendInterval.day);
  });
}
