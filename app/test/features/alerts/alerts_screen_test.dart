import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';

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

Widget _app(AlertsRepository repo) => ProviderScope(
      overrides: [
        alertsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: AlertsScreen()),
    );

void main() {
  testWidgets('renders alert messages once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('SKU 42 out of stock'), findsOneWidget);
    expect(find.text('Shelf price mismatch'), findsOneWidget);
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
