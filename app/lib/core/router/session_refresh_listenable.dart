import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../network/app_version.dart';

/// Bridges Riverpod session-state changes into a [Listenable] that
/// GoRouter's `refreshListenable` can watch, so `redirect` re-runs whenever
/// [sessionControllerProvider] changes (e.g. after login/logout), not just
/// on navigation — and whenever [appUpdateRequired] changes.
class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
    // And when the server refuses this build, or the refusal is cleared, so
    // the redirect can send every route to /update-required and back (#400).
    appUpdateRequired.addListener(notifyListeners);
    ref.onDispose(() => appUpdateRequired.removeListener(notifyListeners));
  }
}

final sessionRefreshListenableProvider = Provider<SessionRefreshListenable>((
  ref,
) {
  return SessionRefreshListenable(ref);
});
