import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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

  /// Units on the shelf, or null when this SKU was never counted (#389).
  ///
  /// Null and 0 are different findings and travel to the server as different
  /// findings. 0 is an agent standing at an empty shelf: it raises a stock-out
  /// task and drags on-shelf availability down. Null is a SKU the agent has not
  /// reached, and it does neither — the server drops it from the ratio's
  /// denominator entirely.
  ///
  /// It used to be a non-null `int`, and the capture screen filled every
  /// untouched field with 0, so a half-finished count accused the store of
  /// being out of stock on every shelf the agent had not walked to yet.
  final int? unitsAvailable;
  final DateTime lastStockinDate;

  /// The `POST /stock` item shape. An uncounted SKU is sent as an explicit
  /// `null` rather than omitted: the server reads both the same way, and a
  /// present null says "we looked and there is no count" instead of leaving the
  /// reader to guess whether the field was dropped by an old client.
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
                unitsAvailable: Value(entry.unitsAvailable),
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
