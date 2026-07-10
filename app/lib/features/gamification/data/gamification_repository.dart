import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });
  final String agentId;
  final String email;
  final int visitsSubmitted;
  final int tasksClosed;
  final int rank;
  final double avgScorecard;
  final double points;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        agentId: json['agentId'] as String,
        email: json['email'] as String,
        visitsSubmitted: json['visitsSubmitted'] as int? ?? 0,
        tasksClosed: json['tasksClosed'] as int? ?? 0,
        rank: json['rank'] as int? ?? 0,
        avgScorecard: (json['avgScorecard'] as num?)?.toDouble() ?? 0,
        points: (json['points'] as num?)?.toDouble() ?? 0,
      );
}

abstract class GamificationRepository {
  Future<List<LeaderboardEntry>> leaderboard();
}

class DioGamificationRepository implements GamificationRepository {
  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    final response = await dio.get('/gamification/leaderboard');
    return (response.data as List)
        .map((json) => LeaderboardEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final gamificationRepositoryProvider =
    Provider<GamificationRepository>((ref) => DioGamificationRepository());

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.read(gamificationRepositoryProvider).leaderboard();
});
