import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/human_error.dart';

DioException _dio({
  DioExceptionType type = DioExceptionType.unknown,
  int? statusCode,
  Object? error,
}) {
  final options = RequestOptions(path: '/dashboard');
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  group('humanErrorMessage', () {
    test('every flavour of unreachable maps to the same connectivity line', () {
      // Offline is the expected state for a field agent, so the copy tells
      // them what to do (check the connection) instead of reporting which of
      // Dio's four timeout/connection failure modes happened to fire — a
      // distinction that means nothing to the person holding the phone.
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          humanErrorMessage(_dio(type: type)),
          'Could not reach the server. Check your connection and try again.',
          reason: '$type should read as a connectivity problem',
        );
      }
    });

    test('a 401 reads as an expired session, not bad credentials', () {
      // Outside the login screen a 401 means the 12h token expired, and the
      // api_client interceptor is already signing the user out. "Invalid
      // credentials" here would accuse the user of a typo they never made.
      expect(
        humanErrorMessage(
          _dio(type: DioExceptionType.badResponse, statusCode: 401),
        ),
        'Your session has expired. Please sign in again.',
      );
    });

    test('a server-side 500 gets the generic line, not the status code', () {
      expect(
        humanErrorMessage(
          _dio(type: DioExceptionType.badResponse, statusCode: 500),
        ),
        'Something went wrong. Please try again.',
      );
    });

    test('a non-Dio error also gets the generic line', () {
      // A parsing bug or programmer error is ours to fix, not the agent's to
      // read — the details belong in a log.
      expect(
        humanErrorMessage(Exception('unexpected null in payload')),
        'Something went wrong. Please try again.',
      );
    });

    test('never leaks the raw exception, whatever it carries', () {
      // The regression this guards: AsyncSection used to interpolate `$err`,
      // putting a multi-line DioException — SocketException, hostname and
      // all — on every console screen.
      final leaky = _dio(
        type: DioExceptionType.connectionError,
        error: 'SocketException: Failed host lookup: api.tradeiq.internal',
      );
      final message = humanErrorMessage(leaky);
      expect(message, isNot(contains('DioException')));
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('api.tradeiq.internal')));
    });
  });
}
