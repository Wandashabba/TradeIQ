import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

/// A fake HTTP layer that returns a canned body, following the pattern in
/// `test/features/tasks/tasks_admin_repository_test.dart`. It also keeps the
/// last request's options so a test can read what was sent.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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

  test('AppUser.fromJson parses displayName, and label prefers it', () {
    final user = AppUser.fromJson(const {
      'id': 'u3',
      'email': 'agent3@example.com',
      'role': 'field_agent',
      'active': true,
      'displayName': 'Sipho Ndlovu',
    });

    expect(user.displayName, 'Sipho Ndlovu');
    expect(user.label, 'Sipho Ndlovu');
  });

  test(
    'AppUser.label falls back to the email when displayName is null or missing',
    () {
      final explicitNull = AppUser.fromJson(const {
        'id': 'u4',
        'email': 'legacy@example.com',
        'role': 'manager',
        'displayName': null,
      });
      final missing = AppUser.fromJson(const {
        'id': 'u5',
        'email': 'older@example.com',
        'role': 'manager',
      });

      expect(explicitNull.displayName, isNull);
      expect(explicitNull.label, 'legacy@example.com');
      expect(missing.displayName, isNull);
      expect(missing.label, 'older@example.com');
    },
  );

  group('DioUsersRepository.createUser', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    const created =
        '{"id": "u9", "email": "new@example.com", '
        '"role": "field_agent", "active": true, "displayName": "Lerato Mahlangu"}';

    test('sends a trimmed displayName when one is given', () async {
      final adapter = _RecordingAdapter(created);
      dio.httpClientAdapter = adapter;

      final user = await DioUsersRepository().createUser(
        email: 'new@example.com',
        password: 'secret123',
        role: 'field_agent',
        displayName: ' Lerato Mahlangu ',
      );

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['displayName'], 'Lerato Mahlangu');
      expect(user.label, 'Lerato Mahlangu');
    });

    test('omits displayName when it is null or blank', () async {
      for (final name in [null, '', '   ']) {
        final adapter = _RecordingAdapter(created);
        dio.httpClientAdapter = adapter;

        await DioUsersRepository().createUser(
          email: 'new@example.com',
          password: 'secret123',
          role: 'field_agent',
          displayName: name,
        );

        final sent = adapter.lastRequest!.data as Map<String, dynamic>;
        expect(
          sent.containsKey('displayName'),
          isFalse,
          reason: 'name: "$name"',
        );
      }
    });
  });

  group('DioUsersRepository.updateDisplayName', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    const updated =
        '{"id": "u9", "email": "new@example.com", '
        '"role": "field_agent", "active": true, "displayName": "Lerato Mahlangu"}';

    test('PATCHes /users/:id with only the trimmed displayName', () async {
      final adapter = _RecordingAdapter(updated);
      dio.httpClientAdapter = adapter;

      final user = await DioUsersRepository().updateDisplayName(
        'u9',
        '  Lerato Mahlangu ',
      );

      final request = adapter.lastRequest!;
      expect(request.method, 'PATCH');
      expect(request.path, '/users/u9');
      expect(request.data, {'displayName': 'Lerato Mahlangu'});
      expect(user.label, 'Lerato Mahlangu');
    });

    test(
      'sends an explicit null to clear when the name is null or blank',
      () async {
        for (final name in [null, '', '   ']) {
          final adapter = _RecordingAdapter(
            '{"id": "u9", "email": "new@example.com", '
            '"role": "field_agent", "active": true, "displayName": null}',
          );
          dio.httpClientAdapter = adapter;

          final user = await DioUsersRepository().updateDisplayName('u9', name);

          final sent = adapter.lastRequest!.data as Map<String, dynamic>;
          // The key must be present: absent would mean "leave it unchanged".
          expect(
            sent.containsKey('displayName'),
            isTrue,
            reason: 'name: "$name"',
          );
          expect(sent['displayName'], isNull, reason: 'name: "$name"');
          expect(user.label, 'new@example.com');
        }
      },
    );
  });

  group('DioUsersRepository.listUsers', () {
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
          '{"data": [{"id": "u1", "email": "agent@example.com", '
          '"role": "field_agent", "active": true}], '
          '"nextCursor": "cursor-1"}',
        );

        final page = await DioUsersRepository().listUsers();

        expect(page, isA<PaginatedResponse<AppUser>>());
        expect(page.data, hasLength(1));
        expect(page.data.first.id, 'u1');
        expect(page.nextCursor, 'cursor-1');
      },
    );
  });
}
