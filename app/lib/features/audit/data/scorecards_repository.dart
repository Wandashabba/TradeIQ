import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/paginated_response.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_status.dart';

/// The six dimensions, in the order the agent worked through them, with the
/// words an agent uses rather than the field names the API uses.
const kDimensionLabels = <String, String>{
  'availability': 'Availability',
  'visibility': 'Visibility',
  'display': 'Display',
  'pricing': 'Pricing',
  'competitive': 'Share of shelf',
  'salesCapability': 'Team capability',
};

/// Why a dimension could not be scored — in the agent's terms, so an unscored
/// dimension reads as a fact about the store, not a failure of theirs.
const kUnmeasurableReasons = <String, String>{
  'competitive': 'No competitor on shelf — not counted against you.',
  'salesCapability': 'No staff on shift — not counted against you.',
};

/// A scorecard as the *server* computed it — the one the manager sees.
///
/// The app can also compute a scorecard offline (ADR 0005), but that one is a
/// proxy: it scores pricing as "did you capture anything" and uses the default
/// weights rather than this client's. Showing it as *the* score would mean
/// showing the agent a number that quietly changes behind their back. So the
/// outcome screen shows this one, or none.
class ServerScorecard {
  const ServerScorecard({
    required this.visitId,
    required this.weightedTotal,
    required this.ratingBand,
    required this.dimensionScores,
  });

  final String visitId;
  final double weightedTotal;

  /// The wire value: 'green' | 'amber' | 'red'. Kept exactly as the server
  /// sends it — it is never shown. `core/rating_band.dart` turns it into the
  /// display name (Healthy / Watch / Gap) at the render site.
  final String ratingBand;

  /// A dimension the server could not measure is ABSENT here, not zero — and it
  /// must render as "—". A zero would read to the agent as "you scored nothing
  /// on this", when in truth there was nothing in the store to score.
  final Map<String, double> dimensionScores;

  double? scoreOf(String dimension) => dimensionScores[dimension];

  factory ServerScorecard.fromJson(Map<String, dynamic> json) {
    final scores = (json['dimensionScores'] as Map?) ?? const {};
    return ServerScorecard(
      visitId: json['visitId'] as String,
      weightedTotal: (json['weightedTotal'] as num).toDouble(),
      ratingBand: json['ratingBand'] as String,
      dimensionScores: {
        for (final entry in scores.entries)
          if (entry.value is num)
            entry.key as String: (entry.value as num).toDouble(),
      },
    );
  }
}

abstract class ScorecardsRepository {
  /// The server's scorecard for a visit, or null if it hasn't been scored yet.
  Future<ServerScorecard?> getForVisit(String remoteVisitId);

  /// This agent's previous scores at this outlet, most recent first.
  Future<List<ServerScorecard>> historyForOutlet(String outletId);
}

class DioScorecardsRepository implements ScorecardsRepository {
  @override
  Future<ServerScorecard?> getForVisit(String remoteVisitId) async {
    try {
      final response = await dio.get('/scorecards/$remoteVisitId');
      return ServerScorecard.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Not scored yet is an ordinary outcome (the queue hasn't reached the
      // server), not an error to shout about. Anything else is.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<ServerScorecard>> historyForOutlet(String outletId) async {
    final response = await dio.get(
      '/scorecards/history',
      queryParameters: {'outletId': outletId},
    );
    // The endpoint now answers with the shared `{data, nextCursor}` envelope.
    // Only the first page is read, and deliberately: this is the "last
    // handful of scores at this outlet" that feeds the up-or-down delta on
    // the outcome screen, not a browsable history — there is no "load more"
    // to hang the cursor off. The server's default limit is what "handful"
    // means, so it lives in one place rather than being re-guessed here.
    final page = PaginatedResponse<ServerScorecard>.fromJson(
      response.data as Map<String, dynamic>,
      (json) => ServerScorecard.fromJson(json as Map<String, dynamic>),
    );
    return page.data;
  }
}

final scorecardsRepositoryProvider = Provider<ScorecardsRepository>(
  (ref) => DioScorecardsRepository(),
);

/// How the visit ended.
class VisitOutcome {
  const VisitOutcome({
    required this.score,
    required this.previous,
    this.previousUnknown = false,
  });

  /// Null means the visit has not reached the server yet — so there is no score
  /// to show, and we say so instead of inventing one.
  final ServerScorecard? score;

  /// This agent's last score at this outlet, if they have been here before.
  ///
  /// Null means one of two different things, and [previousUnknown] says
  /// which: the history loaded and held no earlier card (a first scored
  /// visit), or the history could not be read at all.
  final ServerScorecard? previous;

  /// True when the history request failed, so whether there *was* an earlier
  /// visit is not known. Unknown is not absent: "First scored visit here" is
  /// a claim, and on a dropped request at a store they have scored before it
  /// is a false one.
  final bool previousUnknown;

  bool get isHeldOnPhone => score == null;

  /// Change since their last visit here, in points. Null when there is nothing
  /// honest to compare against.
  double? get delta {
    final now = score;
    final then = previous;
    if (now == null || then == null) return null;
    return now.weightedTotal - then.weightedTotal;
  }
}

/// Everything the outcome screen needs, fetched when it opens.
///
/// Flushes the outbox first, because the visit and its scorecard marker are
/// sitting in it — without that, a visit submitted on good signal would still
/// say "held on this phone" for as long as it took the next flush to come round.
///
/// **Auto-dispose, and that is the whole of the reconciliation line working.**
/// A score the agent read that is later changed on review is the event this
/// screen exists to catch, and it can only be caught on a LATER open. Kept
/// alive, the second open would be served the number from the first one —
/// which always equals what the phone recorded, so the line could never
/// render outside a test. Every open of a submitted visit's outcome now asks
/// the server again.
final visitOutcomeProvider = FutureProvider.autoDispose
    .family<VisitOutcome, ({String visitDraftId, String outletId})>((
      ref,
      args,
    ) async {
      final db = ref.read(localDbProvider);
      final repo = ref.read(scorecardsRepositoryProvider);

      try {
        await ref.read(syncNowProvider)();
      } catch (_) {
        // No signal. That is the offline path, not a failure — fall through and let
        // the outcome say "held on this phone".
      }

      final draft = await (db.select(
        db.visitDrafts,
      )..where((t) => t.id.equals(args.visitDraftId))).getSingleOrNull();
      final remoteId = draft?.remoteId;
      if (remoteId == null) {
        return const VisitOutcome(score: null, previous: null);
      }

      ServerScorecard? score;
      List<ServerScorecard> history = const [];
      try {
        score = await repo.getForVisit(remoteId);
        history = await repo.historyForOutlet(args.outletId);
      } on DioException {
        // The captures are safe in the outbox either way. A network failure here
        // costs the agent a number on a screen, not their work.
        //
        // When the score arrived and only the history dropped, the previous
        // visit is UNKNOWN, not absent — and the screen must not turn that
        // into "first scored visit here".
        return VisitOutcome(
          score: score,
          previous: null,
          previousUnknown: score != null,
        );
      }

      // The visit that just ended is in its own history — the comparison is against
      // the one before it.
      ServerScorecard? previous;
      for (final card in history) {
        if (card.visitId != remoteId) {
          previous = card;
          break;
        }
      }

      return VisitOutcome(score: score, previous: previous);
    });
