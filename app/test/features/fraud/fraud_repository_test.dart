import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';

/// A fake HTTP layer that returns a canned body and records the request,
/// following the pattern in `test/features/alerts/alerts_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body, {this.status = 200});
  final String body;
  final int status;
  RequestOptions? lastRequest;

  /// The request body as the repository handed it to dio: a plain map, before
  /// any transformer has turned it into bytes.
  Map<String, dynamic>? lastBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastBody = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : null;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('FlaggedVisit.fromJson parses fields and nested signals', () {
    final visit = FlaggedVisit.fromJson({
      'visitId': 'v-12345678',
      'outletId': 'o1',
      'agentId': 'a1',
      'riskScore': 82,
      'signals': [
        {'code': 'gps_mismatch', 'detail': '500m from outlet', 'weight': 40},
        {'code': 'fast_visit', 'detail': 'Under 2 minutes', 'weight': 42},
      ],
      'scoredAt': '2026-09-15T08:00:00.000Z',
    });

    expect(visit.visitId, 'v-12345678');
    expect(visit.outletId, 'o1');
    expect(visit.agentId, 'a1');
    expect(visit.riskScore, 82.0);
    expect(visit.signals, hasLength(2));
    expect(visit.signals.first.code, 'gps_mismatch');
    expect(visit.signals.first.detail, '500m from outlet');
    expect(visit.signals.last.code, 'fast_visit');
  });

  test('FlaggedVisit.fromJson defaults signals to empty when absent', () {
    final visit = FlaggedVisit.fromJson({
      'visitId': 'v2',
      'outletId': 'o2',
      'agentId': 'a2',
      'riskScore': 30,
    });

    expect(visit.signals, isEmpty);
  });

  test('FlaggedPage.fromJson defaults unscored to 0 when absent', () {
    final page = FlaggedPage.fromJson(const {'data': [], 'nextCursor': null});

    expect(page.data, isEmpty);
    expect(page.nextCursor, isNull);
    expect(page.unscored, 0);
  });

  group('DioFraudRepository.flagged', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    // #236: the endpoint returns the standard page envelope. The repository
    // used to cast the body to a List, which no longer matched the backend.
    test(
      'parses the {data, nextCursor, unscored} envelope into a FlaggedPage',
      () async {
        final adapter = _RecordingAdapter(
          '{"data": [{"visitId": "v1", "outletId": "o1", "agentId": "a1", '
          '"riskScore": 65, "signals": [{"code": "failed_attempts", '
          '"detail": "1 failed", "weight": 10}], '
          '"scoredAt": "2026-09-15T08:00:00.000Z"}], '
          '"nextCursor": "v1", "unscored": 4, '
          '"from": "2026-08-16T08:00:00.000Z", '
          '"to": "2026-09-15T08:00:00.000Z"}',
        );
        dio.httpClientAdapter = adapter;

        final page = await DioFraudRepository().flagged(minScore: 60);

        expect(page, isA<PaginatedResponse<FlaggedVisit>>());
        expect(page.data, hasLength(1));
        expect(page.data.first.visitId, 'v1');
        expect(page.data.first.riskScore, 65.0);
        expect(page.data.first.signals.single.code, 'failed_attempts');
        expect(page.nextCursor, 'v1');
        expect(page.unscored, 4);
        expect(adapter.lastRequest!.path, '/fraud/flagged');
        expect(adapter.lastRequest!.queryParameters['minScore'], 60);
        // The OPEN queue is the default (#392): a ruled visit leaves it,
        // because a queue that never shortens is a queue people stop opening.
        expect(adapter.lastRequest!.queryParameters['reviewed'], 'false');
      },
    );

    test('asks for the decided side when the rail says so', () async {
      final adapter = _RecordingAdapter(
        '{"data": [], "nextCursor": null, "unscored": 0}',
      );
      dio.httpClientAdapter = adapter;

      await DioFraudRepository().flagged(reviewed: FlaggedReviewFilter.decided);

      expect(adapter.lastRequest!.queryParameters['reviewed'], 'true');
    });

    test('asks for everything when the rail says All', () async {
      final adapter = _RecordingAdapter(
        '{"data": [], "nextCursor": null, "unscored": 0}',
      );
      dio.httpClientAdapter = adapter;

      await DioFraudRepository().flagged(reviewed: FlaggedReviewFilter.all);

      expect(adapter.lastRequest!.queryParameters['reviewed'], 'all');
    });
  });

  group('the verdict endpoint (#392)', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test(
      'records a ruling under the wire word, never the screen word',
      () async {
        final adapter = _RecordingAdapter(
          '{"visitId": "v1", "verdict": "dismissed", '
          '"reviewer": {"id": "u1", "label": "Nomsa Dlamini-Mkhize"}, '
          '"note": null, "riskScoreAtReview": 82, '
          '"decidedAt": "2026-09-20T09:00:00.000Z"}',
          status: 201,
        );
        dio.httpClientAdapter = adapter;

        final verdict = await DioFraudRepository().recordVerdict(
          visitId: 'v1',
          kind: FraudVerdictKind.cleared,
        );

        // "Cleared" is what a reviewer reads; `dismissed` is what the wire says.
        expect(adapter.lastBody!['verdict'], 'dismissed');
        expect(verdict.kind, FraudVerdictKind.cleared);
        expect(verdict.reviewerLabel, 'Nomsa Dlamini-Mkhize');
        expect(verdict.riskScoreAtReview, 82);
        expect(verdict.note, isNull);
      },
    );

    test('a blank note is no note, and is not sent as one', () async {
      final adapter = _RecordingAdapter(
        '{"visitId": "v1", "verdict": "dismissed", '
        '"reviewer": {"id": "u1", "label": "You"}, "note": null, '
        '"riskScoreAtReview": null, '
        '"decidedAt": "2026-09-20T09:00:00.000Z"}',
        status: 201,
      );
      dio.httpClientAdapter = adapter;

      await DioFraudRepository().recordVerdict(
        visitId: 'v1',
        kind: FraudVerdictKind.cleared,
        note: '   ',
      );

      expect(adapter.lastBody!.containsKey('note'), isFalse);
    });

    test('a note is trimmed before it is filed', () async {
      final adapter = _RecordingAdapter(
        '{"visitId": "v1", "verdict": "inconclusive", '
        '"reviewer": {"id": "u1", "label": "You"}, '
        '"note": "Ask for the till roll.", "riskScoreAtReview": 51, '
        '"decidedAt": "2026-09-20T09:00:00.000Z"}',
        status: 201,
      );
      dio.httpClientAdapter = adapter;

      final verdict = await DioFraudRepository().recordVerdict(
        visitId: 'v1',
        kind: FraudVerdictKind.needsEvidence,
        note: '  Ask for the till roll.  ',
      );

      expect(adapter.lastBody!['note'], 'Ask for the till roll.');
      expect(verdict.kind, FraudVerdictKind.needsEvidence);
    });

    test('409 carries the ruling that stands, not a raw failure', () async {
      final adapter = _RecordingAdapter(
        '{"error": "Nomsa already ruled this visit", '
        '"verdict": {"visitId": "v1", "verdict": "confirmed", '
        '"reviewer": {"id": "u2", "label": "Nomsa Dlamini-Mkhize"}, '
        '"note": "Two shops, one GPS fix.", "riskScoreAtReview": 82, '
        '"decidedAt": "2026-09-19T09:00:00.000Z"}}',
        status: 409,
      );
      dio.httpClientAdapter = adapter;

      // The loser of the race learns WHOSE decision applies, rather than
      // believing theirs did.
      await expectLater(
        DioFraudRepository().recordVerdict(
          visitId: 'v1',
          kind: FraudVerdictKind.cleared,
        ),
        throwsA(
          isA<FraudVerdictConflict>()
              .having(
                (e) => e.standing.kind,
                'kind',
                FraudVerdictKind.confirmed,
              )
              .having(
                (e) => e.standing.reviewerLabel,
                'reviewer',
                'Nomsa Dlamini-Mkhize',
              ),
        ),
      );
    });

    test('a 409 with no standing verdict is not swallowed as one', () async {
      final adapter = _RecordingAdapter('{"error": "conflict"}', status: 409);
      dio.httpClientAdapter = adapter;

      await expectLater(
        DioFraudRepository().recordVerdict(
          visitId: 'v1',
          kind: FraudVerdictKind.cleared,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('FraudVerdict.fromJson', () {
    test('maps every wire word onto a ruling a reviewer can read', () {
      for (final kind in FraudVerdictKind.values) {
        expect(FraudVerdictKind.fromWire(kind.wire), kind);
      }
      expect(FraudVerdictKind.fromWire('something-else'), isNull);
      expect(FraudVerdictKind.fromWire(null), isNull);
    });

    test('a visit nobody ruled carries null, never a default ruling', () {
      final visit = FlaggedVisit.fromJson({
        'visitId': 'v1',
        'outletId': 'o1',
        'agentId': 'a1',
        'riskScore': 65,
        'signals': <dynamic>[],
        'verdict': null,
      });

      // Null is the honest answer for "not yet reviewed": a row without a
      // verdict has not been cleared, it has not been looked at.
      expect(visit.verdict, isNull);
    });
  });
}
