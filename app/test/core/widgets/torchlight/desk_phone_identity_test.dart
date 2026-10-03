import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

import '../../../features/assistant/ask_harness.dart';
import '../../../features/dashboard/floor_harness.dart';
import 'console_desk_harness.dart';

/// ── THE PHONE DID NOT MOVE, AND HERE IS THE EVIDENCE ───────────────────
///
/// > *"don't touch mobile as it is perfect"* — the owner.
///
/// Below [ConsoleDesk.deskMinWidth] nothing changes. That is a claim about
/// pixels, and the only honest way to hold it is to render the same screens at
/// the same sizes on `main` and on the branch and compare the **files**.
///
/// This file writes those renders and nothing else. It is deliberately
/// written so it compiles on `main` as well — it uses only harness entry
/// points that existed before this change — so the same file can be dropped
/// into a worktree of `main`, run, and the two directories hashed:
///
/// ```sh
/// PHONE_LOOK=1 PHONE_LOOK_DIR=/tmp/phone-main/ flutter test \
///   test/core/widgets/torchlight/desk_phone_identity_test.dart \
///   --update-goldens
/// # … and the same on the branch into /tmp/phone-branch/, then
/// shasum -a 256 /tmp/phone-main/* /tmp/phone-branch/*
/// ```
///
/// **Any difference at all is a bug in the change, not an improvement.**
///
/// The four screens are not arbitrary. Exceptions and Webhooks are lists of
/// `SoftRow`s, which is what `TorchBleed` serves and therefore what the gutter
/// change could have moved. The Floor and Ask are the two routes that grew a
/// desk of their own in this change and so had their `build` rewritten — the
/// two most likely places for a phone pixel to move by accident.
///
/// It is skipped unless `PHONE_LOOK=1`, for `floor_look_test.dart`'s reason:
/// CI rasterises Schibsted Grotesk differently from macOS, so a committed
/// pixel comparison fails on the day it lands.
void main() {
  final looking = Platform.environment['PHONE_LOOK'] == '1';
  final dir = Platform.environment['PHONE_LOOK_DIR'] ?? 'goldens/phone/';

  setUpAll(() async {
    await loadDeskFonts();
    await loadDeskIcons();
  });

  const phones = <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ];

  for (final (skinName, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night()),
    ('day', TiqSkin.day()),
  ]) {
    for (final (name, size) in phones) {
      testWidgets('Exceptions at $name $skinName', (tester) async {
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
          matchesGoldenFile('${dir}phone_alerts_${name}_$skinName.png'),
        );
      }, skip: !looking);

      testWidgets('Webhooks at $name $skinName', (tester) async {
        await pumpDesk(
          tester,
          const WebhooksScreen(),
          size: size,
          skin: skin,
          path: '/webhooks',
          overrides: deskWebhookOverrides(),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('amber-golden-boundary')),
          matchesGoldenFile('${dir}phone_webhooks_${name}_$skinName.png'),
        );
      }, skip: !looking);

      testWidgets('The Floor at $name $skinName', (tester) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          size: size,
          skin: skin,
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
          plateImage: await SyncImage.fromFile(
            tester,
            '../backend/assets/places/ALL.jpg',
          ),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('amber-golden-boundary')),
          matchesGoldenFile('${dir}phone_floor_${name}_$skinName.png'),
        );
      }, skip: !looking);

      testWidgets('Ask at $name $skinName', (tester) async {
        await pumpAsk(tester, size: size, skin: skin);
        await expectLater(
          find.byKey(askBoundaryKey),
          matchesGoldenFile('${dir}phone_ask_${name}_$skinName.png'),
        );
      }, skip: !looking);
    }
  }
}
