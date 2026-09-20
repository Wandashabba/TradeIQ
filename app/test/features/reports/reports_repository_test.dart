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
  _csvRowCounting();

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

    test(
      'parses the {data, nextCursor} envelope into a PaginatedResponse',
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
      },
    );
  });
}

// ── The CSV the Run action downloads (#390) ─────────────────────────────────

void _csvRowCounting() {
  group('ReportCsv.countRows', () {
    test('a header and three rows is three rows', () {
      expect(ReportCsv.countRows('outlet,visits\nA,1\nB,2\nC,3\n'), 3);
    });

    test('a header alone is a measured zero, not an unknown', () {
      expect(ReportCsv.countRows('outlet,visits\n'), 0);
    });

    test('an empty body is zero rows', () {
      expect(ReportCsv.countRows(''), 0);
    });

    test('a newline inside a quoted cell is not a row boundary', () {
      // An address column ships these, and a naive split on '\n' reports four
      // rows where the file holds two.
      expect(
        ReportCsv.countRows(
          'outlet,address\n'
          'A,"12 Main St\nJohannesburg"\n'
          'B,"7 Long St\nCape Town"\n',
        ),
        2,
      );
    });

    test('a doubled quote inside a quoted cell keeps the parity', () {
      expect(ReportCsv.countRows('outlet,note\nA,"said ""hello"" twice"\n'), 1);
    });

    test('a last line without a trailing newline still counts', () {
      expect(ReportCsv.countRows('outlet,visits\nA,1'), 1);
    });
  });
}
