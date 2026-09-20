import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_db_connection.dart';
import 'tables.dart';

part 'local_db.g.dart';

/// The app's offline-first local database.
///
/// Holds in-progress visit drafts ([VisitDrafts]) and the generic outbox of
/// pending mutations ([SyncQueueItems]) that the sync service flushes to the
/// backend once connectivity returns.
@DriftDatabase(
  tables: [VisitDrafts, StockDrafts, SyncQueueItems, PinnedVisitTemplates],
)
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(visitDrafts, visitDrafts.remoteId);
          }
          if (from < 4) {
            // Pre-merge lineages carried StockDrafts with different column
            // sets (visitId vs visitDraftId) — recreate it in the merged
            // shape; draft rows are re-capturable, so the drop is safe.
            await customStatement('DROP TABLE IF EXISTS stock_drafts');
            await m.createTable(stockDrafts);
          }
          if (from < 5) {
            // Additive — an agent mid-visit keeps every queued capture.
            await m.addColumn(syncQueueItems, syncQueueItems.attempts);
            await m.addColumn(syncQueueItems, syncQueueItems.lastError);
            await m.addColumn(syncQueueItems, syncQueueItems.lastAttemptAt);
          }
          if (from < 7) {
            // Additive, and deliberately left NULL for existing rows. Their
            // owner is unrecoverable, and backfilling them to whoever happens
            // to migrate the database would recreate the exact bug this column
            // exists to prevent. Unowned rows are never flushed.
            await m.addColumn(syncQueueItems, syncQueueItems.userId);
          }
          if (from < 8) {
            // Additive: the client's audit template pinned per visit (#122).
            // A visit already in progress has no pin and simply shows no
            // client-questions section.
            await m.createTable(pinnedVisitTemplates);
          }
          if (from < 9) {
            // Additive, and left NULL for existing rows on purpose (#382). A
            // row queued before this column has never had its payload measured,
            // and backfilling it from `length(payload_json)` would record the
            // ENCODED length — the one number this column exists not to be.
            await m.addColumn(syncQueueItems, syncQueueItems.payloadBytes);
            // Widening, not dropping: `units_available` becomes nullable so an
            // uncounted SKU can be submitted as null instead of being coerced
            // to 0 and reported as an empty shelf (#389). alterTable recreates
            // the table and carries every in-progress count across — an agent
            // mid-visit must not lose a morning's work to an app update.
            await m.alterTable(TableMigration(stockDrafts));
          }
        },
      );

  static QueryExecutor _openConnection() => openDbConnection();
}

/// The user whose captures are currently being queued, from the `userId` claim
/// of their token. Set by the session controller on login and restore, cleared
/// on logout.
///
/// A global for the same reason `currentAuthToken` is one: the outbox is
/// written from a dozen repositories that have no business each being handed a
/// session, and threading one through them all would guarantee that some future
/// insert forgets. Stamping it in [LocalDbSyncQueue.enqueue] means an unowned
/// row can only be a pre-migration one.
String? currentLocalUserId;

/// `data:<mime>;base64,<payload>` as it appears inside an outbox row's JSON.
///
/// The JSON string it lives in cannot itself contain a raw `"` or `\`, and
/// base64 uses none of the characters that would end the match early, so this
/// finds the whole encoded payload and nothing after it.
final _base64DataUrl = RegExp(r'data:[^;"\\]+;base64,([A-Za-z0-9+/=]+)');

/// How many bytes of real payload a queued row is holding (#382).
///
/// `utf8.encode(payloadJson).length` is the size of the row as stored, and for
/// everything except a photo that IS the payload. A photo is different: it is a
/// base64 data URL inside the JSON, and base64 inflates by 4/3, so the stored
/// length overstates the image by a third. A 3 MB photo would be reported as
/// 4 MB, and an agent told to clear 4 MB of queue would free 3.
///
/// The simplest implementation that is actually correct: take the row's real
/// UTF-8 byte length, then for each embedded base64 payload subtract the
/// encoding overhead — the difference between its encoded length and the bytes
/// it decodes to. Nothing is decoded and no multi-megabyte buffer is allocated;
/// the decoded size of base64 is arithmetic on its length and padding. The
/// alternative — decoding every data URL to measure it — doubles the memory of
/// every photo enqueue on a phone, to learn a number the length already knows.
///
/// The backend draws the same encoded-vs-decoded distinction, for the same
/// reason, in `photos/thumbnails.ts`.
int decodedPayloadBytes(String payloadJson) {
  var bytes = utf8.encode(payloadJson).length;
  for (final match in _base64DataUrl.allMatches(payloadJson)) {
    final encoded = match.group(1)!;
    bytes -= encoded.length - _decodedBase64Length(encoded);
  }
  // A malformed payload must never report a negative size; "nothing measurable"
  // is 0 bytes, which is honest for a row holding no payload at all.
  return bytes < 0 ? 0 : bytes;
}

/// Bytes a base64 string decodes to, from its length and padding alone.
int _decodedBase64Length(String encoded) {
  var padding = 0;
  while (padding < 2 && padding < encoded.length && encoded[encoded.length - 1 - padding] == '=') {
    padding += 1;
  }
  // Well-formed base64 is a multiple of 4. Anything else is not ours to repair,
  // so fall back to the ratio rather than inventing padding that is not there.
  if (encoded.length % 4 != 0) return (encoded.length * 3) ~/ 4;
  return (encoded.length ~/ 4) * 3 - padding;
}

extension LocalDbSyncQueue on LocalDb {
  /// Queues a mutation for the sync service, stamped with its owner and its
  /// decoded size.
  ///
  /// The single write path into the outbox, on purpose. Twelve call sites
  /// constructing companions by hand is twelve chances to omit the owner, and
  /// an unowned row is one that will never send. Measuring the payload here for
  /// the same reason: a size computed at twelve call sites is a size that is
  /// wrong at one of them.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String payloadJson,
  }) {
    return into(syncQueueItems).insert(
      SyncQueueItemsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        payloadJson: payloadJson,
        userId: Value(currentLocalUserId),
        payloadBytes: Value(decodedPayloadBytes(payloadJson)),
      ),
    );
  }
}

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
