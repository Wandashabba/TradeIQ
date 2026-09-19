import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/features/gamification/data/gamification_repository.dart';
import 'package:tradeiq_app/features/me/data/my_record_repository.dart';

/// THE WIRE, AND WHAT THE SCREEN IS ALLOWED TO CONCLUDE FROM IT.
///
/// Three rules live here rather than in the widget, because all three are
/// about the *shape of a request or a response* and none should need a pumped
/// frame to be true: a null is never read as a zero, the bar never invents a
/// denominator, and the query this repository sends is the query the screen's
/// words are written against.

/// Answers each path from a canned body, and remembers every request it was
/// given — including its query — so a test can assert on what was ASKED,
/// not only on what came back.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.bodies);

  /// Path (without the base URL) to the JSON body to answer it with.
  final Map<String, Object?> bodies;
  final List<RequestOptions> requests = <RequestOptions>[];

  RequestOptions requestFor(String path) =>
      requests.firstWhere((RequestOptions r) => r.path == path);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(bodies[options.path] ?? <String, dynamic>{}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('the request this screen actually sends', () {
    late HttpClientAdapter original;
    late _RecordingAdapter adapter;

    setUp(() {
      original = dio.httpClientAdapter;
      adapter = _RecordingAdapter(<String, Object?>{
        '/gamification/me': <String, dynamic>{
          'agentId': 'a1',
          'email': 'thandi@example.com',
          'displayName': 'Thandi Nkosi',
          'visitsSubmitted': 14,
          'tasksClosed': 6,
          'avgScorecard': 78,
          'points': 1840,
          'rank': 4,
          'recentEntries': <dynamic>[],
        },
        '/incentives': <String, dynamic>{'data': <dynamic>[]},
      });
      dio.httpClientAdapter = adapter;
    });

    tearDown(() => dio.httpClientAdapter = original);

    test('asks for the whole record, with no window — as the words say', () async {
      await DioMyRecordRepository().myEarnings();

      final me = adapter.requestFor('/gamification/me');
      // `/gamification/me` takes optional from/to; `parseWindow` returns {}
      // when both are absent and the service then omits the occurredAt filter
      // entirely, so this request is LIFETIME. That is deliberate — the
      // incentive payout engine has no window either, and a month-scoped bar
      // would promise a reward the engine will not pay — and the screen says
      // "All time" and "POINTS ALL TIME" because of it.
      //
      // This assertion is the pin between the two. If a window is ever added
      // here, the three strings move back in the same commit, and this test
      // is what says so.
      expect(me.queryParameters['from'], isNull);
      expect(me.queryParameters['to'], isNull);
      expect(me.uri.query, isEmpty);
    });

    test('and reads the agent\'s own visits without naming an agent', () async {
      adapter.bodies['/visits/me'] = <String, dynamic>{'data': <dynamic>[]};
      await DioMyRecordRepository().myVisits();

      final visits = adapter.requestFor('/visits/me');
      // Self-scoped off the token. A widening parameter is the one thing this
      // request must never grow.
      expect(visits.queryParameters.containsKey('agentId'), isFalse);
      expect(visits.queryParameters['cursor'], isNull);
    });

    test('a caller with no place on the board keeps a null rank', () async {
      // What the server answers a manager: they are not a field agent, so
      // they are not on the board at all. It used to answer
      // `leaderboard.length + 1`, and the screen printed that as a figure.
      (adapter.bodies['/gamification/me']! as Map<String, dynamic>)['rank'] =
          null;
      final earnings = await DioMyRecordRepository().myEarnings();

      expect(earnings.rank, isNull);
    });

    test('and a real place survives the parse', () async {
      final earnings = await DioMyRecordRepository().myEarnings();
      expect(earnings.rank, 4);
    });
  });

  group('a visit off the wire', () {
    test('carries the agent\'s own pin report', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v2',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'geofencePass': false,
        'checkinDistanceM': 140,
        'pinReported': true,
      });
      expect(visit.pinReported, isTrue);
      expect(visit.geofencePass, isFalse);
    });

    test('keeps an unmeasured distance and an unknown dwell as null', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v1',
        'outletId': 'o1',
        'outletName': 'Kasi Corner Spaza',
        'outletCode': 'KC-0412',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'checkinDistanceM': null,
        'geofencePass': true,
        'status': 'in_progress',
        'dwellMinutes': null,
        'sectionsCaptured': 0,
        'sectionsTotal': 7,
        'photos': 0,
        'tasksRaised': 0,
        'score': null,
        'reviewedVerdict': null,
      });

      expect(visit.checkinDistanceM, isNull);
      expect(visit.dwellMinutes, isNull);
      // An older server that does not send the field has no pin report.
      expect(visit.pinReported, isFalse);
      expect(visit.score, isNull);
      expect(visit.submitted, isFalse);
      // A measured zero is a zero and stays one.
      expect(visit.sectionsCaptured, 0);
      expect(visit.photos, 0);
    });

    test('keeps the device\'s score apart from the server\'s', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v1',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'geofencePass': true,
        'status': 'submitted',
        'score': <String, dynamic>{
          'weightedTotal': 71,
          'ratingBand': 'amber',
          'scoredAt': '2026-09-17T12:00:00.000Z',
          'seen': <String, dynamic>{
            'weightedTotal': 84,
            'ratingBand': 'green',
            'seenAt': '2026-09-17T09:41:00.000Z',
          },
        },
      });

      expect(visit.score!.weightedTotal, 71);
      expect(visit.score!.seen!.weightedTotal, 84);
      expect(visit.score!.changedSinceSeen, isTrue);
    });

    test('a difference that rounds away is not a change worth announcing', () {
      final visit = MyVisit.fromJson(<String, dynamic>{
        'id': 'v1',
        'checkinTs': '2026-09-17T09:00:00.000Z',
        'geofencePass': true,
        'status': 'submitted',
        'score': <String, dynamic>{
          'weightedTotal': 71.2,
          'ratingBand': 'amber',
          'scoredAt': '2026-09-17T12:00:00.000Z',
          'seen': <String, dynamic>{
            'weightedTotal': 70.8,
            'ratingBand': 'amber',
            'seenAt': '2026-09-17T09:41:00.000Z',
          },
        },
      });

      // The screen prints whole points. "71 became 71" is noise dressed as
      // honesty, and it would teach an agent to stop reading the line that
      // matters.
      expect(visit.score!.changedSinceSeen, isFalse);
    });

    test(
      'a scorecard with no recorded device figure has nothing to reconcile',
      () {
        final visit = MyVisit.fromJson(<String, dynamic>{
          'id': 'v1',
          'checkinTs': '2026-09-17T09:00:00.000Z',
          'geofencePass': true,
          'status': 'submitted',
          'score': <String, dynamic>{
            'weightedTotal': 71,
            'ratingBand': 'amber',
            'scoredAt': '2026-09-17T12:00:00.000Z',
            'seen': null,
          },
        });

        expect(visit.score!.seen, isNull);
        expect(visit.score!.changedSinceSeen, isFalse);
      },
    );
  });

  group('which scheme the bar shows', () {
    MyEarnings earnings({
      int visits = 14,
      int tasks = 3,
      double avg = 78,
      List<IncentiveScheme> schemes = const <IncentiveScheme>[],
    }) => MyEarnings(
      entry: LeaderboardEntry(
        agentId: 'a1',
        email: 'a@example.com',
        visitsSubmitted: visits,
        tasksClosed: tasks,
        rank: 4,
        avgScorecard: avg,
        points: 1840,
      ),
      ledger: const <PointsEntry>[],
      schemes: schemes,
    );

    test('no scheme means no bar, rather than a bar at zero', () {
      expect(earnings().focusScheme, isNull);
    });

    test('the nearest unreached threshold wins', () {
      final near = earnings(
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'far',
            name: 'Fifty stores',
            metric: 'visits',
            threshold: 50,
            rewardPoints: 1000,
          ),
          IncentiveScheme(
            id: 'near',
            name: 'Twenty stores',
            metric: 'visits',
            threshold: 20,
            rewardPoints: 250,
          ),
        ],
      ).focusScheme;

      expect(near!.id, 'near');
    });

    test('everything cleared shows the one that was reached, not nothing', () {
      final scheme = earnings(
        visits: 40,
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'twenty',
            name: 'Twenty stores',
            metric: 'visits',
            threshold: 20,
            rewardPoints: 250,
          ),
        ],
      ).focusScheme;

      // Disappearing at the moment of the win is the one thing the bar must
      // not do — the reward is the sentence, and the sentence needs a bar to
      // sit under.
      expect(scheme!.id, 'twenty');
    });

    test('a metric this response cannot measure is skipped, not guessed', () {
      final scheme = earnings(
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'mystery',
            name: 'Something else',
            metric: 'orders_placed',
            threshold: 10,
            rewardPoints: 50,
          ),
        ],
      ).focusScheme;

      expect(scheme, isNull);
    });

    test('an ENDED scheme is not a scheme', () {
      // `GET /incentives` lists every scheme the manager has written, running
      // or ended, so that a paused one can be restarted. The payout read
      // (`computeEarnedIncentives`) filters `active: true`. A bar driven by an
      // ended scheme reads "Reward reached — R 250 airtime" for airtime
      // nobody will send.
      final scheme = earnings(
        visits: 40,
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'ended',
            name: 'Ended scheme',
            metric: 'visits',
            threshold: 20,
            rewardPoints: 250,
            rewardDetail: 'R 250 airtime',
            active: false,
          ),
        ],
      ).focusScheme;

      expect(scheme, isNull);
    });

    test('and an ended one never wins the focus off a running one', () {
      final scheme = earnings(
        visits: 14,
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'ended',
            name: 'Nearer, but over',
            metric: 'visits',
            threshold: 15,
            rewardPoints: 100,
            active: false,
          ),
          IncentiveScheme(
            id: 'running',
            name: 'Twenty stores',
            metric: 'visits',
            threshold: 20,
            rewardPoints: 250,
          ),
        ],
      ).focusScheme;

      expect(scheme!.id, 'running');
    });

    test('a scheme off the wire is running unless the wire says otherwise', () {
      // `active` has a @default(true) in the schema and is always serialised;
      // a body without it is older than the manager's toggle, when every
      // scheme was on. An absent field must not silently delete the bar.
      expect(
        IncentiveScheme.fromJson(const <String, dynamic>{
          'id': 's1',
          'name': 'Twenty stores',
          'metric': 'visits',
          'threshold': 20,
          'rewardPoints': 250,
        }).active,
        isTrue,
      );
      expect(
        IncentiveScheme.fromJson(const <String, dynamic>{
          'id': 's1',
          'name': 'Twenty stores',
          'metric': 'visits',
          'threshold': 20,
          'rewardPoints': 250,
          'active': false,
        }).active,
        isFalse,
      );
    });

    test('a zero threshold is not a scheme', () {
      final scheme = earnings(
        schemes: const <IncentiveScheme>[
          IncentiveScheme(
            id: 'broken',
            name: 'Misconfigured',
            metric: 'visits',
            threshold: 0,
            rewardPoints: 10,
          ),
        ],
      ).focusScheme;

      expect(scheme, isNull);
    });

    test('each metric reads its own figure', () {
      final e = earnings(visits: 14, tasks: 3, avg: 78);
      const visitsScheme = IncentiveScheme(
        id: 'v',
        name: 'v',
        metric: 'visits',
        threshold: 20,
        rewardPoints: 1,
      );
      const tasksScheme = IncentiveScheme(
        id: 't',
        name: 't',
        metric: 'tasks_closed',
        threshold: 20,
        rewardPoints: 1,
      );
      const scoreScheme = IncentiveScheme(
        id: 's',
        name: 's',
        metric: 'scorecard',
        threshold: 90,
        rewardPoints: 1,
      );

      expect(e.progressFor(visitsScheme), 14);
      expect(e.progressFor(tasksScheme), 3);
      expect(e.progressFor(scoreScheme), 78);
    });
  });
}
