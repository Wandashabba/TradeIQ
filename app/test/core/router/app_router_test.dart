import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/app_router.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

Widget _appWithOverrides(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider)),
    ),
  );
}

void main() {
  testWidgets('unauthenticated root route shows the login screen', (tester) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();
    expect(find.text('TradeIQ Login'), findsOneWidget);
  });

  testWidgets('unauthenticated request for /dashboard redirects to login', (tester) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();

    expect(find.text('TradeIQ Login'), findsOneWidget);
  });

  testWidgets('authenticated field_agent starting at /login lands on /audit', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'field_agent')),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('S1 Outlet Information'), findsOneWidget);
  });

  testWidgets('authenticated manager starting at /login lands on /dashboard', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Numeric Distribution'), findsOneWidget);
  });

  testWidgets('logging out from a protected route redirects back to login', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Numeric Distribution'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('TradeIQ Login'), findsOneWidget);
  });
}
