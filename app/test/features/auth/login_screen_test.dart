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
import 'package:tradeiq_app/core/widgets/torchlight/display_headline.dart';
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
    // VALIDATE ON PRESS, NOT ON SIGHT — 30 September 2026.
    //
    // This used to assert the screen scolded you on arrival: a dead button and
    // "Email is required" printed under it before anyone had typed a
    // character. It came out of the owner asking for the mockup's amber on the
    // commit, which a disabled button may not wear — so the button became
    // live, and a live button has to say what is missing when it is PRESSED.
    //
    // The fact under the old assertion is unchanged and is still pinned: an
    // empty form does not submit, and it names the email. What moved is when
    // it says so.
    testWidgets('an empty form says what is missing when it is pressed', (
      tester,
    ) async {
      await _pump(tester);

      // Nothing on arrival.
      expect(_primary(tester).onPressed, isNotNull);
      expect(_primary(tester).blockedReason, isNull);
      expect(find.text('Email is required'), findsNothing);

      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(_primary(tester).blockedReason, 'Email is required');
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('an email with no password names the password', (tester) async {
      await _pump(tester);
      await scrollEntryTo(tester, _key('login-email'));
      await tester.enterText(_key('login-email'), 'manager@tradeiq.com');
      await tester.pumpAndSettle();

      // Still silent until pressed — see the note above.
      expect(_primary(tester).blockedReason, isNull);

      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      expect(_primary(tester).onPressed, isNotNull);
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
      expect(
        find.text('We do not recognise that email and password.'),
        findsOneWidget,
      );
      // The body is the one sentence and nothing that would separate "no
      // such user" from "wrong password" — the whole reason this screen has
      // one message.
      //
      // The sentence changed on 30 September 2026 and the fact did not: it
      // was "Invalid credentials", which is the jargon a server logs rather
      // than anything a person says, and it treats the pair as one unit for
      // exactly the reason the tells below are banned.
      expect(
        state.message.body,
        'We do not recognise that email and password.',
      );
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

      expect(
        find.text('We do not recognise that email and password.'),
        findsOneWidget,
      );
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
      expect(
        find.text('We do not recognise that email and password.'),
        findsNothing,
      );
    });

    /// THE LOCKOUT IS A DESIGNED STATE, NOT AN EDGE CASE.
    ///
    /// The server refuses after **10 attempts in 15 minutes, by IP**, so this
    /// is a screen a real person reaches on a real morning — and reaches
    /// while already unable to get in. Until 30 September 2026 it printed the
    /// 401's headline, "We could not sign you in", over the shared 429 body:
    /// the screen said their credentials had been refused when in fact
    /// nothing had been checked at all.
    ///
    /// What this test holds down is that the two stories stay apart, and that
    /// the lockout's own sentence answers the question a pause actually
    /// raises. It is not "how long" — it is *is my account gone*.
    testWidgets('a 429 is a rule, not a refusal of who you are', (
      tester,
    ) async {
      await _pump(tester, auth: _FailingAuthRepository(_status(429)));
      await _fill(tester);
      await tester.tap(_key('login-submit'));
      await tester.pumpAndSettle();

      final state = tester.widget<ErrorState>(_key('login-error'));
      expect(state.message.offersRetry, isFalse);

      // Not the 401's words, in either half.
      expect(find.text('We could not sign you in'), findsNothing);
      expect(
        find.text('We do not recognise that email and password.'),
        findsNothing,
      );

      expect(state.message.headline, 'Too many sign-in attempts');
      expect(
        state.message.body,
        contains('Nothing is wrong with your account'),
        reason: 'a lockout that does not say this reads as a closed account',
      );

      // It never names the threshold. "10 attempts per 15 minutes" on the
      // screen is a number that helps nobody who is signing in honestly and
      // helps somebody pacing a guess.
      for (final number in <String>['10', '15', 'ten', 'fifteen']) {
        expect(
          find.textContaining(number, skipOffstage: false),
          findsNothing,
          reason: 'naming the limit only helps somebody pace their attempts',
        );
      }
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
      // No scroll: Forgot password moved out of the scrolling body and into
      // the pinned commit region on 30 September 2026, so it is always on
      // screen. `scrollUntilVisible` cannot find a widget that is not in the
      // scrollable, and threw rather than passing — which is the honest
      // failure for an assumption that stopped being true.
      await tester.tap(_key('login-forgot-password'));
      await tester.pumpAndSettle();

      expect(find.text('FORGOT SCREEN'), findsOneWidget);
    });

    /// THE BACK ARROW IS GONE, AND SO IS THE HEADER IT SAT IN.
    ///
    /// **A design intention overridden, not a fact that moved.** This test
    /// used to assert that the arrow named where it went ("Back to welcome")
    /// and went there, and it was right on its own terms: the destination was
    /// real and the label was honest.
    ///
    /// What it could not see is that the destination comes straight back.
    /// `/` is the splash; the splash holds for five seconds and then routes
    /// an unauthenticated visitor to `/login`. Pressing back put a person who
    /// cannot sign in through a five-second brand hold and returned them to
    /// the screen they pressed it on. The router's own redirect is the proof
    /// — see `app_router.dart`, where `/` is exempt so nothing cuts the hold
    /// short, and `LandingScreen._maybeAdvance` sends a null role to
    /// `/login`.
    ///
    /// It also cost the row a `TorchAppHeader` reserves above its title, on
    /// the one screen in the product with the least room: at 360x640 that row
    /// was the difference between "Remember me" being clipped by the thumb
    /// zone and the whole form fitting.
    ///
    /// Nothing became unreachable. The splash is a brand hold, not a
    /// destination, and `/forgot-password` is still one press away.
    testWidgets('there is no back arrow, and no header to hold one', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(TorchAppHeader), findsNothing);
      expect(find.bySemanticsLabel('Back to welcome'), findsNothing);

      // The screen still names itself — as a headline, which announces as a
      // header node, so a reader has not lost the landmark the app header's
      // title used to give them.
      expect(find.byType(TorchDisplayHeadline), findsOneWidget);
      expect(find.text('Sign in to get to work.'), findsOneWidget);
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
      // No scroll: Forgot password moved out of the scrolling body and into
      // the pinned commit region on 30 September 2026, so it is always on
      // screen. `scrollUntilVisible` cannot find a widget that is not in the
      // scrollable, and threw rather than passing — which is the honest
      // failure for an assumption that stopped being true.
      final handle = tester.ensureSemantics();

      await activate(tester, find.bySemanticsLabel('Forgot password?').first);
      await tester.pumpAndSettle();
      expect(find.text('FORGOT SCREEN'), findsOneWidget);
      handle.dispose();
    });

    /// The back arrow this used to activate is gone — see "there is no back
    /// arrow, and no header to hold one" above for why. What a reader must
    /// not lose with it is the **landmark**: the app header announced its
    /// title as a header node, and that was the one node a screen reader
    /// could jump to on arrival.
    ///
    /// `TorchDisplayHeadline` announces itself as a header for exactly this
    /// reason ("this is the first thing on the route"), so the landmark
    /// survives the header's removal. This test is what says so.
    testWidgets('the headline is still a header node a reader can find', (
      tester,
    ) async {
      await _pump(tester);
      final handle = tester.ensureSemantics();

      expect(
        tester.getSemantics(find.text('Sign in to get to work.')),
        matchesSemantics(label: 'Sign in to get to work.', isHeader: true),
      );
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

    /// THE FAILURE, WRITTEN AS ITSELF.
    ///
    /// `TorchSheetRoute` overrode `barrierDismissible` and nothing else, so
    /// "non-dismissible" stopped at the scrim. A field agent whose token
    /// expired with nine captures on the phone pressed the hardware back
    /// button out of habit and walked straight past the one decision the
    /// design says she cannot walk past.
    testWidgets('the system back button cannot walk past it', (tester) async {
      await _pump(tester, sessionEnded: held);
      await tester.pumpAndSettle();
      expect(_key('session-ended-sheet'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        _key('session-ended-sheet'),
        findsOneWidget,
        reason: 'the back gesture is refused, not merely undocumented',
      );
      expect(TorchSheets.anyOpen, isTrue);
    });

    /// The sheet renders over the form — and it
    /// rendered it regardless of `dismissible`, so outdoors the blocking
    /// sheet grew its own way past itself. It still has two actions, which is
    /// what makes refusing the row safe.
    /// THE FAILURE, WRITTEN AS ITSELF.
    ///
    /// `ProofBlock`'s `semanticsLabel` was the literal 'What is held on this
    /// phone', with no parameter on `SessionEndedSheet` to replace it. An
    /// Afrikaans agent on TalkBack heard three Afrikaans sentences and one
    /// English one — the one naming what is safe.
    testWidgets('every word a reader hears is in her language', (tester) async {
      await _pump(tester, sessionEnded: held, locale: const Locale('af'));
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      // The container merges its own name with the lines beneath it, so the
      // assertion is on the sentence inside the announcement.
      expect(find.bySemanticsLabel(RegExp('Wat word gehou')), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp('What is held')),
        findsNothing,
        reason:
            'the proof block announces itself in English on an Afrikaans '
            'phone at the most anxious moment the product has',
      );
      // And the words on the sheet itself.
      expect(find.text('Jy is uitgeteken'), findsOneWidget);
      expect(find.text('Teken in om dit te stuur'), findsOneWidget);
      expect(find.text('Nie nou nie'), findsOneWidget);

      handle.dispose();
      await tester.tap(find.text('Nie nou nie'));
      await tester.pumpAndSettle();
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
