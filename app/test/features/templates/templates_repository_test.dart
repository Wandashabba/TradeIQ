import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';

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
}
