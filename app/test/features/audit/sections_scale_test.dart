import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/capability_repository.dart';
import 'package:tradeiq_app/features/audit/data/competitive_repository.dart';
import 'package:tradeiq_app/features/audit/data/pricing_repository.dart';
import 'package:tradeiq_app/features/audit/data/risks_repository.dart';
import 'package:tradeiq_app/features/audit/data/scorecard_service.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/data/tasks_repository.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/audit/data/visibility_repository.dart';
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

import '../agent_harness.dart';
import 'client_questions_screen_test.dart' as cq;
import 'section_harness.dart';

/// EVERY SECTION AT 2.0× AND IN AFRIKAANS — the longest words at the largest
/// type, on a 360dp phone, in every skin. Nothing may overflow, and the frame
/// may not spend more amber than the skin allows. A section is a scrolling
/// form, so the check walks the whole body down to its Save, not just the
/// first screenful.

const _sku = Sku(
  id: 's1',
  name: 'Koeldrank 500ml Oorspronklike Smaak Groot Bottel',
  category: 'Drinks',
  minFacingsStandard: 4,
  rrp: 1284.99,
  daysOutOfStock: 3,
  velocityAvg: 12.4,
  effectivePrice: 1284.99,
);

class _Skus implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse<Sku>(data: <Sku>[_sku], nextCursor: null);
}

class _Noop
    implements
        StockRepository,
        VisibilityRepository,
        PricingRepository,
        CompetitiveRepository,
        CapabilityRepository,
        RisksRepository,
        TasksRepository {
  @override
  Future<void> saveStock({
    required String visitDraftId,
    required List<StockEntry> entries,
  }) async {}

  @override
  Future<void> saveVisibility({
    required String visitDraftId,
    required VisibilityCapture capture,
  }) async {}

  @override
  Future<void> savePricing({
    required String visitDraftId,
    required List<PricingEntry> entries,
  }) async {}

  @override
  Future<void> saveCompetitive({
    required String visitDraftId,
    required List<CompetitiveEntry> entries,
  }) async {}

  @override
  Future<void> saveCapability({
    required String visitDraftId,
    required CapabilityCapture capture,
  }) async {}

  @override
  Future<void> saveRisks({
    required String visitDraftId,
    required List<RiskEntry> entries,
  }) async {}

  @override
  Future<void> saveTask({
    required String visitDraftId,
    required String outletId,
    required TaskDraft task,
  }) async {}
}

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _Score extends ScorecardService {
  _Score({required super.db, required super.syncService});

  @override
  Future<LocalScorecard> computeForVisit(String visitDraftId) async =>
      const LocalScorecard(
        dimensionScores: <String, double>{
          'availability': 50,
          'visibility': 80,
          'salesCapability': 70,
        },
        weightedTotal: 61.5,
        ratingBand: 'amber',
      );

  @override
  Future<void> finalizeScorecard(String visitDraftId) async {}
}

List<Override> _overrides() {
  final noop = _Noop();
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return <Override>[
    skusRepositoryProvider.overrideWithValue(_Skus()),
    stockRepositoryProvider.overrideWithValue(noop),
    visibilityRepositoryProvider.overrideWithValue(noop),
    pricingRepositoryProvider.overrideWithValue(noop),
    competitiveRepositoryProvider.overrideWithValue(noop),
    capabilityRepositoryProvider.overrideWithValue(noop),
    risksRepositoryProvider.overrideWithValue(noop),
    tasksRepositoryProvider.overrideWithValue(noop),
    templateSectionRepositoryProvider.overrideWithValue(
      cq.FakeTemplateSectionRepository(),
    ),
    scorecardServiceProvider.overrideWithValue(
      _Score(
        db: db,
        syncService: SyncService(db: db, flusher: _NoopFlusher()),
      ),
    ),
  ];
}

final _sections = <String, Widget>{
  'outlet info': S1OutletInfoScreen(checkinTs: DateTime(2026, 9, 19, 7, 58)),
  'stock': const S2StockScreen(visitDraftId: 'v1', outletId: 'o1'),
  'visibility': const S3S4VisibilityDisplayScreen(visitDraftId: 'v1'),
  'pricing': const S5PricingPromotionsScreen(
    visitDraftId: 'v1',
    outletId: 'o1',
  ),
  'competitive': const S6CompetitiveScreen(visitDraftId: 'v1'),
  'capability': const S7CapabilityScreen(visitDraftId: 'v1'),
  'risks': const S8RisksScreen(visitDraftId: 'v1'),
  'action plan': const S9ActionPlanScreen(visitDraftId: 'v1', outletId: 'o1'),
  'score': const S10ScorecardScreen(visitDraftId: 'v1'),
  'client questions': ClientQuestionsScreen(
    visitDraftId: 'v1',
    template: cq.template,
  ),
};

void main() {
  for (final MapEntry(key: name, value: section) in _sections.entries) {
    for (final skin in agentSkinModes) {
      testWidgets('$name at 2.0× in Afrikaans — ${skin.name}', (tester) async {
        await pumpSection(
          tester,
          section,
          overrides: _overrides(),
          skin: skin,
          textScale: 2.0,
          locale: const Locale('af'),
        );
        expect(tester.takeException(), isNull, reason: '$name on arrival');

        // Walk the whole form: every screenful must lay out.
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 30; i++) {
          final position = tester.state<ScrollableState>(scrollable).position;
          if (position.pixels >= position.maxScrollExtent) break;
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$name scrolled');
        }

        await expectAmberWithinBudget(
          tester,
          skin: skin,
          route: name,
          phase: '2.0x af',
        );
        await disposeAgentScreen(tester);
      });
    }
  }
}
