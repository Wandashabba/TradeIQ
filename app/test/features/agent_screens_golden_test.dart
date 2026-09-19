import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/camera/photo_exposure.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/presentation/submit_gate_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';
import 'package:tradeiq_app/core/widgets/guided_capture_screen.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'agent_goldens.dart';
import 'agent_harness.dart';
import 'audit/visit_harness.dart';
import 'me/me_harness.dart';

/// The migrated agent routes, Night → Day → Veld, as declared values.
///
/// The order is the design's own: Night first, then Day, and Veld last —
/// after Night and Day have stopped moving. Veld matters most here, because
/// this is the outdoor screen: targets 56, rows 64, 2px borders, no
/// gradients, no shadows, and the nav docked.

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
  ],
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
    data: <Outlet>[_khumalo, _sunrise],
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

void main() {
  group('Today', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape', (tester) async {
        final db = agentTestDb();
        await pumpAgentScreen(
          tester,
          const TodayScreen(),
          overrides: <Override>[
            ...agentBaseOverrides(db: db, skin: mode),
            todayRouteProvider.overrideWith((ref) async => _route),
          ],
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
          // The census counts the composed frame, so the commit action has to
          // be in it: on a 360×640 phone the day block puts "Check in here"
          // just past the fold. The header is measured before this scroll —
          // it is a child of the same scroll view.
          bringIntoView: find.byKey(const ValueKey<String>('check-in-next')),
        );
        expectAgentGolden(lines, 'today_${mode.name}');
      });
    }
  });

  group('the visit hub', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape when armed', (
        tester,
      ) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: readyToSubmit,
          skin: mode,
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'visit_hub_ready_${mode.name}');
      });

      testWidgets('${mode.name} holds its declared shape when blocked', (
        tester,
      ) async {
        await pumpVisit(tester, visits: ScriptedVisits.succeeds(), skin: mode);
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'visit_hub_blocked_${mode.name}');
      });
    }
  });

  // ME — the one route in this file with an empty claim set. Its goldens are
  // therefore mostly about the *frame*: four nav slots instead of three, no
  // primary, no thumb zone, and an amber count that is the chrome's alone.
  group('me', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape', (tester) async {
        await pumpMe(tester, skin: mode, size: mePhone);
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'me_${mode.name}');
      });
    }
  });

  group('check-in — too far', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape', (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.tooFar(180),
          skin: mode,
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'check_in_too_far_${mode.name}');
      });
    }
  });

  group('My work', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape when stuck', (
        tester,
      ) async {
        await pumpAgentScreen(
          tester,
          const MyWorkScreen(),
          path: '/my-work',
          overrides: <Override>[
            ...agentBaseOverrides(
              db: agentTestDb(),
              skin: mode,
              sync: _stuckQueue(),
            ),
          ],
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'my_work_stuck_${mode.name}');
      });
    }
  });

  group('the store picker', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape', (tester) async {
        await pumpAgentScreen(
          tester,
          const VisitOutletPickerScreen(),
          path: '/audit',
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            outletsRepositoryProvider.overrideWithValue(_TwoStores()),
          ],
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'store_picker_${mode.name}');
      });
    }
  });

  // ── Closing a visit ─────────────────────────────────────────────────────

  group('the submit gate', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape', (tester) async {
        final db = agentTestDb();
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
          overrides: <Override>[
            ...agentBaseOverrides(db: db, skin: mode),
            visitReviewProvider.overrideWith(
              (ref, arg) => Stream<VisitReview>.value(
                const VisitReview(
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
                  ],
                ),
              ),
            ),
            visitProgressProvider.overrideWith(
              (ref, arg) => Stream<VisitProgress>.value(readyToSubmit),
            ),
          ],
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'submit_gate_${mode.name}');
      });
    }
  });

  group('the outcome', () {
    const scored = ServerScorecard(
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

    Future<void> pumpOutcome(
      WidgetTester tester, {
      required SkinMode mode,
      required VisitOutcome outcome,
    }) async {
      final db = agentTestDb();
      await pumpAgentScreen(
        tester,
        const VisitOutcomeScreen(
          visitDraftId: 'v1',
          outletId: 'o1',
          outletName: 'Sunrise Spaza',
        ),
        path: '/audit/o1/done',
        overrides: <Override>[
          ...agentBaseOverrides(db: db, skin: mode),
          visitOutcomeProvider.overrideWith((ref, arg) async => outcome),
        ],
      );
    }

    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape when scored', (
        tester,
      ) async {
        await pumpOutcome(
          tester,
          mode: mode,
          outcome: const VisitOutcome(score: scored, previous: null),
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'visit_outcome_scored_${mode.name}');
      });

      testWidgets('${mode.name} holds its declared shape when held', (
        tester,
      ) async {
        await pumpOutcome(
          tester,
          mode: mode,
          outcome: const VisitOutcome(score: null, previous: null),
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'visit_outcome_held_${mode.name}');
      });
    }
  });

  group('photo capture — the pre-capture card', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} holds its declared shape', (tester) async {
        final db = agentTestDb();
        await pumpAgentScreen(
          tester,
          const GuidedCaptureScreen(
            label: 'Shelf photo',
            hint: 'Stand back far enough to get the whole bay.',
          ),
          path: '/capture',
          overrides: <Override>[
            ...agentBaseOverrides(db: db, skin: mode),
            photoCaptureServiceProvider.overrideWithValue(
              PhotoCaptureService(gateway: _NoCamera()),
            ),
            photoExposureProvider.overrideWithValue(
              (String dataUrl) async => null,
            ),
          ],
        );
        final lines = await measureAgentFrame(
          tester,
          skin: agentSkinFor(mode),
        );
        expectAgentGolden(lines, 'photo_capture_${mode.name}');
      });
    }
  });
}

/// A picker that is never reached: the golden measures the card at rest.
class _NoCamera implements ImagePickerGateway {
  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async => null;
}
