import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';

/// A fake HTTP layer that records the request and returns a canned body,
/// following the pattern in `test/features/agents/agents_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body, {this.status = 200});
  final String body;
  final int status;

  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: body.isEmpty
          ? const {}
          : {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
    );
  }
}

const _row = {
  'id': 's1',
  'clientId': 'c1',
  'reportDefinitionId': 'r1',
  'cadence': 'weekly',
  'recipients': ['ops@acme.test', 'lead@acme.test'],
  'lastRunAt': '2026-09-14T10:05:00.000Z',
  'active': false,
  'createdAt': '2026-09-01T08:00:00.000Z',
  'reportDefinition': {'name': 'Coverage by outlet'},
};

void main() {
  group('ReportSchedule.fromJson', () {
    test('parses every field, including the joined report name', () {
      final s = ReportSchedule.fromJson(_row);

      expect(s.id, 's1');
      expect(s.reportDefinitionId, 'r1');
      expect(s.reportName, 'Coverage by outlet');
      expect(s.cadence, 'weekly');
      expect(s.recipients, ['ops@acme.test', 'lead@acme.test']);
      expect(s.active, isFalse);
      expect(s.lastRunAt, DateTime.utc(2026, 9, 14, 10, 5));
    });

    test('a bare row (PATCH/run shape) has no name and may have no run', () {
      final s = ReportSchedule.fromJson(const {
        'id': 's2',
        'reportDefinitionId': 'r2',
        'cadence': 'daily',
        'recipients': ['a@acme.test', 7],
        'lastRunAt': null,
      });

      expect(s.reportName, isNull);
      expect(s.lastRunAt, isNull);
      // `recipients` is a JSON column — only its strings are trusted.
      expect(s.recipients, ['a@acme.test']);
      expect(s.active, isTrue);
    });
  });

  test('cadenceLabel names the backend allow-list', () {
    expect(reportCadences, ['daily', 'weekly']);
    expect(cadenceLabel('daily'), 'Daily');
    expect(cadenceLabel('weekly'), 'Weekly');
  });

  group('DioReportSchedulesRepository', () {
    late HttpClientAdapter originalAdapter;

    setUp(() => originalAdapter = dio.httpClientAdapter);
    tearDown(() => dio.httpClientAdapter = originalAdapter);

    test('listSchedules GETs the {data, nextCursor} envelope', () async {
      final adapter = _RecordingAdapter(
        jsonEncode({
          'data': [_row],
          'nextCursor': 'cursor-1',
        }),
      );
      dio.httpClientAdapter = adapter;

      final page = await DioReportSchedulesRepository().listSchedules();

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/report-schedules');
      expect(page, isA<PaginatedResponse<ReportSchedule>>());
      expect(page.data.single.reportName, 'Coverage by outlet');
      expect(page.nextCursor, 'cursor-1');
    });

    test('createSchedule POSTs the report, cadence and recipients', () async {
      final adapter = _RecordingAdapter(jsonEncode(_row), status: 201);
      dio.httpClientAdapter = adapter;

      final created = await DioReportSchedulesRepository().createSchedule(
        reportDefinitionId: 'r1',
        cadence: 'weekly',
        recipients: const ['ops@acme.test'],
      );

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/report-schedules');
      expect(adapter.last!.data, {
        'reportDefinitionId': 'r1',
        'cadence': 'weekly',
        'recipients': ['ops@acme.test'],
      });
      expect(created.id, 's1');
    });

    test('setActive PATCHes only the active flag', () async {
      final adapter = _RecordingAdapter(jsonEncode(_row));
      dio.httpClientAdapter = adapter;

      await DioReportSchedulesRepository().setActive('s1', false);

      expect(adapter.last!.method, 'PATCH');
      expect(adapter.last!.path, '/report-schedules/s1');
      expect(adapter.last!.data, {'active': false});
    });

    test('deleteSchedule sends DELETE and accepts the 204', () async {
      final adapter = _RecordingAdapter('', status: 204);
      dio.httpClientAdapter = adapter;

      await DioReportSchedulesRepository().deleteSchedule('s1');

      expect(adapter.last!.method, 'DELETE');
      expect(adapter.last!.path, '/report-schedules/s1');
    });

    test('runNow POSTs to /run and parses the run result', () async {
      final adapter = _RecordingAdapter(
        jsonEncode({
          'schedule': _row,
          'generatedAt': '2026-09-14T10:05:00.000Z',
          'rowCount': 42,
          'deliveredTo': ['ops@acme.test', 'lead@acme.test'],
        }),
      );
      dio.httpClientAdapter = adapter;

      final result = await DioReportSchedulesRepository().runNow('s1');

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/report-schedules/s1/run');
      expect(result.rowCount, 42);
      expect(result.generatedAt, '2026-09-14T10:05:00.000Z');
      expect(result.deliveredTo, ['ops@acme.test', 'lead@acme.test']);
      expect(result.schedule.id, 's1');
    });
  });
}
