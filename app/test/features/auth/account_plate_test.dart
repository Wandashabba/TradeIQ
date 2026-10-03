import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/password_repository.dart';
import 'package:tradeiq_app/core/network/app_version.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/features/auth/presentation/account_frame.dart';
import 'package:tradeiq_app/features/auth/presentation/change_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/entry_brand.dart';
import 'package:tradeiq_app/features/auth/presentation/entry_plate.dart';
import 'package:tradeiq_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';
import 'package:tradeiq_app/features/auth/presentation/update_required_screen.dart';

import '../agent_harness.dart'
    show
        agentBaseOverrides,
        agentTestDb,
        loadAgentFonts,
        pumpAgentScreen,
        scrollAgentTo;
import 'account_screens_test.dart' show FakePasswordRepository;
import 'entry_harness.dart';

/// THE PLATE ON THE THREE ACCOUNT SCREENS — the reserve, the fold and the
/// clearance, measured rather than argued.
///
/// > *"Lets fix the change password page, it's outdated from the app"* — the
/// > owner, 3 October 2026.
///
/// `entry_plate_test.dart` does this for the door. This is the same three
/// questions asked of the three screens that joined it, and it exists because
/// of what happened the last time one of them was answered from arithmetic
/// instead of a render: `EntryPlate.ground` was 566 for three owner reports,
/// and 566 was the 844dp phone's own leftovers.
///
/// | group | the question |
/// |---|---|
/// | the reserve | do the declared numbers cover what the screen really keeps? |
/// | the fold | is the commit reachable on the shortest screen, at every scale? |
/// | the top slot | does its one occupant clear the strip light? |
///
/// **The fold group is the one that matters.** `entry_frame.dart` records that
/// at 360×640 the sign-in form already runs past the fold, and these screens
/// have three and four fields where it has two. The reason they can still
/// carry a 250dp picture is structural and not a tuning result: the commit is
/// a [TorchThumbZone] that is a *sibling* of the scroll view, so nothing in
/// the column can push it off the screen. That claim is asserted here at
/// every size and scale, for all three screens, because a commit button that
/// cannot be reached is a worse outcome than a screen without a plate.
void main() {
  setUpAll(loadAgentFonts);

  /// The two phones the account screens are designed at, and the four scales
  /// the app allows. 1.3× is in here because it is the scale the door's
  /// recorded headline defect begins at, and these screens had to be checked
  /// against it rather than assumed clear of it.
  const sizes = <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ];
  const scales = <double>[1.0, 1.3, 1.6, 2.0];

  for (final (sizeName, size) in sizes) {
    for (final scale in scales) {
      final at = '$sizeName ${scale}x';

      for (final screen in _screens) {
        testWidgets('${screen.name} at $at: the reserve covers what is kept', (
          tester,
        ) async {
          await screen.pump(tester, size: size, scale: scale);

          final plate = tester.getRect(find.byType(TiqPlate));
          final zone = tester.getRect(find.byType(TorchThumbZone));
          final spec = screen.specAt(size, scale);

          // THE ONE CELL WHERE THE RESERVE IS NOT THE QUESTION.
          //
          // Reset password at 360×640 and 2.0× cannot keep its first field
          // beside anything: the paragraph alone is 240dp of a 640dp screen
          // and the field is 114 more. The reserve says 484 and `shortest`
          // takes the picture away, and that is the honest answer rather than
          // a number to tune — so this asserts the collapse instead of
          // measuring a span whose top has scrolled off the screen. Measuring
          // it anyway is how a test that cannot fail gets written: the span
          // comes out NEGATIVE there, and `negative <= 484` passes.
          if (spec.form != PlateForm.photographic) {
            // ignore: avoid_print
            print(
              'RESERVE ${screen.name} $at: the picture gives way — '
              '${spec.form.name}, because the viewport has '
              '${(size.height - screen.reserve.at(scale)).toStringAsFixed(0)}dp '
              'left against a ${screen.reserve.shortest.toStringAsFixed(0)}dp '
              'floor. The band is ${plate.height.toStringAsFixed(0)}dp and '
              'the commit is still pinned below the scroll.',
            );
            expect(spec.form, PlateForm.collapsed);
            return;
          }

          // The anchor is the last thing that has to be on screen beside the
          // picture: the first field, or — on update required, which has no
          // field — the first paragraph. Everything between it and the foot
          // of the plate is in the span, so the gaps and reset password's
          // paragraph are counted without being named one at a time.
          //
          // It is scrolled to before it is measured. On a 360×640 phone at
          // 2.0× reset password's own paragraph is 200dp and the field below
          // it is genuinely past the fold, and the body is a lazy list, so an
          // unscrolled `getRect` would throw rather than report. See the
          // `cannot be kept` assertion below for what that cell means.
          final anchorFinder = screen.anchor;
          if (anchorFinder.evaluate().isEmpty) {
            await scrollAgentTo(tester, anchorFinder);
          }
          final anchor = tester.getRect(anchorFinder);

          final scrolled = tester.getRect(find.byType(Scrollable).first);
          final offset = tester.widget<Scrollable>(
            find.byType(Scrollable).first,
          );
          final scrollPx = offset.controller?.offset ?? 0;

          final measured =
              plate.top + (anchor.bottom - plate.bottom) + zone.height;
          final declared = screen.reserve.at(scale);

          // ignore: avoid_print
          print(
            'RESERVE ${screen.name} $at\n'
            '  shell top inset              '
            '${plate.top.toStringAsFixed(1)}\n'
            '  plate foot to anchor foot    '
            '${(anchor.bottom - plate.bottom).toStringAsFixed(1)}\n'
            '  the pinned thumb zone        '
            '${zone.height.toStringAsFixed(1)}\n'
            '  ---------------------------------\n'
            '  measured                     ${measured.toStringAsFixed(1)}'
            '${scrollPx > 0 ? '  (after ${scrollPx.toStringAsFixed(0)}dp of scroll)' : ''}\n'
            '  declared                     ${declared.toStringAsFixed(1)}\n'
            '  plate                        '
            '${plate.height.toStringAsFixed(1)}  '
            '(scroll viewport ends at ${scrolled.bottom.toStringAsFixed(0)})',
          );

          expect(
            measured,
            lessThanOrEqualTo(declared + 0.5),
            reason:
                'The reserve ${screen.name} actually keeps beside its plate is '
                '$measured and its EntryPlateReserve promises only $declared. '
                'Raise its `prose` until `at($scale)` clears the measured '
                'number — and read EntryPlate §3 before touching `ground`, '
                'because the piece that is NOT in this span is the commit row '
                'and putting it back is the 566 mistake.',
          );
        });
      }

      testWidgets('the commit is reachable on all four routes at $at', (
        tester,
      ) async {
        for (final screen in <_Screen>[..._screens, _signIn]) {
          await screen.pump(tester, size: size, scale: scale);

          final scrolled = tester.getRect(find.byType(Scrollable).first);
          final primary = tester.getRect(find.byKey(screen.primaryKey));

          // ignore: avoid_print
          print(
            'FOLD ${screen.name} $at: the commit is at '
            '${primary.top.toStringAsFixed(0)}-'
            '${primary.bottom.toStringAsFixed(0)} in a '
            '${size.height.toInt()}dp viewport, below a scroll that ends at '
            '${scrolled.bottom.toStringAsFixed(0)}',
          );

          expect(
            primary.top,
            greaterThanOrEqualTo(scrolled.bottom - 0.5),
            reason:
                '${screen.name} at $at has put its commit inside the scroll '
                'view. Every reserve in EntryPlateReserve assumes it is '
                'pinned beneath it, and a form this long with a commit at the '
                'end of a scroll is the outcome the plate is not worth.',
          );
          expect(
            primary.bottom,
            lessThanOrEqualTo(size.height),
            reason:
                '${screen.name} at $at has pushed its commit off the bottom '
                'of a ${size.height.toInt()}dp screen.',
          );
          expect(
            find.descendant(
              of: find.byType(Scrollable),
              matching: find.byType(TorchThumbZone),
            ),
            findsNothing,
            reason: '${screen.name} at $at: the thumb zone has joined the '
                'scroll, so nothing below it is pinned any more.',
          );
          await disposeEntryScreen(tester);
        }
      });
    }
  }

  // ── The plate each size and scale actually resolves ────────────────────
  //
  // Declared values rather than rendered pixels, so a diff names the number
  // that moved. The one cell that is not a 250dp photograph is named, because
  // a collapse nobody wrote down is how 566 survived three reports.
  group('what each screen resolves to', () {
    const expected = <String, String>{
      'change password 390x844 1.0x': 'photographic 250.0',
      'change password 390x844 1.3x': 'photographic 250.0',
      'change password 390x844 1.6x': 'photographic 250.0',
      'change password 390x844 2.0x': 'photographic 250.0',
      'change password 360x640 1.0x': 'photographic 250.0',
      'change password 360x640 1.3x': 'photographic 250.0',
      'change password 360x640 1.6x': 'photographic 250.0',
      'change password 360x640 2.0x': 'photographic 250.0',
      'update required 390x844 1.0x': 'photographic 250.0',
      'update required 390x844 1.3x': 'photographic 250.0',
      'update required 390x844 1.6x': 'photographic 250.0',
      'update required 390x844 2.0x': 'photographic 250.0',
      'update required 360x640 1.0x': 'photographic 250.0',
      'update required 360x640 1.3x': 'photographic 250.0',
      'update required 360x640 1.6x': 'photographic 250.0',
      'update required 360x640 2.0x': 'photographic 250.0',
      'reset password 390x844 1.0x': 'photographic 250.0',
      'reset password 390x844 1.3x': 'photographic 250.0',
      'reset password 390x844 1.6x': 'photographic 250.0',
      'reset password 390x844 2.0x': 'photographic 250.0',
      'reset password 360x640 1.0x': 'photographic 250.0',
      'reset password 360x640 1.3x': 'photographic 250.0',
      // The picture gives way here and the two cells are different answers to
      // the same arithmetic. At 1.6× the reserve is 412 of a 640dp screen, so
      // the plate takes what is left; at 2.0× it is 484 and 156dp is under
      // `shortest`, so the band draws instead. Reset password is the only one
      // of the three with a paragraph between the picture and its first
      // field, which is the whole of why it is the only one that gives way.
      'reset password 360x640 1.6x': 'photographic 228.0',
      'reset password 360x640 2.0x': 'collapsed 96.0',
    };

    test('the declared plate, every screen × size × scale', () {
      final got = <String, String>{};
      for (final (sizeName, size) in sizes) {
        for (final scale in scales) {
          for (final screen in _screens) {
            final spec = screen.specAt(size, scale);
            got['${screen.name} $sizeName ${scale}x'] =
                '${spec.form.name} ${spec.height.toStringAsFixed(1)}';
          }
        }
      }
      // ignore: avoid_print
      print(
        'THE PLATE, DECLARED\n'
        '${got.entries.map((e) => '  ${e.key.padRight(32)} ${e.value}').join('\n')}',
      );
      expect(got, expected);
    });
  });

  // ── The top slot's one occupant ────────────────────────────────────────
  group('the top slot carries one thing, and it clears the light', () {
    for (final (sizeName, size) in sizes) {
      for (final scale in scales) {
        for (final screen in _screens) {
          testWidgets(
            '${screen.name} at $sizeName ${scale}x: '
            '${screen.hasBack ? 'the way out' : 'the mark'}, clearing the strip',
            (tester) async {
              await screen.pump(tester, size: size, scale: scale);

              // ONE OCCUPANT, AND WHICH ONE IS THE SCREEN'S OWN ANSWER.
              //
              // The mark says which product before anybody has typed a
              // character, which the door needs to say and a screen reached
              // from it does not. So a screen with a way out shows the arrow
              // and a screen without one shows the mark, and never both:
              // beside each other at 360 wide and 2.0× the mark wraps and the
              // slot becomes 94dp, 15dp into its own strip light.
              expect(
                find.byType(TorchIconButton),
                screen.hasBack ? findsOneWidget : findsNothing,
              );
              expect(
                find.byType(EntryBrand),
                screen.hasBack ? findsNothing : findsOneWidget,
              );

              final plate = tester.getRect(find.byType(TiqPlate));
              final slot = tester.getRect(
                screen.hasBack
                    ? find.byType(TorchIconButton)
                    : find.byType(EntryBrand),
              );
              final spec = PlateSpec.resolve(
                skin: entrySkinFor(SkinMode.night),
                viewportHeight: size.height,
                textScale: scale,
                ground: screen.reserve.at(scale),
                tallest: EntryPlate.tallest,
                shortest: screen.reserve.shortest,
              );
              if (spec.form != PlateForm.photographic) return;

              final light = plate.top + spec.stripLightY;
              // ignore: avoid_print
              print(
                'TOP SLOT ${screen.name} $sizeName ${scale}x: '
                '${slot.top.toStringAsFixed(0)}-'
                '${slot.bottom.toStringAsFixed(0)} '
                '(${slot.height.toStringAsFixed(0)}dp) against a strip light '
                'at ${light.toStringAsFixed(1)} — clearance '
                '${(light - slot.bottom).toStringAsFixed(1)}',
              );
              expect(
                slot.bottom,
                lessThanOrEqualTo(light),
                reason:
                    '${screen.name} at $sizeName ${scale}x paints its top '
                    'slot across the strip light. plate_spec.dart records '
                    'what that costs when the light is lit: the census reads '
                    'one cut light as two objects. Raise that screen\'s '
                    '`shortest`, or take something out of the slot.',
              );
            },
          );
        }
      }
    }
  });
}

// ── The three screens, stood up ────────────────────────────────────────────

class _Screen {
  const _Screen({
    required this.name,
    required this.reserve,
    required this.primaryKey,
    required this.anchor,
    required this.hasBack,
    required this.pump,
  });

  final String name;
  final EntryPlateReserve reserve;
  final Key primaryKey;

  /// The last thing that has to be on screen beside the picture.
  final Finder anchor;

  final bool hasBack;

  /// What [PlateSpec] resolves for this screen at a size and a scale, from
  /// the screen's own declared reserve.
  PlateSpec specAt(Size size, double scale) => PlateSpec.resolve(
    skin: entrySkinFor(SkinMode.night),
    viewportHeight: size.height,
    textScale: scale,
    ground: reserve.at(scale),
    tallest: EntryPlate.tallest,
    shortest: reserve.shortest,
  );

  final Future<void> Function(
    WidgetTester tester, {
    required Size size,
    required double scale,
  })
  pump;
}

Finder _key(String k) => find.byKey(ValueKey<String>(k));

final _screens = <_Screen>[
  _Screen(
    name: 'change password',
    reserve: EntryPlateReserve.changePassword,
    primaryKey: const ValueKey<String>('change-submit'),
    anchor: _key('change-current-password'),
    hasBack: true,
    pump: (tester, {required size, required scale}) => pumpAgentScreen(
      tester,
      const ChangePasswordScreen(),
      path: '/account/password',
      size: size,
      textScale: scale,
      overrides: <Override>[
        ...agentBaseOverrides(db: agentTestDb(), skin: SkinMode.night),
        passwordRepositoryProvider.overrideWithValue(FakePasswordRepository()),
      ],
      extraRoutes: <GoRoute>[namedRoute('/notifications', 'SETTINGS')],
    ),
  ),
  _Screen(
    name: 'update required',
    reserve: EntryPlateReserve.updateRequired,
    primaryKey: const ValueKey<String>('update-try-again'),
    anchor: find.byType(AccountText).first,
    hasBack: false,
    pump: (tester, {required size, required scale}) {
      appUpdateRequired.value = const AppUpdateRequired(
        minimumVersion: '9.1.0',
      );
      addTearDown(() => appUpdateRequired.value = null);
      return pumpAgentScreen(
        tester,
        const UpdateRequiredScreen(),
        path: '/update-required',
        size: size,
        textScale: scale,
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: SkinMode.night),
          entrySkinProvider.overrideWith(() => PinnedEntrySkin(SkinMode.night)),
        ],
      );
    },
  ),
  _Screen(
    name: 'reset password',
    reserve: EntryPlateReserve.resetPassword,
    primaryKey: const ValueKey<String>('forgot-submit'),
    anchor: _key('forgot-email'),
    hasBack: true,
    pump: (tester, {required size, required scale}) => pumpAgentScreen(
      tester,
      const ForgotPasswordScreen(),
      path: '/forgot-password',
      size: size,
      textScale: scale,
      overrides: <Override>[
        ...agentBaseOverrides(db: agentTestDb(), skin: SkinMode.night),
        entrySkinProvider.overrideWith(() => PinnedEntrySkin(SkinMode.night)),
        passwordRepositoryProvider.overrideWithValue(FakePasswordRepository()),
      ],
      extraRoutes: <GoRoute>[namedRoute('/login', 'LOGIN')],
    ),
  ),
];

/// The door, in the fold group only. It is the screen the other three are
/// being brought alongside, so the claim that the commit is pinned and on
/// screen is worth asserting on all four together rather than on three and a
/// memory of the fourth.
final _signIn = _Screen(
  name: 'sign-in',
  reserve: EntryPlateReserve.door,
  primaryKey: const ValueKey<String>('login-submit'),
  anchor: _key('login-email'),
  hasBack: false,
  pump: (tester, {required size, required scale}) => pumpEntryScreen(
    tester,
    const LoginScreen(),
    size: size,
    textScale: scale,
    overrides: entryBaseOverrides(db: entryTestDb(), skin: SkinMode.night),
    extraRoutes: <GoRoute>[
      namedRoute('/forgot-password', 'FORGOT'),
      namedRoute('/today', 'TODAY'),
    ],
  ),
);
