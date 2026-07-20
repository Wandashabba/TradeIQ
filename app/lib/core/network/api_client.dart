import 'package:dio/dio.dart';

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

final dio = Dio(BaseOptions(baseUrl: apiBaseUrl))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = currentAuthToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
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
      final isLoginAttempt =
          error.requestOptions.path.endsWith('/auth/login');
      if (error.response?.statusCode == 401 && !isLoginAttempt) {
        onUnauthorized?.call();
      }
      // Always forwarded: callers still need to see the failure. Signing out is
      // in addition to the error, not instead of it.
      handler.next(error);
    },
  ));
