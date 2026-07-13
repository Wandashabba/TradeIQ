import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One captured S6 competitive-intelligence line during a visit.
class CompetitiveEntry {
  const CompetitiveEntry({
    required this.competitorSku,
    required this.competitorPrice,
    required this.competitorPosmType,
    required this.competitorPromoterPresent,
    this.facingsCount = 1,
  });
  final String competitorSku;
  final double competitorPrice;
  final String competitorPosmType;
  final bool competitorPromoterPresent;

  /// How many facings this competitor holds.
  ///
  /// Share of shelf used to count each captured ROW as one facing, so a
  /// competitor with a whole shelf counted the same as one with a single can
  /// (#93). Defaults to 1, which reproduces that old behaviour for a caller that
  /// does not supply it.
  final int facingsCount;

  Map<String, dynamic> toJson() => {
        'competitorSku': competitorSku,
        'competitorPrice': competitorPrice,
        'competitorPosmType': competitorPosmType,
        'competitorPromoterPresent': competitorPromoterPresent,
        'facingsCount': facingsCount,
        // Phase-1: empty geotag object — the check-in GPS is the visit-level geotag.
        'geotag': const <String, double>{},
      };
}

abstract class CompetitiveRepository {
  Future<void> saveCompetitive({required String visitDraftId, required List<CompetitiveEntry> entries});
}

class DriftCompetitiveRepository implements CompetitiveRepository {
  DriftCompetitiveRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveCompetitive({required String visitDraftId, required List<CompetitiveEntry> entries}) async {
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'competitive',
          entityId: _uuid.v4(),
          payloadJson: jsonEncode({
            'visitDraftId': visitDraftId,
            'items': entries.map((e) => e.toJson()).toList(),
          }),
        ));

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the capture is queued and retried on the next flush.
    }
  }
}

final competitiveRepositoryProvider = Provider<CompetitiveRepository>((ref) => DriftCompetitiveRepository(
      db: ref.read(localDbProvider),
      syncService: ref.read(syncServiceProvider),
    ));
