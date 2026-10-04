import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/beatplans/presentation/beatplans_screen.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

// THE NON-LIST ROUTE'S OWN FAKES, reused rather than re-invented. Prefixed
// because that harness exports a dozen record types and two of them share a
// name with `worklist_harness.dart`'s.
import '../../../features/dashboard/overview_harness.dart' as oh;
import 'console_desk_harness.dart';

/// THE CONSOLE AT A DESK, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// > *"it should be very seamless and smooth and highest quality product and
/// > UI/UX matching with the mobile app"* — the owner.
///
/// Every other test in this group asserts a number. This one produces the
/// images the owner and the reviewer compare against mockup C, with
/// **Schibsted Grotesk, JetBrains Mono and the Material icon font loaded** —
/// the test font is wider, so a desk rendered in it wraps sooner, measures
/// taller and is a picture of the wrong screen.
///
/// The set, and what each image is for:
///
/// | image | what it has to get right |
/// |---|---|
/// | `1440x900-selected` | three panes, a record open, the bar in the detail pane |
/// | `1440x900-at-rest` | the detail pane reading **at rest**, not empty |
/// | `1280x900-selected` | the same at the narrower of the two approved widths |
/// | `1920x1080-selected` | the same on a full-HD desktop |
/// | `1440x900-column` | a NON-list route — the **Perfect Store scorecard**: rail + one column that fills, no third pane |
/// | `390x844-phone` | the phone, **unchanged** — the before/after pair's "after" |
///
/// And since 4 October 2026, the two frames the owner's two defects are
/// judged on:
///
/// | image | the question it answers |
/// |---|---|
/// | `foot-shut` | **can somebody find the theme control in under two seconds without being told where it is?** The rail's account row, at rest |
/// | `foot-open` | the brightness, the password and Sign out, one press from any desk screen |
/// | `webhooks-toolbar` | a list screen whose marker carries no verb, so the relocated refresh is alone on the toolbar row — the hardest case for defect 2 |
///
/// Both skins, every row. The phone pair is in the set because "below the
/// threshold nothing changes" is a claim about pixels and the only honest way
/// to hold it is to render the same screen at 390×844 on this branch and on
/// `main` and compare the two files.
///
/// ## Why it does not run in CI
///
/// `floor_look_test.dart`'s reason, unchanged: CI rasterises anti-aliased
/// Schibsted Grotesk on `ubuntu-latest` and this repository is developed on
/// macOS, so a pixel comparison fails on the day it lands and is skipped
/// within a week. These are artefacts to **look at**; the pins are the
/// measurements in `console_desk_test.dart` and
/// `console_wash_contrast_test.dart`, which do run everywhere.
///
/// Regenerate with:
///
/// ```sh
/// DESK_LOOK=1 flutter test \
///   test/core/widgets/torchlight/console_desk_look_test.dart --update-goldens
/// ```
///
/// `DESK_LOOK_DIR` sends them somewhere else — a scratch folder, without
/// touching the committed set. `DESK_LOOK_SCALE=1.3` shoots the same frames at
/// the text scale a cheap Android ships with the slider nudged once; the scale
/// travels into the filename so the two sets never collide.
void main() {
  final looking = Platform.environment['DESK_LOOK'] == '1';
  final dir = Platform.environment['DESK_LOOK_DIR'] ?? 'goldens/';
  final scale = _scale();
  final sfx = scale == 1.0 ? '' : '-${scale.toStringAsFixed(1)}x';

  setUpAll(() async {
    await loadDeskFonts();
    await loadDeskIcons();
  });

  for (final (skinName, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night()),
    ('day', TiqSkin.day()),
  ]) {
    // ── THE THREE-PANE SET ────────────────────────────────────────────
    for (final (name, size) in <(String, Size)>[
      ('1440x900', Size(1440, 900)),
      ('1280x900', Size(1280, 900)),
      ('1920x1080', Size(1920, 1080)),
    ]) {
      for (final selected in <bool>[true, false]) {
        testWidgets('Exceptions at $name $skinName, '
            '${selected ? "a record open" : "at rest"}', (tester) async {
          await pumpDesk(
            tester,
            const AlertsScreen(),
            size: size,
            skin: skin,
            textScale: scale,
            path: '/alerts',
            // THE FOOT HAS SOMEBODY IN IT. Without this the real
            // `SessionController` runs, finds no keychain under
            // `flutter_test`, and the account row photographs its signed-out
            // form — which is a state the product does not reach.
            overrides: <Override>[...deskAlertOverrides(), ...deskSession()],
            users: deskPeople(),
          );
          if (selected) {
            await tester.tap(
              find.byKey(const ValueKey<String>('console-record-a2')),
            );
            await tester.pumpAndSettle();
          }
          await expectLater(
            find.byKey(const ValueKey<String>('amber-golden-boundary')),
            matchesGoldenFile(
              '${dir}desk_${name}_$skinName'
              '-${selected ? "selected" : "at-rest"}$sfx.png',
            ),
          );
        }, skip: !looking);
      }
    }


    // ── THE RAIL'S FOOT, WHICH IS DEFECT 1 ─────────────────────────────
    //
    // > *"I cant see theme change on desktop"* — the owner.
    //
    // The pair that has to be looked at rather than measured. `foot-shut` is
    // the question: is there anything on this screen a manager would press to
    // change the brightness, without being told? `foot-open` is the answer it
    // gives when they press it.
    for (final (name, size) in <(String, Size)>[
      ('1440x900', Size(1440, 900)),
      ('1920x1080', Size(1920, 1080)),
    ]) {
      for (final open in <bool>[false, true]) {
        testWidgets('the rail\'s foot at $name $skinName, '
            '${open ? "open" : "shut"}', (tester) async {
          await pumpDesk(
            tester,
            const AlertsScreen(),
            size: size,
            skin: skin,
            textScale: scale,
            path: '/alerts',
            overrides: <Override>[...deskAlertOverrides(), ...deskSession()],
            users: deskPeople(),
          );
          if (open) {
            await tester.tap(
              find.byKey(const ValueKey<String>('rail-account')),
            );
            await tester.pumpAndSettle();
          }
          await expectLater(
            find.byKey(const ValueKey<String>('amber-golden-boundary')),
            matchesGoldenFile(
              '${dir}desk_${name}_$skinName'
              '-foot-${open ? "open" : "shut"}$sfx.png',
            ),
          );
        }, skip: !looking);
      }
    }

    // ── THE RELOCATED REFRESH, WHICH IS DEFECT 2 ───────────────────────
    //
    // Webhooks rather than Beat plans, deliberately: its marker carries **no
    // verb**, so this is the frame where the lifted control has only the
    // count and the row for company. If the fix reads as a floating artefact
    // anywhere, it reads as one here.
    testWidgets('Webhooks toolbar at 1440x900 $skinName', (tester) async {
      await pumpDesk(
        tester,
        const WebhooksScreen(),
        size: const Size(1440, 900),
        skin: skin,
        textScale: scale,
        path: '/webhooks',
        overrides: <Override>[...deskWebhookOverrides(), ...deskSession()],
      );
      await tester.tap(find.byKey(const ValueKey<String>('console-record-w1')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}desk_1440x900_$skinName-toolbar$sfx.png'),
      );
    }, skip: !looking);

    // ── BEAT PLANS, THE SCREEN THE OWNER WAS LOOKING AT ────────────────
    //
    // Its toolbar row is the one with both halves — `PLANS · 3` and the
    // list's own verb — so this is the frame that shows the refresh where the
    // brief asked for it: with the count and the verbs.
    testWidgets('Beat plans toolbar at 1440x900 $skinName', (tester) async {
      await pumpDesk(
        tester,
        const BeatPlansScreen(),
        size: const Size(1440, 900),
        skin: skin,
        textScale: scale,
        path: '/beatplans',
        overrides: <Override>[...deskBeatPlanOverrides(), ...deskSession()],
      );
      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}desk_1440x900_$skinName-beatplans$sfx.png'),
      );
    }, skip: !looking);

    // ── THE NON-LIST SET: rail + one column that fills ─────────────────
    //
    // IT USED TO BE WEBHOOKS, AND WEBHOOKS IS NOW A LIST. The old image was
    // captioned "a screen that is not a list of records … its rows expand in
    // place and have no detail destination at all", and the expanding is what
    // disproved it: the thing those rows expand to show is the delivery log,
    // which is a detail pane. Webhooks passes a `ConsoleDeskRecords` now, so
    // the one-column shape needs a route that genuinely has no record to
    // select — the **Perfect Store scorecard**: a figure block, a trend and
    // two lists of cards. It passes no desk and gets no diff, which is the
    // image.
    //
    // **The committed `-column` pair is still the old screen** until somebody
    // regenerates the set with the command in this file's comment. It is an
    // artefact to look at rather than a pin, and `console_desk_test.dart` is
    // where the one-column geometry is actually asserted.
    testWidgets('Perfect Store at 1440x900 $skinName, one column', (
      tester,
    ) async {
      await pumpDesk(
        tester,
        const DashboardShellScreen(),
        size: const Size(1440, 900),
        skin: skin,
        textScale: scale,
        path: '/dashboard/overview',
        // The scorecard's own fakes, reused rather than re-invented.
        overrides: oh.overviewOverrides(
          current: oh.kpis(),
          previous: oh.kpis(execution: 66),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}desk_1440x900_$skinName-column$sfx.png'),
      );
    }, skip: !looking);

    // ── AND THE PHONE, WHICH MUST NOT HAVE MOVED ───────────────────────
    testWidgets('Exceptions at 390x844 $skinName, the phone', (tester) async {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(390, 844),
        skin: skin,
        textScale: scale,
        path: '/alerts',
        // NOT `deskSession`, and that is the point of this frame: it is
        // compared byte for byte against `main`, so it must pump exactly what
        // `main` pumps. The phone has no rail and therefore no foot.
        overrides: deskAlertOverrides(),
        users: deskPeople(),
      );
      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}desk_390x844_$skinName-phone$sfx.png'),
      );
    }, skip: !looking);
  }
}

double _scale() =>
    double.tryParse(Platform.environment['DESK_LOOK_SCALE'] ?? '') ?? 1.0;
