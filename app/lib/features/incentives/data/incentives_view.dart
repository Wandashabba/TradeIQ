import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/data/gamification_repository.dart';
import 'incentives_repository.dart';

/// Which figure a scheme pays on.
///
/// The wire sends a key the scoring engine knows. It is mapped once, here, so
/// a screen never has to know that `tasks_closed` is what a manager calls
/// "tasks closed" — and so a key this client has not been taught is shown as
/// the key rather than being silently dropped or renamed.
enum IncentiveMetric {
  scorecard('scorecard', 'Average scorecard', 'points'),
  tasksClosed('tasks_closed', 'Tasks closed', 'tasks'),
  visits('visits', 'Visits submitted', 'visits');

  const IncentiveMetric(this.wire, this.label, this.unitWord);

  final String wire;

  /// What a manager calls it.
  final String label;

  /// The unit the threshold is counted in.
  final String unitWord;

  static IncentiveMetric? fromWire(String value) {
    for (final metric in IncentiveMetric.values) {
      if (metric.wire == value) return metric;
    }
    return null;
  }

  /// One agent's standing on this metric, from the board's own figures.
  ///
  /// Null where the board cannot answer: an average nobody has scored is not
  /// a zero, and a bar drawn at 0 for it would tell an agent they had made no
  /// progress when nobody has measured them at all.
  static double? valueFor(IncentiveMetric metric, LeaderboardEntry entry) =>
      switch (metric) {
        IncentiveMetric.scorecard =>
          entry.scorecardsCounted == 0 ? null : entry.avgScorecard,
        IncentiveMetric.tasksClosed => entry.tasksClosed.toDouble(),
        IncentiveMetric.visits => entry.visitsSubmitted.toDouble(),
      };
}

/// One agent's progress toward one scheme's reward.
class IncentiveProgress {
  const IncentiveProgress({
    required this.agentId,
    required this.name,
    required this.value,
    required this.threshold,
  });

  final String agentId;
  final String name;

  /// Null means the board cannot answer for this metric — not zero.
  final double? value;

  final double threshold;

  bool get earned => value != null && value! >= threshold;

  /// Null where the value is unknown: a fraction of nothing is not a fraction.
  double? get remaining => value == null
      ? null
      : (threshold - value!).clamp(0, threshold).toDouble();
}

/// One scheme, with who is close to earning it.
class IncentiveSchemeRow {
  const IncentiveSchemeRow({
    required this.scheme,
    required this.metric,
    required this.progress,
  });

  final IncentiveScheme scheme;

  /// Null for a metric key this client has not been taught. The row then shows
  /// the key itself rather than renaming it or hiding the scheme.
  final IncentiveMetric? metric;

  /// Every measurable agent, nearest to the reward first, earners last —
  /// a list of people who have already earned it does not answer "who is
  /// about to?".
  final List<IncentiveProgress> progress;

  int get earnedCount => progress.where((p) => p.earned).length;

  /// The agent closest to the reward without having reached it, or null when
  /// nobody is on the way — everybody has earned it, or nobody is measurable.
  IncentiveProgress? get closest {
    for (final p in progress) {
      if (!p.earned && p.value != null) return p;
    }
    return null;
  }
}

/// The incentives screen's view model.
class IncentivesView {
  const IncentivesView({required this.rows, required this.agentsMeasured});

  final List<IncentiveSchemeRow> rows;

  /// How many agents the board could answer for at all. The denominator of
  /// every "3 of 11" on this screen, and zero when the board is unavailable —
  /// in which case no bar renders, rather than a bar out of a made-up total.
  final int agentsMeasured;

  int get awarding => rows.where((r) => r.scheme.active).length;
}

/// Schemes, merged with the board's figures so "who is close?" can be answered
/// without a second endpoint.
///
/// The board is a **base layer, never a blocker**: a slow or failed board
/// leaves every scheme listed and editable with no progress beneath it, which
/// is the honest rendering of "nobody has told us yet". A screen that refused
/// to list a scheme because a figure would not resolve is a screen a manager
/// cannot administer.
final incentivesViewProvider = FutureProvider<IncentivesView>((ref) async {
  final page = await ref.read(incentivesRepositoryProvider).listSchemes();

  final board = ref
      .watch(leaderboardProvider)
      .maybeWhen(
        data: (list) => list,
        orElse: () => const <LeaderboardEntry>[],
      );

  return IncentivesView(
    agentsMeasured: board.length,
    rows: <IncentiveSchemeRow>[
      for (final scheme in page.data)
        _rowFor(scheme, IncentiveMetric.fromWire(scheme.metric), board),
    ],
  );
});

IncentiveSchemeRow _rowFor(
  IncentiveScheme scheme,
  IncentiveMetric? metric,
  List<LeaderboardEntry> board,
) {
  if (metric == null) {
    return IncentiveSchemeRow(
      scheme: scheme,
      metric: null,
      progress: const <IncentiveProgress>[],
    );
  }
  final progress = <IncentiveProgress>[
    for (final entry in board)
      IncentiveProgress(
        agentId: entry.agentId,
        name: entry.label,
        value: IncentiveMetric.valueFor(metric, entry),
        threshold: scheme.threshold,
      ),
  ];
  // Nearest to the reward first; earners after them; agents nobody can
  // measure last, because an unknown is not a position in a race.
  progress.sort((a, b) {
    final aRank = a.value == null ? 2 : (a.earned ? 1 : 0);
    final bRank = b.value == null ? 2 : (b.earned ? 1 : 0);
    if (aRank != bRank) return aRank.compareTo(bRank);
    final ar = a.remaining;
    final br = b.remaining;
    if (ar == null || br == null) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    final byRemaining = ar.compareTo(br);
    return byRemaining != 0
        ? byRemaining
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return IncentiveSchemeRow(scheme: scheme, metric: metric, progress: progress);
}
