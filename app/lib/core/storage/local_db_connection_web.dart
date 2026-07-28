// The legacy drift web API is enough for a volatile database; migrating to
// package:drift/wasm.dart needs bundled sqlite3.wasm/worker assets and is
// tracked in #177 — deliberately not scheduled.
//
// The assets are obtainable (sqlite3.wasm from the sqlite3.dart release tagged
// `sqlite3-<version>`, drift_worker.js from drift's own release), so this is a
// choice rather than a blocker.
//
// The reason not to take it — stated precisely, because an earlier version of
// this comment claimed the web surface never opens this connection, and that
// was wrong. It does. `SessionController.logout` calls `_dropSyncedRows`
// unconditionally, with no role check, and its `.go()` is a real query — so a
// manager signing out of the web console opens this database.
//
// What makes that survivable is not that the path is dead, but that it is
// inert: the delete runs against an empty in-memory database (managers never
// capture, so the outbox has no rows) inside a `catch (_)` that swallows
// everything. The capture paths that would give this connection real work —
// `syncStatusProvider`, watched only by `AgentScaffold`, my-work and the submit
// gate — are agent-side, and agents are on mobile.
//
// So: bundling ~1.5MB of WASM into every manager's page load to silence a
// deprecation on a swallowed no-op is still a poor trade. Same conclusion,
// honest reasoning.
//
// Revisit when the premise changes, not on a schedule: if agents ever capture
// on web, this connection carries real data, and #177 should be done at the
// same time as the encryption question below — not before it.
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
