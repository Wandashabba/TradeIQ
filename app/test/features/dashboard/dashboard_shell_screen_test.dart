import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis() async => const DashboardKpis(
        numericDistribution: 72.5,
        weightedDistribution: 81.3,
        osaPct: 93.1,
        executionScore: 67.8,
        priceCompliancePct: 88.0,
        visibilityCompliancePct: 76.4,
        shareOfShelf: 41.2,
        perfectStoreRate: 55.6,
      );
}

class _ThrowingDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis() async => throw Exception('network down');
}

Widget _app(DashboardRepository repo) => ProviderScope(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DashboardShellScreen()),
    );

void main() {
  testWidgets('renders all 8 KPI labels with their values once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeDashboardRepository()));
    await tester.pumpAndSettle();

    const expected = {
      'Numeric Distribution': '72.5%',
      'Weighted Distribution': '81.3%',
      'OSA %': '93.1%',
      // Execution Score is a score, not a rate — rendered without a % suffix.
      'Execution Score': '67.8',
      'Price Compliance %': '88.0%',
      'Visibility Compliance %': '76.4%',
      'Share of Shelf': '41.2%',
      'Perfect Store Rate': '55.6%',
    };
    expected.forEach((label, value) {
      expect(find.text(label), findsOneWidget);
      expect(find.text(value), findsOneWidget);
    });
  });

  testWidgets('shows the error state with a Retry button when the fetch fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingDashboardRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load KPIs:'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(_app(_FakeDashboardRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(DashboardShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });
}
