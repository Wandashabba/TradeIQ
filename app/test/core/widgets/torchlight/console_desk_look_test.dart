import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

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
/// | `1440x900-column` | a NON-list route: rail + one centred column, no third pane |
/// | `390x844-phone` | the phone, **unchanged** — the before/after pair's "after" |
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
            overrides: deskAlertOverrides(),
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

    // ── THE NON-LIST SET: rail + one centred column ────────────────────
    //
    // Webhooks, which the brief names as a screen that is not a list of
    // records in the sense the third pane needs: its rows expand in place and
    // have no detail destination at all. It passes no desk and gets no diff,
    // which is the image.
    testWidgets('Webhooks at 1440x900 $skinName, one column', (tester) async {
      await pumpDesk(
        tester,
        const WebhooksScreen(),
        size: const Size(1440, 900),
        skin: skin,
        textScale: scale,
        path: '/webhooks',
        overrides: deskWebhookOverrides(),
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
