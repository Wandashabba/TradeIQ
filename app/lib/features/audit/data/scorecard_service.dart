import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

/// Default dimension weights, mirrors the seed Client.scorecardWeights;
/// per-client weights come from the server-side scorecard which is
/// authoritative.
const Map<String, double> kScorecardWeights = {
  'availability': 0.3,
  'visibility': 0.25,
  'display': 0.15,
  'pricing': 0.1,
  'competitive': 0.1,
  'salesCapability': 0.1,
};

/// The offline scorecard computed on-device from the local sync queue, so the
/// agent sees the score before leaving the outlet (ADR 0005).
class LocalScorecard {
  const LocalScorecard({
    required this.dimensionScores,
    required this.weightedTotal,
    required this.ratingBand,
  });
  final Map<String, double> dimensionScores;
  final double weightedTotal;
  final String ratingBand;
}

/// Local, offline scorecard computation per ADR 0005: the agent sees the score
/// before leaving the outlet, no network. The server-side scorecard remains
/// authoritative and is recomputed from the persisted rows on sync.
class ScorecardService {
  ScorecardService({required this.db, required this.syncService});

  final LocalDb db;
  final SyncService syncService;
  static const _uuid = Uuid();

  Future<LocalScorecard> computeForVisit(String visitDraftId) async {
    final rows = await db.select(db.syncQueueItems).get();
    final payloadsByType = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      if (payload['visitDraftId'] != visitDraftId) continue;
      payloadsByType.putIfAbsent(row.entityType, () => []).add(payload);
    }

    final dimensions = <String, double>{
      'availability': _availability(payloadsByType['stock'] ?? const []),
      ..._visibilityAndDisplay(payloadsByType['visibility'] ?? const []),
      // Pricing needs deviation vs RRP, which the client doesn't know —
      // Phase-1 local proxy: 100 if any pricing items were captured, else 0
      // (the server-side scorecard computes the true deviation-based score).
      'pricing': _anyItemsCaptured(payloadsByType['pricing'] ?? const [])
          ? 100
          : 0,
      'salesCapability': _salesCapability(
        payloadsByType['capability'] ?? const [],
      ),
    };

    // Competitive is our share of shelf, mirroring the server (#93). It used to
    // be "captured anything at all → 100", which scored data entry rather than
    // the store. When there is nothing to measure it against the dimension is
    // UNKNOWN: omitted here and skipped in the weighted total below, so an
    // unmeasurable dimension never silently scores 0 and drags the score down.
    final competitive = _shareOfShelf(
      payloadsByType['visibility'] ?? const [],
      payloadsByType['competitive'] ?? const [],
    );
    if (competitive != null) {
      dimensions['competitive'] = competitive;
    }

    var weightedSum = 0.0;
    var weightSum = 0.0;
    for (final entry in kScorecardWeights.entries) {
      // Normalise by the weights actually used — the remaining dimensions carry
      // the score between them.
      if (!dimensions.containsKey(entry.key)) continue;
      weightedSum += dimensions[entry.key]! * entry.value;
      weightSum += entry.value;
    }
    final total = weightSum == 0
        ? 0.0
        : ((weightedSum / weightSum) * 100).round() / 100;

    return LocalScorecard(
      dimensionScores: dimensions,
      weightedTotal: total,
      // Default thresholds; the server applies per-client kpiThresholds.
      ratingBand: total >= 80 ? 'green' : (total >= 60 ? 'amber' : 'red'),
    );
  }

  /// Our facings vs the competitors' facings, from the queued payloads.
  ///
  /// Returns null when there is nothing to measure — no competitor rows, or no
  /// facings on either side. Null means UNKNOWN, not zero.
  double? _shareOfShelf(
    List<Map<String, dynamic>> visibility,
    List<Map<String, dynamic>> competitive,
  ) {
    final competitorRows = competitive
        .expand((p) => (p['items'] as List? ?? const []))
        .cast<Map<String, dynamic>>()
        .toList();
    if (competitorRows.isEmpty) return null;

    final own = visibility.fold<double>(0, (sum, p) {
      final facings = p['facingsCount'];
      if (facings is Map && facings['total'] is num) {
        return sum + (facings['total'] as num).toDouble();
      }
      return sum;
    });
    final theirs = competitorRows.fold<double>(
      0,
      (sum, row) => sum + ((row['facingsCount'] as num?)?.toDouble() ?? 1),
    );

    final shelf = own + theirs;
    if (shelf <= 0) return null;
    return ((100 * own / shelf) * 100).round() / 100;
  }

  /// Enqueues the finalize marker; the server recomputes the scorecard
  /// authoritatively from the persisted rows.
  Future<void> finalizeScorecard(String visitDraftId) async {
    await db.enqueue(
      entityType: 'scorecard',
      entityId: _uuid.v4(),
      payloadJson: jsonEncode({'visitDraftId': visitDraftId}),
    );

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the finalize is queued and retried on the next flush.
    }
  }

  static double _availability(List<Map<String, dynamic>> stockPayloads) {
    var total = 0;
    var inStock = 0;
    for (final payload in stockPayloads) {
      final items = (payload['items'] as List?) ?? const [];
      for (final item in items) {
        total += 1;
        final units = ((item as Map)['unitsAvailable'] as num?) ?? 0;
        if (units > 0) inStock += 1;
      }
    }
    if (total == 0) return 0;
    return _clamp(100 * inStock / total);
  }

  static Map<String, double> _visibilityAndDisplay(
    List<Map<String, dynamic>> payloads,
  ) {
    if (payloads.isEmpty) return const {'visibility': 0, 'display': 0};
    final payload = payloads.last;
    final planogram = ((payload['planogramCompliancePct'] as num?) ?? 0)
        .toDouble();
    final cleanliness = ((payload['cleanlinessScore'] as num?) ?? 0).toDouble();
    return {
      'visibility': _clamp(planogram),
      'display': _clamp(cleanliness * 20),
    };
  }

  static bool _anyItemsCaptured(List<Map<String, dynamic>> payloads) => payloads
      .any((payload) => ((payload['items'] as List?) ?? const []).isNotEmpty);

  static double _salesCapability(List<Map<String, dynamic>> payloads) {
    if (payloads.isEmpty) return 0;
    final quiz = ((payloads.last['quizScore'] as num?) ?? 0).toDouble();
    return _clamp(quiz);
  }

  static double _clamp(double value) => value.clamp(0, 100).toDouble();
}

final scorecardServiceProvider = Provider<ScorecardService>(
  (ref) => ScorecardService(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);
