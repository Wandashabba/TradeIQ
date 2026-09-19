import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/password_repository.dart';
import 'package:tradeiq_app/core/auth/password_rule.dart';
import 'package:tradeiq_app/core/network/api_client.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final String body;
  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('the password rule, as the phone checks it', () {
    test('twelve characters is the floor', () {
      expect(checkNewPassword('elevenchars'), PasswordProblem.tooShort);
      expect(checkNewPassword('twelve chars'), isNull);
    });

    test('padding is not length', () {
      // The server trims before it measures; so does the phone.
      expect(checkNewPassword('   short    '), PasswordProblem.tooShort);
    });

    test('72 bytes is the ceiling, counted in bytes not characters', () {
      expect(checkNewPassword('a' * 72), isNull);
      expect(checkNewPassword('a' * 73), PasswordProblem.tooLong);
      // 25 three-byte characters: 25 characters, 75 bytes.
      expect(checkNewPassword('€' * 25), PasswordProblem.tooLong);
    });

    test('not your own email, in any case', () {
      expect(
        checkNewPassword(
          'Agent.One@Example.com',
          email: 'agent.one@example.com',
        ),
        PasswordProblem.isEmail,
      );
    });

    test('the password is never trimmed or changed', () {
      // Spaces at either end are allowed, they just do not count.
      expect(checkNewPassword(' blue truck monday '), isNull);
    });
  });

  group('the refusals a screen words itself', () {
    DioException err(int status, Object? data) {
      final o = RequestOptions(path: '/x');
      return DioException(
        requestOptions: o,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: o, statusCode: status, data: data),
      );
    }

    test('matched on the server\'s code, never its prose', () {
      expect(
        passwordRefusalOf(err(401, {'code': 'current_password_incorrect'})),
        PasswordRefusal.wrongCurrentPassword,
      );
      expect(
        passwordRefusalOf(err(401, {'code': 'reset_code_invalid'})),
        PasswordRefusal.codeRejected,
      );
      expect(
        passwordRefusalOf(err(401, {'error': 'Current password is incorrect'})),
        isNull,
        reason: 'a 401 without a code is an expired session',
      );
    });

    test('400, 403 and 404', () {
      expect(passwordRefusalOf(err(400, {})), PasswordRefusal.passwordRejected);
      expect(passwordRefusalOf(err(403, {})), PasswordRefusal.notPermitted);
      expect(passwordRefusalOf(err(404, {})), PasswordRefusal.notFound);
      expect(passwordRefusalOf(err(429, {})), isNull);
      expect(passwordRefusalOf(err(500, {})), isNull);
    });
  });

  group('DioPasswordRepository', () {
    late HttpClientAdapter original;
    setUp(() => original = dio.httpClientAdapter);
    tearDown(() => dio.httpClientAdapter = original);

    test(
      'change-password sends both passwords and reads the sessions flag',
      () async {
        final adapter = _Adapter(200, '{"otherSessionsEnded":false}');
        dio.httpClientAdapter = adapter;
        final result = await DioPasswordRepository().changePassword(
          currentPassword: 'old password 1',
          newPassword: 'blue truck monday',
        );
        expect(adapter.last!.path, '/auth/change-password');
        expect(adapter.last!.data, {
          'currentPassword': 'old password 1',
          'newPassword': 'blue truck monday',
        });
        expect(result.otherSessionsEnded, isFalse);
      },
    );

    test('reset sends the email normalised and the code as typed', () async {
      final adapter = _Adapter(200, '{"otherSessionsEnded":false}');
      dio.httpClientAdapter = adapter;
      await DioPasswordRepository().redeemResetCode(
        email: ' Agent@Example.com ',
        code: '4821 7390',
        newPassword: 'blue truck monday',
      );
      expect(adapter.last!.path, '/auth/reset-password');
      expect(adapter.last!.data, {
        'email': 'agent@example.com',
        'code': '4821 7390',
        'newPassword': 'blue truck monday',
      });
    });

    test(
      'a refused code surfaces as a refusal, not an exception dump',
      () async {
        dio.httpClientAdapter = _Adapter(
          401,
          jsonEncode({
            'error': 'That reset code is not valid or has expired',
            'code': 'reset_code_invalid',
          }),
        );
        await expectLater(
          DioPasswordRepository().redeemResetCode(
            email: 'a@b.c',
            code: '00000000',
            newPassword: 'blue truck monday',
          ),
          throwsA(
            isA<PasswordRefused>().having(
              (r) => r.reason,
              'reason',
              PasswordRefusal.codeRejected,
            ),
          ),
        );
      },
    );

    test('issuing a code reads it back, and never prints it', () async {
      final adapter = _Adapter(
        201,
        jsonEncode({
          'code': '48217390',
          'expiresAt': '2026-09-19T10:15:00.000Z',
          'userId': 'u1',
          'email': 'agent@example.com',
        }),
      );
      dio.httpClientAdapter = adapter;
      final issued = await DioPasswordRepository().issueResetCode('u1');
      expect(adapter.last!.path, '/users/u1/password-reset-code');
      expect(issued.code, '48217390');
      expect(issued.email, 'agent@example.com');
      // A debug print or crash report that stringifies this object must not
      // carry the secret with it.
      expect(issued.toString(), isNot(contains('48217390')));
    });

    test('set-password posts to the user', () async {
      final adapter = _Adapter(200, '{"otherSessionsEnded":false}');
      dio.httpClientAdapter = adapter;
      await DioPasswordRepository().setPasswordFor('u 1', 'blue truck monday');
      expect(adapter.last!.path, '/users/u%201/password');
      expect(adapter.last!.data, {'newPassword': 'blue truck monday'});
    });
  });
}
