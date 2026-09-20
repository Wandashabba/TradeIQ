import 'package:drift/drift.dart';

/// The client's audit template as it stood when a visit started (#122).
///
/// A client can add its own questions to the audit as an extra section after
/// S1–S10. The template is pinned to the visit once, at check-in, so the
/// questions cannot change under an agent mid-visit, reopening the section
/// after the app is killed needs no signal, and the answers can say which
/// version they were given against.
///
/// A row with a null [templateId] records that the client used no template
/// when the visit started. The newest row for the signed-in agent is also the
/// offline fallback for a visit started with no signal.
@DataClassName('PinnedVisitTemplate')
class PinnedVisitTemplates extends Table {
  TextColumn get visitDraftId => text()();
  TextColumn get templateId => text().nullable()();
  TextColumn get templateName => text().nullable()();
  IntColumn get templateVersion => integer().nullable()();

  /// The template's `schema`, JSON-encoded exactly as the server sent it.
  TextColumn get schemaJson => text().nullable()();

  /// Who the template was fetched for, so a shared device never offers one
  /// agent's client questions to another agent offline.
  TextColumn get userId => text().nullable()();
  DateTimeColumn get pinnedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {visitDraftId};
}

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

  /// Units on the shelf, or NULL when this SKU was never counted (#389).
  ///
  /// NULL and 0 are different findings and must stay different: 0 is an agent
  /// standing at an empty shelf, and it raises a stock-out task and drags
  /// on-shelf availability down. NULL is a SKU the agent has not reached, and
  /// it must do neither — it leaves every ratio's denominator instead.
  ///
  /// It used to be NOT NULL, and the capture screen coerced an untyped field to
  /// 0, so every shelf the agent had not reached yet was reported as out of
  /// stock. The column has to allow null before the screen can stop lying.
  IntColumn get unitsAvailable => integer().nullable()();
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

  /// Who queued this, from the `userId` claim of their token.
  ///
  /// Field devices get shared. Without this the flusher sent every unsynced
  /// row under whichever token happened to be current, so agent B logging in
  /// after agent A would push A's captures to the server as their own — a
  /// disclosure and an attribution bug at once, feeding scorecards and fraud
  /// signals with work the named agent never did.
  ///
  /// Nullable only because rows queued before this column existed cannot have
  /// their owner recovered. Those are deliberately never flushed: guessing an
  /// owner is precisely the bug being fixed here.
  TextColumn get userId => text().nullable()();

  /// How many bytes of real payload this row is holding — the DECODED size
  /// (#382).
  ///
  /// The outbox is the one place that knows why a phone's storage is filling
  /// up, and nothing could say it: a sync screen could count rows, but a row is
  /// either a 200-byte stock batch or a multi-megabyte photo, and counting them
  /// tells an agent nothing about which is which.
  ///
  /// It is the decoded size, not `payloadJson.length`, because a photo payload
  /// is a base64 data URL inside the JSON and base64 inflates by 4/3. Reporting
  /// the encoded length would overstate every photo row by a third — see
  /// `decodedPayloadBytes` in local_db.dart, and the same encoded-vs-decoded
  /// distinction in the backend's `photos/thumbnails.ts`.
  ///
  /// Nullable, and deliberately NOT backfilled: rows queued before this column
  /// existed have never been measured, and `length(payload_json)` is precisely
  /// the wrong number to guess them with. Null means unmeasured; it must never
  /// read as an empty payload.
  IntColumn get payloadBytes => integer().nullable()();
}
