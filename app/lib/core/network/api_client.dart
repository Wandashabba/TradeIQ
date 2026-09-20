import 'package:dio/dio.dart';

import 'app_version.dart';

String? currentAuthToken;

/// The backend base URL. Overridable at build/run time with
/// `--dart-define=API_BASE_URL=...` so the same binary can target a local
/// server, an Android emulator (`http://10.0.2.2:4000`), or a deployed
/// environment without a code change. Defaults to the local dev server.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

/// Called when the server rejects our credentials on an authenticated request.
///
/// Wired to the session controller's logout at startup. It is a hook rather
/// than a direct dependency because this file is plain Dio setup with no access
/// to the provider container, and inverting that would drag Riverpod into
/// every test that touches the client.
void Function()? onUnauthorized;

/// Long enough for a rural 2G handshake, short enough that an agent knows the
/// attempt failed rather than watching a spinner.
const _connectTimeout = Duration(seconds: 30);

/// Applies between chunks, not to the whole transfer, so a slow 8 MB shelf
/// photo on a weak signal is not cut off merely for being large — only a
/// connection that has genuinely stopped moving is.
const _transferTimeout = Duration(seconds: 60);

final dio = Dio(BaseOptions(
  baseUrl: apiBaseUrl,
  // Dio's defaults are null, meaning wait forever. On the flaky connectivity
  // this app is built for, that is a request that never returns and a UI that
  // spins until the agent force-quits — losing the queued work they were
  // trying to send. It also left login_screen's timeout messages unreachable:
  // it maps connectionTimeout/sendTimeout/receiveTimeout to a "check your
  // connection" message that could never fire, because none could occur.
  connectTimeout: _connectTimeout,
  receiveTimeout: _transferTimeout,
  sendTimeout: _transferTimeout,
))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = currentAuthToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      // Which build sent this (#400). Before this header the server could not
      // tell which build produced a stuck outbox row, and had no way to turn
      // away a build whose payloads it no longer understands.
      options.headers[appVersionHeader] = appVersion;
      options.headers[appBuildHeader] = appBuild;
      handler.next(options);
    },
    onError: (error, handler) {
      // The backend issues a 12h token and has no refresh endpoint, so expiry
      // is not an edge case — it happens to every user every day. Without this,
      // hour 12:01 leaves the app "logged in" with every screen erroring and
      // nothing offering a way back.
      //
      // A 401 from the login request itself means wrong credentials, not an
      // expired session. Logging out there would clobber the login screen's own
      // error handling and tell the user the wrong story.
      if (endsSession(error)) {
        onUnauthorized?.call();
      }
      // The server has refused this build (#400). A 426 and not a 401, so the
      // session survives: the build is stale, the password is fine.
      final tooOld = AppUpdateRequired.fromError(error);
      if (tooOld != null) appUpdateRequired.value = tooOld;
      // Always forwarded: callers still need to see the failure. Signing out is
      // in addition to the error, not instead of it.
      handler.next(error);
    },
  ));

/// The 401 `code`s that mean "a secret typed into THIS request was wrong", not
/// "your session is over" (#400). Each is one constant per route on the
/// server, shared by every failure there.
const _wrongSecretCodes = {'current_password_incorrect', 'reset_code_invalid'};

/// Whether [error] means the session has ended and the user must sign in again.
///
/// A 401 almost always does: the backend issues a 12h token with no refresh.
/// Three 401s do not, and signing out on them would tell the user the wrong
/// story or throw away the session they were using:
///
/// - `/auth/login` — wrong credentials; the login screen words it itself.
/// - a wrong current password on change-password — the session is fine, and
///   ending it would punish a typo by logging the agent out of their day.
/// - a rejected reset code — the person is signed out already.
bool endsSession(DioException error) {
  final response = error.response;
  if (response?.statusCode != 401) return false;
  if (error.requestOptions.path.endsWith('/auth/login')) return false;
  final body = response?.data;
  if (body is Map && _wrongSecretCodes.contains(body['code'])) return false;
  return true;
}
