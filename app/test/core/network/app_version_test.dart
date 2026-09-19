import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/app_version.dart';

/// Answers every request with [status] and [body], and keeps what was sent.
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

DioException _error(int status, Object? data, {String path = '/visits'}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  late HttpClientAdapter original;
  late void Function()? originalUnauthorized;

  setUp(() {
    original = dio.httpClientAdapter;
    originalUnauthorized = onUnauthorized;
    appUpdateRequired.value = null;
  });

  tearDown(() {
    dio.httpClientAdapter = original;
    onUnauthorized = originalUnauthorized;
    appUpdateRequired.value = null;
  });

  test('the default version is the one pubspec.yaml declares', () {
    // A build that forgets --dart-define=APP_VERSION must still report the
    // version it was cut from. If this default lags pubspec, the day an
    // operator raises MIN_APP_VERSION the newest build locks itself out.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml declares no version');
    expect(appVersion, match!.group(1));
    if (match.group(2) != null) expect(appBuild, match.group(2));
  });

  test('every request says which build sent it', () async {
    final adapter = _Adapter(200, '{}');
    dio.httpClientAdapter = adapter;
    await dio.get<void>('/health');
    expect(adapter.last!.headers['X-App-Version'], appVersion);
    expect(adapter.last!.headers['X-App-Build'], appBuild);
  });

  group('the version gate (426)', () {
    test('a 426 with the gate\'s code sets the update state', () async {
      var signedOut = false;
      onUnauthorized = () => signedOut = true;
      dio.httpClientAdapter = _Adapter(
        426,
        '{"error":"too old","code":"app_update_required","minimumVersion":"1.5.0"}',
      );

      await expectLater(dio.get<void>('/visits'), throwsA(isA<DioException>()));

      expect(
        appUpdateRequired.value,
        const AppUpdateRequired(minimumVersion: '1.5.0'),
      );
      // The build is stale; the session is fine. Signing out would ask for a
      // password the person does not need to re-enter.
      expect(signedOut, isFalse);
    });

    test('a 426 without the code is not the gate', () {
      // A proxy's 426 must not strand the app on a dead-end screen.
      expect(AppUpdateRequired.fromError(_error(426, 'Upgrade')), isNull);
      expect(
        AppUpdateRequired.fromError(_error(426, {'code': 'something_else'})),
        isNull,
      );
    });

    test('a missing minimum is null, never invented', () {
      expect(
        AppUpdateRequired.fromError(
          _error(426, {'code': 'app_update_required'}),
        ),
        const AppUpdateRequired(),
      );
    });
  });

  group('which 401s end the session', () {
    test('an ordinary 401 does: the 12h token expired', () {
      expect(endsSession(_error(401, {'error': 'Unauthorized'})), isTrue);
    });

    test('a failed login does not', () {
      expect(endsSession(_error(401, null, path: '/auth/login')), isFalse);
    });

    test('a wrong current password does not — the session is intact', () {
      expect(
        endsSession(
          _error(401, {
            'error': 'Current password is incorrect',
            'code': 'current_password_incorrect',
          }, path: '/auth/change-password'),
        ),
        isFalse,
      );
    });

    test('a refused reset code does not', () {
      expect(
        endsSession(
          _error(401, {
            'error': 'That reset code is not valid or has expired',
            'code': 'reset_code_invalid',
          }, path: '/auth/reset-password'),
        ),
        isFalse,
      );
    });

    test('an expired token on change-password still does', () {
      // requireAuth answers before the route runs, with no code. That one IS
      // the session ending, and must still sign the user out.
      expect(
        endsSession(
          _error(401, {'error': 'Unauthorized'}, path: '/auth/change-password'),
        ),
        isTrue,
      );
    });

    test(
      'the interceptor keeps the session on a wrong current password',
      () async {
        var signedOut = false;
        onUnauthorized = () => signedOut = true;
        dio.httpClientAdapter = _Adapter(
          401,
          '{"error":"Current password is incorrect","code":"current_password_incorrect"}',
        );
        await expectLater(
          dio.post<void>('/auth/change-password'),
          throwsA(isA<DioException>()),
        );
        expect(signedOut, isFalse);
      },
    );
  });
}
