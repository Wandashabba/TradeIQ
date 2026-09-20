import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/person_label.dart';
import '../../../core/network/api_client.dart';

/// One agent's standing in the S-gamification leaderboard returned by
/// GET /gamification/leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.agentId,
    required this.email,
    required this.visitsSubmitted,
    required this.tasksClosed,
    required this.rank,
    required this.avgScorecard,
    required this.scorecardsCounted,
    required this.points,
    this.displayName,
  });
  final String agentId;
  final String email;
  final int visitsSubmitted;
  final int tasksClosed;

  /// The agent's place, or **null** for an agent with nothing measured in the
  /// window (#398).
  ///
  /// The board used to hand every row `index + 1`, so an agent with no
  /// submitted visit and no closed task was told they came last. Last place is
  /// a comparison and an absence is not one. The row still renders — it sorts
  /// below every ranked row — and the screen says "not ranked yet" in words.
  final int? rank;

  /// The mean of [scorecardsCounted] scores, and meaningless when that is 0.
  final double avgScorecard;

  /// How many scorecards [avgScorecard] is the mean of, in the window.
  ///
  /// `mean([])` is 0, so without this a client cannot tell an agent who scored
  /// zero from an agent nobody has scored. It is also the sample size: an
  /// average needs n >= 3 before it is a comparison rather than an anecdote.
  final int scorecardsCounted;

  /// The payout figure. **Not a peer of [avgScorecard]** — the engine adds a
  /// 0-100 mean to 5 per closed task and 2 per submitted visit, so the two
  /// numbers are in different units and a row that printed them side by side
  /// as "85 / 94" would read as a fraction.
  final double points;

  /// What people call this agent. Null for agents never given a name.
  final String? displayName;

  /// The name when there is one, otherwise the email.
  String get label => personLabel(displayName, email);

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        agentId: json['agentId'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        visitsSubmitted: json['visitsSubmitted'] as int? ?? 0,
        tasksClosed: json['tasksClosed'] as int? ?? 0,
        // Null is the wire's word for "unranked" and it is carried through as
        // null. A `?? 0` here would turn every unmeasured agent into rank
        // zero, which is a place, and a worse invention than the last place
        // this replaced.
        rank: (json['rank'] as num?)?.toInt(),
        avgScorecard: (json['avgScorecard'] as num?)?.toDouble() ?? 0,
        scorecardsCounted: (json['scorecardsCounted'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toDouble() ?? 0,
      );
}

/// One row of the points ledger (#124): a single thing that earned points.
///
/// A scorecard entry earns no points of its own — the leaderboard adds the
/// *average* scorecard — so it carries the [score] it feeds into that average.
class PointsEntry {
  const PointsEntry({
    required this.id,
    required this.points,
    required this.reason,
    required this.sourceType,
    required this.sourceId,
    required this.occurredAt,
    this.score,
    this.outletName,
  });

  final String id;
  final int points;
  final String reason;
  final String sourceType;
  final String sourceId;
  final double? score;
  final DateTime occurredAt;

  /// Where it happened, when the source can still be resolved.
  final String? outletName;

  /// The reason in words, **in English**.
  ///
  /// The manager console is English-only, so this is the right thing there.
  /// It is not the right thing on a translated screen: use `meReasonLabel` in
  /// `my_record_screen.dart`, which maps the same three wire values through
  /// the ARB and falls back to this for a reason it does not know.
  String get reasonLabel => switch (reason) {
    'visit_submitted' => 'Visit submitted',
    'task_closed' => 'Task closed',
    'scorecard' => 'Scorecard',
    '' => 'Points',
    _ =>
      '${reason[0].toUpperCase()}'
          '${reason.substring(1).replaceAll('_', ' ')}',
  };

  factory PointsEntry.fromJson(Map<String, dynamic> json) => PointsEntry(
    id: json['id'] as String,
    points: (json['points'] as num?)?.toInt() ?? 0,
    reason: json['reason'] as String? ?? '',
    sourceType: json['sourceType'] as String? ?? '',
    sourceId: json['sourceId'] as String? ?? '',
    score: (json['score'] as num?)?.toDouble(),
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    outletName: json['outletName'] as String?,
  );
}

/// GET /gamification/agents/:agentId/points — who, and their latest entries.
class AgentPointsHistory {
  const AgentPointsHistory({
    required this.agentId,
    required this.email,
    required this.entries,
    this.displayName,
    this.nextCursor,
  });

  final String agentId;
  final String email;
  final String? displayName;
  final List<PointsEntry> entries;
  final String? nextCursor;

  String get label => personLabel(displayName, email);

  factory AgentPointsHistory.fromJson(Map<String, dynamic> json) {
    final agent = json['agent'] as Map<String, dynamic>? ?? const {};
    return AgentPointsHistory(
      agentId: agent['agentId'] as String? ?? '',
      email: agent['email'] as String? ?? '',
      displayName: agent['displayName'] as String?,
      entries: (json['data'] as List? ?? const [])
          .map((e) => PointsEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

abstract class GamificationRepository {
  Future<List<LeaderboardEntry>> leaderboard();

  /// One agent's latest points entries (manager/admin).
  Future<AgentPointsHistory> agentPoints(String agentId);
}

class DioGamificationRepository implements GamificationRepository {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    final response = await dio.get('/gamification/leaderboard');
    return (response.data as List)
        .map((json) => LeaderboardEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AgentPointsHistory> agentPoints(String agentId) async {
    final response = await dio.get(
      '/gamification/agents/${Uri.encodeComponent(agentId)}/points',
    );
    return AgentPointsHistory.fromJson(response.data as Map<String, dynamic>);
  }
}

final gamificationRepositoryProvider = Provider<GamificationRepository>(
  (ref) => DioGamificationRepository(),
);

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.read(gamificationRepositoryProvider).leaderboard();
});

final agentPointsProvider = FutureProvider.family<AgentPointsHistory, String>((
  ref,
  agentId,
) {
  return ref.read(gamificationRepositoryProvider).agentPoints(agentId);
});
