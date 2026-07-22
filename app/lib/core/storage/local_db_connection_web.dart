// The legacy drift web API is enough for a volatile database; migrating to
// package:drift/wasm.dart needs bundled sqlite3.wasm/worker assets and is
// tracked separately.
// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// The web build's local database — in memory, and deliberately so.
///
/// #140 (M15) filed this as data loss: a browser refresh mid-visit discards
/// queued captures. That is true, and it is still the right trade.
///
/// Persisting to IndexedDB would *add* an exposure rather than remove one. The
/// native database is encrypted at rest with SQLCipher (#138), keyed from the
/// platform keystore — a browser has no equivalent, so an IndexedDB copy would
/// be plaintext GPS trails and base64 shelf photos sitting in a profile that
/// is far more likely to be shared than a phone is.
///
/// And the loss it prevents is close to theoretical: capture is a field-agent
/// flow and agents are on mobile. Web is the manager console, which reads. If
/// that ever stops being true — if agents genuinely capture on web — this
/// decision must be revisited *with* an answer for encryption, not without one.
///
/// This pairs with [InMemoryTokenStore]: the web build persists nothing, on
/// purpose. One rule, not two exceptions.
QueryExecutor openDbConnection() {
  return WebDatabase.withStorage(DriftWebStorage.volatile());
}
