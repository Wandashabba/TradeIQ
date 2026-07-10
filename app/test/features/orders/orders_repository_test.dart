import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/orders/data/orders_repository.dart';

void main() {
  test('OrderItem.fromJson parses total as double and lines from _count', () {
    final order = OrderItem.fromJson(const {
      'id': 'ord-123',
      'outletId': 'o1',
      'status': 'submitted',
      'total': 149.5,
      '_count': {'lines': 3},
    });

    expect(order.id, 'ord-123');
    expect(order.outletId, 'o1');
    expect(order.status, 'submitted');
    expect(order.total, 149.5);
    expect(order.total, isA<double>());
    expect(order.lineCount, 3);
  });

  test('OrderItem.fromJson coerces integer total to double', () {
    final order = OrderItem.fromJson(const {
      'id': 'ord-int',
      'outletId': 'o2',
      'status': 'draft',
      'total': 200,
      '_count': {'lines': 1},
    });

    expect(order.total, 200.0);
    expect(order.total, isA<double>());
  });

  test('OrderItem.fromJson defaults lineCount to 0 when _count absent', () {
    final order = OrderItem.fromJson(const {
      'id': 'ord-nocount',
      'outletId': 'o3',
      'status': 'draft',
      'total': 0,
    });

    expect(order.lineCount, 0);
  });
}
