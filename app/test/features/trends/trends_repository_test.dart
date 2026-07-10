import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

void main() {
  test('TrendPoint.fromJson parses period and coerces value to double', () {
    final point = TrendPoint.fromJson(const {
      'period': '2026-W27',
      'value': 42,
      'count': 5,
    });

    expect(point.period, '2026-W27');
    expect(point.value, 42.0);
    expect(point.value, isA<double>());
  });

  test('parsing the points list yields the right length and values', () {
    final payload = <String, dynamic>{
      'interval': 'week',
      'points': [
        {'period': '2026-W26', 'value': 10.5, 'count': 3},
        {'period': '2026-W27', 'value': 12, 'count': 4},
      ],
    };

    final points = (payload['points'] as List)
        .map((json) => TrendPoint.fromJson(json as Map<String, dynamic>))
        .toList();

    expect(points.length, 2);
    expect(points[0].period, '2026-W26');
    expect(points[0].value, 10.5);
    expect(points[1].period, '2026-W27');
    expect(points[1].value, 12.0);
  });
}
