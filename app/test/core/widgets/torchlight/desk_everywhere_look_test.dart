import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

import '../../../features/assistant/ask_harness.dart';
import '../../../features/dashboard/floor_harness.dart';
import 'console_desk_harness.dart';

/// ── THE DESK EVERYWHERE, RENDERED, SO SOMEBODY CAN LOOK AT IT ──────────
///
/// > *"Please make the floor desktop as well follow that artifact I gave
/// > please, you doing your own things and I dont like it."*
/// > *"You also not fully changing to desktop theres things cut, please fix…
/// > Dont be choosy make the app desktop everywhere and don't touch mobile as
/// > it is perfect"* — the owner, 3 October 2026.
///
/// `console_desk_look_test.dart` photographs the three-pane console at the two
/// widths the first desk was signed off at. This file is the set the owner's
/// second reading asked for and that one does not have:
///
/// | image | what it has to get right |
/// |---|---|
/// | `floor` | The Floor **has** a desk: rail, plate full width of the column, briefing under it, composer at the column's foot, and no app header |
/// | `ask` | Ask has one too: rail, transcript in the column, composer at its foot |
/// | `list-selected` | three panes with a record open, the bar the width of the detail column |
/// | `list-at-rest` | three panes with nothing chosen — at rest, not empty |
/// | `non-list` | a genuinely non-list route: rail and one column that **fills** |
///
/// **1920×1080 is in the set because the owner's own window is about that
/// wide**, and it is the width at which the old 8 : 11 split left a quarter of
/// the screen as ground beside a 440dp column. 1280×900 is the narrowest
/// approved desk; 1440×900 is the one the first desk was signed off at.
///
/// Both skins, every row. Thirty images, of which **the 1920×1080 ten and the
/// four phone frames are committed** and the 1440 and 1280 twenty are not: the
/// whole set is 13MB against a repository that carries 11MB of goldens in
/// total, and one command regenerates any of them. 1920 is the committed width
/// because it is the one the owner opened; the phone four are committed
/// because *"don't touch mobile"* is a claim somebody has to be able to check.
/// `console_desk_look_test.dart` keeps the 1440 and 1280 three-pane set that
/// #517 was signed off on, regenerated here.
///
/// ## Why it does not run in CI
///
/// `floor_look_test.dart`'s reason, unchanged: CI rasterises anti-aliased
/// Schibsted Grotesk on `ubuntu-latest` and this repository is developed on
/// macOS, so a pixel comparison fails on the day it lands and is skipped
/// within a week. These are artefacts to **look at**; the pins are the
/// measurements in `console_desk_test.dart`, `desk_clipping_test.dart` and
/// `console_wash_test.dart`, which do run everywhere.
///
/// ```sh
/// DESK_LOOK=1 flutter test \
///   test/core/widgets/torchlight/desk_everywhere_look_test.dart \
///   --update-goldens
/// ```
///
/// `DESK_LOOK_DIR` sends them somewhere else without touching the committed
/// set.
void main() {
  final looking = Platform.environment['DESK_LOOK'] == '1';
  final dir = Platform.environment['DESK_LOOK_DIR'] ?? 'goldens/';

  setUpAll(() async {
    await loadDeskFonts();
    await loadDeskIcons();
  });

  const sizes = <(String, Size)>[
    ('1440x900', Size(1440, 900)),
    ('1280x900', Size(1280, 900)),
    ('1920x1080', Size(1920, 1080)),
  ];

  for (final (skinName, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night()),
    ('day', TiqSkin.day()),
  ]) {
    for (final (name, size) in sizes) {
      // ── THE FLOOR, WHICH HAD NO DESK AT ALL ──────────────────────────
      testWidgets('The Floor at $name $skinName', (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          size: size,
          skin: skin,
          // The rail asks the router which destination it is standing on.
          // See `pumpFloor`'s `path`.
          path: '/dashboard',
          current: kpis(osa: 61, execution: 73, priceCompliance: 74),
          previous: kpis(osa: 64, execution: 92),
          alerts: <AlertItem>[
            alert(
              id: 'a1',
              outletId: 'o1',
              message:
                  'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
              createdAt: DateTime.utc(2026, 9, 16, 9, 6),
            ),
          ],
          outlets: <Outlet>[
            outlet('o1', 'SaveMor Glenwood'),
            outlet('o2', 'Shoprite Klipspruit Mall'),
          ],
          territories: const <Territory>[],
          plateImage: await SyncImage.fromFile(
            tester,
            '../backend/assets/places/ALL.jpg',
          ),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('amber-golden-boundary')),
          matchesGoldenFile('${dir}desk_floor_${name}_$skinName.png'),
        );
      }, skip: !looking);

      // ── ASK, WHICH HAD NONE EITHER ───────────────────────────────────
      testWidgets('Ask at $name $skinName', (tester) async {
        await pumpAsk(tester, size: size, skin: skin);
        await expectLater(
          find.byKey(askBoundaryKey),
          matchesGoldenFile('${dir}desk_ask_${name}_$skinName.png'),
        );
      }, skip: !looking);

      // ── A THREE-PANE LIST, OPEN AND AT REST ──────────────────────────
      for (final selected in <bool>[true, false]) {
        testWidgets(
          'Exceptions at $name $skinName, '
          '${selected ? "a record open" : "at rest"}',
          (tester) async {
            await pumpDesk(
              tester,
              const AlertsScreen(),
              size: size,
              skin: skin,
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
                '${dir}desk_list_${name}_$skinName'
                '-${selected ? "selected" : "at-rest"}.png',
              ),
            );
          },
          skip: !looking,
        );
      }

      // ── AND A ROUTE THAT IS GENUINELY NOT A LIST ─────────────────────
      //
      // Trends is three chart panels. Its `_BenchmarkRow`s exist only to pick
      // which series the chart below draws — selecting one changes the chart
      // *in place*, which is the one shape a detail pane would be a second
      // copy of. It gets the rail and one column, and since 3 October 2026
      // that column **fills** what is left after the rail instead of sitting
      // capped and centred with ground on both sides.
      testWidgets('Trends at $name $skinName, one column', (tester) async {
        await pumpDesk(
          tester,
          const TrendsScreen(),
          size: size,
          skin: skin,
          path: '/trends',
          overrides: deskTrendOverrides(),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('amber-golden-boundary')),
          matchesGoldenFile('${dir}desk_nonlist_${name}_$skinName.png'),
        );
      }, skip: !looking);
    }

    // ── AND THE TWO PHONES, WHICH MUST NOT HAVE MOVED ──────────────────
    //
    // `desk_phone_identity_test.dart` is the proof; these are the pictures
    // that go with it.
    for (final (name, size) in <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('Exceptions at $name $skinName, the phone', (tester) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: size,
          skin: skin,
          path: '/alerts',
          overrides: deskAlertOverrides(),
          users: deskPeople(),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('amber-golden-boundary')),
          matchesGoldenFile('${dir}desk_phone_${name}_$skinName.png'),
        );
      }, skip: !looking);
    }
  }
}
