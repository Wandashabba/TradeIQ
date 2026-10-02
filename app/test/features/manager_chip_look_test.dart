import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/features/users/presentation/users_screen.dart';

import 'agent_harness.dart' show loadAgentFonts;
import 'clientadmin_harness.dart' show pumpConsole, sessionAs;
import 'users/users_fakes.dart';
import 'visits/visit_harness.dart';

/// THE MANAGER SIDE OF THE CHIP CHANGE, RENDERED.
///
/// `TiqChip` and its two families are reachable from about fifteen manager
/// files, and the constraint on #484 is that the manager side must not change
/// how it *renders* — which is proved for The Floor, Tasks and Ask by
/// pixel-diffing their existing look harnesses and finding all twenty-six
/// images byte-identical. Those three carry no `TiqChip` at all.
///
/// The other manager screens **do** move, and "the manager side must not
/// change" cannot honestly be claimed for them, so this file photographs the
/// two that carry the most of it, at the size and in the typefaces every
/// other look harness uses:
///
/// | screen | what it carries |
/// |---|---|
/// | the visit review | `FlagChip` ×3, `StatusChip`, `SectionStateGlyph` |
/// | users | `StatusChip` in every roster row, `ChoiceRow` in the role sheet |
///
/// Between them that is all four widgets this change touches, on the manager
/// side, so the images answer "what did this do to the console" rather than
/// leaving it to a reviewer's imagination.
///
/// Gated and out of CI for the reason `floor_look_test.dart` gives: CI
/// rasterises anti-aliased Schibsted Grotesk differently from macOS, and a pixel
/// comparison that fails on the day it lands gets skipped within a week.
/// These are artefacts to look at, not regression pins.
///
/// ```sh
/// MANAGER_CHIP_LOOK=1 MANAGER_CHIP_LOOK_DIR=/somewhere/ flutter test \
///   test/features/manager_chip_look_test.dart --update-goldens
/// ```
///
/// `MANAGER_CHIP_LOOK_DIR` is joined to the file name with **no separator**,
/// exactly as `AGENT_LOOK_DIR` is, so it needs its trailing slash.
void main() {
  final looking = Platform.environment['MANAGER_CHIP_LOOK'] == '1';
  final dir = Platform.environment['MANAGER_CHIP_LOOK_DIR'] ?? 'goldens/';

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  /// The same phone every other look harness in this repository uses, so a
  /// difference between two pictures is a difference between two screens.
  const phone = Size(390, 844);

  const skins = <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ];

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byKey(const ValueKey<String>('amber-golden-boundary')),
    matchesGoldenFile('$dir$name.png'),
  );

  group('the visit review', () {
    for (final (name, mode) in skins) {
      // THE CLEAN VISIT, at the top of the scroll. `submittedVisit()` passes
      // its geofence, is not a draft and has no pin dispute, so it renders no
      // flag chips at all — which makes this pair the control: it is
      // byte-identical before and after, and it is the fold a manager
      // actually lands on.
      testWidgets('manager_70_visit_review_$name', (tester) async {
        await pumpVisit(
          tester,
          detail: submittedVisit(),
          skin: TiqSkin.of(mode),
          size: phone,
        );
        await shot(tester, 'manager_70_visit_review_$name');
      }, skip: !looking);

      // THE FLAGGED VISIT. Out of fence with a distance and a reported pin —
      // two of the three flag chips, plus the score's status chip — so there
      // is something in the picture to judge.
      testWidgets('manager_72_visit_review_flagged_$name', (tester) async {
        await pumpVisit(
          tester,
          detail: submittedVisit(
            geofencePass: false,
            distanceM: 142.0,
            pinDispute: const VisitPinDispute(
              id: 'd1',
              distanceM: 142,
              status: 'applied',
              note: 'The pin is on the wrong side of the road',
              resolvedByLabel: 'Nomsa D.',
            ),
          ),
          skin: TiqSkin.of(mode),
          size: phone,
        );
        await shot(tester, 'manager_72_visit_review_flagged_$name');
      }, skip: !looking);
    }
  });

  group('users', () {
    for (final (name, mode) in skins) {
      testWidgets('manager_71_users_$name', (tester) async {
        await pumpConsole(
          tester,
          const UsersScreen(),
          skin: TiqSkin.of(mode),
          size: phone,
          path: '/users',
          overrides: <Override>[
            usersRepositoryProvider.overrideWithValue(FakeUsersRepository()),
            sessionAs('admin'),
          ],
        );
        await shot(tester, 'manager_71_users_$name');
      }, skip: !looking);
    }
  });
}

/// Material's icon font, so a chevron is a chevron and not a tofu box.
/// Silent if the SDK keeps it somewhere else — see `tasks_look_test.dart`.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader('MaterialIcons')
        ..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer))))
      .load();
}
