import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/sales_targets/data/sales_targets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

import '../agent_harness.dart';
import '../assistant/ask_harness.dart';
import '../dashboard/floor_harness.dart' as fh;
import '../dashboard/overview_harness.dart' as oh;

/// THE FOUR SCREENS THAT CARRY FIGURES, IN BOTH GROUNDS, SO THE COLOUR CAN BE
/// LOOKED AT.
///
/// `floor_look_test.dart` and `overview_look_test.dart` each render one screen
/// in the skin that screen was designed in. This renders **The Floor, the
/// Execution overview, Today and Ask TradeIQ in Night *and* Day**, side by
/// side, with Schibsted Grotesk and JetBrains Mono loaded — because the question this
/// batch answers is not "does one screen look right" but "does a figure that
/// carries a judgement read as one, on both grounds". Day is the point: the
/// owner's note was written looking at Day, where the whole screen was one
/// navy ink.
///
/// ## Why it does not run in CI
///
/// The reason its two siblings give: CI rasterises anti-aliased Schibsted Grotesk on
/// `ubuntu-latest` and this repository is developed on macOS, so a pixel
/// comparison fails on the day it lands and gets skipped within a week. The
/// images are an artefact to *look at*; the pins are the measurements in the
/// screens' own tests and in `torchlight_contrast_test.dart`, which do run
/// everywhere.
///
/// ```sh
/// COLOUR_LOOK=1 COLOUR_LOOK_DIR=/somewhere/ flutter test \
///   test/features/goldens/colour_look_test.dart --update-goldens
/// ```
void main() {
  final looking = Platform.environment['COLOUR_LOOK'] == '1';
  final dir = Platform.environment['COLOUR_LOOK_DIR'] ?? 'goldens/';

  // flutter_map 8 asks path_provider for the OS cache directory the first time
  // a tile layer builds, and the overview carries the agent map. Same stub,
  // same reason, as `overview_look_test.dart`.
  late final Directory cacheDir;
  setUpAll(() async {
    cacheDir = Directory.systemTemp.createTempSync('colour-look-tiles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cacheDir.path,
        );
    await loadAgentFonts();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  const skins = <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ];

  TiqSkin console(SkinMode mode) => mode == SkinMode.night
      ? TiqSkin.night(density: TiqDensity.console)
      : TiqSkin.day(density: TiqDensity.console);

  // ── 1. The Floor ────────────────────────────────────────────────────
  final decisions = <AlertItem>[
    fh.alert(
      id: 'a1',
      outletId: 'o1',
      photoId: 'p1',
      message: 'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
      createdAt: DateTime.utc(2026, 9, 16, 9, 6),
    ),
    fh.alert(
      id: 'a2',
      severity: 'warning',
      outletId: 'o2',
      message: 'Price above the published band for the third week running',
      createdAt: DateTime.utc(2026, 9, 16, 12),
    ),
    fh.alert(
      id: 'a3',
      outletId: 'o3',
      message: 'Planogram compliance under 50 percent on the main aisle',
      createdAt: DateTime.utc(2026, 9, 17, 6),
    ),
    fh.alert(
      id: 'a4',
      severity: 'warning',
      outletId: 'o4',
      message: 'Competitor facings doubled since the last visit',
      createdAt: DateTime.utc(2026, 9, 17, 14),
    ),
    fh.alert(
      id: 'a5',
      severity: 'warning',
      outletId: 'o5',
      message: 'Shelf talker missing on the promotional end cap',
      createdAt: DateTime.utc(2026, 9, 18, 8),
    ),
  ];

  final floorOutlets = <Outlet>[
    fh.outlet('o1', 'SaveMor Glenwood'),
    fh.outlet('o2', 'Shoprite Klipspruit Mall'),
    fh.outlet('o3', 'Kasi Corner Spaza'),
    fh.outlet('o4', 'Pick n Pay Rosebank'),
    fh.outlet('o5', 'Corner Express Parkhurst'),
  ];

  for (final (name, mode) in skins) {
    testWidgets('The Floor — $name', (tester) async {
      await fh.pumpFloor(
        tester,
        const TheFloorScreen(),
        size: const Size(390, 844),
        skin: console(mode),
        plateImage: await fh.SyncImage.fromFile(
          tester,
          '../backend/assets/places/ALL.jpg',
        ),
        // The owner's figures: health 73 against the published 75, and
        // availability 61 against the published 95.
        current: fh.kpis(osa: 61, execution: 73, priceCompliance: 74),
        previous: fh.kpis(osa: 64, execution: 92),
        alerts: decisions,
        outlets: floorOutlets,
        extraOverrides: <Override>[
          availabilityTrendProvider.overrideWith(
            (ref) async => const <TrendPoint>[
              TrendPoint(period: '2026-W33', value: 71),
              TrendPoint(period: '2026-W34', value: 68),
              TrendPoint(period: '2026-W35', value: 72),
              TrendPoint(period: '2026-W36', value: 66),
              TrendPoint(period: '2026-W37', value: 64),
              TrendPoint(period: '2026-W38', value: 61),
            ],
          ),
        ],
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}colour_floor_$name.png'),
      );
    }, skip: !looking);
  }

  // ── 2. The Execution overview ───────────────────────────────────────
  const bands = <ScoreBand>[
    ScoreBand(label: 'Excellent', minScore: 90, outlets: 4),
    ScoreBand(label: 'Good', minScore: 75, outlets: 11),
    ScoreBand(label: 'Fair', minScore: 60, outlets: 17),
    ScoreBand(label: 'Poor', minScore: 40, outlets: 8),
    ScoreBand(label: 'Critical', minScore: 0, outlets: 2),
  ];

  const series = <TrendPoint>[
    TrendPoint(period: '2026-W33', value: 71.4, count: 38),
    TrendPoint(period: '2026-W34', value: 68.2, count: 41),
    TrendPoint(period: '2026-W35', value: 72.9, count: 44),
    TrendPoint(period: '2026-W36', value: 66.1, count: 39),
    TrendPoint(period: '2026-W37', value: 64.8, count: 43),
    TrendPoint(period: '2026-W38', value: 69.6, count: 42),
  ];

  for (final (name, mode) in skins) {
    testWidgets('Execution overview — $name', (tester) async {
      await oh.pumpOverview(
        tester,
        const DashboardShellScreen(),
        size: const Size(390, 4200),
        skin: console(mode),
        overrides: oh.overviewOverrides(
          current: oh.kpis(execution: 67.8, bands: bands),
          previous: oh.kpis(execution: 66.0),
          byTerritory: <TerritoryDashboardKpis>[
            TerritoryDashboardKpis(
              territoryId: 'ter-1',
              territoryName: 'Gauteng North',
              kpis: oh.kpis(execution: 58.2),
            ),
            TerritoryDashboardKpis(
              territoryId: 'ter-2',
              territoryName: 'Western Cape',
              kpis: oh.kpis(execution: 81.4),
            ),
          ],
          alerts: <AlertItem>[
            oh.alert(id: 'a1'),
            oh.alert(id: 'a2', metric: 'planogram'),
            oh.alert(id: 'a3', severity: 'warning', metric: 'price_breach'),
          ],
          tasks: <TaskItem>[
            oh.task(id: 't1', priority: 'critical'),
            oh.task(id: 't2'),
          ],
          territories: const <Territory>[oh.north, oh.west],
          outlets: <Outlet>[
            oh.outlet('o1', 'SaveMor Glenwood'),
            oh.outlet('o2', 'Shoprite Klipspruit Mall', lat: -26.3, lng: 28.1),
          ],
          agents: <AgentActivity>[
            oh.agent(
              id: 'ag1',
              name: 'Thabo Mokoena',
              state: AgentState.atStore,
              currentOutlet: 'SaveMor Glenwood',
              lastSeen: DateTime.now().subtract(const Duration(minutes: 12)),
              stops: <AgentStop>[oh.stop('SaveMor Glenwood')],
            ),
            oh.agent(
              id: 'ag2',
              name: 'Naledi Dlamini',
              state: AgentState.inTransit,
              lastSeen: DateTime.now().subtract(const Duration(minutes: 48)),
              stops: <AgentStop>[
                oh.stop('Shoprite Klipspruit Mall', lat: -26.3, lng: 28.1),
              ],
            ),
            oh.agent(id: 'ag3', name: 'Sipho Ndlovu'),
          ],
          trend: series,
          attainment: const SalesAttainmentReport(
            month: '2026-09',
            timeZone: 'Africa/Johannesburg',
            skus: <SkuAttainment>[],
            client: AttainmentLevel(
              targets: 12,
              targetUnits: 48000,
              actualUnits: 41280,
              attainmentPct: 86,
            ),
            territory: AttainmentLevel(
              targets: 5,
              targetUnits: 19000,
              actualUnits: 12730,
              attainmentPct: 67,
            ),
            outlet: AttainmentLevel(
              targets: 31,
              targetUnits: 7400,
              actualUnits: 7548,
              attainmentPct: 102,
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}colour_overview_$name.png'),
      );
    }, skip: !looking);
  }

  // ── 3. Today, the oh.agent's home ──────────────────────────────────────
  for (final (name, mode) in skins) {
    testWidgets('Today — $name', (tester) async {
      await pumpAgentScreen(
        tester,
        const TodayScreen(),
        size: const Size(390, 844),
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          todayRouteProvider.overrideWith((ref) async => _today()),
        ],
      );

      await expectLater(
        find.byKey(agentBoundaryKey),
        matchesGoldenFile('${dir}colour_today_$name.png'),
      );
    }, skip: !looking);
  }

  // ── 4. Ask TradeIQ, answering with a chart ──────────────────────────
  for (final (name, mode) in skins) {
    testWidgets('Ask TradeIQ — $name', (tester) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(chartTurn()),
        size: const Size(390, 844),
        skin: console(mode),
      );
      await ask(tester, 'How has availability moved?');

      await expectLater(
        find.byKey(askBoundaryKey),
        matchesGoldenFile('${dir}colour_ask_$name.png'),
      );
      await disposeAsk(tester);
    }, skip: !looking);
  }
}

/// A real day: nine stores, four done, the fifth up next.
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
