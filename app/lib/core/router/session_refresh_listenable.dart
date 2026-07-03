import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';

/// Bridges Riverpod session-state changes into a [Listenable] that
/// GoRouter's `refreshListenable` can watch, so `redirect` re-runs whenever
/// [sessionControllerProvider] changes (e.g. after login/logout), not just
/// on navigation.
class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

final sessionRefreshListenableProvider = Provider<SessionRefreshListenable>((ref) {
  return SessionRefreshListenable(ref);
});
