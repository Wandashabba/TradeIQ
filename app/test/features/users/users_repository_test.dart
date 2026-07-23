import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

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
  test('AppUser.fromJson parses all fields', () {
    final user = AppUser.fromJson(const {
      'id': 'u1',
      'email': 'agent@example.com',
      'role': 'field_agent',
      'active': false,
    });

    expect(user.id, 'u1');
    expect(user.email, 'agent@example.com');
    expect(user.role, 'field_agent');
    expect(user.active, isFalse);
  });

  test('AppUser.fromJson defaults active to true when missing', () {
    final user = AppUser.fromJson(const {
      'id': 'u2',
      'email': 'manager@example.com',
      'role': 'manager',
    });

    expect(user.active, isTrue);
  });

  group('DioUsersRepository.listUsers', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test('parses the {data, nextCursor} envelope into a PaginatedResponse',
        () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"data": [{"id": "u1", "email": "agent@example.com", '
        '"role": "field_agent", "active": true}], '
        '"nextCursor": "cursor-1"}',
      );

      final page = await DioUsersRepository().listUsers();

      expect(page, isA<PaginatedResponse<AppUser>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'u1');
      expect(page.nextCursor, 'cursor-1');
    });
  });
}
