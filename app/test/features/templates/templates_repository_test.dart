import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';

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
  test('AuditTemplate.fromJson parses all fields', () {
    final template = AuditTemplate.fromJson(const {
      'id': 'tpl-1',
      'name': 'Grocery Audit',
      'industry': 'retail',
      'version': 3,
      'active': false,
    });

    expect(template.id, 'tpl-1');
    expect(template.name, 'Grocery Audit');
    expect(template.industry, 'retail');
    expect(template.version, 3);
    expect(template.active, false);
  });

  test('AuditTemplate.fromJson defaults version to 1 and active to true', () {
    final template = AuditTemplate.fromJson(const {
      'id': 'tpl-2',
      'name': 'Pharmacy Audit',
    });

    expect(template.industry, isNull);
    expect(template.version, 1);
    expect(template.active, true);
  });

  test('AuditTemplateDetail.fromJson keeps the schema map verbatim', () {
    final detail = AuditTemplateDetail.fromJson(const {
      'id': 'tpl-1',
      'name': 'Grocery Audit',
      'version': 2,
      'active': true,
      'schema': {
        'sections': [
          {'id': 's1', 'fields': []},
        ],
      },
    });

    expect(detail.template.id, 'tpl-1');
    expect(detail.schema['sections'], isA<List<dynamic>>());
  });

  test('AuditTemplateDetail.fromJson tolerates a missing/mistyped schema', () {
    final missing = AuditTemplateDetail.fromJson(const {
      'id': 'tpl-2',
      'name': 'Pharmacy Audit',
    });
    expect(missing.schema, isEmpty);

    final mistyped = AuditTemplateDetail.fromJson(const {
      'id': 'tpl-3',
      'name': 'Broken Audit',
      'schema': ['not', 'a', 'map'],
    });
    expect(mistyped.schema, isEmpty);
  });

  group('DioTemplatesRepository.listTemplates', () {
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
          '{"data": [{"id": "tpl-1", "name": "Grocery Audit", '
          '"version": 2, "active": true}], '
          '"nextCursor": "cursor-1"}',
        );

        final page = await DioTemplatesRepository().listTemplates();

        expect(page, isA<PaginatedResponse<AuditTemplate>>());
        expect(page.data, hasLength(1));
        expect(page.data.first.id, 'tpl-1');
        expect(page.nextCursor, 'cursor-1');
      },
    );
  });
}
