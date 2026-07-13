import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/incentives/data/incentives_repository.dart';
import 'package:tradeiq_app/features/incentives/presentation/incentives_screen.dart';

import '../../helpers/routed_app.dart';

const _schemeA = IncentiveScheme(
  id: 's-a',
  name: 'Top Scorecard',
  metric: 'scorecard',
  threshold: 80,
  rewardPoints: 100,
  active: true,
);

const _schemeB = IncentiveScheme(
  id: 's-b',
  name: 'Visits Drive',
  metric: 'visits',
  threshold: 20,
  rewardPoints: 50,
  active: true,
);

class _FakeIncentivesRepository implements IncentivesRepository {
  String? deletedId;
  String? createdName;
  String? createdMetric;
  double? createdThreshold;
  int? createdRewardPoints;

  @override
  Future<List<IncentiveScheme>> listSchemes() async => const [_schemeA, _schemeB];

  @override
  Future<IncentiveScheme> createScheme({
    required String name,
    required String metric,
    required double threshold,
    required int rewardPoints,
  }) async {
    createdName = name;
    createdMetric = metric;
    createdThreshold = threshold;
    createdRewardPoints = rewardPoints;
    return IncentiveScheme(
      id: 's-new',
      name: name,
      metric: metric,
      threshold: threshold,
      rewardPoints: rewardPoints,
      active: true,
    );
  }

  @override
  Future<void> deleteScheme(String id) async {
    deletedId = id;
  }

  @override
  Future<List<EarnedIncentive>> earned() async => const [];

  String? toggledId;
  bool? toggledValue;

  @override
  Future<IncentiveScheme> setActive(String id, bool active) async {
    toggledId = id;
    toggledValue = active;
    return _schemeA;
  }
}

class _ThrowingIncentivesRepository implements IncentivesRepository {
  @override
  Future<List<IncentiveScheme>> listSchemes() async => throw Exception('boom');

  @override
  Future<IncentiveScheme> createScheme({
    required String name,
    required String metric,
    required double threshold,
    required int rewardPoints,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteScheme(String id) async => throw UnimplementedError();

  @override
  Future<List<EarnedIncentive>> earned() async => throw UnimplementedError();

  @override
  Future<IncentiveScheme> setActive(String id, bool active) async =>
      throw UnimplementedError();
}

Widget _app(IncentivesRepository repo) => routedApp(
      const IncentivesScreen(),
      overrides: [
        incentivesRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders scheme names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeIncentivesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Top Scorecard'), findsOneWidget);
    expect(find.text('Visits Drive'), findsOneWidget);
  });

  testWidgets('tapping delete records deleteScheme', (tester) async {
    final repo = _FakeIncentivesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-s-a')));
    await tester.pumpAndSettle();

    expect(repo.deletedId, 's-a');
  });

  testWidgets('creating a scheme records the entered args', (tester) async {
    final repo = _FakeIncentivesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('new-name')),
      'Tasks Blitz',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-threshold')),
      '15',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-reward-points')),
      '75',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-scheme')));
    await tester.pumpAndSettle();

    expect(repo.createdName, 'Tasks Blitz');
    expect(repo.createdMetric, 'scorecard');
    expect(repo.createdThreshold, 15.0);
    expect(repo.createdRewardPoints, 75);
  });

  testWidgets('toggling active calls setActive', (tester) async {
    final repo = _FakeIncentivesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // _schemeA starts active; toggling turns it off.
    await tester.tap(find.byKey(const ValueKey<String>('toggle-s-a')));
    await tester.pumpAndSettle();

    expect(repo.toggledId, 's-a');
    expect(repo.toggledValue, false);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingIncentivesRepository()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to load incentives'),
      findsOneWidget,
    );
  });
}
