// TEMPORARY — not committed. Renders The Floor, Today and Ask TradeIQ in
// Night and Day with the real typefaces loaded, so the before and after of the
// Veld removal can be compared pixel for pixel.
//
//   VELD_PROOF=1 flutter test test/veld_proof_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'features/agent_harness.dart';
import 'features/assistant/ask_harness.dart';
import 'features/dashboard/floor_harness.dart';

void main() {
  final looking = Platform.environment['VELD_PROOF'] == '1';

  setUpAll(loadAgentFonts);

  const size = Size(390, 844);

  final outlets = <Outlet>[
    outlet('o1', 'SaveMor Glenwood'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
    outlet('o3', 'Kasi Corner Spaza'),
    outlet('o4', 'Pick n Pay Rosebank'),
    outlet('o5', 'Corner Express Parkhurst'),
  ];

  final decisions = <AlertItem>[
    alert(
      id: 'a1',
      outletId: 'o1',
      message: 'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
      createdAt: DateTime.utc(2026, 9, 16, 9, 6),
    ),
    alert(
      id: 'a2',
      severity: 'warning',
      outletId: 'o2',
      message: 'Price above the published band for the third week running',
      createdAt: DateTime.utc(2026, 9, 16, 12),
    ),
    alert(
      id: 'a3',
      outletId: 'o3',
      message: 'Planogram compliance under 50 percent on the main aisle',
      createdAt: DateTime.utc(2026, 9, 17, 6),
    ),
  ];

  // ── The Floor, Night × Console and Day × Console ─────────────────────
  for (final (name, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night(density: TiqDensity.console)),
    ('day', TiqSkin.day(density: TiqDensity.console)),
  ]) {
    testWidgets('The Floor — $name', (tester) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        size: size,
        skin: skin,
        alerts: decisions,
        outlets: outlets,
        now: DateTime.utc(2026, 9, 18, 9),
      );
      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('veld_proof/floor_$name.png'),
      );
    }, skip: !looking);
  }

  // ── Today, Night × Field and Day × Field ─────────────────────────────
  for (final (name, mode) in <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ]) {
    testWidgets('Today — $name', (tester) async {
      await pumpAgentScreen(
        tester,
        const TodayScreen(),
        size: size,
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          todayRouteProvider.overrideWith((ref) async => _today()),
        ],
      );
      await expectLater(
        find.byKey(agentBoundaryKey),
        matchesGoldenFile('veld_proof/today_$name.png'),
      );
    }, skip: !looking);
  }

  // ── Ask TradeIQ, Night × Console and Day × Console ───────────────────
  for (final (name, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night(density: TiqDensity.console)),
    ('day', TiqSkin.day(density: TiqDensity.console)),
  ]) {
    testWidgets('Ask TradeIQ — $name', (tester) async {
      await pumpAsk(
        tester,
        skin: skin,
        size: size,
        repository: ScriptedRepository(rankedTurn()),
      );
      await ask(tester, 'Which outlets ran out most often?');
      await expectLater(
        find.byKey(askBoundaryKey),
        matchesGoldenFile('veld_proof/ask_$name.png'),
      );
    }, skip: !looking);
  }
}

TodayRoute _today() => TodayRoute(
  planName: 'Tembisa run',
  hasLocation: true,
  stops: <RouteStop>[
    for (var i = 0; i < 4; i++)
      RouteStop(
        sequence: 1 + i,
        outlet: Outlet(
          id: 'done$i',
          name: 'Khumalo Superette $i',
          code: 'KS-01$i',
          lat: 0,
          lng: 0,
        ),
        visited: true,
        distanceMeters: 900.0 + i * 300,
      ),
    RouteStop(
      sequence: 5,
      outlet: Outlet(
        id: 'kasi',
        name: 'Kasi Corner Spaza',
        code: 'KC-0412',
        lat: 0,
        lng: 0,
      ),
      visited: false,
      distanceMeters: 420,
    ),
    for (var i = 0; i < 4; i++)
      RouteStop(
        sequence: 6 + i,
        outlet: Outlet(
          id: 'rest$i',
          name: 'Pick n Pay Vosloorus $i',
          code: 'PP-02$i',
          lat: 0,
          lng: 0,
        ),
        visited: false,
        distanceMeters: 2100.0 + i * 400,
      ),
  ],
);
