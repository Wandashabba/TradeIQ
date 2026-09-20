import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_ended.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';

import 'entry_harness.dart';

/// The sign-in screen on Torchlight.
///
/// Everything the Lumen screen could do, it still does: the email is trimmed
/// and lowercased and the password is not, the box is ticked by default,
/// Forgot password carries the typed address with it, and a 401 says one
/// sentence that does not reveal whether the account exists. What changed is
/// where the refusals live — under the button rather than under the fields —
/// and that is asserted here rather than dropped.

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    // A small delay so the busy state is observable: under the fake clock a
    // repository that resolved on microtasks alone would be fully drained by
    // `await tester.tap(...)` before the assertion ran.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

/// Captures exactly what the screen handed the repository, so a test can pin
/// the credentials that actually go on the wire (#351).
class RecordingAuthRepository implements AuthRepository {
  String? email;
  String? password;

  @override
  Future<AuthResult> login(String email, String password) async {
    this.email = email;
    this.password = password;
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

class _FailingAuthRepository implements AuthRepository {
  _FailingAuthRepository(this.error);

  final Object error;

  @override
  Future<AuthResult> login(String email, String password) async => throw error;
}

DioException _status(int code) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    response: Response<void>(requestOptions: options, statusCode: code),
  );
}

final _offline = DioException(
  requestOptions: RequestOptions(path: '/auth/login'),
  type: DioExceptionType.connectionError,
);

Finder _key(String k) => find.byKey(ValueKey<String>(k));

Future<void> _pump(
  WidgetTester tester, {
  AuthRepository? auth,
  SkinMode skin = SkinMode.night,
  SessionEnded? sessionEnded,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) => pumpEntryScreen(
  tester,
  const LoginScreen(),
  path: '/login',
  textScale: textScale,
  locale: locale,
  overrides: <Override>[
    ...entryBaseOverrides(
      db: entryTestDb(),
      skin: skin,
      auth: auth ?? FakeAuthRepository(),
      sessionEnded: sessionEnded,
    ),
  ],
  extraRoutes: <GoRoute>[
    namedRoute('/', 'SPLASH'),
    namedRoute('/forgot-password', 'FORGOT SCREEN'),
    namedRoute('/dashboard', 'DASHBOARD'),
  ],
);

Future<void> _fill(
  WidgetTester tester, {
  String email = 'manager@tradeiq.com',
  String password = 'password123',
}) async {
  await scrollEntryTo(tester, _key('login-email'));
  await tester.enterText(_key('login-email'), email);
  await tester.pump();
  await scrollEntryTo(tester, _key('login-password'));
  await tester.enterText(_key('login-password'), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

TorchPrimaryButton _primary(WidgetTester tester) =>
    tester.widget<TorchPrimaryButton>(_key('login-submit'));

void main() {
  group('the form refuses, and says what is missing', () {
    testWidgets('an empty form cannot be submitted, and names the email', (
      tester,
    ) async {
      await _pump(tester);

      expect(_primary(tester).onPressed, isNull);
      expect(_primary(tester).blockedReason, 'Email is required');
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('an email with no password names the password', (tester) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-email'));
      await tester.enterText(_key('login-email'), 'manager@tradeiq.com');
      await tester.pumpAndSettle();

      expect(_primary(tester).onPressed, isNull);
      expect(_primary(tester).blockedReason, 'Password is required');
    });

    testWidgets('both fields filled arms the button and clears the note', (
      tester,
    ) async {
      await _pump(tester);
      await _fill(tester);

      expect(_primary(tester).onPressed, isNotNull);
      expect(_primary(tester).blockedReason, isNull);
      expect(find.text('Email is required'), findsNothing);
    });
  });

  testWidgets('submitting turns the primary busy', (tester) async {
    await _pump(tester);
    await _fill(tester);
    await tester.tap(_key('login-submit'));
    await tester.pump();

    expect(_primary(tester).busy, isTrue);
    await tester.pumpAndSettle();
  });

  group('a refusal never says whether the account exists', () {
    testWidgets('a 401 is one sentence, inline, with no Retry', (tester) async {
      await _pump(tester, auth: _FailingAuthRepository(_status(401)));
      await _fill(tester, password: 'wrong-password');
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      final state = tester.widget<ErrorState>(_key('login-error'));
      expect(state.scope, ErrorScope.inline);
      expect(state.message.kind, TorchErrorKind.rejected);
      expect(state.message.offersRetry, isFalse);
      expect(find.text('We could not sign you in'), findsOneWidget);
      expect(find.text('Invalid credentials'), findsOneWidget);
      // The body is the one sentence and nothing that would separate "no
      // such user" from "wrong password" — the whole reason this screen has
      // one message.
      expect(state.message.body, 'Invalid credentials');
      for (final tell in <String>[
        'no such',
        'not found',
        'does not exist',
        'unknown',
        'disabled',
        'locked',
      ]) {
        expect(
          find.textContaining(tell, skipOffstage: false),
          findsNothing,
          reason: 'a refusal that says "$tell" answers who works here',
        );
      }
    });

    testWidgets('an unknown address gets the SAME words as a wrong password', (
      tester,
    ) async {
      // The server answers both with a 401, and the screen must not add a
      // distinction the server deliberately did not make.
      await _pump(tester, auth: _FailingAuthRepository(_status(401)));
      await _fill(tester, email: 'nobody@example.com', password: 'anything');
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('no signal is a network failure and offers no Retry', (
      tester,
    ) async {
      await _pump(tester, auth: _FailingAuthRepository(_offline));
      await _fill(tester);
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      final state = tester.widget<ErrorState>(_key('login-error'));
      expect(state.message.kind, TorchErrorKind.network);
      expect(find.textContaining('Could not reach the server'), findsOneWidget);
      expect(find.text('Invalid credentials'), findsNothing);
    });

    testWidgets('a 429 says wait rather than "wrong password"', (tester) async {
      await _pump(tester, auth: _FailingAuthRepository(_status(429)));
      await _fill(tester);
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsNothing);
      expect(
        tester.widget<ErrorState>(_key('login-error')).message.offersRetry,
        isFalse,
      );
    });

    test('a 500 is a server failure, not a rejection', () {
      expect(loginErrorKind(_status(503)), TorchErrorKind.server);
    });
  });

  group('email normalisation (#351)', () {
    // The reported bug: an Android keyboard capitalised the first letter of
    // the address and the login failed on a correct password.
    testWidgets('sends a trimmed, lowercased email to the repository', (
      tester,
    ) async {
      final repository = RecordingAuthRepository();
      await _pump(tester, auth: repository);
      await _fill(tester, email: '  Agent@Demo-FMCG.TradeIQ.com  ');
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(repository.email, 'agent@demo-fmcg.tradeiq.com');
    });

    // A password is not an identifier: spaces in one may be deliberate, and
    // trimming would lock out whoever chose it.
    testWidgets('passes the password through untouched', (tester) async {
      final repository = RecordingAuthRepository();
      await _pump(tester, auth: repository);
      await _fill(tester, password: ' Pass Word 1 ');
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(repository.password, ' Pass Word 1 ');
    });

    // Normalising on submit fixes the symptom; this stops the keyboard from
    // producing the wrong thing in the first place.
    testWidgets('the email field does not auto-capitalise or autocorrect', (
      tester,
    ) async {
      await _pump(tester);
      final field = tester.widget<TorchTextField>(_key('login-email'));

      expect(field.textCapitalization, TextCapitalization.none);
      expect(field.autocorrect, isFalse);
      expect(field.keyboardType, TextInputType.emailAddress);
      expect(field.autofillHints, contains(AutofillHints.email));
    });
  });

  group('what the screen still does', () {
    testWidgets('remember me is ticked by default and can be untangled', (
      tester,
    ) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-remember-me'));
      expect(
        tester.widget<TorchCheckbox>(_key('login-remember-me')).value,
        isTrue,
        reason:
            'the session was persisted unconditionally before the box '
            'existed; an unticked default would silently make every field '
            'agent re-log in each morning',
      );

      await tester.tap(_key('login-remember-me'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TorchCheckbox>(_key('login-remember-me')).value,
        isFalse,
      );
    });

    testWidgets('remember me off keeps the session out of storage', (
      tester,
    ) async {
      final tokens = FakeTokenStore();
      await pumpEntryScreen(
        tester,
        const LoginScreen(),
        overrides: entryBaseOverrides(
          db: entryTestDb(),
          auth: RecordingAuthRepository(),
          tokens: tokens,
        ),
        extraRoutes: <GoRoute>[namedRoute('/dashboard', 'DASHBOARD')],
      );
      await _fill(tester);
      await scrollEntryTo(tester, _key('login-remember-me'));
      await tester.tap(_key('login-remember-me'));
      await tester.pumpAndSettle();
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(tokens.session, isNull);
    });

    testWidgets('the password is hidden until Show password is ticked', (
      tester,
    ) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-show-password'));
      expect(
        tester.widget<TorchTextField>(_key('login-password')).obscureText,
        isTrue,
      );

      await tester.tap(_key('login-show-password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TorchTextField>(_key('login-password')).obscureText,
        isFalse,
      );
    });

    testWidgets('Forgot password carries the typed address with it', (
      tester,
    ) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-email'));
      await tester.enterText(_key('login-email'), '  Agent@Example.com ');
      await tester.pumpAndSettle();
      await scrollEntryTo(tester, _key('login-forgot-password'));
      await tester.tap(_key('login-forgot-password'));
      await tester.pumpAndSettle();

      expect(find.text('FORGOT SCREEN'), findsOneWidget);
    });

    testWidgets('the back button names where it goes, and goes there', (
      tester,
    ) async {
      await _pump(tester);
      final back = tester.widget<TorchAppHeader>(find.byType(TorchAppHeader));
      expect(back.back!.semanticLabel, 'Back to welcome');

      await tester.tap(find.byWidget(back.back!));
      await tester.pumpAndSettle();
      expect(find.text('SPLASH'), findsOneWidget);
    });

    // #436: the kit once had every button announce itself and do nothing
    // when activated — a `Semantics(…, excludeSemantics: true)` around the
    // gesture. `tester.tap` sends a pointer and cannot see it. These fire the
    // action the PLATFORM fires, through the binding, and then assert the
    // thing that was supposed to happen actually happened.
    Future<void> activate(WidgetTester tester, Finder finder) async {
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: tester.getSemantics(finder).id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
    }

    testWidgets('a reader can press Show password and Remember me', (
      tester,
    ) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-show-password'));
      final handle = tester.ensureSemantics();

      await activate(tester, find.bySemanticsLabel('Show password').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TorchTextField>(_key('login-password')).obscureText,
        isFalse,
        reason: 'Show password announces itself and does nothing',
      );

      await scrollEntryTo(tester, _key('login-remember-me'));
      await activate(tester, find.bySemanticsLabel('Remember me').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TorchCheckbox>(_key('login-remember-me')).value,
        isFalse,
        reason: 'Remember me announces itself and does nothing',
      );
      handle.dispose();
    });

    testWidgets('a reader can press Sign in', (tester) async {
      await _pump(tester);
      await _fill(tester);
      final handle = tester.ensureSemantics();

      await activate(tester, find.bySemanticsLabel('Sign in').last);
      await tester.pump();
      expect(
        _primary(tester).busy,
        isTrue,
        reason: 'Sign in announces itself and does nothing',
      );
      handle.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('a reader can press Forgot password', (tester) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-forgot-password'));
      final handle = tester.ensureSemantics();

      await activate(tester, find.bySemanticsLabel('Forgot password?').first);
      await tester.pumpAndSettle();
      expect(find.text('FORGOT SCREEN'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a reader can press the back button', (tester) async {
      await _pump(tester);
      final handle = tester.ensureSemantics();

      await activate(tester, find.bySemanticsLabel('Back to welcome').first);
      await tester.pumpAndSettle();
      expect(find.text('SPLASH'), findsOneWidget);
      handle.dispose();
    });
  });

  group('signed out with work on the phone (#380)', () {
    const held = SessionEnded(
      lines: <HeldLine>[
        HeldLine(entityType: 'photo', count: 3),
        HeldLine(entityType: 'stock', count: 1),
      ],
    );

    testWidgets('raises the sheet, non-dismissible, with the proof block', (
      tester,
    ) async {
      await _pump(tester, sessionEnded: held);
      await tester.pumpAndSettle();

      expect(_key('session-ended-sheet'), findsOneWidget);
      expect(find.text('You have been signed out'), findsOneWidget);
      expect(find.text('3 × Photo'), findsOneWidget);
      expect(find.text('1 × Stock count'), findsOneWidget);
      // It is a state, not an error: no triangle, no crimson, no "error".
      expect(find.textContaining('error'), findsNothing);
      expect(find.textContaining('Error'), findsNothing);
      // Non-dismissible: the scrim swallows the tap. There is a decision to
      // make and no way to walk past it.
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(_key('session-ended-sheet'), findsOneWidget);
    });

    testWidgets('"Not now" leaves the held line under the header', (
      tester,
    ) async {
      await _pump(tester, sessionEnded: held);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(_key('session-ended-sheet'), findsNothing);
      expect(TorchSheets.anyOpen, isFalse);
      expect(_key('login-held-line'), findsOneWidget);
      expect(find.text('4 captures are waiting to send.'), findsOneWidget);
    });

    testWidgets('the sheet never comes back a second time', (tester) async {
      await _pump(tester, sessionEnded: held);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      // A rebuild — typing into the form.
      await tester.enterText(_key('login-email'), 'a@b.com');
      await tester.pumpAndSettle();

      expect(_key('session-ended-sheet'), findsNothing);
    });

    testWidgets('a clean outbox gets no sheet and no line at all', (
      tester,
    ) async {
      await _pump(
        tester,
        sessionEnded: const SessionEnded(lines: <HeldLine>[]),
      );
      await tester.pumpAndSettle();

      expect(_key('session-ended-sheet'), findsNothing);
      expect(_key('login-held-line'), findsNothing);
    });
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0×', (tester) async {
      await _pump(tester, textScale: 2.0);
      await _fill(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 2.0× fits too, and is Afrikaans', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
      expect(find.text('Teken in'), findsWidgets);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('the Afrikaans refusal is Afrikaans, not English', (
      tester,
    ) async {
      await _pump(
        tester,
        auth: _FailingAuthRepository(_status(401)),
        locale: const Locale('af'),
      );
      await _fill(tester);
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(find.text('Ons kon jou nie inteken nie'), findsOneWidget);
      expect(find.text('We could not sign you in'), findsNothing);
    });
  });
}
