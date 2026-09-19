import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// The outcome of any password change (#400).
///
/// [otherSessionsEnded] is what the server said, not what the app hopes. Today
/// it is always false: tokens are stateless 12h JWTs and nothing on the server
/// can revoke one early, so every screen that changes a password says so.
class PasswordChanged {
  const PasswordChanged({required this.otherSessionsEnded});
  final bool otherSessionsEnded;

  factory PasswordChanged.fromJson(Object? json) => PasswordChanged(
    otherSessionsEnded: json is Map && json['otherSessionsEnded'] == true,
  );
}

/// A one-time reset code, as returned to the manager who generated it.
///
/// This object is the only place the plaintext exists on the phone. It is held
/// in the generating screen's state and nowhere else — never persisted, never
/// logged, never put in a provider another screen could read.
class IssuedResetCode {
  const IssuedResetCode({
    required this.code,
    required this.expiresAt,
    required this.email,
  });

  final String code;
  final DateTime expiresAt;

  /// Who it is for, so the manager can check they picked the right person.
  final String email;

  factory IssuedResetCode.fromJson(Map<String, dynamic> json) =>
      IssuedResetCode(
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        email: json['email'] as String,
      );

  /// Never the code. A debug print or an error report that stringifies this
  /// object must not carry the secret with it.
  @override
  String toString() => 'IssuedResetCode(for: $email, expires: $expiresAt)';
}

/// Why a password request was refused, in the kinds a screen words
/// differently. Anything else is rethrown as the original [DioException] and
/// worded by `humanErrorMessage`.
enum PasswordRefusal {
  /// Change-password: the current password was wrong. The session is intact.
  wrongCurrentPassword,

  /// Reset: the code (or the email it was paired with) did not work. One
  /// answer for every cause, exactly as the server gives it.
  codeRejected,

  /// A 400: the new password breaks the rule.
  passwordRejected,

  /// A 403 on a staff action: this role may not reset this user (a manager
  /// may reset field agents only).
  notPermitted,

  /// A 404 on a staff action: no such user in this organisation.
  notFound,
}

class PasswordRefused implements Exception {
  const PasswordRefused(this.reason);
  final PasswordRefusal reason;

  @override
  String toString() => 'PasswordRefused($reason)';
}

/// Every way a password is set, from the app (#400).
abstract class PasswordRepository {
  /// POST /auth/change-password — the signed-in user's own.
  Future<PasswordChanged> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// POST /auth/reset-password — redeem a manager's code, signed out.
  Future<PasswordChanged> redeemResetCode({
    required String email,
    required String code,
    required String newPassword,
  });

  /// POST /users/:id/password-reset-code — a manager or admin, for someone
  /// in the field.
  Future<IssuedResetCode> issueResetCode(String userId);

  /// POST /users/:id/password — a manager or admin sets it directly.
  Future<PasswordChanged> setPasswordFor(String userId, String newPassword);
}

class DioPasswordRepository implements PasswordRepository {
  @override
  Future<PasswordChanged> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _refusable(() async {
    final response = await dio.post(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    return PasswordChanged.fromJson(response.data);
  });

  @override
  Future<PasswordChanged> redeemResetCode({
    required String email,
    required String code,
    required String newPassword,
  }) => _refusable(() async {
    final response = await dio.post(
      '/auth/reset-password',
      data: {
        // Normalised the way the login screen sends it (#351); the server
        // normalises too.
        'email': email.trim().toLowerCase(),
        // Spaces and hyphens are the server's to strip, so "4821 7390" read
        // out in two halves works however it was typed.
        'code': code,
        'newPassword': newPassword,
      },
    );
    return PasswordChanged.fromJson(response.data);
  });

  @override
  Future<IssuedResetCode> issueResetCode(String userId) => _refusable(() async {
    final response = await dio.post(
      '/users/${Uri.encodeComponent(userId)}/password-reset-code',
    );
    return IssuedResetCode.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<PasswordChanged> setPasswordFor(String userId, String newPassword) =>
      _refusable(() async {
        final response = await dio.post(
          '/users/${Uri.encodeComponent(userId)}/password',
          data: {'newPassword': newPassword},
        );
        return PasswordChanged.fromJson(response.data);
      });

  Future<T> _refusable<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final refusal = passwordRefusalOf(e);
      if (refusal != null) throw PasswordRefused(refusal);
      rethrow;
    }
  }
}

/// The refusal a password request's failure represents, or null when it is
/// some other failure (offline, 429, 5xx) for the shared error copy.
///
/// Matches the server's `code`, never its prose. A 401 WITHOUT one of the two
/// codes is an expired session, left to the interceptor and the shared copy.
PasswordRefusal? passwordRefusalOf(DioException error) {
  final status = error.response?.statusCode;
  final body = error.response?.data;
  final code = body is Map ? body['code'] : null;
  if (status == 401 && code == 'current_password_incorrect') {
    return PasswordRefusal.wrongCurrentPassword;
  }
  if (status == 401 && code == 'reset_code_invalid') {
    return PasswordRefusal.codeRejected;
  }
  if (status == 400) return PasswordRefusal.passwordRejected;
  if (status == 403) return PasswordRefusal.notPermitted;
  if (status == 404) return PasswordRefusal.notFound;
  return null;
}

final passwordRepositoryProvider = Provider<PasswordRepository>(
  (ref) => DioPasswordRepository(),
);
