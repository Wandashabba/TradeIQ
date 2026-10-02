import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/torch_shell.dart';

/// NOTHING MAY SIT UNDER THE SYSTEM BAR.
///
/// This test exists because the whole design was measured on a surface that
/// does not have one. A `flutter test` viewport reports `padding.top == 0`,
/// and so does a browser — so every golden, every look render and every
/// declared-geometry measurement in this repository was taken where this inset
/// is zero. The defect was therefore invisible in all of them and present on
/// every phone: on 30 September 2026 the owner installed the Android build and
/// the sign-in wordmark was behind the clock and the battery meter.
///
/// The fix is one term in `TorchShell` and one in `TiqPlate`. The reason it
/// needs a test of its own is that **no existing test can fail on it** — they
/// all run at zero inset, where the correct code and the broken code are
/// indistinguishable. A test that only ever runs at zero is not a weaker
/// version of this test; it is a test of a different screen.
///
/// So this one *simulates a device*: a real `MediaQuery.padding.top`, the
/// value an Android status bar actually reports.
void main() {
  /// A Galaxy S10e's status bar, which is the phone the defect was found on.
  const statusBar = 44.0;

  Widget shell({required double topInset, required bool bleedTop}) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
      ).copyWith(padding: EdgeInsets.only(top: topInset)),
      child: Theme(
        data: ThemeData(extensions: <ThemeExtension<dynamic>>[TiqSkin.night()]),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TorchShell(
            profile: TorchShellProfile.agent,
            bleedTop: bleedTop,
            children: <Widget>[
              const SizedBox(
                key: ValueKey<String>('first-thing'),
                height: 40,
                width: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('content clears the status bar, and moves with it', (
    tester,
  ) async {
    await tester.pumpWidget(shell(topInset: 0, bleedTop: false));
    final atZero = tester
        .getTopLeft(find.byKey(const ValueKey<String>('first-thing')))
        .dy;

    await tester.pumpWidget(shell(topInset: statusBar, bleedTop: false));
    final onADevice = tester
        .getTopLeft(find.byKey(const ValueKey<String>('first-thing')))
        .dy;

    // The whole point: the two must NOT be equal. Before the fix they were,
    // which is why every test in this repository passed while the app put a
    // title behind the clock.
    expect(
      onADevice - atZero,
      closeTo(statusBar, 0.5),
      reason:
          'The first thing on the screen did not move when a status bar '
          'appeared. It is sitting under it. Every other test in this '
          'repository runs at padding.top = 0 and cannot see this.',
    );
  });

  testWidgets('bleedTop still bleeds — the picture may run under the bar', (
    tester,
  ) async {
    await tester.pumpWidget(shell(topInset: statusBar, bleedTop: true));
    final top = tester
        .getTopLeft(find.byKey(const ValueKey<String>('first-thing')))
        .dy;

    // `bleedTop` exists so a photographic plate can reach y=0. That is a
    // deliberate shape and the inset must not quietly undo it — the plate's
    // own TYPE is what steps down, inside the plate, not the plate itself.
    expect(
      top,
      closeTo(0, 0.5),
      reason:
          'bleedTop stopped bleeding. The plate is meant to run under the '
          'system bar; only the type on it steps clear.',
    );
  });
}
