import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_db.dart';
import '../../../l10n/l10n.dart';
import 'skus_repository.dart' show skusListProvider;

/// A task this visit will raise for the manager.
///
/// Every one of these is *derived from something the agent captured*. Nothing is
/// invented on this screen, and nothing is added afterwards — which is exactly
/// what the submit gate promises the agent.
class RaisedTask {
  /// A task already worded — [title] and [reason] are shown as they are.
  const RaisedTask({
    required this.title,
    required this.reason,
    required this.priority,
  }) : _kind = null,
       _subject = null,
       _flagType = null;

  /// A `high` restock task for a SKU counted at zero — [skuName] when the SKU
  /// list has it.
  RaisedTask.stockout({String? skuName})
    : this._coded(RaisedTaskKind.stockout, 'high', subject: skuName);

  /// One task per risk, at the risk's own severity: the agent's [note] is the
  /// title when they wrote one.
  RaisedTask.risk({String? note, String? flagType, required String priority})
    : this._coded(
        RaisedTaskKind.risk,
        priority,
        subject: note?.trim().isNotEmpty == true ? note : null,
        flagType: flagType,
      );

  /// An action-plan task the agent wrote, titled with its [requiredFix].
  RaisedTask.actionPlan({String? requiredFix, required String priority})
    : this._coded(RaisedTaskKind.actionPlan, priority, subject: requiredFix);

  RaisedTask._coded(
    RaisedTaskKind kind,
    this.priority, {
    String? subject,
    String? flagType,
  }) : _kind = kind,
       _subject = subject,
       _flagType = flagType,
       title = _titleOf(kind, subject, flagType, englishLocalizations),
       reason = _reasonOf(kind, flagType, englishLocalizations);

  /// The English title; screens use [titleIn].
  final String title;

  /// The English reason; screens use [reasonIn].
  final String reason;

  /// 'critical' | 'high' | 'normal' | 'low' — the server's own priorities.
  final String priority;

  /// Which server rule raises this task; null for an already-worded task.
  RaisedTaskKind? get kind => _kind;

  final RaisedTaskKind? _kind;

  /// The agent's own words or the SKU's name — never translated.
  final String? _subject;
  final String? _flagType;

  bool get isUrgent => priority == 'critical' || priority == 'high';

  /// The title in [l10n]'s language.
  String titleIn(AppLocalizations l10n) {
    final kind = _kind;
    return kind == null ? title : _titleOf(kind, _subject, _flagType, l10n);
  }

  /// The reason in [l10n]'s language.
  String reasonIn(AppLocalizations l10n) {
    final kind = _kind;
    return kind == null ? reason : _reasonOf(kind, _flagType, l10n);
  }

  static String _titleOf(
    RaisedTaskKind kind,
    String? subject,
    String? flagType,
    AppLocalizations l10n,
  ) => switch (kind) {
    RaisedTaskKind.stockout =>
      subject == null
          ? l10n.taskStockoutTitleUnnamed
          : l10n.taskStockoutTitle(subject),
    RaisedTaskKind.risk =>
      subject ??
          (flagType == null
              ? l10n.taskRiskTitleUntyped
              : l10n.taskRiskTitle(flagType)),
    RaisedTaskKind.actionPlan => subject ?? l10n.taskActionPlanTitleUntitled,
  };

  static String _reasonOf(
    RaisedTaskKind kind,
    String? flagType,
    AppLocalizations l10n,
  ) => switch (kind) {
    RaisedTaskKind.stockout => l10n.taskStockoutReason,
    RaisedTaskKind.risk =>
      flagType == null
          ? l10n.taskRiskReasonUntyped
          : l10n.taskRiskReason(flagType),
    RaisedTaskKind.actionPlan => l10n.taskActionPlanReason,
  };
}

/// The server rule a [RaisedTask] mirrors.
enum RaisedTaskKind { stockout, risk, actionPlan }

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

  /// "12 SKUs counted · 2 competitors · 1 photo" — the visit in one line, in
  /// English; screens use [capturedLineIn].
  String get capturedLine => capturedLineIn(englishLocalizations);

  /// The captured line in [l10n]'s language. Each part is a whole message;
  /// the " · " between them is a list separator, not grammar.
  String capturedLineIn(AppLocalizations l10n) {
    final parts = <String>[
      l10n.reviewSkusCounted(skusCounted),
      if (competitors > 0) l10n.reviewCompetitors(competitors),
      if (photos > 0) l10n.reviewPhotos(photos),
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
            RaisedTask.stockout(skuName: skuNames[item['skuId']]),
          for (final risk in risks)
            RaisedTask.risk(
              note: risk['note'] as String?,
              flagType: risk['flagType']?.toString(),
              priority: (risk['severity'] as String?) ?? 'normal',
            ),
          for (final task in actionPlan)
            RaisedTask.actionPlan(
              requiredFix: task['requiredFix'] as String?,
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
