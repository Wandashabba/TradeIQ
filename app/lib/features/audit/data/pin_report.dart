import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';

/// "THE PIN IS WRONG" — #386.
///
/// An agent standing at the front door of a shop that the app says is 180 m
/// away is telling us something true: the outlet's coordinates are wrong.
/// Today there is nowhere to send that. `POST /outlets/:id/pin-correction`
/// does not exist on the wire, and it is on unify §6 question 7's one backend
/// migration ticket.
///
/// So this records it **on the phone and says so**. The too-far screen's
/// third, quieter action writes the outlet id here and then renders a
/// "Reported on this phone" line — not "Thanks, we'll look into it", which
/// would be a sentence about a server that never heard it. When the endpoint
/// lands, [PinReports.report] gains an enqueue and the copy loses its second
/// half; nothing else on the screen moves.
///
/// It is deliberately **not** in the sync outbox. A queued item for an
/// endpoint that does not exist retries until it is `stuck`, and a stuck row
/// renders as "needs you" — which would turn a helpful report into a chore
/// the agent cannot discharge.
abstract class PinReportStore {
  Future<Set<String>> read();

  Future<void> write(Set<String> outletIds);
}

/// The same `flutter_secure_storage` the theme preference uses. Not a secret,
/// but not worth a second storage stack — and specifically not worth a drift
/// migration for a table that is going to be deleted the week the endpoint
/// lands.
class SecurePinReportStore implements PinReportStore {
  SecurePinReportStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  static const _key = 'tiq.pinReports';

  @override
  Future<Set<String>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return <String>{};
      return raw.split(',').where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      // Unreadable is empty, never a crash on a screen an agent reached
      // because something had already gone wrong.
      return <String>{};
    }
  }

  @override
  Future<void> write(Set<String> outletIds) async {
    try {
      await _storage.write(key: _key, value: outletIds.join(','));
    } catch (e) {
      // Best-effort: an unpersisted report still shows its state for this run.
      debugPrint('Pin report not persisted: $e');
    }
  }
}

final pinReportStoreProvider = Provider<PinReportStore>(
  (ref) => SecurePinReportStore(),
);

/// Outlets whose pin this agent has said is wrong, on this phone.
///
/// A plain [Notifier] over a `Set`, not an `AsyncNotifier`: the screen that
/// reads it is a check-in failure screen, and a second loading state on top of
/// a failure is a screen that cannot say anything at all. It starts empty,
/// fills in when the store answers, and the affordance is live either way —
/// the worst case is that a report made on a previous run is offered again,
/// and [report] is idempotent.
class PinReports extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    unawaited(_load());
    return const <String>{};
  }

  Future<void> _load() async {
    final stored = await ref.read(pinReportStoreProvider).read();
    if (stored.isEmpty) return;
    state = <String>{...state, ...stored};
  }

  /// Records the report and moves the screen to its "reported" state.
  ///
  /// Idempotent: a second tap is not a second report, and the affordance is
  /// gone once the state has changed anyway.
  Future<void> report(String outletId) async {
    if (state.contains(outletId)) return;
    final next = <String>{...state, outletId};
    state = next;
    await ref.read(pinReportStoreProvider).write(next);
  }
}

final pinReportsProvider = NotifierProvider<PinReports, Set<String>>(
  PinReports.new,
);
