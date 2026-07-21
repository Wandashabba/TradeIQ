import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_db.dart';
import 'skus_repository.dart' show skusListProvider;

/// A task this visit will raise for the manager.
///
/// Every one of these is *derived from something the agent captured*. Nothing is
/// invented on this screen, and nothing is added afterwards — which is exactly
/// what the submit gate promises the agent.
class RaisedTask {
  const RaisedTask({
    required this.title,
    required this.reason,
    required this.priority,
  });

  final String title;
  final String reason;

  /// 'critical' | 'high' | 'normal' | 'low' — the server's own priorities.
  final String priority;

  bool get isUrgent => priority == 'critical' || priority == 'high';
}

/// What the agent captured, and what it will do.
class VisitReview {
  const VisitReview({
    required this.skusCounted,
    required this.outOfStock,
    required this.skusPriced,
    required this.competitors,
    required this.photos,
    required this.willRaise,
  });

  final int skusCounted;
  final int outOfStock;
  final int skusPriced;
  final int competitors;
  final int photos;

  /// The tasks the manager will see, in the order they will matter.
  final List<RaisedTask> willRaise;

  /// "12 SKUs counted · 2 competitors · 1 photo" — the visit in one line.
  String get capturedLine {
    final parts = <String>[
      '$skusCounted ${skusCounted == 1 ? 'SKU' : 'SKUs'} counted',
      if (competitors > 0)
        '$competitors ${competitors == 1 ? 'competitor' : 'competitors'}',
      if (photos > 0) '$photos ${photos == 1 ? 'photo' : 'photos'}',
    ];
    return parts.join(' · ');
  }
}

/// Reads the outbox and works out what submitting will actually do.
///
/// The tasks below MIRROR the server's two rules exactly. They are not a guess,
/// and they are not a second opinion:
///
///   * `stock.service.ts` raises one `high` `Restock <sku>` task per SKU with
///     zero units on shelf.
///   * `risks.service.ts` raises one task per risk, at the risk's own severity.
///   * an action-plan task the agent wrote is already a task — it is sent as one.
///
/// If either server rule changes, this must change with it, or the gate starts
/// lying to the agent about what they are about to do.
final visitReviewProvider =
    StreamProvider.family<
      VisitReview,
      ({String visitDraftId, String outletId})
    >((ref, key) {
      final db = ref.read(localDbProvider);
      // SKU names, so a finding reads "Fanta Orange 2L is out of stock" rather than
      // "SKU 4f2c… is out of stock". An agent cannot check a uuid against a shelf.
      final skuNames = ref
          .watch(skusListProvider(key.outletId))
          .maybeWhen(
            data: (list) => {for (final sku in list) sku.id: sku.name},
            orElse: () => <String, String>{},
          );

      return db.select(db.syncQueueItems).watch().map((rows) {
        final payloads = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          final Map<String, dynamic> payload;
          try {
            payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }
          if (payload['visitDraftId'] != key.visitDraftId) continue;
          payloads.putIfAbsent(row.entityType, () => []).add(payload);
        }

        List<Map<String, dynamic>> itemsOf(String type) =>
            (payloads[type] ?? const [])
                .expand((p) => (p['items'] as List? ?? const []))
                .whereType<Map<String, dynamic>>()
                .toList();

        final stock = itemsOf('stock');
        final pricing = itemsOf('pricing');
        final competitive = itemsOf('competitive');
        final risks = (payloads['risk'] ?? const [])
            .expand((p) => (p['risks'] as List? ?? const []))
            .whereType<Map<String, dynamic>>()
            .toList();
        final actionPlan = payloads['task'] ?? const [];

        final stockouts = stock
            .where((i) => (i['unitsAvailable'] as num?) == 0)
            .toList();

        final willRaise = <RaisedTask>[
          for (final item in stockouts)
            RaisedTask(
              title: '${skuNames[item['skuId']] ?? 'This SKU'} is out of stock',
              reason: 'You counted zero on shelf',
              priority: 'high',
            ),
          for (final risk in risks)
            RaisedTask(
              title: (risk['note'] as String?)?.trim().isNotEmpty == true
                  ? risk['note'] as String
                  : '${risk['flagType'] ?? 'Risk'} flagged',
              reason: 'Risk you raised · ${risk['flagType'] ?? 'flagged'}',
              priority: (risk['severity'] as String?) ?? 'normal',
            ),
          for (final task in actionPlan)
            RaisedTask(
              title: (task['requiredFix'] as String?) ?? 'Action you asked for',
              reason: 'Action plan you wrote',
              priority: (task['priority'] as String?) ?? 'normal',
            ),
        ]..sort((a, b) => _rank(b.priority).compareTo(_rank(a.priority)));

        return VisitReview(
          skusCounted: stock.length,
          outOfStock: stockouts.length,
          skusPriced: pricing.length,
          competitors: competitive.length,
          photos: (payloads['photo'] ?? const []).length,
          willRaise: willRaise,
        );
      });
    });

int _rank(String priority) => switch (priority) {
  'critical' => 3,
  'high' => 2,
  'normal' => 1,
  _ => 0,
};
