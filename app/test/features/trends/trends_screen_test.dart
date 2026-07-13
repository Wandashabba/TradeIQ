import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

import '../../helpers/routed_app.dart';

const _points = <TrendPoint>[
  TrendPoint(period: '2026-W26', value: 40),
  TrendPoint(period: '2026-W27', value: 80),
];

class _FakeTrendsRepository implements TrendsRepository {
  @override
  Future<List<TrendPoint>> scorecards() async => _points;

  @override
  Future<List<TrendPoint>> availability() async => _points;

  @override
  Future<List<TrendPoint>> perfectStore() async => _points;
}

class _ThrowingTrendsRepository implements TrendsRepository {
  @override
  Future<List<TrendPoint>> scorecards() async => throw Exception('boom');

  @override
  Future<List<TrendPoint>> availability() async => throw Exception('boom');

  @override
  Future<List<TrendPoint>> perfectStore() async => throw Exception('boom');
}

Widget _app(TrendsRepository repo) => routedApp(
      const TrendsScreen(),
      overrides: [
        trendsRepositoryProvider.overrideWithValue(repo),
      ],
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

  testWidgets('shows a failure message when a trend fails to load',
      (tester) async {
    await _pump(tester, _app(_ThrowingTrendsRepository()));

    expect(find.textContaining('Failed to load'), findsWidgets);
  });
}
