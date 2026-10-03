import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/sales_targets/data/sales_targets_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

import '../agent_harness.dart';
import 'overview_harness.dart';

/// PERFECT STORE, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// Called the execution overview until 3 October 2026. The route is still
/// `/dashboard/overview` and the golden files still read `overview_*.png`.
///
/// The sibling of `floor_look_test.dart`, for the other half of the manager's
/// console. It produces the images the owner and the reviewer compare against
/// `goldens/floor_390x844.png` — a 390×844 phone and a 360×640 one, in Night
/// and in Day, populated, with **Schibsted Grotesk and JetBrains Mono loaded**. The test
/// font is wider than Schibsted Grotesk, so a screen rendered in it wraps sooner and
/// measures taller — a picture of the wrong screen.
///
/// ## Why it does not run in CI
///
/// For the reason `floor_look_test.dart` gives: CI rasterises anti-aliased
/// Schibsted Grotesk on `ubuntu-latest` and this repository is developed on macOS, so a
/// pixel comparison fails on the day it lands. The images are an artefact to
/// *look at*, not a regression pin — the pins are the measurements in
/// `overview_grammar_test.dart`, which do run everywhere.
///
/// ```sh
/// OVERVIEW_LOOK=1 OVERVIEW_LOOK_DIR=/somewhere/ flutter test \
///   test/features/dashboard/overview_look_test.dart --update-goldens
/// ```
void main() {
  final looking = Platform.environment['OVERVIEW_LOOK'] == '1';
  final dir = Platform.environment['OVERVIEW_LOOK_DIR'] ?? 'goldens/';

  // flutter_map 8 caches tiles on disk and asks path_provider for the OS
  // cache directory the first time a tile layer builds; a widget test has no
  // such plugin. Same stub, same reason, as `agent_map_screen_test.dart`.
  late final Directory cacheDir;
  setUpAll(() async {
    cacheDir = Directory.systemTemp.createTempSync('overview-look-tiles');
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

  final bands = <ScoreBand>[
    const ScoreBand(label: 'Excellent', minScore: 90, outlets: 4),
    const ScoreBand(label: 'Good', minScore: 75, outlets: 11),
    const ScoreBand(label: 'Fair', minScore: 60, outlets: 17),
    const ScoreBand(label: 'Poor', minScore: 40, outlets: 8),
    const ScoreBand(label: 'Critical', minScore: 0, outlets: 2),
  ];

  /// Six weeks of a series that actually moves — a flat pair of points cannot
  /// show whether the plot has margins, gridline labels or a last-reading
  /// label.
  const series = <TrendPoint>[
    TrendPoint(period: '2026-W33', value: 71.4, count: 38),
    TrendPoint(period: '2026-W34', value: 68.2, count: 41),
    TrendPoint(period: '2026-W35', value: 72.9, count: 44),
    TrendPoint(period: '2026-W36', value: 66.1, count: 39),
    TrendPoint(period: '2026-W37', value: 64.8, count: 43),
    TrendPoint(period: '2026-W38', value: 69.6, count: 42),
  ];

  for (final (name, size, skin) in <(String, Size, TiqSkin)>[
    ('390x844-night', const Size(390, 844), _night),
    ('360x640-night', const Size(360, 640), _night),
    ('390x844-day', const Size(390, 844), _day),
    ('360x640-day', const Size(360, 640), _day),
    // The whole scroll in one frame. Not a fold anybody has — it is the only
    // way to look at every block's grammar at once, which is what a restyle
    // is reviewed against.
    ('390xfull-night', const Size(390, 4200), _night),
    ('390xfull-day', const Size(390, 4200), _day),
  ]) {
    testWidgets('Perfect Store at $name, populated', (tester) async {
      await pumpOverview(
        tester,
        const DashboardShellScreen(),
        size: size,
        skin: skin,
        overrides: overviewOverrides(
          current: kpis(execution: 67.8, bands: bands),
          previous: kpis(execution: 66.0),
          byTerritory: <TerritoryDashboardKpis>[
            TerritoryDashboardKpis(
              territoryId: 'ter-1',
              territoryName: 'Gauteng North',
              kpis: kpis(execution: 58.2),
            ),
            TerritoryDashboardKpis(
              territoryId: 'ter-2',
              territoryName: 'Western Cape',
              kpis: kpis(execution: 81.4),
            ),
          ],
          alerts: <AlertItem>[
            alert(id: 'a1'),
            alert(id: 'a2', metric: 'planogram'),
            alert(id: 'a3', severity: 'warning', metric: 'price_breach'),
          ],
          tasks: <TaskItem>[
            task(id: 't1', priority: 'critical'),
            task(id: 't2'),
          ],
          territories: const <Territory>[north, west],
          outlets: <Outlet>[
            outlet('o1', 'SaveMor Glenwood'),
            outlet('o2', 'Shoprite Klipspruit Mall', lat: -26.3, lng: 28.1),
          ],
          agents: <AgentActivity>[
            agent(
              id: 'ag1',
              name: 'Thabo Mokoena',
              state: AgentState.atStore,
              currentOutlet: 'SaveMor Glenwood',
              lastSeen: DateTime.now().subtract(const Duration(minutes: 12)),
              stops: <AgentStop>[stop('SaveMor Glenwood')],
            ),
            agent(
              id: 'ag2',
              name: 'Naledi Dlamini',
              state: AgentState.inTransit,
              lastSeen: DateTime.now().subtract(const Duration(minutes: 48)),
              stops: <AgentStop>[
                stop('Shoprite Klipspruit Mall', lat: -26.3, lng: 28.1),
              ],
            ),
            agent(id: 'ag3', name: 'Sipho Ndlovu'),
          ],
          trend: series,
          // Targets set, so the sell-in panel renders its three figure
          // blocks rather than its empty state — the block that was a ruled
          // [StatCluster] and is now three cards.
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

      // The console body is a lazy list taller than any phone, so the picture
      // is taken of the whole scroll extent rather than of the fold: what is
      // being looked at is the grammar of every block, not the first 844dp.
      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}overview_$name.png'),
      );
    }, skip: !looking);
  }
}

final TiqSkin _night = TiqSkin.night();
final TiqSkin _day = TiqSkin.day();
