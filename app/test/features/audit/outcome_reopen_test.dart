import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/design/figure_slot.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/data/seen_score.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';

import '../agent_harness.dart';

/// THE RECONCILIATION LINE HAS TO BE REACHABLE.
///
/// "Now scored 71 — it was 84 when you saw it" can only ever appear on a
/// LATER open of a visit's outcome: on the first one, what the phone recorded
/// is what the phone is showing. So the line is only real if two things are
/// true in the shipped app — the agent can get back to a submitted visit's
/// score, and that open asks the server again instead of replaying the number
/// from the walk out of the shop.
///
/// Both were false. The outcome was reachable from exactly one `context.go`
/// after submit, and `visitOutcomeProvider` was kept alive and fetched once,
/// so the capability existed only in widget tests that pre-seeded the store.
///
/// This test is that failure, written as the route the agent actually walks.

/// The server's answer, which a reviewer can change between opens.
class _Repo implements ScorecardsRepository {
  _Repo(this.total);

  double total;
  int reads = 0;

  @override
  Future<ServerScorecard?> getForVisit(String remoteVisitId) async {
    reads++;
    return ServerScorecard(
      visitId: remoteVisitId,
      weightedTotal: total,
      ratingBand: 'amber',
      dimensionScores: const <String, double>{'availability': 83},
    );
  }

  @override
  Future<List<ServerScorecard>> historyForOutlet(String outletId) async =>
      const <ServerScorecard>[];
}

/// The phone's memory of what it showed, without a keychain.
class _SeenScores implements SeenScoreStore {
  Map<String, int> stored = const <String, int>{};

  @override
  Future<Map<String, int>> read() async => stored;

  @override
  Future<void> write(Map<String, int> scores) async => stored = scores;
}

/// The outbox as it looks once the visit has reached the server: one sent
/// `visit_submit` row, carrying the draft id from its payload.
SyncStatus _sent(String draftId) => SyncStatus(
  pending: const <SyncItem>[],
  sent: <SyncItem>[
    SyncItem(
      id: 7,
      entityType: 'visit_submit',
      queuedAt: DateTime(2026, 9, 18, 10, 12),
      synced: true,
      attempts: 1,
      lastAttemptAt: DateTime(2026, 9, 18, 10, 13),
      visitDraftId: draftId,
    ),
  ],
  needsAttention: const <SyncItem>[],
);

/// The hero figure as it is printed, whatever else on the screen shares its
/// digits — the reconciliation line prints the same number in words.
num? _hero(WidgetTester tester) => tester
    .widget<FigureSlot>(find.byKey(const ValueKey<String>('score-hero')))
    .value;

void main() {
  testWidgets('a score changed after the agent saw it is read on the next '
      'open, from My work', (tester) async {
    final db = agentTestDb();
    await db
        .into(db.visitDrafts)
        .insert(
          VisitDraftsCompanion.insert(
            id: 'v1',
            outletId: 'o1',
            checkinTs: DateTime(2026, 9, 18, 9),
            checkinLat: -26.2,
            checkinLng: 28.0,
            geofencePass: true,
            remoteId: const Value<String>('remote-1'),
          ),
        );
    final repo = _Repo(84);

    await pumpAgentScreen(
      tester,
      const Text('Today'),
      path: '/today',
      overrides: <Override>[
        ...agentBaseOverrides(db: db, sync: _sent('v1')),
        scorecardsRepositoryProvider.overrideWithValue(repo),
        seenScoreStoreProvider.overrideWithValue(_SeenScores()),
        syncNowProvider.overrideWithValue(() async {}),
      ],
      extraRoutes: <GoRoute>[
        GoRoute(path: '/my-work', builder: (c, s) => const MyWorkScreen()),
        GoRoute(path: '/audit', builder: (c, s) => const Text('Picker')),
        GoRoute(path: '/map', builder: (c, s) => const Text('Map')),
        GoRoute(path: '/login', builder: (c, s) => const Text('Login')),
        GoRoute(
          path: '/leaderboard/contests',
          builder: (c, s) => const Text('Contests'),
        ),
        // The app's own route, verbatim: this is the entry the submit flow
        // uses, and the one My work has to be able to use again.
        GoRoute(
          path: '/audit/:outletId/done',
          builder: (context, state) => VisitOutcomeScreen(
            outletId: state.pathParameters['outletId']!,
            visitDraftId: state.uri.queryParameters['draft'] ?? '',
            outletName: state.uri.queryParameters['name'] ?? 'This store',
          ),
        ),
      ],
    );

    // 1. Walking out of the shop: the score the agent reads and the app
    //    records.
    GoRouter.of(
      tester.element(find.text('Today')),
    ).go('/audit/o1/done?draft=v1&name=Sunrise%20Spaza');
    await tester.pumpAndSettle();
    expect(_hero(tester), 84);
    expect(
      find.byKey(const ValueKey<String>('outcome-reconciled')),
      findsNothing,
      reason: 'nothing has changed yet',
    );

    // 2. On to My work — the tab root where a submitted visit is met again.
    await tester.tap(find.byKey(const ValueKey<String>('outcome-my-work')));
    await tester.pumpAndSettle();
    expect(find.byType(MyWorkScreen), findsOneWidget);

    // 3. A reviewer changes the score overnight.
    repo.total = 71;

    // 4. The agent opens the submitted visit again: the row, its sheet, and
    //    the way back to the score.
    await scrollAgentTo(
      tester,
      find.byKey(const ValueKey<String>('sync-item-7')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('sync-item-7')));
    await tester.pumpAndSettle();
    final seeScore = find.byKey(const ValueKey<String>('outbox-see-score'));
    expect(
      seeScore,
      findsOneWidget,
      reason:
          'a submitted visit has to be re-openable, or the reconciliation '
          'line is a component nobody can ever be on the right screen to read',
    );
    await tester.tap(seeScore);
    await tester.pumpAndSettle();

    // 5. The line the whole mechanism exists for — and the new number, not
    //    the one this session already fetched.
    expect(_hero(tester), 71);
    expect(repo.reads, 2, reason: 'a re-open asks the server again');
    final line = find.byKey(const ValueKey<String>('outcome-reconciled'));
    expect(line, findsOneWidget);
    expect(
      find.descendant(of: line, matching: find.text('84')),
      findsOneWidget,
      reason: 'the first number the agent saw is the referent',
    );

    await disposeAgentScreen(tester);
  });
}
