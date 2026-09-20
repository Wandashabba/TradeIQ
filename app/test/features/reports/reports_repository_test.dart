import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';

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
  test('ReportDefinition.fromJson parses all fields', () {
    final report = ReportDefinition.fromJson(const {
      'id': 'r1',
      'name': 'Coverage by outlet',
      'type': 'coverage',
      'filters': {'region': 'north'},
    });

    expect(report.id, 'r1');
    expect(report.name, 'Coverage by outlet');
    expect(report.type, 'coverage');
  });

  test('ReportResult.fromJson parses rowCount and generatedAt', () {
    final result = ReportResult.fromJson(const {
      'definition': {'id': 'r1'},
      'generatedAt': '2026-07-09T10:00:00.000Z',
      'rowCount': 42,
      'rows': [],
    });

    expect(result.rowCount, 42);
    expect(result.generatedAt, '2026-07-09T10:00:00.000Z');
  });

  test('ReportResult.fromJson defaults rowCount to 0 when missing', () {
    final result = ReportResult.fromJson(const {
      'generatedAt': '2026-07-09T10:00:00.000Z',
    });

    expect(result.rowCount, 0);
    expect(result.generatedAt, '2026-07-09T10:00:00.000Z');
  });

  group('DioReportsRepository.listReports', () {
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
        '{"data": [{"id": "r1", "name": "Coverage by outlet", '
        '"type": "coverage"}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioReportsRepository().listReports();

      expect(page, isA<PaginatedResponse<ReportDefinition>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'r1');
      expect(page.nextCursor, 'cursor-1');
    });
  });
}
