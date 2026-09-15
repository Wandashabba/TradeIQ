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

    test('updateSchedule PATCHes the cadence and recipients', () async {
      final adapter = _RecordingAdapter(jsonEncode(_row));
      dio.httpClientAdapter = adapter;

      final updated = await DioReportSchedulesRepository().updateSchedule(
        's1',
        cadence: 'weekly',
        recipients: const ['ops@acme.test', 'lead@acme.test'],
      );

      expect(adapter.last!.method, 'PATCH');
      expect(adapter.last!.path, '/report-schedules/s1');
      // Never the report: the route cannot relink a schedule.
      expect(adapter.last!.data, {
        'cadence': 'weekly',
        'recipients': ['ops@acme.test', 'lead@acme.test'],
      });
      expect(updated.id, 's1');
      expect(updated.cadence, 'weekly');
    });

    test('updateSchedule sends only the fields it is given', () async {
      final adapter = _RecordingAdapter(jsonEncode(_row));
      dio.httpClientAdapter = adapter;

      await DioReportSchedulesRepository()
          .updateSchedule('s1', recipients: const ['ops@acme.test']);
      expect(adapter.last!.data, {
        'recipients': ['ops@acme.test'],
      });

      await DioReportSchedulesRepository()
          .updateSchedule('s1', cadence: 'daily');
      expect(adapter.last!.data, {'cadence': 'daily'});
    });

    test('updateSchedule surfaces a 400 as an error', () async {
      dio.httpClientAdapter = _RecordingAdapter(
        jsonEncode({'error': 'cadence must be daily|weekly'}),
        status: 400,
      );

      expect(
        DioReportSchedulesRepository().updateSchedule('s1', cadence: 'daily'),
        throwsA(isA<DioException>()),
      );
    });

    test('deleteSchedule sends DELETE and accepts the 204', () async {
      final adapter = _RecordingAdapter('', status: 204);
      dio.httpClientAdapter = adapter;

      await DioReportSchedulesRepository().deleteSchedule('s1');

      expect(adapter.last!.method, 'DELETE');
      expect(adapter.last!.path, '/report-schedules/s1');
    });

    test('runNow POSTs to /run and parses the run and its deliveries',
        () async {
      final adapter = _RecordingAdapter(
        jsonEncode({
          'schedule': _row,
          'runId': 'run-1',
          'trigger': 'manual',
          'generatedAt': '2026-09-14T10:05:00.000Z',
          'rowCount': 42,
          'deliveredTo': ['https://hooks.acme.test/reports'],
          'deliveries': [
            {
              'channel': 'webhook',
              'status': 'queued',
              'targets': ['https://hooks.acme.test/reports'],
              'webhookDeliveryIds': ['d1'],
            },
            {
              'channel': 'email',
              'status': 'not_configured',
              'targets': ['ops@acme.test', 'lead@acme.test'],
              'detail': 'Email delivery not configured',
            },
            'not-an-outcome',
          ],
        }),
      );
      dio.httpClientAdapter = adapter;

      final result = await DioReportSchedulesRepository().runNow('s1');

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/report-schedules/s1/run');
      expect(result.runId, 'run-1');
      expect(result.rowCount, 42);
      expect(result.generatedAt, '2026-09-14T10:05:00.000Z');
      expect(result.deliveredTo, ['https://hooks.acme.test/reports']);
      expect(result.schedule.id, 's1');
      expect(result.deliveries, hasLength(2));
      expect(result.outcomeFor('webhook')!.status, 'queued');
      final email = result.outcomeFor('email')!;
      expect(email.status, 'not_configured');
      expect(email.targets, ['ops@acme.test', 'lead@acme.test']);
      expect(email.detail, 'Email delivery not configured');
      expect(result.outcomeFor('sms'), isNull);
    });

    test('listRuns GETs the schedule\'s runs with limit and cursor, and parses them',
        () async {
      final adapter = _RecordingAdapter(
        jsonEncode({
          'data': [
            {
              'id': 'run-1',
              'scheduleId': 's1',
              'trigger': 'scheduled',
              'status': 'partial',
              'dueAt': '2026-09-14T09:00:00.000Z',
              'generatedAt': '2026-09-14T09:01:00.000Z',
              'rowCount': 42,
              'reason': '1 email could not be sent',
              'summary': {
                'webhook': {'status': 'queued', 'delivered': 1, 'failed': 0, 'pending': 0},
                'email': {
                  'status': 'queued',
                  'sent': 1,
                  'failed': 1,
                  'pending': 0,
                  'notConfigured': 0,
                },
              },
              'deliveries': [
                {'channel': 'webhook', 'status': 'queued', 'targets': ['https://a.test']},
              ],
              'webhookDeliveries': [
                {
                  'id': 'wd-1',
                  'webhookId': 'w1',
                  'url': 'https://a.test',
                  'status': 'succeeded',
                  'attempts': 1,
                  'lastStatusCode': 204,
                  'lastError': null,
                },
              ],
              'csvDownloadUrl': 'https://api.test/report-downloads/t',
              'csvDownloadExpiresAt': '2026-09-21T09:01:00.000Z',
            },
            {
              'id': 'run-2',
              'generatedAt': '2026-09-13T09:01:00.000Z',
              'status': 'something_new',
            },
          ],
          'nextCursor': 'run-2',
        }),
      );
      dio.httpClientAdapter = adapter;

      final page = await DioReportSchedulesRepository()
          .listRuns('s1', cursor: 'run-0', limit: 2);

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/report-schedules/s1/runs');
      expect(adapter.last!.queryParameters, {'limit': 2, 'cursor': 'run-0'});
      expect(page.nextCursor, 'run-2');

      final run = page.data.first;
      expect(run.status, ReportRunStatus.partial);
      expect(run.scheduled, isTrue);
      expect(run.dueAt, DateTime.utc(2026, 9, 14, 9));
      expect(run.rowCount, 42);
      expect(run.reason, '1 email could not be sent');
      expect(run.webhook.delivered, 1);
      expect(run.email.sent, 1);
      expect(run.email.failed, 1);
      expect(run.outcomeFor('webhook')!.status, 'queued');
      expect(run.webhookDeliveries.single.status, DeliveryStatus.succeeded);
      expect(run.webhookDeliveries.single.lastStatusCode, 204);
      expect(run.csvDownloadUrl, 'https://api.test/report-downloads/t');
      expect(run.csvDownloadExpiresAt, DateTime.utc(2026, 9, 21, 9, 1));

      // A sparse or newer row still parses, to safe defaults.
      final sparse = page.data.last;
      expect(sparse.status, ReportRunStatus.unknown);
      expect(sparse.trigger, 'manual');
      expect(sparse.email.status, isNull);
      expect(sparse.csvDownloadUrl, isNull);
    });

    test('listRuns sends no cursor for the first page', () async {
      final adapter = _RecordingAdapter(
        jsonEncode({'data': [], 'nextCursor': null}),
      );
      dio.httpClientAdapter = adapter;

      await DioReportSchedulesRepository().listRuns('s1');

      expect(adapter.last!.queryParameters, {'limit': reportRunsPageSize});
    });

    test('listEmailDeliveries GETs one run\'s deliveries', () async {
      final adapter = _RecordingAdapter(
        jsonEncode({
          'data': [
            {
              'id': 'e1',
              'recipient': 'ops@acme.test',
              'status': 'gave_up',
              'attempts': 6,
              'lastError': 'SMTP 550',
            },
          ],
          'nextCursor': null,
        }),
      );
      dio.httpClientAdapter = adapter;

      final list =
          await DioReportSchedulesRepository().listEmailDeliveries('s1', 'run-1');

      expect(adapter.last!.path, '/report-schedules/s1/runs/run-1/email-deliveries');
      expect(adapter.last!.queryParameters, {'limit': 50});
      expect(list.single.recipient, 'ops@acme.test');
      expect(list.single.status, DeliveryStatus.gaveUp);
      expect(list.single.attempts, 6);
      expect(list.single.lastError, 'SMTP 550');
    });

    test('an older run response without deliveries still parses', () {
      final result = ScheduleRunResult.fromJson({
        'schedule': _row,
        'generatedAt': '2026-09-14T10:05:00.000Z',
        'rowCount': 3,
      });
      expect(result.runId, isNull);
      expect(result.deliveredTo, isEmpty);
      expect(result.deliveries, isEmpty);
    });
  });
}
