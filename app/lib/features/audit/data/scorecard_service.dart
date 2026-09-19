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

  /// A dimension with **nothing captured behind it is ABSENT here, not zero** —
  /// the same rule [ServerScorecard.dimensionScores] states, and for the same
  /// reason: "you scored nothing on this" and "nobody measured this" are
  /// different sentences about a shop, and only one of them is true on a visit
  /// whose sections have not been saved yet.
  final Map<String, double> dimensionScores;

  /// Null when **no** dimension was measured — a visit where nothing has been
  /// captured has no score, and a 0.0 in the Gap band is an accusation the
  /// arithmetic cannot support.
  final double? weightedTotal;

  /// Null with [weightedTotal]: there is no band without a total.
  final String? ratingBand;

  /// Whether anything at all was measured on this visit.
  bool get isMeasured => weightedTotal != null;
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

    // EVERY dimension is UNKNOWN until something is captured behind it — the
    // rule `competitive` has had since #93, now applied to all six. Until this
    // was true, opening Score before capturing anything told the agent the
    // store had scored zero on availability and was in the critical band: a
    // verdict on a shop nobody had measured, from a number that then disagreed
    // with the server's for a reason that was a bug rather than the honest
    // difference in formula `provisional` exists to explain (#390).
    final measured = <String, double?>{
      'availability': _availability(payloadsByType['stock'] ?? const []),
      ..._visibilityAndDisplay(payloadsByType['visibility'] ?? const []),
      // Pricing needs deviation vs RRP, which the client doesn't know —
      // Phase-1 local proxy: 100 if any pricing items were captured, else 0
      // (the server-side scorecard computes the true deviation-based score).
      // Null when the section has not been saved at all: an empty pricing
      // section the agent *did* save is a measured zero, a section they have
      // not reached is not.
      'pricing': (payloadsByType['pricing'] ?? const []).isEmpty
          ? null
          : (_anyItemsCaptured(payloadsByType['pricing']!) ? 100 : 0),
      'salesCapability': _salesCapability(
        payloadsByType['capability'] ?? const [],
      ),
      // Competitive is our share of shelf, mirroring the server (#93). It used
      // to be "captured anything at all → 100", which scored data entry rather
      // than the store.
      'competitive': _shareOfShelf(
        payloadsByType['visibility'] ?? const [],
        payloadsByType['competitive'] ?? const [],
      ),
    };

    final dimensions = <String, double>{
      for (final entry in measured.entries)
        if (entry.value != null) entry.key: entry.value!,
    };

    var weightedSum = 0.0;
    var weightSum = 0.0;
    for (final entry in kScorecardWeights.entries) {
      // Normalise by the weights actually used — the remaining dimensions carry
      // the score between them. An unmeasured dimension is skipped rather than
      // scored 0, so it never drags the total down.
      if (!dimensions.containsKey(entry.key)) continue;
      weightedSum += dimensions[entry.key]! * entry.value;
      weightSum += entry.value;
    }
    // Nothing measured is not a zero. It has no total and therefore no band.
    final total = weightSum == 0
        ? null
        : ((weightedSum / weightSum) * 100).round() / 100;

    return LocalScorecard(
      dimensionScores: dimensions,
      weightedTotal: total,
      // Default thresholds; the server applies per-client kpiThresholds.
      ratingBand: total == null
          ? null
          : (total >= 80 ? 'green' : (total >= 60 ? 'amber' : 'red')),
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

  /// On-shelf availability: 100 * (lines with stock) / (lines that were
  /// COUNTED) — the same rule as the server's `onShelfAvailabilityPct` (#389).
  ///
  /// An uncounted line (`unitsAvailable: null`) leaves the ratio entirely: it
  /// is neither on the shelf nor off it. This used to read `?? 0`, which put
  /// every shelf the agent had not reached into the denominator as an empty
  /// one — so the number the agent saw on the walk out disagreed with the
  /// server's for a reason that was a bug, not the honest difference in formula
  /// that `provisional` exists to explain (#390).
  ///
  /// A denominator of zero is UNKNOWN, not zero: a shelf on which nothing has
  /// been counted has no availability, and rendering that as "0" is the same
  /// lie `?? 0` used to tell one line at a time.
  static double? _availability(List<Map<String, dynamic>> stockPayloads) {
    var counted = 0;
    var inStock = 0;
    for (final payload in stockPayloads) {
      final items = (payload['items'] as List?) ?? const [];
      for (final item in items) {
        final units = (item as Map)['unitsAvailable'] as num?;
        if (units == null) continue;
        counted += 1;
        if (units > 0) inStock += 1;
      }
    }
    if (counted == 0) return null;
    return _clamp(100 * inStock / counted);
  }

  /// Null for both when the visibility section has not been captured — there
  /// is no planogram compliance and no cleanliness score to read.
  static Map<String, double?> _visibilityAndDisplay(
    List<Map<String, dynamic>> payloads,
  ) {
    if (payloads.isEmpty) {
      return const {'visibility': null, 'display': null};
    }
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

  /// Null when the capability section has not been captured: nobody was quizzed
  /// is not a quiz score of zero.
  static double? _salesCapability(List<Map<String, dynamic>> payloads) {
    if (payloads.isEmpty) return null;
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
