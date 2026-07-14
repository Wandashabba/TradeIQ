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
  int get schemaVersion => 5;

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
        },
      );

  static QueryExecutor _openConnection() => openDbConnection();
}

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
