import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/format/person_label.dart';
import '../../../core/network/api_client.dart';

/// Ledger reasons a contest can count (#124), in the backend's order.
const contestEventTypes = ['visit_submitted', 'task_closed', 'scorecard'];

/// A time-boxed contest, as GET /contests and friends return it.
///
/// [startDate] and [endDate] are calendar dates (`YYYY-MM-DD`), inclusive, in
/// the client's timezone. [status] is computed by the server — `upcoming`,
/// `active`, `ended` or `cancelled` — because "today" is the client's, not the
/// phone's.
class Contest {
  const Contest({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    this.prizeDescription,
    this.territoryId,
    this.territoryName,
    this.eventTypes = const [],
    this.daysLeft,
  });

  final String id;
  final String name;
  final String? description;
  final String? prizeDescription;
  final String startDate;
  final String endDate;
  final String? territoryId;
  final String? territoryName;

  /// The reasons that count. Empty means every reason.
  final List<String> eventTypes;
  final String status;

  /// Local days left counting today, while active.
  final int? daysLeft;

  bool get isActive => status == 'active';
  bool get isUpcoming => status == 'upcoming';
  bool get isEnded => status == 'ended';
  bool get isCancelled => status == 'cancelled';

  factory Contest.fromJson(Map<String, dynamic> json) {
    final territory = json['territory'] as Map<String, dynamic>?;
    return Contest(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      prizeDescription: json['prizeDescription'] as String?,
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      territoryId: json['territoryId'] as String?,
      territoryName: territory?['name'] as String?,
      eventTypes: (json['eventTypes'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      status: json['status'] as String? ?? '',
      daysLeft: (json['daysLeft'] as num?)?.toInt(),
    );
  }
}

/// One agent's row in a contest's standings. Equal points share a rank.
class ContestStanding {
  const ContestStanding({
    required this.rank,
    required this.agentId,
    required this.email,
    required this.points,
    this.displayName,
    this.visitsSubmitted = 0,
    this.tasksClosed = 0,
    this.avgScorecard = 0,
  });

  final int rank;
  final String agentId;
  final String email;
  final String? displayName;
  final double points;
  final int visitsSubmitted;
  final int tasksClosed;
  final double avgScorecard;

  String get label => personLabel(displayName, email);

  factory ContestStanding.fromJson(Map<String, dynamic> json) =>
      ContestStanding(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        agentId: json['agentId'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String?,
        points: (json['points'] as num?)?.toDouble() ?? 0,
        visitsSubmitted: (json['visitsSubmitted'] as num?)?.toInt() ?? 0,
        tasksClosed: (json['tasksClosed'] as num?)?.toInt() ?? 0,
        avgScorecard: (json['avgScorecard'] as num?)?.toDouble() ?? 0,
      );
}

List<ContestStanding> _standingsOf(Object? raw) => (raw as List? ?? const [])
    .map((e) => ContestStanding.fromJson(e as Map<String, dynamic>))
    .toList();

/// GET /contests/:id/standings — the contest and its whole board.
class ContestStandings {
  const ContestStandings({
    required this.contest,
    required this.participantCount,
    required this.standings,
  });

  final Contest contest;
  final int participantCount;
  final List<ContestStanding> standings;

  factory ContestStandings.fromJson(Map<String, dynamic> json) =>
      ContestStandings(
        contest: Contest.fromJson(json['contest'] as Map<String, dynamic>),
        participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
        standings: _standingsOf(json['standings']),
      );
}

/// One entry of GET /contests/current: the contest, the top of its board and
/// the caller's own row ([me] is null for anyone not on the board).
class CurrentContest {
  const CurrentContest({
    required this.contest,
    required this.participantCount,
    required this.standings,
    this.me,
  });

  final Contest contest;
  final int participantCount;
  final List<ContestStanding> standings;
  final ContestStanding? me;

  factory CurrentContest.fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>?;
    return CurrentContest(
      contest: Contest.fromJson(json),
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      standings: _standingsOf(json['standings']),
      me: me == null ? null : ContestStanding.fromJson(me),
    );
  }
}

/// What the manager's form sends, for both create and edit.
class ContestInput {
  const ContestInput({
    required this.name,
    required this.startDate,
    required this.endDate,
    this.description,
    this.prizeDescription,
    this.territoryId,
    this.eventTypes = const [],
  });

  final String name;
  final String? description;
  final String? prizeDescription;
  final String startDate;
  final String endDate;
  final String? territoryId;
  final List<String> eventTypes;

  /// Every field, nulls included: an edit that clears the prize or widens
  /// the contest to all territories must say so.
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'prizeDescription': prizeDescription,
        'startDate': startDate,
        'endDate': endDate,
        'territoryId': territoryId,
        'eventTypes': eventTypes,
      };
}

abstract class ContestsRepository {
  /// GET /contests — manager/admin. The first page, newest start first.
  Future<List<Contest>> listContests();

  Future<Contest> createContest(ContestInput input);

  Future<Contest> updateContest(String id, ContestInput input);

  Future<Contest> cancelContest(String id);

  Future<void> deleteContest(String id);

  /// GET /contests/:id/standings — manager/admin.
  Future<ContestStandings> standings(String id);

  /// GET /contests/current — the agent's view.
  Future<List<CurrentContest>> currentContests();
}

class DioContestsRepository implements ContestsRepository {
  String _path(String id) => '/contests/${Uri.encodeComponent(id)}';

  @override
  Future<List<Contest>> listContests() async {
    final response = await dio.get('/contests');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data
        .map((e) => Contest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Contest> createContest(ContestInput input) async {
    final response = await dio.post('/contests', data: input.toJson());
    return Contest.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Contest> updateContest(String id, ContestInput input) async {
    final response = await dio.patch(_path(id), data: input.toJson());
    return Contest.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Contest> cancelContest(String id) async {
    final response = await dio.post('${_path(id)}/cancel');
    return Contest.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteContest(String id) async {
    await dio.delete(_path(id));
  }

  @override
  Future<ContestStandings> standings(String id) async {
    final response = await dio.get('${_path(id)}/standings');
    return ContestStandings.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<CurrentContest>> currentContests() async {
    final response = await dio.get('/contests/current');
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return data
        .map((e) => CurrentContest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final contestsRepositoryProvider =
    Provider<ContestsRepository>((ref) => DioContestsRepository());

final contestsListProvider = FutureProvider<List<Contest>>((ref) {
  return ref.read(contestsRepositoryProvider).listContests();
});

final contestStandingsProvider =
    FutureProvider.family<ContestStandings, String>((ref, id) {
  return ref.read(contestsRepositoryProvider).standings(id);
});

final currentContestsProvider = FutureProvider<List<CurrentContest>>((ref) {
  return ref.read(contestsRepositoryProvider).currentContests();
});

/// How many contests are running now, for the hint on the agent's Contests
/// entry point. Reuses [currentContestsProvider], so opening the Contests view
/// and the hint share one request, and refreshing either refreshes both.
///
/// Only field agents are asked: nobody else sees the entry point. A failure is
/// 0 — a missing hint must never break Today.
final runningContestsCountProvider = FutureProvider<int>((ref) async {
  final role = ref.watch(sessionControllerProvider).value?.role;
  if (role != 'field_agent') return 0;
  try {
    final contests = await ref.watch(currentContestsProvider.future);
    return contests.where((c) => c.contest.isActive).length;
  } on Object {
    return 0;
  }
});
