import 'gamification_repository.dart';

/// THE LEADERBOARD'S VIEW MODEL.
///
/// Two decisions live here rather than in the widget tree, so both are
/// testable without pumping a frame.
///
/// 1. **An agent nobody measured is unranked, not last (#398).** The wire now
///    sends `rank: null` for an agent with no submitted visit, no closed task
///    and no scorecard in the window. The board splits on that rather than
///    printing a place: last is a comparison, and an absence is not one.
/// 2. **A place and a payout are not peers of an average.** The engine adds a
///    0–100 mean to 5 a closed task and 2 a submitted visit, so `points` and
///    `avgScorecard` are in different units. The board shows the payout, and
///    the average belongs on the agent's own ledger where its sample size is
///    beside it.
class LeaderboardView {
  const LeaderboardView({required this.ranked, required this.unranked});

  /// Agents with a place, in it — best first.
  final List<LeaderboardEntry> ranked;

  /// Agents the window holds nothing for, alphabetical by the name shown.
  /// They are listed, never hidden: an agent missing from a board reads as an
  /// agent who left, and the fact worth knowing is that nobody has measured
  /// them.
  final List<LeaderboardEntry> unranked;

  int get total => ranked.length + unranked.length;

  bool get isEmpty => total == 0;

  static LeaderboardView of(List<LeaderboardEntry> entries) {
    final ranked = entries.where((e) => e.rank != null).toList()
      ..sort((a, b) => a.rank!.compareTo(b.rank!));
    final unranked = entries.where((e) => e.rank == null).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return LeaderboardView(ranked: ranked, unranked: unranked);
  }
}
