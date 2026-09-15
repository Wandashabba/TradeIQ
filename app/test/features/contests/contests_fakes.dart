import 'package:tradeiq_app/features/contests/data/contests_repository.dart';

/// Shared fixtures for the contest screen tests (#124).

const activeContest = Contest(
  id: 'c-active',
  name: 'October Sprint',
  description: 'Most points in October wins.',
  prizeDescription: 'R500 voucher',
  startDate: '2026-10-01',
  endDate: '2026-10-31',
  status: 'active',
  daysLeft: 3,
  eventTypes: ['visit_submitted', 'task_closed'],
);

const upcomingContest = Contest(
  id: 'c-upcoming',
  name: 'November Push',
  startDate: '2026-11-01',
  endDate: '2026-11-30',
  status: 'upcoming',
  territoryId: 't-1',
  territoryName: 'North',
);

const endedContest = Contest(
  id: 'c-ended',
  name: 'September Cup',
  startDate: '2026-09-01',
  endDate: '2026-09-10',
  status: 'ended',
);

const cancelledContest = Contest(
  id: 'c-cancelled',
  name: 'Scrapped',
  startDate: '2026-10-01',
  endDate: '2026-10-05',
  status: 'cancelled',
);

const aisha = ContestStanding(
  rank: 1,
  agentId: 'a-1',
  email: 'aisha@example.com',
  displayName: 'Aisha Patel',
  points: 14,
  visitsSubmitted: 2,
  tasksClosed: 2,
);

const bongani = ContestStanding(
  rank: 1,
  agentId: 'a-2',
  email: 'bongani@example.com',
  points: 14,
  visitsSubmitted: 7,
);

const me = ContestStanding(
  rank: 3,
  agentId: 'a-me',
  email: 'me@example.com',
  displayName: 'Thandi Mokoena',
  points: 7.5,
  visitsSubmitted: 1,
  tasksClosed: 1,
);

class FakeContestsRepository implements ContestsRepository {
  FakeContestsRepository({
    this.contests = const [],
    this.current = const [],
    this.standingsById = const {},
    this.failCurrent = false,
  });

  final List<Contest> contests;
  final List<CurrentContest> current;
  final Map<String, ContestStandings> standingsById;
  final bool failCurrent;

  final calls = <String>[];
  ContestInput? created;
  String? updatedId;
  ContestInput? updated;

  @override
  Future<List<Contest>> listContests() async => contests;

  @override
  Future<Contest> createContest(ContestInput input) async {
    created = input;
    calls.add('create');
    return Contest(
      id: 'c-new',
      name: input.name,
      startDate: input.startDate,
      endDate: input.endDate,
      status: 'upcoming',
    );
  }

  @override
  Future<Contest> updateContest(String id, ContestInput input) async {
    updatedId = id;
    updated = input;
    calls.add('update:$id');
    return contests.firstWhere((c) => c.id == id);
  }

  @override
  Future<Contest> cancelContest(String id) async {
    calls.add('cancel:$id');
    return contests.firstWhere((c) => c.id == id);
  }

  @override
  Future<void> deleteContest(String id) async {
    calls.add('delete:$id');
  }

  @override
  Future<ContestStandings> standings(String id) async =>
      standingsById[id] ?? (throw Exception('no standings for $id'));

  @override
  Future<List<CurrentContest>> currentContests() async {
    if (failCurrent) throw Exception('boom');
    return current;
  }
}
