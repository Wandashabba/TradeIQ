import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/human_error.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

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

  group('HumanError codes', () {
    final af = lookupAppLocalizations(const Locale('af'));

    test('each failure maps to its code', () {
      expect(
        HumanError.of(
          _dio(type: DioExceptionType.badResponse, statusCode: 401),
        ),
        HumanError.sessionExpired,
      );
      expect(
        HumanError.of(_dio(type: DioExceptionType.receiveTimeout)),
        HumanError.unreachable,
      );
      expect(
        HumanError.of(
          _dio(type: DioExceptionType.badResponse, statusCode: 500),
        ),
        HumanError.generic,
      );
      expect(HumanError.of(StateError('bug')), HumanError.generic);
    });

    test('a rate limit and a refused build get their own words (#400)', () {
      expect(
        HumanError.of(
          _dio(type: DioExceptionType.badResponse, statusCode: 429),
        ),
        HumanError.tooManyAttempts,
      );
      expect(
        HumanError.of(
          _dio(type: DioExceptionType.badResponse, statusCode: 426),
        ),
        HumanError.updateRequired,
      );
      expect(
        HumanError.tooManyAttempts.message(),
        'Too many attempts. Wait a few minutes, then try again.',
      );
      expect(
        HumanError.updateRequired.message(af),
        'Hierdie weergawe van die toep is te oud. Dateer TradeIQ op om voort '
        'te gaan.',
      );
    });

    test('each code maps to its English and Afrikaans copy', () {
      expect(
        HumanError.sessionExpired.message(),
        'Your session has expired. Please sign in again.',
      );
      expect(
        HumanError.sessionExpired.message(af),
        'Jou sessie het verval. Teken asseblief weer in.',
      );
      expect(
        HumanError.unreachable.message(englishLocalizations),
        'Could not reach the server. Check your connection and try again.',
      );
      expect(
        HumanError.unreachable.message(af),
        'Kon nie die bediener bereik nie. Kyk of jy verbinding het en probeer '
        'weer.',
      );
      expect(
        HumanError.generic.message(af),
        'Iets het fout gegaan. Probeer asseblief weer.',
      );
      expect(
        humanErrorMessage(_dio(type: DioExceptionType.connectionError), af),
        HumanError.unreachable.message(af),
      );
    });

    // REMOVED WITH `AsyncSection`. The case it guarded was that the console's
    // shared error surface kept its English copy on an Afrikaans device,
    // because it called `humanErrorMessage` without an `AppLocalizations`.
    // That is no longer the product's position — the manager console is fully
    // Afrikaans, and every migrated surface reports a failure through
    // `TorchErrorMessage.sanitise`, which its caller localises. The helper's
    // own Afrikaans behaviour is still asserted directly above.
  });
}
