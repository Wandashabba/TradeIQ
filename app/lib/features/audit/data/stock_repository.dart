import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// Offline-first repository for per-SKU stock/availability observations
/// captured during S2 of an audit visit.
///
/// Mirrors [DriftVisitsRepository]'s pattern from S1: write locally, enqueue
/// a sync item, then best-effort flush — but simpler, since there's no
/// geofence/location step here, so [recordStock] just returns `Future<void>`.
abstract class StockRepository {
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  });
}

class DriftStockRepository implements StockRepository {
  DriftStockRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;

  static const _uuid = Uuid();

  @override
  Future<void> recordStock({
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
  }) async {
    final id = _uuid.v4();
    await db.transaction(() async {
      await db.into(db.stockDrafts).insert(StockDraftsCompanion.insert(
            id: id,
            visitId: visitId,
            skuId: skuId,
            unitsAvailable: unitsAvailable,
            lastStockinDate: lastStockinDate,
            daysOutOfStock: daysOutOfStock,
            velocityAvg: velocityAvg,
            salesActual: salesActual,
            salesTarget: salesTarget,
          ));
      await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
            entityType: 'stock',
            entityId: id,
            payloadJson: jsonEncode({
              'visitId': visitId,
              'skuId': skuId,
              'unitsAvailable': unitsAvailable,
              'lastStockinDate': lastStockinDate.toIso8601String(),
              'daysOutOfStock': daysOutOfStock,
              'velocityAvg': velocityAvg,
              'salesActual': salesActual,
              'salesTarget': salesTarget,
            }),
          ));
    });

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the entry is already saved locally and queued; a
      // failed flush just means it stays queued for the next attempt.
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) => DriftStockRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));
