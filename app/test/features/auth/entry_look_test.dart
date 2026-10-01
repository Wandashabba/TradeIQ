import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/password_repository.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/auth/presentation/change_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/landing_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';

import '../agent_harness.dart'
    show agentBaseOverrides, agentTestDb, loadAgentFonts, pumpAgentScreen;
import 'account_screens_test.dart' show FakePasswordRepository;
import 'entry_harness.dart';

/// THE WAY IN, RENDERED — the six screens an unauthenticated visitor reaches,
/// in both skins, at four viewport sizes.
///
/// The auth screens had no look harness until the entry redesign. Every other
/// surface in this product got one before it was redesigned, for the reason
/// `floor_look_test.dart` gives first: the questions a redesign is judged on —
/// *does the headline lead*, *does the lockout read as an explanation rather
/// than a failure* — are not questions an assertion answers. The amber census
/// in `entry_amber_census_test.dart` and the measurements in
/// `login_screen_test.dart` are the pins; these are the pictures.
///
/// | image | what it has to get right |
/// |---|---|
/// | `landing` | the aisle and the mark, nothing written on it |
/// | `signin` | an invitation: the mark leads, two fields, one action, no card pasted on |
/// | `signin-error` | a refusal about the two fields directly beneath it |
/// | `signin-limited` | the lockout, reading as an explanation and not a failure |
/// | `forgot` | the redeemed code, in the account frame's one voice |
/// | `change` | the same frame on the agent skin, signed in |
///
/// **No real endpoint is touched.** The failures are `DioException`s built in
/// this file and thrown by a fake repository; the login rate limit is 10
/// attempts per 15 minutes by IP and the dev server is live, so the 429 state
/// is *constructed*, never provoked.
///
/// ## Why it does not run in CI
///
/// The reason its four siblings give: CI rasterises anti-aliased Onest on
/// `ubuntu-latest` and this repository is developed on macOS, so a pixel
/// comparison fails on the day it lands and gets skipped within a week.
///
/// ```sh
/// ENTRY_LOOK=1 ENTRY_LOOK_DIR=/somewhere/ flutter test \
///   test/features/auth/entry_look_test.dart --update-goldens
/// ```
///
/// `ENTRY_LOOK_DIR` **needs its trailing slash** — the name is appended with
/// no separator, the same contract the other four harnesses use.
///
/// ## THE TWO SIZES THAT WERE MISSING, AND WHAT THEY COST
///
/// This harness landed with two phones on it — 390×844 and 360×640 — and the
/// redesign it was built to judge was therefore judged at phone width only.
/// The owner opened the same screen in a desktop browser at roughly 1200
/// logical pixels and said *"Thats not good please fix spacing"*: the fields
/// ran the full viewport, the mark sat on the top edge, and the commit bar
/// was pinned hundreds of pixels below the form it belongs to. **None of
/// that was visible in any picture this file produced**, which is the whole
/// argument for the two sizes added on 30 September 2026:
///
/// | size | what it is |
/// |---|---|
/// | `1280x1800` | a desktop browser — the viewport the complaint came from |
/// | `834x1112` | an iPad Air in portrait — the width between the two |
///
/// A look harness that only renders the sizes a screen was designed at
/// cannot catch the size it was not.
void main() {
  final looking = Platform.environment['ENTRY_LOOK'] == '1';
  final dir = Platform.environment['ENTRY_LOOK_DIR'] ?? 'goldens/';

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  const sizes = <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
    // The desktop browser the owner is looking at, and the tablet width
    // between it and the phones. See the note above the function.
    ('1280x1800', Size(1280, 1800)),
    ('834x1112', Size(834, 1112)),
    // ── 395×708, THE WINDOW THE DEFECT WAS REPORTED FROM THREE TIMES ─────
    //
    // *"Why is now the login different? Look at the image attached?"* — the
    // owner, 1 October 2026, with no photograph on the door.
    //
    // It is the owner's own browser window and it was eight dp short of the
    // last fix's cliff: the reserve wanted 716dp of viewport and this is 708.
    // The same defect had already been reported at 749 and at 749-against-810,
    // and each round moved the boundary instead of removing it — because each
    // round was judged on one pinned number, and this harness only ever
    // rendered sizes that happened to be on the safe side of it.
    //
    // The argument for it is the same as the argument for 1280×1800 above,
    // made a second time by the same kind of report: **a look harness that
    // only renders the sizes a screen was designed at cannot catch the size
    // it was not.** 708 is now one of the sizes it was designed at.
    ('395x708', Size(395, 708)),
  ];
  const skins = <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ];

  Finder boundary() => find.byKey(entryBoundaryKey);

  for (final (sizeName, size) in sizes) {
    for (final (skinName, skin) in skins) {
      final suffix = '$sizeName-\$STATE-$skinName';
      String at(String state) =>
          '${dir}entry_${suffix.replaceFirst('\$STATE', state)}.png';

      // ── 1. The splash ────────────────────────────────────────────────
      //
      // Night carries the aisle footage; Day is paper with the same mark on
      // it. The video never initialises under the test binding, so Night
      // renders the ground the footage sits on — which is what a reader is
      // checking here anyway: the mark, its size and its placing.
      testWidgets('entry look — landing, $sizeName $skinName', (tester) async {
        await pumpEntryScreen(
          tester,
          const LandingScreen(),
          path: '/',
          size: size,
          settle: false,
          overrides: entryBaseOverrides(db: entryTestDb(), skin: skin),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(boundary(), matchesGoldenFile(at('landing')));
        await disposeEntryScreen(tester);
      }, skip: !looking);

      // ── 2. Sign-in at rest ───────────────────────────────────────────
      //
      // The screen the owner has complained about twice. Nothing typed, so
      // the primary is blocked and the whole frame carries zero amber.
      testWidgets('entry look — sign-in, $sizeName $skinName', (tester) async {
        await _pumpLogin(tester, skin: skin, size: size);

        await expectLater(boundary(), matchesGoldenFile(at('signin')));
        await disposeEntryScreen(tester);
      }, skip: !looking);

      // ── 3. Sign-in refused ───────────────────────────────────────────
      //
      // A 401. One sentence that never says whether the account exists, above
      // the two fields it is about.
      testWidgets('entry look — sign-in refused, $sizeName $skinName', (
        tester,
      ) async {
        await _pumpLogin(
          tester,
          skin: skin,
          size: size,
          auth: _FailingAuth(_status(401)),
        );
        await _attemptSignIn(tester);

        await expectLater(boundary(), matchesGoldenFile(at('signin-error')));
        await disposeEntryScreen(tester);
      }, skip: !looking);

      // ── 4. Sign-in locked out ────────────────────────────────────────
      //
      // A 429 — ten attempts in fifteen minutes, by IP. A designed state and
      // not an edge case: the person is not being told they are wrong, they
      // are being told to wait, and the picture is how that reading is
      // checked.
      testWidgets('entry look — sign-in rate-limited, $sizeName $skinName', (
        tester,
      ) async {
        await _pumpLogin(
          tester,
          skin: skin,
          size: size,
          auth: _FailingAuth(_status(429)),
        );
        await _attemptSignIn(tester);

        await expectLater(boundary(), matchesGoldenFile(at('signin-limited')));
        await disposeEntryScreen(tester);
      }, skip: !looking);

      // ── 5. Forgot password ───────────────────────────────────────────
      //
      // Reached signed-out, so it wears the entry skin even though it is
      // pumped through the agent harness — both are pinned, which is how the
      // existing account tests prove it is not quietly reading the wrong one.
      testWidgets('entry look — forgot password, $sizeName $skinName', (
        tester,
      ) async {
        await pumpAgentScreen(
          tester,
          const ForgotPasswordScreen(),
          path: '/forgot-password',
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: skin),
            entrySkinProvider.overrideWith(() => PinnedEntrySkin(skin)),
            passwordRepositoryProvider.overrideWithValue(
              FakePasswordRepository(),
            ),
          ],
          extraRoutes: <GoRoute>[namedRoute('/login', 'LOGIN')],
        );

        await expectLater(boundary(), matchesGoldenFile(at('forgot')));
        await disposeEntryScreen(tester);
      }, skip: !looking);

      // ── 6. Change password ───────────────────────────────────────────
      //
      // The one account screen that needs a session, so it stays on the agent
      // skin. It is in this set because it wears the same frame, and a frame
      // that changed shape on two screens and not the third would be the
      // regression this harness exists to catch.
      testWidgets('entry look — change password, $sizeName $skinName', (
        tester,
      ) async {
        await pumpAgentScreen(
          tester,
          const ChangePasswordScreen(),
          path: '/account/password',
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: skin),
            passwordRepositoryProvider.overrideWithValue(
              FakePasswordRepository(),
            ),
          ],
          extraRoutes: <GoRoute>[namedRoute('/notifications', 'SETTINGS')],
        );

        await expectLater(boundary(), matchesGoldenFile(at('change')));
        await disposeEntryScreen(tester);
      }, skip: !looking);
    }
  }
}

// ── Standing the screens up ────────────────────────────────────────────

Future<void> _pumpLogin(
  WidgetTester tester, {
  required SkinMode skin,
  required Size size,
  AuthRepository? auth,
}) => pumpEntryScreen(
  tester,
  const LoginScreen(),
  size: size,
  overrides: entryBaseOverrides(
    db: entryTestDb(),
    skin: skin,
    auth: auth ?? _FailingAuth(_status(401)),
  ),
  extraRoutes: <GoRoute>[
    namedRoute('/forgot-password', 'FORGOT'),
    namedRoute('/today', 'TODAY'),
  ],
);

/// Type a plausible pair and press the one action, so the screen is rendered
/// in the state a person actually reaches — not with an error bolted onto an
/// empty form.
Future<void> _attemptSignIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('login-email')),
    'thandi@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('login-password')),
    'not the right one',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('login-submit')));
  await tester.pumpAndSettle();
}

// ── Fakes. Nothing here reaches a server. ──────────────────────────────

class _FailingAuth implements AuthRepository {
  _FailingAuth(this.error);

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

Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}
