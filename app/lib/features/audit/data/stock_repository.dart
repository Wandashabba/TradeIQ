import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One captured stock line for a SKU during a visit. daysOutOfStock,
/// velocityAvg, salesActual, and salesTarget are no longer agent input —
/// the server computes the first two and there is no source for the other
/// two yet (#112).
class StockEntry {
  const StockEntry({
    required this.skuId,
    required this.unitsAvailable,
    required this.lastStockinDate,
  });
  final String skuId;
  final int unitsAvailable;
  final DateTime lastStockinDate;

  Map<String, dynamic> toJson() => {
    'skuId': skuId,
    'unitsAvailable': unitsAvailable,
    'lastStockinDate': lastStockinDate.toUtc().toIso8601String(),
  };
}

abstract class StockRepository {
  Future<void> saveStock({
    required String visitDraftId,
    required List<StockEntry> entries,
  });
}

class DriftStockRepository implements StockRepository {
  DriftStockRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveStock({
    required String visitDraftId,
    required List<StockEntry> entries,
  }) async {
    final batchId = _uuid.v4();
    await db.transaction(() async {
      for (final entry in entries) {
        await db
            .into(db.stockDrafts)
            .insert(
              StockDraftsCompanion.insert(
                id: _uuid.v4(),
                visitDraftId: visitDraftId,
                skuId: entry.skuId,
                unitsAvailable: entry.unitsAvailable,
                lastStockinDate: entry.lastStockinDate,
              ),
            );
      }
      await db.enqueue(
        entityType: 'stock',
        entityId: batchId,
        payloadJson: jsonEncode({
          'visitDraftId': visitDraftId,
          'items': entries.map((e) => e.toJson()).toList(),
        }),
      );
    });

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: rows are persisted and queued for the next flush.
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => DriftStockRepository(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);
