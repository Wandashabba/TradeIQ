import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One captured S5 pricing/promotions line for a SKU during a visit.
class PricingEntry {
  const PricingEntry({
    required this.skuId,
    required this.priceActual,
    required this.promoActive,
    required this.promoMaterialsDetected,
    required this.commsRating,
  });
  final String skuId;
  final double priceActual;
  final bool promoActive;
  final Map<String, bool> promoMaterialsDetected;
  final int commsRating;

  Map<String, dynamic> toJson() => {
    'skuId': skuId,
    'priceActual': priceActual,
    'promoActive': promoActive,
    'promoMaterialsDetected': promoMaterialsDetected,
    'commsRating': commsRating,
  };
}

abstract class PricingRepository {
  Future<void> savePricing({
    required String visitDraftId,
    required List<PricingEntry> entries,
  });
}

class DriftPricingRepository implements PricingRepository {
  DriftPricingRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> savePricing({
    required String visitDraftId,
    required List<PricingEntry> entries,
  }) async {
    await db.enqueue(
      entityType: 'pricing',
      entityId: _uuid.v4(),
      payloadJson: jsonEncode({
        'visitDraftId': visitDraftId,
        'items': entries.map((e) => e.toJson()).toList(),
      }),
    );

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the capture is queued and retried on the next flush.
    }
  }
}

final pricingRepositoryProvider = Provider<PricingRepository>(
  (ref) => DriftPricingRepository(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);
