import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_ended.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/auth/presentation/landing_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';

import '../../core/design/amber_golden.dart';
import 'entry_harness.dart';

/// THE AMBER CENSUS FOR THE WAY IN — every route × every phase × every skin,
/// counted from pixels.
///
/// `TorchScope` asserts what a route *claims*. This counts what got
/// *painted*, which is the failure a claim cannot see: a brand mark that lit
/// itself, a bloom where no object was declared, a video frame that happened
/// to contain a shop light.
///
/// | route | phase | Night | Day | Veld |
/// |---|---|---|---|---|
/// | splash | holding | 0 | 0 | 0 |
/// | sign-in | blocked (empty form) | 0 | 0 | 0 |
/// | sign-in | blocked (email only) | 0 | 0 | 0 |
/// | sign-in | armed | 1 | 1 | 1 |
/// | sign-in | sending | 0 | 0 | 0 |
/// | sign-in | error, fields still filled | 1 | 1 | 1 |
/// | route beneath the session-ended sheet | 0 | 0 | 0 |
///
/// Neither route has a nav, so Night's slot 1 is never spent on chrome and
/// its budget of two is never approached. **One object can be lit here at
/// all** — the sign-in button — and only while it is armed.
///
/// Two rows are worth reading twice because they are the ones a designer
/// would guess wrong:
///
/// * **Sending is dark.** A busy primary declares nothing, which is the
///   convention the account screens landed with (#400): while the request is
///   in flight there is nothing left to commit, and the busy dots are what
///   carry the state. The light comes back if the request fails.
/// * **A refusal is lit, not dark.** The two fields are still filled, so the
///   form is still armed and the one thing to do on the screen is press it
///   again with a different password. A refusal that also put the button out
///   would leave a screen with an error on it and no lit way forward.
void main() {
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  Future<void> expectCount(
    WidgetTester tester,
    SkinMode mode, {
    required String route,
    required String phase,
    required int expected,
  }) async {
    final skin = entrySkinFor(mode);
    final scope = tester.widget<TorchScope>(find.byType(TorchScope).first);
    expect(scope.phase, phase, reason: '$route declared the wrong phase');
    final census = await amberCensus(tester);
    expectWithinAmberBudget(census, skin, route: route, phase: phase);
    expect(
      census.objectCount,
      expected,
      reason: '${mode.name} × $route × $phase\n${census.describe()}',
    );
  }

  for (final mode in entrySkinModes) {
    group(mode.name, () {
      testWidgets('splash: nothing is armed, so nothing is lit', (
        tester,
      ) async {
        await pumpEntryScreen(
          tester,
          const LandingScreen(),
          path: '/',
          settle: false,
          overrides: entryBaseOverrides(db: entryTestDb(), skin: mode),
        );
        await expectCount(
          tester,
          mode,
          route: 'splash',
          phase: 'holding',
          expected: 0,
        );
      });

      testWidgets('sign-in, empty: the brand is a word, and a word is unlit', (
        tester,
      ) async {
        await _pumpSignIn(tester, mode);
        await expectCount(
          tester,
          mode,
          route: 'sign-in',
          phase: 'blocked',
          expected: 0,
        );
      });

      testWidgets('sign-in, half-filled: still nothing to commit', (
        tester,
      ) async {
        await _pumpSignIn(tester, mode);
        await scrollEntryTo(tester, key('login-email'));
        await tester.enterText(key('login-email'), 'agent@example.com');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await expectCount(
          tester,
          mode,
          route: 'sign-in',
          phase: 'blocked',
          expected: 0,
        );
      });

      testWidgets('sign-in, armed: exactly one — the sign-in button', (
        tester,
      ) async {
        await _pumpSignIn(tester, mode);
        await _fill(tester);
        await expectCount(
          tester,
          mode,
          route: 'sign-in',
          phase: 'armed',
          expected: 1,
        );
      });

      testWidgets('sign-in, sending: the same one, busy', (tester) async {
        await _pumpSignIn(tester, mode, auth: _SlowAuth());
        await _fill(tester);
        await tester.tap(key('login-submit'));
        await tester.pump();
        await expectCount(
          tester,
          mode,
          route: 'sign-in',
          phase: 'sending',
          expected: 0,
        );
        await tester.pumpAndSettle();
      });

      testWidgets('sign-in, refused: still armed, still exactly one', (
        tester,
      ) async {
        await _pumpSignIn(tester, mode, auth: _Refusing());
        await _fill(tester);
        await tester.tap(key('login-submit'));
        await tester.pumpAndSettle();
        await expectCount(
          tester,
          mode,
          route: 'sign-in',
          phase: 'error',
          expected: 1,
        );
      });

      testWidgets('beneath the session-ended sheet, everything is out', (
        tester,
      ) async {
        await _pumpSignIn(
          tester,
          mode,
          sessionEnded: const SessionEnded(
            lines: <HeldLine>[HeldLine(entityType: 'photo', count: 3)],
          ),
        );
        await tester.pumpAndSettle();

        // The whole frame still holds one lit object — the sheet's own
        // "Sign in to send them" — and never two.
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          entrySkinFor(mode),
          route: 'sign-in',
          phase: 'session-ended',
        );
        expect(census.objectCount, 1, reason: census.describe());

        if (mode == SkinMode.veld) {
          // Veld has no sheets and no scrims (unify §1.10): this is a
          // full-screen route, the sign-in form is not rendered behind it,
          // and there is nothing beneath to extinguish.
          expect(find.byType(LoginScreen), findsNothing);
        } else {
          // Night and Day: the route beneath declares nothing while a sheet
          // is up, so the sheet genuinely owns the screen at 72% rather than
          // at 88%.
          final scope = tester.widget<TorchScope>(
            find.byType(TorchScope).first,
          );
          expect(scope.beneathSheet, isTrue);
          expect(scope.allocation.granted, isEmpty);
        }
      });
    });
  }
}

class _SlowAuth implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return const AuthResult(token: 't', role: 'manager');
  }
}

class _Refusing implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    final options = RequestOptions(path: '/auth/login');
    throw DioException(
      requestOptions: options,
      response: Response<void>(requestOptions: options, statusCode: 401),
    );
  }
}

class _OkAuth implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async =>
      const AuthResult(token: 't', role: 'manager');
}

Future<void> _pumpSignIn(
  WidgetTester tester,
  SkinMode mode, {
  AuthRepository? auth,
  SessionEnded? sessionEnded,
}) => pumpEntryScreen(
  tester,
  const LoginScreen(),
  path: '/login',
  overrides: entryBaseOverrides(
    db: entryTestDb(),
    skin: mode,
    auth: auth ?? _OkAuth(),
    sessionEnded: sessionEnded,
  ),
);

Future<void> _fill(WidgetTester tester) async {
  Finder key(String k) => find.byKey(ValueKey<String>(k));
  await scrollEntryTo(tester, key('login-email'));
  await tester.enterText(key('login-email'), 'agent@example.com');
  await tester.pump();
  await scrollEntryTo(tester, key('login-password'));
  await tester.enterText(key('login-password'), 'blue truck monday');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  // Back to the top, so the census measures the frame a person arrives at
  // rather than one scrolled halfway down a form.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
  await tester.pumpAndSettle();
}
