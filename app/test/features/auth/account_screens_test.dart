import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/password_repository.dart';
import 'package:tradeiq_app/core/network/app_version.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/skin_controls.dart';
import 'package:tradeiq_app/features/auth/presentation/account_frame.dart';
import 'package:tradeiq_app/features/auth/presentation/change_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/update_required_screen.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';
import 'entry_harness.dart';

/// A password repository that records what it was asked and answers with
/// whatever the test sets.
class FakePasswordRepository implements PasswordRepository {
  Object? changeFailure;
  Object? redeemFailure;
  final calls = <String>[];
  Map<String, String>? lastRedeem;
  Map<String, String>? lastChange;

  @override
  Future<PasswordChanged> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add('change');
    lastChange = {'current': currentPassword, 'new': newPassword};
    if (changeFailure != null) throw changeFailure!;
    return const PasswordChanged(otherSessionsEnded: false);
  }

  @override
  Future<PasswordChanged> redeemResetCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    calls.add('redeem');
    lastRedeem = {'email': email, 'code': code, 'new': newPassword};
    if (redeemFailure != null) throw redeemFailure!;
    return const PasswordChanged(otherSessionsEnded: false);
  }

  @override
  Future<IssuedResetCode> issueResetCode(String userId) =>
      throw UnimplementedError();

  @override
  Future<PasswordChanged> setPasswordFor(String userId, String newPassword) =>
      throw UnimplementedError();
}

const _good = 'blue truck monday';

/// The skin the screen is actually painting with — the theme extension its own
/// route wrapper installed, read from inside the frame rather than from the
/// provider a test hoped it read.
TiqSkin _ground(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AccountFrame))).extension<TiqSkin>()!;

Finder _key(String k) => find.byKey(ValueKey<String>(k));

TorchPrimaryButton _primary(WidgetTester tester, String key) =>
    tester.widget<TorchPrimaryButton>(_key(key));

Future<void> _pumpForgot(
  WidgetTester tester,
  FakePasswordRepository repo, {
  SkinMode skin = SkinMode.night,
  SkinMode? entrySkin,
  String? email,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) => pumpAgentScreen(
  tester,
  ForgotPasswordScreen(initialEmail: email),
  path: '/forgot-password',
  textScale: textScale,
  locale: locale,
  overrides: <Override>[
    ...agentBaseOverrides(db: agentTestDb(), skin: skin),
    // `/forgot-password` is reached with nobody signed in, so its ground is
    // the entry skin. Pinning the agent one as well proves the screen is not
    // quietly reading it: the two are deliberately set apart in
    // `the signed-out screens wear the way in's skin`.
    entrySkinProvider.overrideWith(() => PinnedEntrySkin(entrySkin ?? skin)),
    passwordRepositoryProvider.overrideWithValue(repo),
  ],
  extraRoutes: <GoRoute>[
    GoRoute(
      path: '/login',
      builder: (context, state) => const Text('LOGIN SCREEN'),
    ),
  ],
);

Future<void> _pumpChange(
  WidgetTester tester,
  FakePasswordRepository repo, {
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) => pumpAgentScreen(
  tester,
  const ChangePasswordScreen(),
  path: '/account/password',
  textScale: textScale,
  locale: locale,
  overrides: <Override>[
    ...agentBaseOverrides(db: agentTestDb(), skin: skin),
    passwordRepositoryProvider.overrideWithValue(repo),
  ],
  extraRoutes: <GoRoute>[
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const Text('SETTINGS SCREEN'),
    ),
  ],
);

Future<void> _fillForgot(
  WidgetTester tester, {
  String email = 'agent@example.com',
  String code = '4821 7390',
  String password = _good,
  String? confirm,
}) async {
  await _enter(tester, 'forgot-email', email);
  await _enter(tester, 'forgot-code', code);
  await _enter(tester, 'forgot-new-password', password);
  await _enter(tester, 'forgot-confirm-password', confirm ?? password);
  // Put the keyboard away so the frame is the resting one.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _fillChange(
  WidgetTester tester, {
  String current = 'old password 1',
  String password = _good,
  String? confirm,
}) async {
  await _enter(tester, 'change-current-password', current);
  await _enter(tester, 'change-new-password', password);
  await _enter(tester, 'change-confirm-password', confirm ?? password);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

/// The body is a lazy list, so a field below the fold on a 360×640 phone is
/// not built until it is scrolled to — exactly as on the phone.
Future<void> _enter(WidgetTester tester, String key, String text) async {
  await scrollAgentTo(tester, _key(key));
  await tester.enterText(_key(key), text);
}

Future<void> _press(WidgetTester tester, String key) async {
  if (_key(key).evaluate().isEmpty) await scrollAgentTo(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  group('forgot password', () {
    testWidgets('says how the field reset works, and carries the email over', (
      tester,
    ) async {
      await _pumpForgot(tester, FakePasswordRepository(), email: 'a@b.co');
      expect(
        find.textContaining('Ask your manager for a reset code'),
        findsOne,
      );
      final email = tester.widget<EditableText>(
        find.descendant(
          of: _key('forgot-email'),
          matching: find.byType(EditableText),
        ),
      );
      expect(email.controller.text, 'a@b.co');
    });

    // THE PRIMARY STILL NAMES WHAT IS MISSING — IT WAITS TO BE ASKED.
    //
    // This read the reason off the first frame and required `onPressed` to be
    // null. Both described the ghost-until-complete primary these two screens
    // used to carry, and neither is what sign-in does: there the button is
    // pressable from the start and the reason arrives on the attempt
    // (`_tried`, #494). 3 October brought forgot and change into line.
    //
    // The behaviour worth protecting is unchanged and still asserted: the app
    // never refuses without saying what it wants. What moved is when it says
    // it — on the press, rather than at somebody who has not typed yet.
    testWidgets('the primary names what is missing, once asked', (
      tester,
    ) async {
      await _pumpForgot(tester, FakePasswordRepository());
      expect(_primary(tester, 'forgot-submit').blockedReason, isNull);

      await _press(tester, 'forgot-submit');
      expect(
        _primary(tester, 'forgot-submit').blockedReason,
        'Enter your email first',
      );

      await _enter(tester, 'forgot-email', 'agent@example.com');
      await _enter(tester, 'forgot-code', '1234');
      await tester.pumpAndSettle();
      expect(
        _primary(tester, 'forgot-submit').blockedReason,
        'Enter the 8-digit code from your manager',
      );

      await _enter(tester, 'forgot-code', '4821 7390');
      await tester.pumpAndSettle();
      expect(
        _primary(tester, 'forgot-submit').blockedReason,
        'Choose a new password',
      );
    });

    testWidgets('redeems the code and says what it cannot do', (tester) async {
      final repo = FakePasswordRepository();
      await _pumpForgot(tester, repo);
      await _fillForgot(tester);
      await _press(tester, 'forgot-submit');

      expect(repo.lastRedeem, {
        'email': 'agent@example.com',
        'code': '4821 7390',
        'new': _good,
      });
      expect(find.text('Your password is changed'), findsOneWidget);
      // Honest about the token design: other sessions are not ended.
      expect(
        find.textContaining('stay signed in until their session ends'),
        findsOneWidget,
      );

      await _press(tester, 'forgot-go-to-sign-in');
      expect(find.text('LOGIN SCREEN'), findsOneWidget);
    });

    testWidgets('a short password is caught on the phone, not sent', (
      tester,
    ) async {
      final repo = FakePasswordRepository();
      await _pumpForgot(tester, repo);
      await _fillForgot(tester, password: 'short one');
      await _press(tester, 'forgot-submit');
      expect(repo.calls, isEmpty);
      expect(
        find.text('Too short: use at least 12 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('mismatched passwords are caught on the phone', (tester) async {
      final repo = FakePasswordRepository();
      await _pumpForgot(tester, repo);
      await _fillForgot(tester, confirm: 'blue truck tuesday');
      await _press(tester, 'forgot-submit');
      expect(repo.calls, isEmpty);
      expect(find.text('The two new passwords do not match.'), findsOneWidget);
    });

    testWidgets('a refused code reads the same whatever the cause', (
      tester,
    ) async {
      final repo = FakePasswordRepository()
        ..redeemFailure = const PasswordRefused(PasswordRefusal.codeRejected);
      await _pumpForgot(tester, repo);
      await _fillForgot(tester);
      await _press(tester, 'forgot-submit');

      expect(find.text('That code did not work'), findsOneWidget);
      // One sentence for every cause — it cannot tell anyone whether the
      // account exists.
      expect(
        find.textContaining('mistyped, used already or older than 15 minutes'),
        findsOneWidget,
      );
      expect(find.text('Your password is changed'), findsNothing);
    });

    testWidgets('a password the server refuses is a field error', (
      tester,
    ) async {
      final repo = FakePasswordRepository()
        ..redeemFailure = const PasswordRefused(
          PasswordRefusal.passwordRejected,
        );
      await _pumpForgot(tester, repo);
      await _fillForgot(tester, password: 'password1234');
      await _press(tester, 'forgot-submit');
      expect(find.textContaining('That password was not accepted'), findsOne);
    });

    testWidgets('the password fields are hidden until asked', (tester) async {
      await _pumpForgot(tester, FakePasswordRepository());
      EditableText field() => tester.widget<EditableText>(
        find.descendant(
          of: _key('forgot-new-password'),
          matching: find.byType(EditableText),
        ),
      );
      await scrollAgentTo(tester, _key('forgot-new-password'));
      expect(field().obscureText, isTrue);
      // A keyboard that learns a password offers it to the next borrower.
      expect(field().autocorrect, isFalse);
      expect(field().enableSuggestions, isFalse);
      await _press(tester, 'forgot-show-passwords');
      await scrollAgentTo(tester, _key('forgot-new-password'));
      expect(field().obscureText, isFalse);
    });

    testWidgets('Afrikaans at 2.0× still lays out', (tester) async {
      await _pumpForgot(
        tester,
        FakePasswordRepository(),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(find.text('Stel jou wagwoord terug'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('change password', () {
    testWidgets('changes it and says other phones stay signed in', (
      tester,
    ) async {
      final repo = FakePasswordRepository();
      await _pumpChange(tester, repo);
      // The reason arrives on the attempt now, not from the first frame —
      // see "the primary names what is missing, once asked" above for why.
      await _press(tester, 'change-submit');
      expect(
        _primary(tester, 'change-submit').blockedReason,
        'Enter your current password',
      );
      await _fillChange(tester);
      await _press(tester, 'change-submit');

      expect(repo.lastChange, {'current': 'old password 1', 'new': _good});
      expect(find.text('Password changed'), findsOneWidget);
      expect(
        find.textContaining('You stay signed in on this phone'),
        findsOneWidget,
      );
      expect(
        find.textContaining('stay signed in until their session ends'),
        findsOneWidget,
      );
      await _press(tester, 'change-done');
      expect(find.text('SETTINGS SCREEN'), findsOneWidget);
    });

    testWidgets('a wrong current password is a field error, nothing more', (
      tester,
    ) async {
      final repo = FakePasswordRepository()
        ..changeFailure = const PasswordRefused(
          PasswordRefusal.wrongCurrentPassword,
        );
      await _pumpChange(tester, repo);
      await _fillChange(tester, current: 'not it at all');
      await _press(tester, 'change-submit');
      expect(find.text('That is not your current password.'), findsOneWidget);
      expect(find.text('Password changed'), findsNothing);
      // Still on the form, still signed in — see app_version_test.dart for
      // the interceptor half.
      expect(_key('change-current-password'), findsOneWidget);
    });

    testWidgets('Afrikaans at 2.0× still lays out', (tester) async {
      await _pumpChange(
        tester,
        FakePasswordRepository(),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(find.text('Verander wagwoord'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('update required', () {
    setUp(() => appUpdateRequired.value = null);
    tearDown(() => appUpdateRequired.value = null);

    testWidgets('names both versions when the server said', (tester) async {
      appUpdateRequired.value = const AppUpdateRequired(
        minimumVersion: '9.1.0',
      );
      await pumpAgentScreen(
        tester,
        const UpdateRequiredScreen(),
        path: '/update-required',
        overrides: agentBaseOverrides(db: agentTestDb()),
      );
      expect(find.text('Update TradeIQ'), findsOneWidget);
      expect(
        find.text(
          'This phone has version $appVersion. Version 9.1.0 or newer is '
          'needed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Nothing saved on this phone is deleted by this.'),
        findsOneWidget,
      );
    });

    testWidgets('never invents a minimum it was not told', (tester) async {
      appUpdateRequired.value = const AppUpdateRequired();
      await pumpAgentScreen(
        tester,
        const UpdateRequiredScreen(),
        path: '/update-required',
        overrides: agentBaseOverrides(db: agentTestDb()),
      );
      expect(
        find.text(
          'This phone has version $appVersion. A newer version is needed.',
        ),
        findsOneWidget,
      );
    });

    /// The refused build was the one account screen with no length test, and
    /// it is the worst candidate to skip: three paragraphs and a sentence
    /// carrying two version numbers, on a phone whose owner cannot get past
    /// it.
    for (final skin in <SkinMode>[SkinMode.night]) {
      testWidgets('Afrikaans at 2.0× still lays out in ${skin.name}', (
        tester,
      ) async {
        appUpdateRequired.value = const AppUpdateRequired(
          minimumVersion: '9.1.0',
        );
        await pumpAgentScreen(
          tester,
          const UpdateRequiredScreen(),
          path: '/update-required',
          textScale: 2.0,
          locale: const Locale('af'),
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: skin),
            entrySkinProvider.overrideWith(() => PinnedEntrySkin(skin)),
          ],
        );
        expect(find.text('Dateer TradeIQ op'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"Try again" clears the state', (tester) async {
      appUpdateRequired.value = const AppUpdateRequired(
        minimumVersion: '9.1.0',
      );
      await pumpAgentScreen(
        tester,
        const UpdateRequiredScreen(),
        path: '/update-required',
        overrides: agentBaseOverrides(db: agentTestDb()),
        extraRoutes: <GoRoute>[
          GoRoute(path: '/', builder: (context, state) => const Text('HOME')),
        ],
      );
      await _press(tester, 'update-try-again');
      expect(appUpdateRequired.value, isNull);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  /// WHICH SKIN THE WAY IN WEARS, ON THE WAY IN'S OTHER TWO SCREENS.
  ///
  /// `entry_skin.dart` names its own scope: "the splash, sign-in, **the reset
  /// code** and **the refused build**". Two of those four were never wired to
  /// it. `/forgot-password` and `/update-required` are both reached with
  /// nobody signed in — there is no agent to have a morning — and both were
  /// wrapped in `TorchlightRoute`, which reads `agentSkinProvider` and
  /// defaults to **Day**.
  ///
  /// So sign-in was Night and "Forgot password?" was white, and the cycle in
  /// the thumb zone wrote a provider the two screens did not share: set Day
  /// on sign-in, walk to the reset code, and you were back in Night with no
  /// way to tell why.
  group('the signed-out screens wear the way in\'s skin', () {
    // The two providers are set APART on purpose. A screen that reads the
    // right one cannot pass this by accident.
    testWidgets('forgot password follows the entry skin, not the agent\'s', (
      tester,
    ) async {
      await _pumpForgot(
        tester,
        FakePasswordRepository(),
        skin: SkinMode.night,
        entrySkin: SkinMode.day,
      );
      expect(
        _ground(tester).palette.ground,
        entrySkinFor(SkinMode.day).palette.ground,
        reason:
            'the reset code is reached signed out, so the entry skin is the '
            'one that decides its ground',
      );
      expect(
        _ground(tester).palette.ground,
        isNot(agentSkinFor(SkinMode.night).palette.ground),
      );
    });

    testWidgets('the refused build follows it too', (tester) async {
      appUpdateRequired.value = const AppUpdateRequired(
        minimumVersion: '9.1.0',
      );
      addTearDown(() => appUpdateRequired.value = null);
      await pumpAgentScreen(
        tester,
        const UpdateRequiredScreen(),
        path: '/update-required',
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: SkinMode.night),
          entrySkinProvider.overrideWith(() => PinnedEntrySkin(SkinMode.day)),
        ],
      );
      expect(
        _ground(tester).palette.ground,
        entrySkinFor(SkinMode.day).palette.ground,
      );
    });

    testWidgets('changing your own password needs a session, so it stays on '
        'the agent skin', (tester) async {
      await _pumpChange(tester, FakePasswordRepository(), skin: SkinMode.day);
      expect(
        _ground(tester).palette.ground,
        agentSkinFor(SkinMode.day).palette.ground,
        reason:
            '/account/password is behind a session: there IS an agent here, '
            'and they keep the skin they were already in',
      );
    });

    // The control and the ground must answer to one provider. A cycle wired
    // to the other one still moves and still repaints nothing.
    // NO CYCLE BEFORE THE DOOR — owner instruction, 30 September 2026:
    // *"That change of theme on the sign in we can remove it. Let's only make
    // the change of theme only on settings."*
    //
    // The standing rule this supersedes — never a screen without the cycle —
    // exists so the control cannot become unreachable. It stays true of every
    // screen behind the door, where the cycle sits on nineteen of them. What
    // the owner ruled is that a person who has not signed in yet is not the
    // person that rule was written for.
    //
    // The pairing the old test protected is still worth protecting, so the
    // signed-in half below is unchanged: a cycle wired to the wrong provider
    // still moves and still repaints nothing.
    testWidgets('the pre-auth screens carry no cycle at all', (tester) async {
      await _pumpForgot(tester, FakePasswordRepository());
      expect(find.byType(EntrySkinCycle), findsNothing);
      expect(find.byType(AgentSkinCycle), findsNothing);
    });

    // AND THE SIGNED-IN ONE CARRIES NONE EITHER, AS OF 3 OCTOBER.
    //
    // This asserted `findsOneWidget` because change password was the one
    // screen in this file behind the door, and the standing rule was that a
    // signed-in screen always offers the cycle. The owner has now said twice
    // that the theme control belongs in one place: *"That change of theme on
    // the sign in we can remove it. Let's only make the change of theme only
    // on settings"* (1 October), and then, seeing it still here, *"remember I
    // also said the theme button must not be there, only on settings"*.
    //
    // The first pass took it off the sign-in screen rather than off the frame
    // the four routes share, which is why it survived here. It is off the
    // frame now, so this screen has none — and nothing is lost: change
    // password is reached from the menu sheet, whose "This app" section is
    // where the control lives.
    testWidgets('and the signed-in one carries none either', (tester) async {
      await _pumpChange(tester, FakePasswordRepository());
      expect(find.byType(AgentSkinCycle), findsNothing);
      expect(find.byType(EntrySkinCycle), findsNothing);
    });
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      final name = skin.name;

      // NOTHING TYPED IS NOW ONE LIT OBJECT, NOT NONE — 3 OCTOBER.
      //
      // This read 0 and was named "nothing is armed", because these two
      // screens stood their commit button up as a ghost until the form was
      // complete. Sign-in never did: it has shown a lit primary from the
      // first frame since #494 and names what is missing only once you press
      // (`_tried`). The owner called these screens "outdated from the app",
      // and that difference was the largest part of it.
      //
      // So the button is lit here from the first frame too, and the count
      // goes 0 -> 1. **That is inside budget and it spends all of Day's.**
      // Night allows 2 and uses 1; Day allows 1 and now uses it. Anything
      // these screens later want lit has to take it from this button.
      testWidgets('forgot, nothing typed, $name: 1 — the primary, unarmed', (
        tester,
      ) async {
        await _pumpForgot(tester, FakePasswordRepository(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          entrySkinFor(skin),
          route: 'forgot-password',
          phase: 'blocked',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('forgot, filled, $name: 1 — the primary', (tester) async {
        await _pumpForgot(tester, FakePasswordRepository(), skin: skin);
        await _fillForgot(tester);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          entrySkinFor(skin),
          route: 'forgot-password',
          phase: 'armed',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('forgot, code refused, $name: 1 — the failure is not lit', (
        tester,
      ) async {
        final repo = FakePasswordRepository()
          ..redeemFailure = const PasswordRefused(PasswordRefusal.codeRejected);
        await _pumpForgot(tester, repo, skin: skin);
        await _fillForgot(tester);
        await _press(tester, 'forgot-submit');
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          entrySkinFor(skin),
          route: 'forgot-password',
          phase: 'error',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('forgot, done, $name: 1 — "Go to sign in"', (tester) async {
        await _pumpForgot(tester, FakePasswordRepository(), skin: skin);
        await _fillForgot(tester);
        await _press(tester, 'forgot-submit');
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          entrySkinFor(skin),
          route: 'forgot-password',
          phase: 'done',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      // Same move as `forgot, nothing typed` above, same arithmetic: the
      // commit button is lit from the first frame now instead of waiting for
      // a complete form, so this goes 0 -> 1 and Day's single grant is spent.
      testWidgets('change, nothing typed, $name: 1 — the primary, unarmed', (
        tester,
      ) async {
        await _pumpChange(tester, FakePasswordRepository(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'account-password',
          phase: 'blocked',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('change, wrong current password, $name: 1', (tester) async {
        final repo = FakePasswordRepository()
          ..changeFailure = const PasswordRefused(
            PasswordRefusal.wrongCurrentPassword,
          );
        await _pumpChange(tester, repo, skin: skin);
        await _fillChange(tester);
        await _press(tester, 'change-submit');
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'account-password',
          phase: 'armed',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('change, done, $name: 1', (tester) async {
        await _pumpChange(tester, FakePasswordRepository(), skin: skin);
        await _fillChange(tester);
        await _press(tester, 'change-submit');
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'account-password',
          phase: 'done',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('update required, $name: 1 — "Try again"', (tester) async {
        appUpdateRequired.value = const AppUpdateRequired(
          minimumVersion: '9.1.0',
        );
        addTearDown(() => appUpdateRequired.value = null);
        await pumpAgentScreen(
          tester,
          const UpdateRequiredScreen(),
          path: '/update-required',
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: skin),
            entrySkinProvider.overrideWith(() => PinnedEntrySkin(skin)),
          ],
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          entrySkinFor(skin),
          route: 'update-required',
          phase: 'update-required',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });
}
