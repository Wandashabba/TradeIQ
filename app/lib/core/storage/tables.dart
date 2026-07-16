import 'package:drift/drift.dart';

/// Local mirror of an in-progress (or recently completed) outlet visit.
///
/// This mirrors the subset of the backend `Visit` model relevant to
/// offline-first check-in capture (S1), so a rep can start / continue a
/// visit without connectivity. It is synced to the backend via the
/// [SyncQueueItems] outbox.
class VisitDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get outletId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('in_progress'))();
  DateTimeColumn get checkinTs => dateTime()();
  RealColumn get checkinLat => real()();
  RealColumn get checkinLng => real()();
  BoolColumn get geofencePass => boolean()();

  /// The server-assigned `Visit.id`, populated once the check-in syncs
  /// (POST /visits). Null while the visit is still queued offline. Child
  /// records (e.g. stock) resolve this to reference the real server visit.
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local mirror of captured S2 stock rows awaiting sync. References the local
/// [VisitDrafts] row (`visitDraftId`), not the server visit id; the sync
/// flusher resolves the server id via [VisitDrafts.remoteId] at flush time.
class StockDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get visitDraftId => text()();
  TextColumn get skuId => text()();
  IntColumn get unitsAvailable => integer()();
  DateTimeColumn get lastStockinDate => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Generic outbox of locally-created/mutated entities awaiting sync to the
/// backend. Consumed by the (future) `SyncService` when connectivity
/// returns.
class SyncQueueItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get queuedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// How many times we have tried to send this item, and why the last try
  /// failed.
  ///
  /// The flusher used to swallow every failure silently and retry forever, so
  /// an item that could *never* succeed — a photo the server rejects as too
  /// large, say — looked exactly like one waiting for signal. The agent had no
  /// way to tell "it will send itself" from "this will never send". Recording
  /// the attempt makes the difference visible, which is the whole point of the
  /// sync screen.
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
}
