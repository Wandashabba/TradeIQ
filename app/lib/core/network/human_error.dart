import 'package:dio/dio.dart';

/// Maps a failed request to copy a person can act on.
///
/// Never show a raw [DioException]: its toString is a multi-line dump with a
/// SocketException and the server's hostname, and offline is the *expected*
/// state for a field agent, not an incident to be reported in stack-trace
/// form. Every generic error surface (AsyncSection, panels) should route
/// through here so the whole console speaks with one voice.
String humanErrorMessage(Object error) {
  if (error is DioException) {
    // A 401 on an authenticated request means the 12h token expired — the
    // interceptor in api_client.dart is already signing the user out, so the
    // honest copy is "your session ended", not "invalid credentials". The
    // login screen, where a 401 *does* mean bad credentials, keeps its own
    // wording (see loginErrorMessage).
    if (error.response?.statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Could not reach the server. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  // Non-Dio errors (parsing bugs, programmer errors) get the same generic
  // line: the details belong in a log, not on an agent's phone.
  return 'Something went wrong. Please try again.';
}
