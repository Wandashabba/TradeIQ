import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodChannel;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/geo/geofence.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet/torch_sheet.dart';
import 'package:tradeiq_app/features/agent_map/data/agent_map.dart';
import 'package:tradeiq_app/features/agent_map/presentation/agent_map_screen.dart';
import 'package:tradeiq_app/features/audit/data/capability_repository.dart';
import 'package:tradeiq_app/features/audit/data/competitive_repository.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/audit/data/pricing_repository.dart';
import 'package:tradeiq_app/features/audit/data/risks_repository.dart';
import 'package:tradeiq_app/features/audit/data/scorecard_service.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/data/visibility_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/pin_dispute_view.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/client_questions_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s10_scorecard_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s1_outlet_info_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s3_4_visibility_display_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s5_pricing_promotions_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s6_competitive_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s7_capability_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s8_risks_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s9_action_plan_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/submit_gate_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'agent_harness.dart';
import 'audit/section_harness.dart';
import 'audit/visit_harness.dart';
import 'me/me_harness.dart';

/// THE AGENT SIDE, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// The owner's words on 29 September 2026, looking at the running app:
///
/// > *"Now look at the manager side of the app. The agent side is looking
/// > completely off and not like the manager side. Please make them align and
/// > don't change the manager side, it looks perfect."*
///
/// Every other test under `test/features/audit`, `beatplans` and `agent_map`
/// asserts a capability, a token or a pixel of amber. **None of them produces
/// an image**, so nothing in the repository could answer "does the agent side
/// look like the manager side". This file does one thing: it photographs every
/// screen a field agent reaches, at the size and in the typefaces the manager
/// screens are photographed at, in both skins.
///
/// | group | screens |
/// |---|---|
/// | `route` | Today (a walking order, and a day with no plan) |
/// | `visit` | the hub blocked and armed, check-in too far, the wrong-pin report |
/// | `section` | all nine capture sections plus the client template |
/// | `closing` | the submit gate blocked and armed, the outcome |
/// | `work` | My work with a stuck capture, one outbox item's sheet, the store picker |
/// | `elsewhere` | the map, and the agent's own record |
///
/// **The control set.** The manager screens are rendered by their own gated
/// look tests, which already stand them up at 390×844 with the same fonts —
/// `floor_look_test.dart`, `tasks_look_test.dart` and `ask_look_test.dart`.
/// Point their `*_LOOK_DIR` at the same folder and the comparison is
/// like-for-like rather than against a memory of the manager side:
///
/// ```sh
/// AGENT_LOOK=1 AGENT_LOOK_DIR=/somewhere/agent/ flutter test \
///   test/features/agent_look_test.dart --update-goldens
/// FLOOR_LOOK=1 FLOOR_LOOK_DIR=/somewhere/manager/ flutter test \
///   test/features/dashboard/floor_look_test.dart --update-goldens
/// ```
///
/// **The trailing slash is load-bearing.** The name is concatenated onto the
/// directory with no separator, so `AGENT_LOOK_DIR=/somewhere/agent` writes
/// `/somewhere/agentroute_...png` beside the folder rather than inside it.
/// Every look test in this repository has the same trap.
///
/// ## Why it does not run in CI
///
/// The reason `floor_look_test.dart`, `tasks_look_test.dart` and
/// `ask_look_test.dart` each give: CI rasterises anti-aliased Onest on
/// `ubuntu-latest` and this repository is developed on macOS, so a pixel
/// comparison fails on the day it lands and gets skipped within a week. These
/// are artefacts to *look at*; the pins are the assertions in
/// `agent_screens_golden_test.dart` and the per-screen tests, which do run
/// everywhere.
void main() {
  final looking = Platform.environment['AGENT_LOOK'] == '1';
  final dir = Platform.environment['AGENT_LOOK_DIR'] ?? 'goldens/';

  // flutter_map 8 caches tiles on disk and asks path_provider for the OS
  // cache directory the first time any tile layer is built. A widget test has
  // no path_provider plugin, so that ask throws a MissingPluginException
  // asynchronously — and which test it lands in depends on how long the map
  // test happens to run. `agent_map_screen_test.dart` answers the channel the
  // same way, for the same reason.
  late final Directory tiles;

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
    tiles = Directory.systemTemp.createTempSync('agent-look-tiles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tiles.path,
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  // `TorchSheets.openCount` is a static. A test that ends with a sheet up
  // leaves it at 1, and the next route thinks it is beneath a sheet and puts
  // every amber out — or, as here, refuses to open a second sheet at all.
  setUp(TorchSheets.resetForTest);

  /// The phone the manager side is photographed on. Every image in this file
  /// is this size, so a difference between two pictures is a difference
  /// between two screens.
  const phone = Size(390, 844);

  /// Night first, then Day — the order the design says to build them in.
  const skins = <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ];

  /// Shoot the composed frame, nav pill and thumb zone included.
  ///
  /// The boundary is the one `agent_harness` puts around the whole app inside
  /// `MaterialApp`'s `builder`, which is *under* the checked-mode banner — so
  /// the barber pole is not in the picture. `pumpSection` and `pumpVisit` both
  /// go through the same pump, so every image here has the same frame.
  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byKey(agentBoundaryKey),
    matchesGoldenFile('$dir$name.png'),
  );

  // ───────────────────────────────────────────────────────────── the route ──

  group('route', () {
    for (final (name, mode) in skins) {
      testWidgets('Today — a walking order, $name', (tester) async {
        await pumpAgentScreen(
          tester,
          const TodayScreen(),
          size: phone,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            todayRouteProvider.overrideWith((ref) async => _todaysRoute),
          ],
        );
        await shot(tester, 'agent_01_today_route_$name');
      }, skip: !looking);

      // An empty route is not an empty screen: nobody planned a day for this
      // agent, which is a different fact from "the plan is finished".
      testWidgets('Today — no plan at all, $name', (tester) async {
        await pumpAgentScreen(
          tester,
          const TodayScreen(),
          size: phone,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            todayRouteProvider.overrideWith((ref) async => null),
          ],
        );
        await shot(tester, 'agent_02_today_empty_$name');
      }, skip: !looking);
    }
  });

  // ────────────────────────────────────────────────────────────── the visit ──

  group('visit', () {
    for (final (name, mode) in skins) {
      testWidgets('the hub, nothing captured, $name', (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          skin: mode,
          size: phone,
        );
        await shot(tester, 'agent_10_visit_hub_blocked_$name');
      }, skip: !looking);

      testWidgets('the hub, armed to submit, $name', (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: readyToSubmit,
          skin: mode,
          size: phone,
        );
        await shot(tester, 'agent_11_visit_hub_ready_$name');
      }, skip: !looking);

      // A section the app could not establish — the fourth silhouette, and the
      // only state on the hub that is neither done nor undone.
      testWidgets("the hub with a can't-confirm section, $name", (
        tester,
      ) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: cantConfirmStock,
          skin: mode,
          size: phone,
        );
        await shot(tester, 'agent_12_visit_hub_cant_confirm_$name');
      }, skip: !looking);

      testWidgets('check-in, too far from the door, $name', (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.tooFar(184),
          skin: mode,
          size: phone,
        );
        await shot(tester, 'agent_13_check_in_too_far_$name');
      }, skip: !looking);

      testWidgets('the wrong-pin report, $name', (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.tooFar(184),
          skin: mode,
          size: phone,
          extraOverrides: <Override>[
            queuedPhotosRepositoryProvider.overrideWithValue(_NoPhotos()),
            storefrontPhotoPickerProvider.overrideWithValue(
              (context) async => null,
            ),
          ],
        );
        final report = find.byKey(const ValueKey<String>('pin-is-wrong'));
        await scrollAgentTo(tester, report);
        await tester.tap(report);
        await tester.pumpAndSettle();
        await shot(tester, 'agent_14_pin_dispute_$name');
      }, skip: !looking);
    }
  });

  // ─────────────────────────────────────────────────────────── the sections ──

  group('section', () {
    for (final (name, mode) in skins) {
      Future<void> section(
        WidgetTester tester,
        Widget screen,
        String file, {
        List<Override> overrides = const <Override>[],
      }) async {
        await pumpSection(
          tester,
          screen,
          overrides: overrides,
          skin: mode,
          size: phone,
        );
        await shot(tester, file);
      }

      testWidgets('S1 outlet information, $name', (tester) async {
        await section(
          tester,
          S1OutletInfoScreen(checkinTs: DateTime(2026, 9, 18, 9, 12)),
          'agent_20_section_s1_outlet_info_$name',
        );
      }, skip: !looking);

      // PART-CAPTURED, which is the state an agent is in for most of a visit:
      // two of five counted, one of them a finding.
      testWidgets('S2 stock, part counted, $name', (tester) async {
        await section(
          tester,
          const S2StockScreen(visitDraftId: 'v1', outletId: 'o1'),
          'agent_21_section_s2_stock_part_$name',
          overrides: <Override>[
            skusRepositoryProvider.overrideWithValue(_Skus(_shelf)),
            stockRepositoryProvider.overrideWithValue(_NoStock()),
            queuedPhotosRepositoryProvider.overrideWithValue(_NoPhotos()),
            photoCaptureServiceProvider.overrideWithValue(fakeCapture()),
            scriptedExposure(0.5),
          ],
        );
        // Two SKUs counted and the third left alone — the middle of the job,
        // which is the state an agent is in for most of a section. The second
        // count is a measured zero, so the row takes the finding treatment.
        await _step(tester, 's1', 'One more', times: 6);
        await _step(tester, 's2', 'One fewer');
        await tester.pumpAndSettle();
        await shot(tester, 'agent_22_section_s2_stock_typed_$name');
      }, skip: !looking);

      testWidgets('S3/S4 visibility and display, $name', (tester) async {
        await section(
          tester,
          const S3S4VisibilityDisplayScreen(visitDraftId: 'v1'),
          'agent_23_section_s3_visibility_$name',
          overrides: <Override>[
            visibilityRepositoryProvider.overrideWithValue(_NoVisibility()),
            queuedPhotosRepositoryProvider.overrideWithValue(_NoPhotos()),
            photoCaptureServiceProvider.overrideWithValue(fakeCapture()),
            scriptedExposure(0.5),
          ],
        );
      }, skip: !looking);

      testWidgets('S5 pricing and promotions, $name', (tester) async {
        await section(
          tester,
          const S5PricingPromotionsScreen(visitDraftId: 'v1', outletId: 'o1'),
          'agent_24_section_s5_pricing_$name',
          overrides: <Override>[
            skusRepositoryProvider.overrideWithValue(_Skus(_shelf)),
            pricingRepositoryProvider.overrideWithValue(_NoPricing()),
            queuedPhotosRepositoryProvider.overrideWithValue(_NoPhotos()),
            photoCaptureServiceProvider.overrideWithValue(fakeCapture()),
            scriptedExposure(0.5),
          ],
        );
      }, skip: !looking);

      testWidgets('S6 competitive, $name', (tester) async {
        await section(
          tester,
          const S6CompetitiveScreen(visitDraftId: 'v1'),
          'agent_25_section_s6_competitive_$name',
          overrides: <Override>[
            competitiveRepositoryProvider.overrideWithValue(_NoCompetitive()),
          ],
        );
      }, skip: !looking);

      testWidgets('S7 capability, $name', (tester) async {
        await section(
          tester,
          const S7CapabilityScreen(visitDraftId: 'v1'),
          'agent_26_section_s7_capability_$name',
          overrides: <Override>[
            capabilityRepositoryProvider.overrideWithValue(_NoCapability()),
          ],
        );
      }, skip: !looking);

      testWidgets('S8 risks, $name', (tester) async {
        await section(
          tester,
          const S8RisksScreen(visitDraftId: 'v1'),
          'agent_27_section_s8_risks_$name',
          overrides: <Override>[
            risksRepositoryProvider.overrideWithValue(_NoRisks()),
          ],
        );
      }, skip: !looking);

      testWidgets('S9 action plan, $name', (tester) async {
        await section(
          tester,
          const S9ActionPlanScreen(visitDraftId: 'v1', outletId: 'o1'),
          'agent_28_section_s9_action_plan_$name',
          overrides: <Override>[
            tasksRepositoryProvider.overrideWithValue(_NoTasks()),
          ],
        );
      }, skip: !looking);

      testWidgets('S10 the score so far, $name', (tester) async {
        await section(
          tester,
          const S10ScorecardScreen(visitDraftId: 'v1'),
          'agent_29_section_s10_score_$name',
          overrides: <Override>[
            scorecardServiceProvider.overrideWithValue(_scorecard()),
          ],
        );
      }, skip: !looking);

      testWidgets("the client's own questions, $name", (tester) async {
        await section(
          tester,
          ClientQuestionsScreen(visitDraftId: 'v1', template: _template),
          'agent_30_section_client_questions_$name',
          overrides: <Override>[
            templateSectionRepositoryProvider.overrideWithValue(
              _NoTemplateAnswers(),
            ),
          ],
        );
      }, skip: !looking);
    }
  });

  // ─────────────────────────────────────────────────────── closing a visit ──

  group('closing', () {
    Widget gate() => const SubmitGateScreen(
      visitDraftId: 'visit-1',
      outletId: 'o1',
      outletName: 'Kasi Corner Spaza',
      checkinTs: null,
      onConfirm: _nothing,
    );

    Future<void> pumpGate(
      WidgetTester tester, {
      required SkinMode mode,
      required VisitProgress progress,
    }) => pumpAgentScreen(
      tester,
      gate(),
      path: '/audit/o1/submit',
      size: phone,
      overrides: <Override>[
        ...agentBaseOverrides(db: agentTestDb(), skin: mode),
        visitReviewProvider.overrideWith(
          (ref, arg) => Stream<VisitReview>.value(_review),
        ),
        visitProgressProvider.overrideWith(
          (ref, arg) => Stream<VisitProgress>.value(progress),
        ),
      ],
    );

    for (final (name, mode) in skins) {
      // THE BLOCKED GATE — the screen that has to say what is missing and why
      // the commit is dark. The state an agent meets when they hit Submit
      // early, which is most of the time.
      testWidgets('the submit gate, blocked, $name', (tester) async {
        await pumpGate(tester, mode: mode, progress: nothingDone);
        await shot(tester, 'agent_40_submit_gate_blocked_$name');
      }, skip: !looking);

      testWidgets('the submit gate, armed, $name', (tester) async {
        await pumpGate(tester, mode: mode, progress: readyToSubmit);
        await shot(tester, 'agent_41_submit_gate_ready_$name');
      }, skip: !looking);

      testWidgets('the outcome, scored, $name', (tester) async {
        await pumpAgentScreen(
          tester,
          const VisitOutcomeScreen(
            visitDraftId: 'v1',
            outletId: 'o1',
            outletName: 'Kasi Corner Spaza',
          ),
          path: '/audit/o1/done',
          size: phone,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            visitOutcomeProvider.overrideWith(
              (ref, arg) async =>
                  const VisitOutcome(score: _scored, previous: null),
            ),
          ],
        );
        await shot(tester, 'agent_42_outcome_scored_$name');
      }, skip: !looking);

      testWidgets('the outcome, held offline, $name', (tester) async {
        await pumpAgentScreen(
          tester,
          const VisitOutcomeScreen(
            visitDraftId: 'v1',
            outletId: 'o1',
            outletName: 'Kasi Corner Spaza',
          ),
          path: '/audit/o1/done',
          size: phone,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            visitOutcomeProvider.overrideWith(
              (ref, arg) async =>
                  const VisitOutcome(score: null, previous: null),
            ),
          ],
        );
        await shot(tester, 'agent_43_outcome_held_$name');
      }, skip: !looking);
    }
  });

  // ───────────────────────────────────────────────────────────────── work ──

  group('work', () {
    Future<void> pumpWork(WidgetTester tester, SkinMode mode) =>
        pumpAgentScreen(
          tester,
          const MyWorkScreen(),
          path: '/my-work',
          size: phone,
          overrides: <Override>[
            ...agentBaseOverrides(
              db: agentTestDb(),
              skin: mode,
              sync: _stuckQueue(),
            ),
          ],
          extraRoutes: <GoRoute>[
            GoRoute(path: '/today', builder: (c, s) => const Text('Today')),
            GoRoute(path: '/map', builder: (c, s) => const Text('Map')),
            GoRoute(path: '/me', builder: (c, s) => const Text('Me')),
            GoRoute(path: '/audit', builder: (c, s) => const Text('Picker')),
          ],
        );

    for (final (name, mode) in skins) {
      testWidgets('My work, one capture stuck, $name', (tester) async {
        await pumpWork(tester, mode);
        await shot(tester, 'agent_50_my_work_stuck_$name');
      }, skip: !looking);

      // The sheet the stuck row opens: the one place an agent is told what a
      // rejection means and offered the two ways out of it.
      testWidgets("the outbox item's sheet, $name", (tester) async {
        await pumpWork(tester, mode);
        final row = find.byKey(const ValueKey<String>('sync-item-2'));
        await scrollAgentTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await shot(tester, 'agent_51_outbox_item_sheet_$name');
      }, skip: !looking);

      testWidgets('the store picker, $name', (tester) async {
        await pumpAgentScreen(
          tester,
          const VisitOutletPickerScreen(),
          path: '/audit',
          size: phone,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            outletsRepositoryProvider.overrideWithValue(_Stores()),
          ],
        );
        await shot(tester, 'agent_52_store_picker_$name');
      }, skip: !looking);
    }
  });

  // ───────────────────────────────────────────────────────────── elsewhere ──

  group('elsewhere', () {
    for (final (name, mode) in skins) {
      // NEVER `pumpAndSettle` on the map: flutter_map's tile layer keeps
      // retrying a fetch the test environment blocks, so a settle never
      // returns. A fixed number of frames is all a built frame needs.
      testWidgets('the map, $name', (tester) async {
        await pumpAgentScreen(
          tester,
          const AgentMapScreen(),
          path: '/map',
          size: phone,
          settle: false,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            agentMapProvider.overrideWith((ref) async => _mapView),
          ],
          extraRoutes: <GoRoute>[
            GoRoute(path: '/today', builder: (c, s) => const Text('Today')),
            GoRoute(path: '/my-work', builder: (c, s) => const Text('Work')),
            GoRoute(path: '/me', builder: (c, s) => const Text('Me')),
            GoRoute(path: '/audit', builder: (c, s) => const Text('Picker')),
          ],
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await shot(tester, 'agent_60_map_$name');
      }, skip: !looking);

      testWidgets("the agent's own record, $name", (tester) async {
        await pumpMe(tester, skin: mode, size: phone);
        await shot(tester, 'agent_61_me_$name');
      }, skip: !looking);
    }
  });
}

void _nothing() {}

/// Press a count stepper's [label] button [times] times.
///
/// `null → One more` records 1 and `null → One fewer` records 0 (unify §1.8),
/// so six presses is six on the shelf and one press of the other is a measured
/// zero — the finding.
Future<void> _step(
  WidgetTester tester,
  String skuId,
  String label, {
  int times = 1,
}) async {
  final button = find.descendant(
    of: find.byKey(ValueKey<String>('units-$skuId')),
    matching: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    ),
  );
  await scrollAgentTo(tester, button);
  for (var i = 0; i < times; i++) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

// ── The day ────────────────────────────────────────────────────────────────

const _kasi = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.2400,
  lng: 27.8580,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-0221',
  lat: -26.2520,
  lng: 27.8580,
);
const _khumalo = Outlet(
  id: 'o3',
  name: 'Khumalo Superette',
  code: 'KS-0014',
  lat: -26.2600,
  lng: 27.8580,
);
const _shoprite = Outlet(
  id: 'o4',
  name: 'Shoprite Klipspruit Mall',
  code: 'SK-1180',
  lat: -26.2660,
  lng: 27.8720,
);

/// A real walking order: one store done, one next at 420 m, two to go.
final _todaysRoute = TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: true,
  stops: <RouteStop>[
    const RouteStop(
      sequence: 1,
      outlet: _kasi,
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
      outlet: _khumalo,
      visited: false,
      distanceMeters: 1830,
    ),
    const RouteStop(
      sequence: 4,
      outlet: _shoprite,
      visited: false,
      distanceMeters: 3140,
    ),
  ],
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
      distanceMeters: 420,
    ),
    const MapOutlet(
      outlet: _khumalo,
      state: MapPinState.territory,
      distanceMeters: 1830,
    ),
    const MapOutlet(
      outlet: _shoprite,
      state: MapPinState.territory,
      distanceMeters: 3140,
    ),
  ],
  here: const Coordinates(lat: -26.2399, lng: 27.858),
  problem: null,
  planName: 'Naledi · Soweto East',
);

// ── The shelf ──────────────────────────────────────────────────────────────

const _shelf = <Sku>[
  Sku(
    id: 's1',
    name: 'Kalahari Cola 2L',
    category: 'Beverages',
    minFacingsStandard: 4,
    rrp: 24.99,
    daysOutOfStock: 0,
    velocityAvg: 4.2,
    effectivePrice: 24.99,
  ),
  Sku(
    id: 's2',
    name: 'Fanta Orange 2L',
    category: 'Beverages',
    minFacingsStandard: 4,
    rrp: 24.99,
    daysOutOfStock: 6,
    velocityAvg: 3.1,
    effectivePrice: 22.5,
  ),
  Sku(
    id: 's3',
    name: 'Salt & Vinegar Crisps 125g',
    category: 'Snacks',
    minFacingsStandard: 2,
    rrp: 12.5,
    daysOutOfStock: 0,
    velocityAvg: 1.5,
    effectivePrice: 12.5,
  ),
];

final _template = ClientTemplate(
  templateId: 'tpl-1',
  name: 'Promo Check',
  version: 3,
  schemaJson: const <String, Object?>{
    'sections': <Object?>[
      <String, Object?>{
        'id': 'promo',
        'title': 'Promo stand',
        'fields': <Object?>[
          <String, Object?>{
            'id': 'standUp',
            'label': 'Is the promo stand up?',
            'type': 'boolean',
          },
          <String, Object?>{
            'id': 'facings',
            'label': 'Promo facings',
            'type': 'number',
            'required': true,
          },
          <String, Object?>{
            'id': 'comment',
            'label': 'Anything else worth saying?',
            'type': 'text',
          },
        ],
      },
    ],
  },
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
      title: 'Planogram compliance under 50%',
      reason: 'You marked the main aisle as not to plan',
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

/// One rejected capture beside a held one — the state where "Send now" is
/// armed and one row is asking for a decision.
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

/// The real service over an empty in-memory database: a visit on which no
/// section has been saved, which is what Score shows for most of a visit.
ScorecardService _scorecard() {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return ScorecardService(
    db: db,
    syncService: SyncService(db: db, flusher: _NoFlush()),
  );
}

// ── Repositories that answer and record nothing ────────────────────────────

class _Stores implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse<Outlet>(
    data: <Outlet>[_kasi, _sunrise, _khumalo, _shoprite],
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

class _Skus implements SkusRepository {
  _Skus(this.skus);

  final List<Sku> skus;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => PaginatedResponse<Sku>(data: skus, nextCursor: null);
}

class _NoStock implements StockRepository {
  @override
  Future<void> saveStock({
    required String visitDraftId,
    required List<StockEntry> entries,
  }) async {}
}

class _NoPricing implements PricingRepository {
  @override
  Future<void> savePricing({
    required String visitDraftId,
    required List<PricingEntry> entries,
  }) async {}
}

class _NoVisibility implements VisibilityRepository {
  @override
  Future<void> saveVisibility({
    required String visitDraftId,
    required VisibilityCapture capture,
  }) async {}
}

class _NoCompetitive implements CompetitiveRepository {
  @override
  Future<void> saveCompetitive({
    required String visitDraftId,
    required List<CompetitiveEntry> entries,
  }) async {}
}

class _NoCapability implements CapabilityRepository {
  @override
  Future<void> saveCapability({
    required String visitDraftId,
    required CapabilityCapture capture,
  }) async {}
}

class _NoRisks implements RisksRepository {
  @override
  Future<void> saveRisks({
    required String visitDraftId,
    required List<RiskEntry> entries,
  }) async {}
}

class _NoTasks implements TasksRepository {
  @override
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  }) async {}
}

class _NoPhotos implements QueuedPhotosRepository {
  @override
  Future<void> queuePhoto({
    required String visitDraftId,
    required String section,
    required String dataUrl,
    Map<String, dynamic> gpsTag = const <String, dynamic>{},
    DateTime? capturedAt,
    String? source,
  }) async {}
}

class _NoTemplateAnswers implements TemplateSectionRepository {
  @override
  Future<void> pinForVisit(String visitDraftId) async {}

  @override
  Future<Map<String, Object?>> savedAnswers({
    required String visitDraftId,
    required String templateId,
  }) async => const <String, Object?>{};

  @override
  Future<void> saveAnswers({
    required String visitDraftId,
    required ClientTemplate template,
    required Map<String, Object?> answers,
  }) async {}
}

class _NoFlush implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

/// The icon font, out of the Flutter SDK's own cache.
///
/// It is not in the test asset bundle, so without this every nav destination
/// and every chevron is a hollow box. Its absence is silent and harmless — a
/// look test has no business failing over an icon on a machine that keeps its
/// SDK somewhere else.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}
