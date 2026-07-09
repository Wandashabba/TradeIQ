import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One captured stock line for a SKU during a visit.
class StockEntry {
  const StockEntry({
    required this.skuId,
    required this.unitsAvailable,
    required this.lastStockinDate,
    required this.daysOutOfStock,
    required this.velocityAvg,
    required this.salesActual,
    required this.salesTarget,
  });
  final String skuId;
  final int unitsAvailable;
  final DateTime lastStockinDate;
  final int daysOutOfStock;
  final double velocityAvg;
  final double salesActual;
  final double salesTarget;

  Map<String, dynamic> toJson() => {
        'skuId': skuId,
        'unitsAvailable': unitsAvailable,
        'lastStockinDate': lastStockinDate.toUtc().toIso8601String(),
        'daysOutOfStock': daysOutOfStock,
        'velocityAvg': velocityAvg,
        'salesActual': salesActual,
        'salesTarget': salesTarget,
      };
}

abstract class StockRepository {
  Future<void> saveStock({required String visitDraftId, required List<StockEntry> entries});
}

class DriftStockRepository implements StockRepository {
  DriftStockRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveStock({required String visitDraftId, required List<StockEntry> entries}) async {
    final batchId = _uuid.v4();
    await db.transaction(() async {
      for (final entry in entries) {
        await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
              id: _uuid.v4(),
              visitDraftId: visitDraftId,
              skuId: entry.skuId,
              unitsAvailable: entry.unitsAvailable,
              lastStockinDate: entry.lastStockinDate,
              daysOutOfStock: entry.daysOutOfStock,
              velocityAvg: entry.velocityAvg,
              salesActual: entry.salesActual,
              salesTarget: entry.salesTarget,
            ));
      }
      await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
            entityType: 'stock',
            entityId: batchId,
            payloadJson: jsonEncode({
              'visitDraftId': visitDraftId,
              'items': entries.map((e) => e.toJson()).toList(),
            }),
          ));
    });

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: rows are persisted and queued for the next flush.
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) => DriftStockRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));
