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
@DriftDatabase(tables: [VisitDrafts, StockDrafts, SyncQueueItems])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

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

extension LocalDbSyncQueue on LocalDb {
  /// Queues a mutation for the sync service, stamped with its owner.
  ///
  /// The single write path into the outbox, on purpose. Twelve call sites
  /// constructing companions by hand is twelve chances to omit the owner, and
  /// an unowned row is one that will never send.
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
      ),
    );
  }
}

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
