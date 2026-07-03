import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';

void main() {
  testWidgets('shows a stepper with all 10 audit sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuditShellScreen()));
    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });
}
