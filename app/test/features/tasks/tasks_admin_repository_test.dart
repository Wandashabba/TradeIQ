import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';

/// A fake HTTP layer that returns a canned body, following the pattern in
/// `test/features/agents/agents_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;

  /// The query the last request carried, so a test can assert what was asked
  /// for rather than only what came back.
  Map<String, dynamic> lastQuery = const <String, dynamic>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
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
  test('TaskItem.fromJson parses all fields including visitId, slaDueAt and '
      'evidencePhotoId', () {
    final task = TaskItem.fromJson(const {
      'id': 't1',
      'findingType': 'out_of_stock',
      'requiredFix': 'Restock SKU 42',
      'priority': 'critical',
      'status': 'closed',
      'closurePhotoUrl': 'https://cdn.example.com/t1.png',
      'closureVerified': true,
      'outletId': 'o1',
      'visitId': 'v1',
      'slaDueAt': '2026-08-01T10:00:00.000Z',
      'evidencePhotoId': 'p1',
    });

    expect(task.id, 't1');
    expect(task.findingType, 'out_of_stock');
    expect(task.requiredFix, 'Restock SKU 42');
    expect(task.priority, 'critical');
    expect(task.status, 'closed');
    expect(task.closurePhotoUrl, 'https://cdn.example.com/t1.png');
    expect(task.closureVerified, isTrue);
    expect(task.outletId, 'o1');
    expect(task.visitId, 'v1');
    expect(task.slaDueAt, DateTime.utc(2026, 8, 1, 10));
    expect(task.evidencePhotoId, 'p1');
  });

  test(
    'TaskItem.fromJson defaults closureVerified to false and allows null optionals',
    () {
      // slaDueAt stays required — the backend computes it on task creation and
      // always sends it; evidencePhotoId is genuinely nullable (no visit, or a
      // photoless visit).
      final task = TaskItem.fromJson(const {
        'id': 't2',
        'findingType': 'price_wrong',
        'requiredFix': 'Correct shelf price',
        'priority': 'normal',
        'status': 'open',
        'outletId': 'o2',
        'slaDueAt': '2026-07-30T08:00:00.000Z',
        'evidencePhotoId': null,
      });

      expect(task.closureVerified, isFalse);
      expect(task.closurePhotoUrl, isNull);
      expect(task.visitId, isNull);
      expect(task.slaDueAt, DateTime.utc(2026, 7, 30, 8));
      expect(task.evidencePhotoId, isNull);
    },
  );

  group('DioTasksAdminRepository.listTasks', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    const oneTask =
        '{"id": "t1", "findingType": "out_of_stock", '
        '"requiredFix": "Restock SKU 42", "priority": "critical", '
        '"status": "open", "closureVerified": false, "outletId": "o1", '
        '"slaDueAt": "2026-08-01T10:00:00.000Z"}';

    test('parses the {data, nextCursor} envelope', () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [$oneTask], "nextCursor": "cursor-1"}',
      );

      final page = await DioTasksAdminRepository().listTasks();

      expect(page.data, hasLength(1));
      expect(page.data.first.id, 't1');
      expect(page.nextCursor, 'cursor-1');
    });

    test('parses the whole-set breakdown beside the page', () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [$oneTask], "nextCursor": "cursor-1", "total": 1190, '
        '"counts": {"all": 32368, "open": 1190, "overdue": 1122, '
        '"done": 31178, "awaitingVerification": 43}}',
      );

      final page = await DioTasksAdminRepository().listTasks(
        state: TaskState.open,
      );

      expect(page.total, 1190);
      final counts = page.counts!;
      expect(counts.all, 32368);
      expect(counts.open, 1190);
      expect(counts.overdue, 1122);
      expect(counts.done, 31178);
      expect(counts.awaitingVerification, 43);
      expect(counts.forState(TaskState.overdue), 1122);
    });

    test('a server that does not count answers a null breakdown', () async {
      // Not zeros. The screen renders an unknown differently from a measured
      // nought, and a `counts` object invented out of absence here is exactly
      // the confident wrong number the whole change exists to stop.
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [$oneTask], "nextCursor": null}',
      );
      expect((await DioTasksAdminRepository().listTasks()).counts, isNull);
    });

    test('half a breakdown is no breakdown', () async {
      // A partial object cannot be added up, and four real figures beside one
      // silently-zero fifth is worse than five honest unknowns.
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [$oneTask], "nextCursor": null, '
        '"counts": {"all": 5, "open": 2, "overdue": 1}}',
      );
      expect((await DioTasksAdminRepository().listTasks()).counts, isNull);
    });

    test('sends the state the screen asked for', () async {
      final adapter = _RecordingAdapter('{"data": [], "nextCursor": null}');
      dio.httpClientAdapter = adapter;

      await DioTasksAdminRepository().listTasks(state: TaskState.overdue);
      expect(adapter.lastQuery['state'], 'overdue');

      await DioTasksAdminRepository().listTasks();
      expect(adapter.lastQuery.containsKey('state'), isFalse);
    });
  });
}
