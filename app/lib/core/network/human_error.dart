import 'package:dio/dio.dart';

import '../../l10n/l10n.dart';

/// What went wrong with a request, in the three kinds a person can act on.
///
/// A code rather than a sentence, so a layer with no [BuildContext] (a
/// repository returning a result) can say *what* failed and leave the wording
/// to the screen that shows it, in the agent's language — see [message].
enum HumanError {
  /// A 401 on an authenticated request: the session token expired.
  sessionExpired,

  /// The server could not be reached — offline, or a connect/send/receive
  /// timeout.
  unreachable,

  /// Anything else: a server error, a parsing bug, a programmer error.
  generic;

  /// Classifies [error].
  static HumanError of(Object error) {
    if (error is DioException) {
      // A 401 on an authenticated request means the 12h token expired — the
      // interceptor in api_client.dart is already signing the user out, so the
      // honest copy is "your session ended", not "invalid credentials". The
      // login screen, where a 401 *does* mean bad credentials, keeps its own
      // wording (see loginErrorMessage).
      if (error.response?.statusCode == 401) return HumanError.sessionExpired;
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return HumanError.unreachable;
        default:
          return HumanError.generic;
      }
    }
    // Non-Dio errors (parsing bugs, programmer errors) get the same generic
    // line: the details belong in a log, not on an agent's phone.
    return HumanError.generic;
  }

  /// The copy for this error in [l10n]'s language — English when omitted, which
  /// is what the (not yet localised) manager console gets.
  String message([AppLocalizations? l10n]) {
    final l = l10n ?? englishLocalizations;
    return switch (this) {
      HumanError.sessionExpired => l.errorSessionExpired,
      HumanError.unreachable => l.errorUnreachable,
      HumanError.generic => l.errorGeneric,
    };
  }
}

/// Maps a failed request to copy a person can act on.
///
/// Never show a raw [DioException]: its toString is a multi-line dump with a
/// SocketException and the server's hostname, and offline is the *expected*
/// state for a field agent, not an incident to be reported in stack-trace
/// form. Every generic error surface (AsyncSection, panels) should route
/// through here so the whole console speaks with one voice.
///
/// Pass the active [l10n] (`context.l10n`) on agent screens; without it the
/// English copy is used (the manager console is not localised yet).
String humanErrorMessage(Object error, [AppLocalizations? l10n]) =>
    HumanError.of(error).message(l10n);
