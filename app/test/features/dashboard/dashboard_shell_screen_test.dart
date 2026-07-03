import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

void main() {
  testWidgets('renders all 8 KPI tile labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardShellScreen()));
    const labels = [
      'Numeric Distribution',
      'Weighted Distribution',
      'OSA %',
      'Execution Score',
      'Price Compliance %',
      'Visibility Compliance %',
      'Share of Shelf',
      'Perfect Store Rate',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
