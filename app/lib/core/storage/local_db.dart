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
@DriftDatabase(tables: [VisitDrafts, SyncQueueItems, StockDrafts])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  static QueryExecutor _openConnection() => openDbConnection();
}

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
