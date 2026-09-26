import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/me/data/my_record_repository.dart';
import 'package:tradeiq_app/features/me/presentation/my_record_screen.dart';

import '../agent_harness.dart';

/// FIXTURES AND A PUMP FOR /me.
///
/// The repository is stubbed rather than the two providers, so a test can
/// assert on what a *response shape* renders as — an unscored visit, a rank
/// the server will not give, a scheme with no reward words — which is where
/// every unknown-versus-zero rule on this screen lives.

/// A scored visit, with every argument overridable so a test names only the
/// one fact it is about.
MyVisit visitFixture({
  String id = 'v1',
  String outletName = 'Kasi Corner Spaza',
  DateTime? checkinTs,
  double? distance = 12,
  bool geofencePass = true,
  String status = 'submitted',
  int? dwellMinutes = 41,
  int sectionsCaptured = 5,
  int photos = 2,
  int tasksRaised = 3,
  double? score = 71,
  double? seen,
  String? reviewedVerdict,
  bool pinReported = false,
}) => MyVisit(
  id: id,
  outletId: 'o-$id',
  outletName: outletName,
  outletCode: 'KC-0412',
  checkinTs: checkinTs ?? DateTime(2026, 9, 17, 9),
  checkinDistanceM: distance,
  geofencePass: geofencePass,
  status: status,
  dwellMinutes: dwellMinutes,
  sectionsCaptured: sectionsCaptured,
  sectionsTotal: 7,
  photos: photos,
  tasksRaised: tasksRaised,
  reviewedVerdict: reviewedVerdict,
  pinReported: pinReported,
  score: score == null
      ? null
      : MyVisitScore(
          weightedTotal: score,
          ratingBand: 'amber',
          scoredAt: DateTime(2026, 9, 17, 12),
          seen: seen == null
              ? null
              : SeenScore(
                  weightedTotal: seen,
                  ratingBand: 'green',
                  seenAt: DateTime(2026, 9, 17, 9, 41),
                ),
        ),
);

/// The agent's standing, and the rules they are running against.
/// [rank] is the agent's place, and **null is the server's answer for a
/// caller who is not on the board at all** — a manager, since `/me` is open to
/// them. There is no zeroth place and the server never sends one.
MyEarnings earningsFixture({
  double points = 1840,
  int? rank = 4,
  int visitsSubmitted = 14,
  int tasksClosed = 6,
  double avgScorecard = 78,
  List<PointsEntry>? ledger,
  List<IncentiveScheme>? schemes,
}) => MyEarnings(
  entry: LeaderboardEntry(
    agentId: 'a1',
    email: 'thandi@example.com',
    displayName: 'Thandi Nkosi',
    visitsSubmitted: visitsSubmitted,
    tasksClosed: tasksClosed,
    // A board row always has a place; the "not on the board" case is `rank`
    // beside it, and that is the one the screen reads.
    rank: rank ?? 1,
    avgScorecard: avgScorecard,
    // A figure with a sample behind it: the board's own rows now say how many
    // scorecards their mean is of, so an unscored agent is told apart from
    // one who scored nothing.
    scorecardsCounted: 4,
    points: points,
  ),
  rank: rank,
  ledger:
      ledger ??
      <PointsEntry>[
        PointsEntry(
          id: 'p1',
          points: 5,
          reason: 'visit_submitted',
          sourceType: 'visit',
          sourceId: 'v1',
          occurredAt: DateTime(2026, 9, 17, 12),
          outletName: 'Kasi Corner Spaza',
        ),
        // A SCORECARD ROW, IN THE DEFAULT LEDGER AND NOT ONLY IN ONE TEST.
        //
        // Roughly half of a real agent's ledger is these, and every one of
        // them carries `points: 0` and a `score` (`pointsLedger.ts`:
        // `scorecardEvent`). The fixture used to hold a grant and a reversal
        // only, so 47 tests ran against a ledger no agent has and none of them
        // saw the rising mint "+0" the scorecard rows were drawing.
        PointsEntry(
          id: 'p3',
          points: 0,
          reason: 'scorecard',
          sourceType: 'scorecard',
          sourceId: 'sc1',
          score: 85,
          occurredAt: DateTime(2026, 9, 17, 12, 30),
          outletName: 'Kasi Corner Spaza',
        ),
        PointsEntry(
          id: 'p2',
          points: -5,
          reason: 'visit_reversed',
          sourceType: 'visit',
          sourceId: 'v2',
          occurredAt: DateTime(2026, 9, 16, 12),
        ),
      ],
  schemes:
      schemes ??
      <IncentiveScheme>[
        const IncentiveScheme(
          id: 's1',
          name: 'Twenty stores',
          metric: 'visits',
          threshold: 20,
          rewardPoints: 250,
          rewardDetail: 'R 250 airtime',
        ),
      ],
);

/// A repository that answers from memory, or throws.
class FakeMyRecordRepository implements MyRecordRepository {
  FakeMyRecordRepository({
    List<MyVisit>? visits,
    MyEarnings? earnings,
    this.visitsThrow = false,
    this.earningsThrow = false,
    this.hang = false,
    this.pages = const <String, List<MyVisit>>{},
    this.firstCursor,
    this.olderThrows = false,
  }) : visits = visits ?? <MyVisit>[visitFixture()],
       earnings = earnings ?? earningsFixture();

  final List<MyVisit> visits;
  final MyEarnings earnings;
  final bool visitsThrow;
  final bool earningsThrow;

  /// The pages behind each cursor. `GET /visits/me` is cursor-paged and the
  /// client ignored the cursor entirely until 26 September 2026, so a fake
  /// that only ever answers page one cannot tell a paged list from a
  /// truncated one.
  final Map<String, List<MyVisit>> pages;

  /// The cursor page one hands back, or null for "there is no more".
  final String? firstCursor;

  /// Only the *next* page fails. The visits already on screen must stay.
  final bool olderThrows;

  /// Every cursor asked for, in order — so a test can prove the screen sent
  /// the one the server gave it rather than a guess.
  final List<String?> cursorsAsked = <String?>[];

  /// Never answer, so the loading state can be asserted on.
  ///
  /// A plain `async` body resolves in a microtask, and `pump()` flushes
  /// microtasks — so a fake that returns immediately is *already loaded* by
  /// the first frame a test can look at, and the skeleton is never on screen
  /// even though the real screen shows it for as long as a 2G handshake takes.
  final bool hang;

  @override
  Future<MyVisitsPage> myVisits({String? cursor}) async {
    cursorsAsked.add(cursor);
    if (hang) return Completer<MyVisitsPage>().future;
    if (visitsThrow) throw StateError('no signal');
    if (cursor == null) {
      return MyVisitsPage(visits: visits, nextCursor: firstCursor);
    }
    if (olderThrows) throw StateError('no signal');
    final page = pages[cursor];
    if (page == null) return const MyVisitsPage(visits: <MyVisit>[]);
    // The next cursor is the key after this one, so a two-page fake ends
    // naturally rather than by a flag.
    final keys = pages.keys.toList();
    final at = keys.indexOf(cursor);
    return MyVisitsPage(
      visits: page,
      nextCursor: at + 1 < keys.length ? keys[at + 1] : null,
    );
  }

  @override
  Future<MyEarnings> myEarnings() async {
    if (hang) return Completer<MyEarnings>().future;
    if (earningsThrow) throw StateError('no signal');
    return earnings;
  }
}

/// The phone the amber census measures: 360×640, because a connected-
/// components count is a function of the layout and the law is about the
/// composed frame a real agent holds.
const Size mePhone = Size(360, 640);

/// A viewport tall enough to lay out the whole route at once.
///
/// The shell's body is one **lazy** `ListView`, so on a real phone the visit
/// rows are genuinely unbuilt until a thumb reaches them — which is correct,
/// and which makes every content assertion a test about scrolling rather than
/// about the thing it is named for. Behaviour tests take this viewport and
/// say what the screen renders; the census takes [mePhone] and says what the
/// screen *lights*, which is the measurement that depends on the fold.
const Size meTall = Size(360, 2400);

/// Pump `/me` in [skin], with the nav's three sibling destinations and the
/// Contests view stubbed so a tap on a tab or on the Contests row can be
/// asserted on.
Future<void> pumpMe(
  WidgetTester tester, {
  FakeMyRecordRepository? repository,
  SkinMode skin = SkinMode.night,
  SyncStatus sync = SyncStatus.empty,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  LocalDb? db,
  bool settle = true,
  Size size = meTall,
  int runningContests = 0,
  List<Override> extraOverrides = const <Override>[],
}) async {
  final database = db ?? agentTestDb();
  await pumpAgentScreen(
    tester,
    const MyRecordScreen(),
    path: '/me',
    overrides: <Override>[
      ...agentBaseOverrides(
        db: database,
        skin: skin,
        sync: sync,
        runningContests: runningContests,
      ),
      myRecordRepositoryProvider.overrideWithValue(
        repository ?? FakeMyRecordRepository(),
      ),
      ...extraOverrides,
    ],
    textScale: textScale,
    locale: locale,
    settle: settle,
    size: size,
    extraRoutes: <GoRoute>[
      GoRoute(path: '/today', builder: (c, s) => const Text('Today screen')),
      GoRoute(path: '/my-work', builder: (c, s) => const Text('My work')),
      GoRoute(path: '/map', builder: (c, s) => const Text('Map view')),
      GoRoute(
        path: '/leaderboard/contests',
        builder: (c, s) => const Text('Contests view'),
      ),
    ],
  );
}
