import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alert_rules_screen.dart';

import '../../helpers/routed_app.dart';

// Newest first, as GET /alerts/rules returns them.
const _oos = AlertRule(
  id: 'r-oos',
  name: 'Out of stock',
  metric: 'out_of_stock',
  severity: 'critical',
  active: true,
);

const _price = AlertRule(
  id: 'r-price',
  name: 'Price deviation',
  metric: 'price_deviation',
  severity: 'warning',
  active: true,
  threshold: 10,
);

const _paused = AlertRule(
  id: 'r-score',
  name: 'Low scorecard',
  metric: 'low_scorecard',
  severity: 'normal',
  active: false,
  threshold: 60,
);

class _FakeAlertRulesRepository implements AlertRulesRepository {
  _FakeAlertRulesRepository([this.rules = const [_oos, _price, _paused]]);

  final List<AlertRule> rules;

  ({String name, String metric, double? threshold, String? severity})? created;
  ({String id, bool? active, double? threshold, String? severity})? updated;

  @override
  Future<List<AlertRule>> listRules() async => rules;

  @override
  Future<AlertRule> createRule({
    required String name,
    required String metric,
    double? threshold,
    String? severity,
  }) async {
    created = (
      name: name,
      metric: metric,
      threshold: threshold,
      severity: severity,
    );
    return AlertRule(
      id: 'r-new',
      name: name,
      metric: metric,
      severity: severity ?? 'normal',
      active: true,
      threshold: threshold,
    );
  }

  @override
  Future<AlertRule> updateRule(
    String id, {
    bool? active,
    double? threshold,
    String? severity,
  }) async {
    updated = (
      id: id,
      active: active,
      threshold: threshold,
      severity: severity,
    );
    final existing = rules.firstWhere((r) => r.id == id);
    return AlertRule(
      id: id,
      name: existing.name,
      metric: existing.metric,
      severity: severity ?? existing.severity,
      active: active ?? existing.active,
      threshold: threshold ?? existing.threshold,
    );
  }
}

class _ThrowingAlertRulesRepository implements AlertRulesRepository {
  @override
  Future<List<AlertRule>> listRules() async => throw Exception('boom');

  @override
  Future<AlertRule> createRule({
    required String name,
    required String metric,
    double? threshold,
    String? severity,
  }) async =>
      throw Exception('boom');

  @override
  Future<AlertRule> updateRule(
    String id, {
    bool? active,
    double? threshold,
    String? severity,
  }) async =>
      throw Exception('boom');
}

Widget _app(AlertRulesRepository repo, {ThemeData? theme}) => routedApp(
      const AlertRulesScreen(),
      theme: theme,
      overrides: [
        alertRulesRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertRulesRepository(), theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertRulesScreen), findsOneWidget);
  });

  testWidgets('lists every rule, active and paused alike', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertRulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('Price deviation'), findsOneWidget);
    // A paused rule is still config — it stays on the page, dimmed, not hidden.
    expect(find.text('Low scorecard'), findsOneWidget);
  });

  testWidgets('state is a word, not just a colour', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertRulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsNWidgets(2));
    expect(find.text('INACTIVE'), findsOneWidget);
  });

  testWidgets('a rule shows its metric, severity and threshold', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertRulesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('price_deviation'), findsOneWidget);
    expect(find.text('Severity warning'), findsOneWidget);
    // Whole thresholds read as integers, and a rule without one says nothing
    // rather than inventing a zero.
    expect(find.text('Threshold 10'), findsOneWidget);
    expect(find.textContaining('Threshold', findRichText: true), findsNWidgets(2));
  });

  testWidgets('the metric filter narrows the list', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertRulesRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('filter-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price deviation').last);
    await tester.pumpAndSettle();

    expect(find.text('Price deviation'), findsWidgets);
    expect(find.text('Out of stock'), findsNothing);
  });

  testWidgets('toggling a rule off patches active: false with its id', (
    tester,
  ) async {
    final repo = _FakeAlertRulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('toggle-r-oos')));
    await tester.pumpAndSettle();

    expect(repo.updated?.id, 'r-oos');
    expect(repo.updated?.active, false);
  });

  testWidgets('toggling a paused rule back on patches active: true', (
    tester,
  ) async {
    final repo = _FakeAlertRulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('toggle-r-score')));
    await tester.pumpAndSettle();

    expect(repo.updated?.id, 'r-score');
    expect(repo.updated?.active, true);
  });

  testWidgets('creating a rule sends the name, metric, severity and threshold',
      (tester) async {
    final repo = _FakeAlertRulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('new-rule-name')),
      'Shelf gaps',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-rule-threshold')),
      '15',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-rule')));
    await tester.pumpAndSettle();

    expect(repo.created?.name, 'Shelf gaps');
    // The dialog defaults to the first metric in the backend's allow-list.
    expect(repo.created?.metric, 'out_of_stock');
    expect(repo.created?.threshold, 15);
    expect(repo.created?.severity, 'normal');
  });

  testWidgets('a rule cannot be created without a name', (tester) async {
    final repo = _FakeAlertRulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('create-rule')));
    await tester.pumpAndSettle();

    // The API 400s on an empty name; the dialog says so rather than round-trip.
    expect(repo.created, isNull);
    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('a non-numeric threshold is refused before the request', (
    tester,
  ) async {
    final repo = _FakeAlertRulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('add-rule')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-rule-name')),
      'Bad threshold',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('new-rule-threshold')),
      'ten',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-rule')));
    await tester.pumpAndSettle();

    expect(repo.created, isNull);
    expect(find.text('Threshold must be a number'), findsOneWidget);
  });

  testWidgets('editing a rule patches its threshold and severity', (
    tester,
  ) async {
    final repo = _FakeAlertRulesRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('edit-r-price')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('edit-rule-threshold')),
      '25',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-rule')));
    await tester.pumpAndSettle();

    expect(repo.updated?.id, 'r-price');
    expect(repo.updated?.threshold, 25);
    // Severity always rides along, so the PATCH is never an empty body.
    expect(repo.updated?.severity, 'warning');
    expect(repo.updated?.active, isNull);
  });

  testWidgets('a second active rule on a metric is called out as shadowed', (
    tester,
  ) async {
    // The evaluator only honours the newest active rule per metric. A manager
    // who adds a second one must be told it will never fire.
    const newer = AlertRule(
      id: 'r-oos-new',
      name: 'Out of stock (strict)',
      metric: 'out_of_stock',
      severity: 'critical',
      active: true,
    );
    final repo = _FakeAlertRulesRepository(const [newer, _oos, _paused]);

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Shadowed by a newer active rule'), findsOneWidget);
  });

  testWidgets('says so when there is nothing configured yet', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertRulesRepository(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No rules configured'), findsOneWidget);
  });

  testWidgets('shows an error message when the list fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ThrowingAlertRulesRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load alert rules'), findsOneWidget);
  });
}
