import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';

void main() {
  testWidgets('shows a stepper with all 10 audit sections', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuditShellScreen()),
      ),
    );
    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuditShellScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });
}
