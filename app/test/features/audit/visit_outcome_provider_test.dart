import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';

/// WHAT THE OUTCOME KNOWS, and what it only thinks it knows.
///
/// The screen prints "First scored visit here." whenever there is no previous
/// card. That sentence is a claim about the agent's own record, so the thing
/// that assembles the outcome has to tell the difference between *the history
/// said there is none* and *the history never arrived*.

const _card = ServerScorecard(
  visitId: 'remote-1',
  weightedTotal: 71,
  ratingBand: 'amber',
  dimensionScores: <String, double>{'availability': 83},
);

const _earlier = ServerScorecard(
  visitId: 'remote-0',
  weightedTotal: 65,
  ratingBand: 'amber',
  dimensionScores: <String, double>{},
);

/// A repository whose history can drop the way a taxi rank drops a request.
class _Repo implements ScorecardsRepository {
  _Repo({this.score = _card, this.history, this.historyThrows = false});

  final ServerScorecard? score;
  final List<ServerScorecard>? history;
  final bool historyThrows;

  @override
  Future<ServerScorecard?> getForVisit(String remoteVisitId) async => score;

  @override
  Future<List<ServerScorecard>> historyForOutlet(String outletId) async {
    if (historyThrows) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/scorecards/history'),
        reason: 'no signal',
      );
    }
    return history ?? const <ServerScorecard>[];
  }
}

Future<VisitOutcome> _outcome(LocalDb db, _Repo repo) async {
  final container = ProviderContainer(
    overrides: <Override>[
      localDbProvider.overrideWithValue(db),
      scorecardsRepositoryProvider.overrideWithValue(repo),
      // The provider flushes the outbox first; the queue is not what is
      // under test here.
      syncNowProvider.overrideWithValue(() async {}),
    ],
  );
  addTearDown(container.dispose);
  return container.read(
    visitOutcomeProvider((visitDraftId: 'v1', outletId: 'o1')).future,
  );
}

void main() {
  late LocalDb db;

  setUp(() async {
    db = LocalDb(NativeDatabase.memory());
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
  });

  tearDown(() => db.close());

  test('a history that dropped is unknown, not "no previous visit"', () async {
    final outcome = await _outcome(db, _Repo(historyThrows: true));

    // The score arrived; only the history request failed. An agent on patchy
    // signal must not be told this is their first scored visit at a store
    // they have scored before.
    expect(outcome.score, isNotNull);
    expect(outcome.previous, isNull);
    expect(
      outcome.previousUnknown,
      isTrue,
      reason: 'a dropped history is unknown, and the screen says so in words',
    );
  });

  test('a history that loaded and held no earlier card is a first visit', () async {
    final outcome = await _outcome(
      db,
      _Repo(history: const <ServerScorecard>[_card]),
    );

    // The visit that just ended is in its own history; there is nothing
    // before it. That IS a first scored visit, and the sentence is true.
    expect(outcome.previous, isNull);
    expect(outcome.previousUnknown, isFalse);
  });

  test('a history with an earlier card carries it', () async {
    final outcome = await _outcome(
      db,
      _Repo(history: const <ServerScorecard>[_card, _earlier]),
    );

    expect(outcome.previous?.visitId, 'remote-0');
    expect(outcome.previousUnknown, isFalse);
    expect(outcome.delta, 71 - 65);
  });

  test('no score at all is held on the phone, not an unknown history', () async {
    final outcome = await _outcome(db, _Repo(score: null, historyThrows: true));

    // Nothing to compare against because there is nothing to compare: the
    // held receipt owns this case, and it must not also carry the
    // could-not-load sentence.
    expect(outcome.isHeldOnPhone, isTrue);
    expect(outcome.previousUnknown, isFalse);
  });
}
