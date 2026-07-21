import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/scorecard_service.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s10_scorecard_screen.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _FakeScorecardService extends ScorecardService {
  _FakeScorecardService({required super.db, required super.syncService});

  int computeCalls = 0;
  String? finalizedVisitDraftId;

  @override
  Future<LocalScorecard> computeForVisit(String visitDraftId) async {
    computeCalls++;
    return const LocalScorecard(
      dimensionScores: {
        'availability': 50,
        'visibility': 80,
        'display': 80,
        'pricing': 0,
        'competitive': 0,
        'salesCapability': 70,
      },
      weightedTotal: 54.0,
      ratingBand: 'red',
    );
  }

  @override
  Future<void> finalizeScorecard(String visitDraftId) async {
    finalizedVisitDraftId = visitDraftId;
  }
}

void main() {
  testWidgets('renders dimension scores, total and band; finalize queues', (
    tester,
  ) async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final fake = _FakeScorecardService(
      db: db,
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorecardServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S10ScorecardScreen(visitDraftId: 'v1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('S10 Scorecard'), findsOneWidget);
    expect(find.byKey(const ValueKey('score-availability')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-visibility')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-display')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-pricing')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-competitive')), findsOneWidget);
    expect(find.byKey(const ValueKey('score-salesCapability')), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);
    expect(find.text('Total: 54.0'), findsOneWidget);
    expect(find.text('red'), findsOneWidget);

    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(fake.computeCalls, 2);

    await tester.ensureVisible(find.text('Finalize scorecard'));
    await tester.tap(find.text('Finalize scorecard'));
    await tester.pumpAndSettle();

    expect(fake.finalizedVisitDraftId, 'v1');
    expect(find.text('Scorecard queued for sync'), findsOneWidget);
  });
}
