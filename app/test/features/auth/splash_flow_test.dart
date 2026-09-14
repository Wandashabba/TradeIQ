import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/app_router.dart';

/// A session controller pinned to a known state, so tests control the
/// max(5s, restore) race deterministically.
class _FixedSession extends SessionController {
  _FixedSession(this._state);
  final SessionState _state;
  @override
  Future<SessionState> build() async => _state;
}

/// A session controller that never resolves — restore still pending.
class _HangingSession extends SessionController {
  @override
  Future<SessionState> build() => Completer<SessionState>().future;
}

Widget _app(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: Consumer(
    builder: (context, ref, _) {
      return MaterialApp.router(routerConfig: ref.watch(routerProvider));
    },
  ),
);

// NOTE on asserted strings: 'Sign in' appears TWICE on the login screen
// (headline + submit button), so the login marker here is its stable unique
// string, 'Forgot password?' — the same marker the router tests use.
// 'Execution overview' is the dashboard's AppBar title.
void main() {
  testWidgets('holds for 5 seconds, then advances to sign-in when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        sessionControllerProvider.overrideWith(
          () => _FixedSession(const SessionState()),
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Forgot password?'), findsNothing); // still on splash

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Forgot password?'), findsNothing); // 4.1s — still holding

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget); // past 5s — advanced
  });

  testWidgets('tap anywhere skips the hold immediately', (tester) async {
    await tester.pumpWidget(
      _app([
        sessionControllerProvider.overrideWith(
          () => _FixedSession(const SessionState()),
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('a restored manager session lands on the dashboard, not sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        sessionControllerProvider.overrideWith(
          () => _FixedSession(const SessionState(role: 'manager', token: 't')),
        ),
        // Dashboard pulls live data; that is fine — AsyncSection shows loaders.
      ]),
    );
    // The brand hold applies to authed users too. Two checkpoints INSIDE the
    // 5s window prove the splash is holding rather than the router having
    // bounced straight to the dashboard (a mutation-probe review found the
    // suite couldn't tell those apart; a single early checkpoint was still
    // too weak because the router's post-restore refresh needs extra frames).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TRADEIQ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(
      find.text('Execution overview'),
      findsNothing,
      reason: 'dashboard must not appear during the 5s brand hold',
    );
    expect(
      find.text('TRADEIQ'),
      findsOneWidget,
      reason: 'the splash must still be holding at ~2s',
    );
    await tester.pump(const Duration(seconds: 6));
    // Settle, don't single-pump: the dashboard's KPI fetch (unstubbed here)
    // schedules timers that must flush before teardown; it settles into the
    // error state, exactly as the router tests do.
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.text('Execution overview'), findsOneWidget);
  });

  testWidgets(
    'never advances before restore resolves, even after 5s and a tap',
    (tester) async {
      await tester.pumpWidget(
        _app([sessionControllerProvider.overrideWith(_HangingSession.new)]),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(seconds: 2));
      // Restore never resolved → still on the splash, no navigation.
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Execution overview'), findsNothing);
    },
  );
}
