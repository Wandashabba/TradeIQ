import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

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

Widget _app(TrendsRepository repo) => ProviderScope(
      overrides: [
        trendsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TrendsScreen()),
    );

void main() {
  testWidgets('renders section headings and trend point data', (tester) async {
    await tester.pumpWidget(_app(_FakeTrendsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Scorecard trend'), findsOneWidget);
    expect(find.text('Availability trend'), findsOneWidget);
    expect(find.text('Perfect store trend'), findsOneWidget);

    // Each of the three sections renders both period labels and values.
    expect(find.text('2026-W26'), findsNWidgets(3));
    expect(find.text('80'), findsNWidgets(3));
  });

  testWidgets('shows a failure message when a trend fails to load',
      (tester) async {
    await tester.pumpWidget(_app(_ThrowingTrendsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load'), findsWidgets);
  });
}
