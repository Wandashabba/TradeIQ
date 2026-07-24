import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/incentives/data/incentives_repository.dart';

/// A fake HTTP layer that returns a canned body, following the pattern in
/// `test/features/agents/agents_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
  test('IncentiveScheme.fromJson parses all fields', () {
    final scheme = IncentiveScheme.fromJson(const {
      'id': 's1',
      'name': 'Top Scorecard',
      'metric': 'scorecard',
      'threshold': 80,
      'rewardPoints': 100,
      'rewardDetail': 'Voucher',
      'active': true,
    });

    expect(scheme.id, 's1');
    expect(scheme.name, 'Top Scorecard');
    expect(scheme.metric, 'scorecard');
    expect(scheme.threshold, 80.0);
    expect(scheme.rewardPoints, 100);
    expect(scheme.active, isTrue);
  });

  test('IncentiveScheme.fromJson defaults active to false when missing', () {
    final scheme = IncentiveScheme.fromJson(const {
      'id': 's2',
      'name': 'Visits Drive',
      'metric': 'visits',
      'threshold': 20.5,
      'rewardPoints': 50,
    });

    expect(scheme.threshold, 20.5);
    expect(scheme.active, isFalse);
  });

  test('EarnedIncentive.fromJson parses all fields', () {
    final earned = EarnedIncentive.fromJson(const {
      'schemeId': 's1',
      'schemeName': 'Top Scorecard',
      'metric': 'scorecard',
      'agentId': 'a1',
      'email': 'agent@example.com',
      'metricValue': 90,
      'rewardPoints': 100,
    });

    expect(earned.schemeName, 'Top Scorecard');
    expect(earned.email, 'agent@example.com');
    expect(earned.rewardPoints, 100);
  });

  group('DioIncentivesRepository.listSchemes', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test('parses the {data, nextCursor} envelope into a PaginatedResponse',
        () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [{"id": "s1", "name": "Top Scorecard", "metric": "scorecard", '
        '"threshold": 80, "rewardPoints": 100, "active": true}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioIncentivesRepository().listSchemes();

      expect(page, isA<PaginatedResponse<IncentiveScheme>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 's1');
      expect(page.nextCursor, 'cursor-1');
    });
  });
}
