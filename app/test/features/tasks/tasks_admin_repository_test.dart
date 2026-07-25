import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';

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
}
