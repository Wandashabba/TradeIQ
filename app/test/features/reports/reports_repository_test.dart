import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';

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
}
