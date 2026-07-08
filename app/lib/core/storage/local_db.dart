import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(visitDrafts, visitDrafts.remoteId);
            await m.createTable(stockDrafts);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'tradeiq_local.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
