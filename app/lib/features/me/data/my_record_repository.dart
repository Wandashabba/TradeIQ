import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../gamification/data/gamification_repository.dart';

/// THE AGENT'S OWN RECORD — the data behind "Me" (#383/#384).
///
/// Every endpoint read here is **self-scoped on the server**, and that is the
/// property the whole screen rests on:
///
/// * `GET /visits/me` takes its agent id from the token. It is not a
///   parameter, so no request this file can build returns a colleague's day.
/// * `GET /gamification/me` returns the caller's own leaderboard entry and
///   their own ledger rows; a caller who is not a field agent is never ranked
///   and gets an empty history to match.
/// * `GET /incentives` is a read of the *client's* schemes — the rules of the
///   game, identical for everyone, carrying no one's figures.
///
/// Nothing here reads `/gamification/leaderboard` or `/gamification/agents/
/// :id/points`. Comparing an agent to their peers belongs to Contests, and the
/// drill-down is manager-only.

/// What the device showed the agent on the way out of the shop.
///
/// Kept apart from the server's number rather than folded into it: the two
/// legitimately disagree (ADR 0005 chose speed over parity on the device), and
/// an agent who watched 84 and later opens 71 is owed the sentence, not a
/// silent replacement.
class SeenScore {
  const SeenScore({
    required this.weightedTotal,
    required this.ratingBand,
    this.seenAt,
  });

  final double weightedTotal;
  final String ratingBand;
  final DateTime? seenAt;

  static SeenScore? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return SeenScore(
      weightedTotal: (json['weightedTotal'] as num).toDouble(),
      ratingBand: json['ratingBand'] as String,
      seenAt: json['seenAt'] == null
          ? null
          : DateTime.parse(json['seenAt'] as String).toLocal(),
    );
  }
}

/// The authoritative score, and what preceded it.
class MyVisitScore {
  const MyVisitScore({
    required this.weightedTotal,
    required this.ratingBand,
    required this.scoredAt,
    this.seen,
  });

  final double weightedTotal;
  final String ratingBand;
  final DateTime scoredAt;
  final SeenScore? seen;

  /// Whether the number moved after the agent read it.
  ///
  /// Rounded to whole points first: the screen prints whole points, and a line
  /// announcing that 71 became 71 is noise, not honesty.
  bool get changedSinceSeen =>
      seen != null && seen!.weightedTotal.round() != weightedTotal.round();

  factory MyVisitScore.fromJson(Map<String, dynamic> json) => MyVisitScore(
    weightedTotal: (json['weightedTotal'] as num).toDouble(),
    ratingBand: json['ratingBand'] as String,
    scoredAt: DateTime.parse(json['scoredAt'] as String).toLocal(),
    seen: SeenScore.fromJson(json['seen'] as Map<String, dynamic>?),
  );
}

/// One visit, as its own agent sees it.
class MyVisit {
  const MyVisit({
    required this.id,
    required this.outletId,
    required this.outletName,
    required this.outletCode,
    required this.checkinTs,
    required this.geofencePass,
    required this.status,
    required this.sectionsCaptured,
    required this.sectionsTotal,
    required this.photos,
    required this.tasksRaised,
    this.checkinDistanceM,
    this.dwellMinutes,
    this.score,
    this.reviewedVerdict,
    this.pinReported = false,
    this.local = false,
  });

  final String id;
  final String outletId;
  final String outletName;
  final String outletCode;
  final DateTime checkinTs;

  /// Metres from the outlet's pin at check-in. **Null is "not measured"** —
  /// the phone had no usable fix — and is a different fact from 0 m.
  final double? checkinDistanceM;

  final bool geofencePass;

  /// `in_progress` or `submitted`.
  final String status;

  /// Minutes in the shop, both stamps from the device's clock. Null on a visit
  /// that has not been submitted, or one recorded before the app stamped it.
  final int? dwellMinutes;

  final int sectionsCaptured;
  final int sectionsTotal;
  final int photos;
  final int tasksRaised;

  /// Null while the server has not scored this visit. It is not a zero, and
  /// the screen must never print one.
  final MyVisitScore? score;

  /// `confirmed` · `dismissed` · `inconclusive` once a reviewer has ruled.
  final String? reviewedVerdict;

  /// The agent started this visit by reporting the outlet's pin as wrong
  /// (#386). Their own claim, so theirs to see — and the reason a visit they
  /// were allowed to start still reads out of fence.
  final bool pinReported;

  /// True for a row assembled from this phone's own drafts rather than from
  /// the server. Today's work, before it syncs.
  final bool local;

  bool get submitted => status == 'submitted';

  factory MyVisit.fromJson(Map<String, dynamic> json) => MyVisit(
    id: json['id'] as String,
    outletId: json['outletId'] as String? ?? '',
    outletName: json['outletName'] as String? ?? '',
    outletCode: json['outletCode'] as String? ?? '',
    checkinTs: DateTime.parse(json['checkinTs'] as String).toLocal(),
    checkinDistanceM: (json['checkinDistanceM'] as num?)?.toDouble(),
    geofencePass: json['geofencePass'] as bool? ?? true,
    status: json['status'] as String? ?? 'submitted',
    dwellMinutes: (json['dwellMinutes'] as num?)?.toInt(),
    sectionsCaptured: (json['sectionsCaptured'] as num?)?.toInt() ?? 0,
    sectionsTotal: (json['sectionsTotal'] as num?)?.toInt() ?? 0,
    photos: (json['photos'] as num?)?.toInt() ?? 0,
    tasksRaised: (json['tasksRaised'] as num?)?.toInt() ?? 0,
    score: json['score'] == null
        ? null
        : MyVisitScore.fromJson(json['score'] as Map<String, dynamic>),
    reviewedVerdict: json['reviewedVerdict'] as String?,
    pinReported: json['pinReported'] as bool? ?? false,
  );
}

/// A page of the agent's own visits.
class MyVisitsPage {
  const MyVisitsPage({required this.visits, this.nextCursor});

  final List<MyVisit> visits;
  final String? nextCursor;

  factory MyVisitsPage.fromJson(Map<String, dynamic> json) => MyVisitsPage(
    visits: <MyVisit>[
      for (final row in (json['data'] as List? ?? const <dynamic>[]))
        MyVisit.fromJson(row as Map<String, dynamic>),
    ],
    nextCursor: json['nextCursor'] as String?,
  );
}

/// One incentive scheme the client is running — the rules, not the agent's
/// standing against them.
class IncentiveScheme {
  const IncentiveScheme({
    required this.id,
    required this.name,
    required this.metric,
    required this.threshold,
    required this.rewardPoints,
    this.active = true,
    this.rewardDetail,
  });

  final String id;
  final String name;

  /// `scorecard` · `tasks_closed` · `visits`.
  final String metric;
  final double threshold;
  final int rewardPoints;

  /// Whether the scheme is **running**.
  ///
  /// `GET /incentives` is the manager's list of every scheme they have ever
  /// written, running or ended — deliberately, because a manager has to be
  /// able to see a paused scheme in order to start it again. So the client
  /// does the filtering, and this is the field it filters on: the payout read
  /// (`computeEarnedIncentives`) only ever considers `active: true`, and a bar
  /// that promised a reward the payout engine will not pay would be the worst
  /// kind of number on this screen.
  ///
  /// Absent on the wire means running: `active` has a `@default(true)` in the
  /// schema and predates nothing, so a response without it is older than the
  /// manager's toggle, when every scheme was on.
  final bool active;

  /// What the agent actually gets — "R 250 airtime". The end of the bar.
  final String? rewardDetail;

  factory IncentiveScheme.fromJson(Map<String, dynamic> json) =>
      IncentiveScheme(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        metric: json['metric'] as String? ?? '',
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
        rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        rewardDetail: json['rewardDetail'] as String?,
      );
}

/// The agent's own standing: their entry, their ledger, and the scheme they
/// are closest to clearing.
class MyEarnings {
  const MyEarnings({
    required this.entry,
    required this.ledger,
    required this.schemes,
    this.rank,
  });

  /// The caller's own row: their totals and the figures the bar measures.
  ///
  /// **Do not read `entry.rank` here.** `LeaderboardEntry` is the board's row
  /// shape and its rank is non-null because every row of a board has a place;
  /// the caller of `/gamification/me` may not be on the board at all, and that
  /// case lives in [rank] below.
  final LeaderboardEntry entry;

  /// The caller's place on the client's board, or **null** when they are not
  /// on it.
  ///
  /// Null is the one genuinely unknown figure on this screen, and it has one
  /// cause: the caller is not a field agent. `/me` is open to managers on
  /// purpose, the board only ranks field agents, and the server used to answer
  /// `leaderboard.length + 1` — a manager on a board of three was shown "4".
  /// The screen printed it as a plain measured figure, because a number is all
  /// it had to go on. It is null now, and the tile says so in words.
  final int? rank;

  /// "How I earned these", newest first.
  final List<PointsEntry> ledger;

  /// Every active scheme, in the order the server returned them.
  final List<IncentiveScheme> schemes;

  /// Progress against [scheme] in that scheme's own metric.
  ///
  /// Returns null for a metric this response cannot measure, which is the
  /// honest answer: an invented denominator is worse than an absent bar.
  double? progressFor(IncentiveScheme scheme) => switch (scheme.metric) {
    'visits' => entry.visitsSubmitted.toDouble(),
    'tasks_closed' => entry.tasksClosed.toDouble(),
    'scorecard' => entry.avgScorecard,
    _ => null,
  };

  /// The one scheme the bar shows: the nearest unreached threshold, or — when
  /// every threshold is cleared — the last one reached, so the bar can say so
  /// rather than disappearing at the moment of the win.
  ///
  /// Null when no scheme is running or none of them is measurable from this
  /// response. The bar then does not render at all: an empty bar reads as zero
  /// progress, which is a different and false statement.
  IncentiveScheme? get focusScheme {
    IncentiveScheme? nearest;
    double? nearestGap;
    IncentiveScheme? reached;
    for (final scheme in schemes) {
      // An ended scheme is not a scheme. `GET /incentives` returns the
      // manager's whole list so they can restart a paused one; the payout read
      // considers `active: true` alone. A bar driven by an ended scheme tells
      // an agent over the threshold "Reward reached — R 250 airtime" for
      // airtime nobody will send.
      if (!scheme.active) continue;
      if (scheme.threshold <= 0) continue;
      final progress = progressFor(scheme);
      if (progress == null) continue;
      final gap = scheme.threshold - progress;
      if (gap <= 0) {
        reached ??= scheme;
        continue;
      }
      if (nearestGap == null || gap < nearestGap) {
        nearestGap = gap;
        nearest = scheme;
      }
    }
    return nearest ?? reached;
  }
}

abstract class MyRecordRepository {
  /// The caller's own visits, newest first.
  Future<MyVisitsPage> myVisits({String? cursor});

  /// The caller's own points, ledger and the schemes they run against.
  Future<MyEarnings> myEarnings();
}

class DioMyRecordRepository implements MyRecordRepository {
  @override
  Future<MyVisitsPage> myVisits({String? cursor}) async {
    final response = await dio.get<dynamic>(
      '/visits/me',
      queryParameters: <String, dynamic>{'cursor': ?cursor},
    );
    return MyVisitsPage.fromJson(response.data as Map<String, dynamic>);
  }

  /// THE WINDOW, AND WHY THERE ISN'T ONE.
  ///
  /// `GET /gamification/me` takes optional `from`/`to`. This call sends
  /// neither, so every figure it returns — the points, the rank, the visit and
  /// task counts, and the twenty `recentEntries` — is the agent's **whole
  /// record**, not a month of it. That is a deliberate choice and the screen's
  /// words are written to match it (`POINTS ALL TIME`, and an "All time" fact
  /// in the header); it used to send no window and say "POINTS THIS MONTH" in
  /// three places, which is a number an agent in their fourth month cannot
  /// check against anything.
  ///
  /// The reason the window is not simply added is the reward bar. Its
  /// threshold belongs to an incentive scheme, and the read that decides who
  /// actually gets paid — `computeEarnedIncentives` in
  /// `incentives.service.ts` — counts an agent's submitted visits, closed
  /// tasks and scorecards over their whole record, with no window at all.
  /// Windowing this call to the calendar month would leave the bar measuring
  /// September against a threshold the payout engine measures a career
  /// against: it would read "6 to go" to an agent who has already earned the
  /// airtime. A screen whose job is a number the agent can check does not get
  /// to disagree with the engine that pays.
  ///
  /// If the incentive engine ever gains a period, this is the call that gains
  /// `from`/`to` with it, and the three strings change back in the same commit.
  @override
  Future<MyEarnings> myEarnings() async {
    // Two reads, in parallel. The schemes are the client's rules and the entry
    // is the agent's standing; neither is derivable from the other, and a
    // sequential pair would cost a second round trip on a 2G handshake.
    final results = await Future.wait(<Future<dynamic>>[
      dio.get<dynamic>('/gamification/me'),
      dio.get<dynamic>('/incentives'),
    ]);

    final me = (results[0] as dynamic).data as Map<String, dynamic>;
    final schemesBody = (results[1] as dynamic).data as Map<String, dynamic>;

    return MyEarnings(
      entry: LeaderboardEntry.fromJson(me),
      // Read off the raw body rather than through LeaderboardEntry, whose
      // `rank` is a board row's non-null place. A caller who is not on the
      // board at all answers null here, and null has to survive the parse.
      rank: (me['rank'] as num?)?.toInt(),
      ledger: <PointsEntry>[
        for (final row in (me['recentEntries'] as List? ?? const <dynamic>[]))
          PointsEntry.fromJson(row as Map<String, dynamic>),
      ],
      schemes: <IncentiveScheme>[
        for (final row in (schemesBody['data'] as List? ?? const <dynamic>[]))
          IncentiveScheme.fromJson(row as Map<String, dynamic>),
      ],
    );
  }
}

final myRecordRepositoryProvider = Provider<MyRecordRepository>(
  (ref) => DioMyRecordRepository(),
);

final myVisitsProvider = FutureProvider<MyVisitsPage>(
  (ref) => ref.read(myRecordRepositoryProvider).myVisits(),
);

final myEarningsProvider = FutureProvider<MyEarnings>(
  (ref) => ref.read(myRecordRepositoryProvider).myEarnings(),
);
