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
    required this.points,
    this.displayName,
  });
  final String agentId;
  final String email;
  final int visitsSubmitted;
  final int tasksClosed;
  final int rank;
  final double avgScorecard;
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
        rank: json['rank'] as int? ?? 0,
        avgScorecard: (json['avgScorecard'] as num?)?.toDouble() ?? 0,
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

  /// The reason in words.
  String get reasonLabel => switch (reason) {
        'visit_submitted' => 'Visit submitted',
        'task_closed' => 'Task closed',
        'scorecard' => 'Scorecard',
        '' => 'Points',
        _ => '${reason[0].toUpperCase()}'
            '${reason.substring(1).replaceAll('_', ' ')}',
      };

  /// What the entry contributes, as a figure: "+5 pts", or "score 78.5" for a
  /// scorecard, whose score is averaged rather than added.
  String get figure => reason == 'scorecard' && score != null
      ? 'score ${_trimmed(score!)}'
      : '${points < 0 ? '-' : '+'}${points.abs()} pts';

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

/// 85 -> "85", 78.5 -> "78.5", 78.33 -> "78.33".
String _trimmed(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

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

final gamificationRepositoryProvider =
    Provider<GamificationRepository>((ref) => DioGamificationRepository());

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.read(gamificationRepositoryProvider).leaderboard();
});

final agentPointsProvider =
    FutureProvider.family<AgentPointsHistory, String>((ref, agentId) {
  return ref.read(gamificationRepositoryProvider).agentPoints(agentId);
});
