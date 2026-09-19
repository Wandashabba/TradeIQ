import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/features/audit/data/scorecard_service.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s10_scorecard_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _FakeScorecard extends ScorecardService {
  _FakeScorecard({
    required super.db,
    required super.syncService,
    this.band = 'red',
  });

  final String band;
  int computeCalls = 0;
  String? finalizedVisitDraftId;

  @override
  Future<LocalScorecard> computeForVisit(String visitDraftId) async {
    computeCalls++;
    return LocalScorecard(
      // `competitive` is ABSENT — no competitor on shelf to measure against —
      // and `pricing` is a measured zero. Two different facts.
      dimensionScores: const <String, double>{
        'availability': 50,
        'visibility': 80,
        'display': 80,
        'pricing': 0,
        'salesCapability': 70,
      },
      weightedTotal: 54.0,
      ratingBand: band,
    );
  }

  @override
  Future<void> finalizeScorecard(String visitDraftId) async {
    finalizedVisitDraftId = visitDraftId;
  }
}

_FakeScorecard _fake({String band = 'red'}) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return _FakeScorecard(
    db: db,
    syncService: SyncService(db: db, flusher: _NoopFlusher()),
    band: band,
  );
}

List<Override> _overrides(ScorecardService svc) => <Override>[
  scorecardServiceProvider.overrideWithValue(svc),
];

const _screen = S10ScorecardScreen(visitDraftId: 'v1');

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  testWidgets('the total, the band in words, and the sentence that keeps it '
      'from reading as final', (tester) async {
    await pumpSection(tester, _screen, overrides: _overrides(_fake()));

    expect(
      find.descendant(of: _key('score-total'), matching: find.text('54.0')),
      findsOneWidget,
    );
    expect(tester.widget<StatusChip>(_key('score-band')).label, 'Gap');
    // Derived on this phone, and it says so — never presented as the verdict.
    expect(
      find.text(
        'Worked out on this phone. The final score comes back when the visit '
        'sends.',
      ),
      findsOneWidget,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets('an unmeasured dimension is a dash and a reason; a measured zero '
      'is 0', (tester) async {
    await pumpSection(tester, _screen, overrides: _overrides(_fake()));

    await scrollAgentTo(tester, _key('score-competitive'));
    final competitive = _key('score-competitive');
    expect(
      find.descendant(of: competitive, matching: find.byType(NotMeasured)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: competitive, matching: find.text('0')),
      findsNothing,
    );

    await scrollAgentTo(tester, _key('score-pricing'));
    final pricing = _key('score-pricing');
    expect(
      find.descendant(of: pricing, matching: find.text('0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pricing, matching: find.byType(NotMeasured)),
      findsNothing,
    );
    await disposeAgentScreen(tester);
  });

  testWidgets('Refresh recomputes; Finalize queues, and then rests', (
    tester,
  ) async {
    final svc = _fake();
    await pumpSection(tester, _screen, overrides: _overrides(svc));
    expect(svc.computeCalls, 1);

    await tapInSection(tester, _key('score-refresh'));
    expect(svc.computeCalls, 2);

    await tapInSection(tester, sectionSave);
    expect(svc.finalizedVisitDraftId, 'v1');
    expect(find.textContaining('Scorecard queued for sync'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  for (final (wire, word, level) in <(String, String, StatusLevel)>[
    ('green', 'Healthy', StatusLevel.onTarget),
    ('amber', 'Watch', StatusLevel.watch),
    ('red', 'Gap', StatusLevel.critical),
  ]) {
    testWidgets('the $wire band is the word "$word" on a silhouette', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(_fake(band: wire)),
      );
      final chip = tester.widget<StatusChip>(_key('score-band'));
      expect(chip.label, word);
      expect(chip.level, level);
      await disposeAgentScreen(tester);
    });
  }

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('Finalize is the one object until queued, then none — '
          '${skin.name}', (tester) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(_fake()),
          skin: skin,
        );
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'score',
          phase: 'armed',
          expected: 1,
        );
        await tapInSection(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'score',
          phase: 'queued',
          expected: 0,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
