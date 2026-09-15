import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';

/// A fake HTTP layer that returns a canned body and records the request,
/// following the pattern in `test/features/alerts/alerts_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
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
      },
    );
  });
}
