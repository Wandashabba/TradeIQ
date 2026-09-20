import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';

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
  test('BeatPlan.fromJson parses summary fields', () {
    final plan = BeatPlan.fromJson(const {
      'id': 'bp1',
      'name': 'North Route',
      'status': 'scheduled',
      'scheduledDate': '2026-07-10',
      'agentId': 'a1',
    });

    expect(plan.id, 'bp1');
    expect(plan.name, 'North Route');
    expect(plan.status, 'scheduled');
    expect(plan.scheduledDate, '2026-07-10');
  });

  test('BeatPlanStop.fromJson parses stop fields', () {
    final stop = BeatPlanStop.fromJson(const {
      'id': 's1',
      'outletId': 'o1',
      'sequence': 3,
      'visited': true,
    });

    expect(stop.id, 's1');
    expect(stop.outletId, 'o1');
    expect(stop.sequence, 3);
    expect(stop.visited, true);
  });

  test('BeatPlanDetail.fromJson parses plan, stops and adherence', () {
    final detail = BeatPlanDetail.fromJson(const {
      'id': 'bp1',
      'name': 'North Route',
      'status': 'in_progress',
      'scheduledDate': '2026-07-10',
      'stops': [
        {'id': 's1', 'outletId': 'o1', 'sequence': 1, 'visited': true},
        {'id': 's2', 'outletId': 'o2', 'sequence': 2, 'visited': false},
      ],
      'adherence': {
        'stopsTotal': 2,
        'stopsVisited': 1,
        'adherenceRate': 0.5,
      },
    });

    expect(detail.plan.id, 'bp1');
    expect(detail.plan.name, 'North Route');
    expect(detail.stops, hasLength(2));
    expect(detail.stops.first.id, 's1');
    expect(detail.stops.first.visited, true);
    expect(detail.stopsTotal, 2);
    expect(detail.stopsVisited, 1);
    expect(detail.adherenceRate, 0.5);
  });

  group('DioBeatPlansRepository.listBeatPlans', () {
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
        '{"data": [{"id": "bp1", "name": "North Route", "status": "planned", '
        '"scheduledDate": "2026-07-10"}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioBeatPlansRepository().listBeatPlans();

      expect(page, isA<PaginatedResponse<BeatPlan>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'bp1');
      expect(page.nextCursor, 'cursor-1');
    });
  });
}
