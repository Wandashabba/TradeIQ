import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';

void main() {
  group('PaginatedResponse.fromJson', () {
    test('parses data and a nextCursor', () {
      final page = PaginatedResponse.fromJson(
        const {'data': [1, 2, 3], 'nextCursor': 'abc'},
        (e) => e as int,
      );
      expect(page.data, [1, 2, 3]);
      expect(page.nextCursor, 'abc');
    });

    test('parses a null nextCursor as null', () {
      final page = PaginatedResponse.fromJson(
        const {'data': [], 'nextCursor': null},
        (e) => e as int,
      );
      expect(page.data, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('treats a missing data key as an empty list', () {
      final page = PaginatedResponse.fromJson(
        const {'nextCursor': null},
        (e) => e as int,
      );
      expect(page.data, isEmpty);
    });
  });
}
