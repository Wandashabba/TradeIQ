import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';

import '../../helpers/routed_app.dart';

const _unacknowledged = AlertItem(
  id: 'a-open',
  metric: 'stock',
  message: 'SKU 42 out of stock',
  severity: 'critical',
  acknowledged: false,
  outletId: 'o1',
);

const _acknowledged = AlertItem(
  id: 'a-done',
  metric: 'price',
  message: 'Shelf price mismatch',
  severity: 'warning',
  acknowledged: true,
  outletId: 'o2',
);

class _FakeAlertsRepository implements AlertsRepository {
  String? acknowledgedId;

  @override
  Future<List<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async =>
      const [_unacknowledged, _acknowledged];

  @override
  Future<AlertItem> acknowledge(String id) async {
    acknowledgedId = id;
    return AlertItem(
      id: id,
      metric: _unacknowledged.metric,
      message: _unacknowledged.message,
      severity: _unacknowledged.severity,
      acknowledged: true,
      outletId: _unacknowledged.outletId,
    );
  }
}

class _ThrowingAlertsRepository implements AlertsRepository {
  @override
  Future<List<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async =>
      throw Exception('boom');

  @override
  Future<AlertItem> acknowledge(String id) async =>
      throw Exception('boom');
}

Widget _app(AlertsRepository repo, {ThemeData? theme}) => routedApp(
      const AlertsScreen(),
      theme: theme,
      overrides: [
        alertsRepositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  testWidgets('renders under the light theme', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository(), theme: AppTheme.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertsScreen), findsOneWidget);
  });

  testWidgets('opens on the triage list — what is still open', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    // The worklist defaults to Open: a manager lands on what still needs doing,
    // not on a mixed pile. The acknowledged alert is one tab away, not gone.
    expect(find.text('SKU 42 out of stock'), findsOneWidget);
    expect(find.text('Shelf price mismatch'), findsNothing);
  });

  testWidgets('the All tab reveals acknowledged alerts', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
    await tester.pumpAndSettle();

    expect(find.text('SKU 42 out of stock'), findsOneWidget);
    expect(find.text('Shelf price mismatch'), findsOneWidget);
  });

  testWidgets('triage counts summarise the list before you read it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('triage-critical')), findsOneWidget);
    expect(find.byKey(const ValueKey('triage-warning')), findsOneWidget);
    expect(find.byKey(const ValueKey('triage-acknowledged')), findsOneWidget);
  });

  testWidgets('an acknowledged alert offers no Acknowledge action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ack-a-open')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ack-a-done')), findsNothing);
  });

  testWidgets('acknowledging an open alert calls acknowledge with its id',
      (tester) async {
    final repo = _FakeAlertsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ack-a-open')));
    await tester.pumpAndSettle();

    expect(repo.acknowledgedId, 'a-open');
  });

  testWidgets('shows an error message when the list fails to load',
      (tester) async {
    await tester.pumpWidget(_app(_ThrowingAlertsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load alerts'), findsOneWidget);
  });
}
