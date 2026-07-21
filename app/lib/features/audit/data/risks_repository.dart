import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// One S8 flagged risk for a visit. Severity is one of
/// 'critical' | 'high' | 'normal'.
class RiskEntry {
  const RiskEntry({
    required this.flagType,
    required this.severity,
    required this.note,
  });
  final String flagType;
  final String severity;
  final String note;

  Map<String, dynamic> toJson() => {
    'flagType': flagType,
    'severity': severity,
    'note': note,
  };
}

abstract class RisksRepository {
  Future<void> saveRisks({
    required String visitDraftId,
    required List<RiskEntry> entries,
  });
}

class DriftRisksRepository implements RisksRepository {
  DriftRisksRepository({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  @override
  Future<void> saveRisks({
    required String visitDraftId,
    required List<RiskEntry> entries,
  }) async {
    await db.enqueue(
      entityType: 'risk',
      entityId: _uuid.v4(),
      payloadJson: jsonEncode({
        'visitDraftId': visitDraftId,
        'risks': entries.map((e) => e.toJson()).toList(),
      }),
    );

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the capture is queued and retried on the next flush.
    }
  }
}

final risksRepositoryProvider = Provider<RisksRepository>(
  (ref) => DriftRisksRepository(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);
