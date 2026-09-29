import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodChannel;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/geo/geofence.dart' show Coordinates;
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/agent_map/data/agent_map.dart';
import 'package:tradeiq_app/features/agent_map/presentation/agent_map_screen.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/submit_gate_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../agent_harness.dart';
import '../audit/visit_harness.dart';

/// THE AGENT SCREENS, RENDERED, SO SOMEBODY CAN LOOK AT THEM.
///
/// The console has had this since the plate landed — `floor_look_test.dart`,
/// `overview_look_test.dart`, `tasks_look_test.dart`, `ask_look_test.dart` —
/// and the agent side has had only text goldens (`agent_goldens.dart`), which
/// name the value that moved and cannot show a shape. "The agent side is
/// looking completely off and not like the manager side" is a judgement about
/// silhouettes, and it cannot be answered by a list of declared numbers.
///
/// Same switch and same reason as the console's set: it does **not** run in
/// CI, because CI rasterises anti-aliased Onest on `ubuntu-latest` while this
/// repository is developed on macOS, so a pixel comparison fails the day it
/// lands. The regression pins stay where they are — the text goldens, the
/// amber census, the proportion tests. These are an artefact to look at.
///
/// ```sh
/// AGENT_LOOK=1 AGENT_LOOK_DIR=/somewhere/ flutter test \
///   test/features/goldens/agent_look_test.dart --update-goldens
/// ```
///
/// `AGENT_LOOK_DIR` needs its trailing slash: the path is `'$dir$name.png'`,
/// with no separator added.
void main() {
  final looking = Platform.environment['AGENT_LOOK'] == '1';
  final dir = Platform.environment['AGENT_LOOK_DIR'] ?? 'goldens/';

  // flutter_map 8 asks path_provider for the OS cache directory the first
  // time a tile layer builds, and a widget test has no such plugin. Same stub
  // and same reason as `agent_map_screen_test.dart` and `overview_look_test`.
  late final Directory cacheDir;
  setUpAll(() async {
    cacheDir = Directory.systemTemp.createTempSync('agent-look-tiles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cacheDir.path,
        );
    await loadAgentFonts();
    await _loadIcons();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  /// The phone the owner looks at. Both skins, every screen.
  const phone = Size(390, 844);

  /// The whole scroll in one frame. Not a fold anybody has — it is the only
  /// way to see every block's grammar at once, which is what a restyle is
  /// reviewed against. Same device the console's look set uses.
  const tall = Size(390, 1800);

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byKey(agentBoundaryKey),
    matchesGoldenFile('$dir$name.png'),
  );

  for (final mode in agentSkinModes) {
    final s = mode.name;

    // ── TODAY — the route, the next store, the rest of the day ──────────
    for (final (label, size) in <(String, Size)>[
      ('today_$s', phone),
      ('today_full_$s', tall),
    ]) {
      testWidgets(label, (tester) async {
        await pumpAgentScreen(
          tester,
          const TodayScreen(),
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            todayRouteProvider.overrideWith((ref) async => _route),
          ],
        );
        await shot(tester, label);
      }, skip: !looking);
    }

    // ── MY WORK — the outbox summary and its queue ──────────────────────
    for (final (label, size) in <(String, Size)>[
      ('my_work_$s', phone),
      ('my_work_full_$s', tall),
    ]) {
      testWidgets(label, (tester) async {
        await pumpAgentScreen(
          tester,
          const MyWorkScreen(),
          path: '/my-work',
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(
              db: agentTestDb(),
              skin: mode,
              sync: _stuckQueue(),
            ),
          ],
        );
        await shot(tester, label);
      }, skip: !looking);
    }

    // ── THE VISIT HUB — the readiness block over the section list ───────
    for (final (label, size) in <(String, Size)>[
      ('visit_hub_$s', phone),
      ('visit_hub_full_$s', tall),
    ]) {
      testWidgets(label, (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: readyToSubmit,
          skin: mode,
          size: size,
        );
        await shot(tester, label);
      }, skip: !looking);
    }

    // ── CHECK-IN, TOO FAR — the distance hero and its severity ──────────
    testWidgets('check_in_too_far_$s', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.tooFar(180),
        skin: mode,
        size: phone,
      );
      await shot(tester, 'check_in_too_far_$s');
    }, skip: !looking);

    // ── THE SUBMIT GATE — the captured block and what it will raise ─────
    for (final (label, size) in <(String, Size)>[
      ('submit_gate_$s', phone),
      ('submit_gate_full_$s', tall),
    ]) {
      testWidgets(label, (tester) async {
        await pumpAgentScreen(
          tester,
          SubmitGateScreen(
            visitDraftId: 'visit-1',
            outletId: 'o1',
            outletName: 'Kasi Corner Spaza',
            checkinTs: null,
            onConfirm: () {},
          ),
          path: '/audit/o1/submit',
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            visitReviewProvider.overrideWith(
              (ref, arg) => Stream<VisitReview>.value(_review),
            ),
            visitProgressProvider.overrideWith(
              (ref, arg) => Stream<VisitProgress>.value(readyToSubmit),
            ),
          ],
        );
        await shot(tester, label);
      }, skip: !looking);
    }

    // ── A CLEAN GATE — the "nothing to raise" block on its own ──────────
    testWidgets('submit_gate_clean_$s', (tester) async {
      await pumpAgentScreen(
        tester,
        SubmitGateScreen(
          visitDraftId: 'visit-1',
          outletId: 'o1',
          outletName: 'Kasi Corner Spaza',
          checkinTs: null,
          onConfirm: () {},
        ),
        path: '/audit/o1/submit',
        size: phone,
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          visitReviewProvider.overrideWith(
            (ref, arg) => Stream<VisitReview>.value(
              const VisitReview(
                skusCounted: 12,
                outOfStock: 0,
                skusPriced: 12,
                competitors: 2,
                photos: 1,
                willRaise: <RaisedTask>[],
              ),
            ),
          ),
          visitProgressProvider.overrideWith(
            (ref, arg) => Stream<VisitProgress>.value(readyToSubmit),
          ),
        ],
      );
      await shot(tester, 'submit_gate_clean_$s');
    }, skip: !looking);

    // ── THE OUTCOME — the score hero and the dimension breakdown ────────
    testWidgets('visit_outcome_$s', (tester) async {
      await pumpAgentScreen(
        tester,
        const VisitOutcomeScreen(
          visitDraftId: 'v1',
          outletId: 'o1',
          outletName: 'Sunrise Spaza',
        ),
        path: '/audit/o1/done',
        size: tall,
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          visitOutcomeProvider.overrideWith(
            (ref, arg) async => const VisitOutcome(score: _scored, previous: null),
          ),
        ],
      );
      await shot(tester, 'visit_outcome_$s');
    }, skip: !looking);

    // ── THE STORE PICKER ────────────────────────────────────────────────
    testWidgets('store_picker_$s', (tester) async {
      await pumpAgentScreen(
        tester,
        const VisitOutletPickerScreen(),
        path: '/audit',
        size: phone,
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          outletsRepositoryProvider.overrideWithValue(_TwoStores()),
        ],
      );
      await shot(tester, 'store_picker_$s');
    }, skip: !looking);

    // ── THE MAP — the band, the legend and the two lists ────────────────
    //
    // `settle: false`: flutter_map's tile layer keeps retrying a fetch the
    // test environment blocks, so a settle here never returns.
    for (final (label, size) in <(String, Size)>[
      ('map_$s', phone),
      ('map_full_$s', tall),
    ]) {
      testWidgets(label, (tester) async {
        await pumpAgentScreen(
          tester,
          const AgentMapScreen(),
          path: '/map',
          size: size,
          settle: false,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            agentMapProvider.overrideWith((ref) async => _mapView),
          ],
          extraRoutes: <GoRoute>[
            GoRoute(path: '/audit', builder: (c, s) => const Text('Picker')),
          ],
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await shot(tester, label);
      }, skip: !looking);
    }
  }
}

// ── The data every picture is drawn from ──────────────────────────────────

const _khumalo = Outlet(
  id: 'o1',
  name: 'Khumalo Superette',
  code: 'KS-014',
  lat: -26.2,
  lng: 28.0,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-221',
  lat: -26.3,
  lng: 28.1,
);
const _kasi = Outlet(
  id: 'o3',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.24,
  lng: 27.858,
);

final _route = TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: true,
  stops: <RouteStop>[
    const RouteStop(
      sequence: 1,
      outlet: _khumalo,
      visited: true,
      distanceMeters: 1200,
    ),
    const RouteStop(
      sequence: 2,
      outlet: _sunrise,
      visited: false,
      distanceMeters: 420,
    ),
    const RouteStop(
      sequence: 3,
      outlet: _kasi,
      visited: false,
      distanceMeters: 2140,
    ),
  ],
);

const _review = VisitReview(
  skusCounted: 12,
  outOfStock: 1,
  skusPriced: 12,
  competitors: 2,
  photos: 1,
  willRaise: <RaisedTask>[
    RaisedTask(
      title: 'Fanta Orange 2L is out of stock',
      reason: 'You counted zero on shelf',
      priority: 'high',
    ),
    RaisedTask(
      title: 'Price above the published band',
      reason: 'R 24,99 against a R 21,99 ceiling',
      priority: 'medium',
    ),
  ],
);

const _scored = ServerScorecard(
  visitId: 'remote-1',
  weightedTotal: 72,
  ratingBand: 'amber',
  dimensionScores: <String, double>{
    'availability': 83,
    'visibility': 80,
    'display': 80,
    'pricing': 61,
    'competitive': 29,
  },
);

final _mapView = AgentMapView(
  pins: <MapOutlet>[
    const MapOutlet(
      outlet: _kasi,
      state: MapPinState.doneToday,
      sequence: 1,
      distanceMeters: 1200,
    ),
    const MapOutlet(
      outlet: _sunrise,
      state: MapPinState.nextUp,
      sequence: 2,
      distanceMeters: 1330,
    ),
    const MapOutlet(
      outlet: _khumalo,
      state: MapPinState.territory,
      distanceMeters: 2400,
    ),
  ],
  here: const Coordinates(lat: -26.2399, lng: 27.858),
  problem: null,
  planName: 'Naledi · Soweto East',
);

/// One stuck capture beside a held one: the state where "Send now" is armed.
SyncStatus _stuckQueue() {
  final held = SyncItem(
    id: 1,
    entityType: 'stock',
    queuedAt: DateTime(2026, 9, 18, 7, 58),
    synced: false,
    attempts: 0,
    payloadBytes: 300 * 1024,
  );
  final stuck = SyncItem(
    id: 2,
    entityType: 'photo',
    queuedAt: DateTime(2026, 9, 18, 8, 4),
    synced: false,
    attempts: 3,
    lastError: 'sync:rejected:422',
    lastAttemptAt: DateTime(2026, 9, 18, 14, 20),
    payloadBytes: 1468006,
  );
  return SyncStatus(
    pending: <SyncItem>[stuck, held],
    sent: const <SyncItem>[],
    needsAttention: <SyncItem>[stuck],
  );
}

class _TwoStores implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse<Outlet>(
    data: <Outlet>[_khumalo, _sunrise, _kasi],
    nextCursor: null,
  );

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

/// The icon font, out of the Flutter SDK's own cache. Without it every glyph
/// in these pictures is a hollow box — the nav, the chevrons, the marks. Its
/// absence is silent, and the pictures are still readable without it.
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
