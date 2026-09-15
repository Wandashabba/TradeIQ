import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_db.dart';
import '../../../l10n/l10n.dart';
import 'skus_repository.dart' show skusListProvider;

/// One section of the audit, as the agent sees it.
enum AuditSection {
  outletInfo(label: 'Outlet info', entityType: null, required: false),
  stock(label: 'Stock & availability', entityType: 'stock', required: true),
  visibility(
    label: 'Visibility & display',
    entityType: 'visibility',
    required: true,
  ),
  pricing(label: 'Pricing & promotions', entityType: 'pricing', required: true),
  competitive(label: 'Competitive', entityType: 'competitive', required: false),
  capability(
    label: 'Team capability',
    entityType: 'capability',
    required: true,
  ),
  risks(label: 'Risks', entityType: 'risk', required: false),
  actionPlan(label: 'Action plan', entityType: 'task', required: false),
  score(label: 'Score', entityType: null, required: false);

  const AuditSection({
    required this.label,
    required this.entityType,
    required this.required,
  });

  final String label;

  /// The outbox entity this section writes. Null for the two sections that are
  /// not captures: outlet info (shown, not entered) and the score (the *result*
  /// of the other eight, so it cannot be "filled in").
  final String? entityType;

  /// Whether a visit can be submitted without it.
  ///
  /// These four are the ones the server's scorecard scores. Without them the
  /// visit lands with a dimension at zero and the store is marked down for work
  /// the agent simply never did — so we stop them, rather than let them submit
  /// something that will misrepresent the store.
  ///
  /// Competitive is deliberately NOT required: an outlet with no competitor on
  /// shelf is a real outcome, and the server now treats that dimension as
  /// unmeasurable rather than zero (#93).
  // ignore: avoid_positional_boolean_parameters
  final bool required;
}

enum SectionState { notStarted, partial, done }

enum _SectionDetailKind {
  confirmedAtCheckIn,
  skusOfTotal,
  stockCounted,
  stockOutOfStock,
  skusPriced,
  noCompetitors,
  competitors,
  captured,
  noRisks,
  risksRaised,
}

/// What a section's one-line summary says, as a code plus its numbers — worded
/// by [text] in the language of the screen that shows it.
final class SectionDetail {
  const SectionDetail._(this._kind, {this.items = 0, this.other = 0});

  /// Outlet info: done by the act of checking in.
  const SectionDetail.confirmedAtCheckIn()
    : this._(_SectionDetailKind.confirmedAtCheckIn);

  /// A per-SKU section part-way through: [items] of [total].
  const SectionDetail.skusOfTotal(int items, int total)
    : this._(_SectionDetailKind.skusOfTotal, items: items, other: total);

  /// Stock counted, with [outOfStock] of the [items] at zero.
  const SectionDetail.stock(int items, int outOfStock)
    : this._(
        outOfStock == 0
            ? _SectionDetailKind.stockCounted
            : _SectionDetailKind.stockOutOfStock,
        items: items,
        other: outOfStock,
      );

  const SectionDetail.skusPriced(int items)
    : this._(_SectionDetailKind.skusPriced, items: items);

  const SectionDetail.competitors(int items)
    : this._(
        items == 0
            ? _SectionDetailKind.noCompetitors
            : _SectionDetailKind.competitors,
        items: items,
      );

  const SectionDetail.captured() : this._(_SectionDetailKind.captured);

  const SectionDetail.risks(int items)
    : this._(
        items == 0 ? _SectionDetailKind.noRisks : _SectionDetailKind.risksRaised,
        items: items,
      );

  final _SectionDetailKind _kind;
  final int items;

  /// The second number, where there is one: the SKU total, or how many are out
  /// of stock.
  final int other;

  String text(AppLocalizations l10n) => switch (_kind) {
    _SectionDetailKind.confirmedAtCheckIn => l10n.progressConfirmedAtCheckIn,
    _SectionDetailKind.skusOfTotal => l10n.progressSkusOfTotal(items, other),
    _SectionDetailKind.stockCounted => l10n.progressStockCounted(items),
    _SectionDetailKind.stockOutOfStock => l10n.progressStockOutOfStock(
      items,
      other,
    ),
    _SectionDetailKind.skusPriced => l10n.progressSkusPriced(items),
    _SectionDetailKind.noCompetitors => l10n.progressNoCompetitors,
    _SectionDetailKind.competitors => l10n.progressCompetitors(items),
    _SectionDetailKind.captured => l10n.progressCaptured,
    _SectionDetailKind.noRisks => l10n.progressNoRisks,
    _SectionDetailKind.risksRaised => l10n.progressRisksRaised(items),
  };

  @override
  bool operator ==(Object other) =>
      other is SectionDetail &&
      other._kind == _kind &&
      other.items == items &&
      other.other == this.other;

  @override
  int get hashCode => Object.hash(_kind, items, other);

  @override
  String toString() => text(englishLocalizations);
}

class VisitProgress {
  const VisitProgress({
    required this.states,
    required this.details,
    this.detailCodes = const {},
  });

  final Map<AuditSection, SectionState> states;

  /// A short line per section — "12 SKUs · 2 out of stock" — so the hub says
  /// what was captured, not just that something was. English; screens use
  /// [detailIn].
  final Map<AuditSection, String> details;

  /// The same lines as codes, for wording in the agent's language.
  final Map<AuditSection, SectionDetail> detailCodes;

  /// A section's line in [l10n]'s language, or null when it has none.
  String? detailIn(AuditSection s, AppLocalizations l10n) =>
      detailCodes[s]?.text(l10n) ?? details[s];

  SectionState stateOf(AuditSection s) => states[s] ?? SectionState.notStarted;

  /// Required sections that are not finished. The submit button is blocked on
  /// exactly this, and it names them rather than just going grey.
  List<AuditSection> get blocking => AuditSection.values
      .where((s) => s.required && stateOf(s) != SectionState.done)
      .toList();

  bool get canSubmit => blocking.isEmpty;

  int get doneCount => AuditSection.values
      .where((s) => s.entityType != null && stateOf(s) == SectionState.done)
      .length;

  /// The eight capturable sections (score is an outcome, not a section).
  int get captureCount =>
      AuditSection.values.where((s) => s.entityType != null).length;
}

/// Reads the audit's progress straight out of the local outbox.
///
/// Deriving it from the queue rather than from in-memory state is what makes it
/// survive the app being killed mid-visit — which, in a shop with no signal and
/// a cheap phone, happens.
final visitProgressProvider =
    StreamProvider.family<
      VisitProgress,
      ({String visitDraftId, String outletId})
    >((ref, key) {
      final db = ref.read(localDbProvider);
      // Item counts are only meaningful against the SKU list; without it we can
      // still say done/not-started, just not "7 of 12".
      final skuCount = ref
          .watch(skusListProvider(key.outletId))
          .maybeWhen(data: (list) => list.length, orElse: () => 0);

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

        final states = <AuditSection, SectionState>{};
        final details = <AuditSection, SectionDetail>{};

        // Outlet info is confirmed by the act of checking in — there is nothing to
        // capture, so it is done the moment the agent is inside the fence.
        states[AuditSection.outletInfo] = SectionState.done;
        details[AuditSection.outletInfo] =
            const SectionDetail.confirmedAtCheckIn();

        for (final section in AuditSection.values) {
          final type = section.entityType;
          if (type == null) continue;

          final captured = payloads[type] ?? const [];
          if (captured.isEmpty) {
            states[section] = SectionState.notStarted;
            continue;
          }

          final items = captured
              .expand((p) => (p['items'] as List? ?? const []))
              .length;

          // A per-SKU section that covers only some of the SKUs is PARTIAL, not
          // done. Saying "done" when five SKUs were never priced would quietly let
          // an incomplete visit through the submit gate.
          final perSku =
              section == AuditSection.stock || section == AuditSection.pricing;
          if (perSku && skuCount > 0 && items < skuCount) {
            states[section] = SectionState.partial;
            details[section] = SectionDetail.skusOfTotal(items, skuCount);
          } else {
            states[section] = SectionState.done;
            final detail = _describe(section, captured, items);
            if (detail != null) details[section] = detail;
          }
        }

        return VisitProgress(
          states: states,
          details: {
            for (final MapEntry(:key, :value) in details.entries)
              key: value.text(englishLocalizations),
          },
          detailCodes: details,
        );
      });
    });

SectionDetail? _describe(
  AuditSection section,
  List<Map<String, dynamic>> captured,
  int items,
) {
  switch (section) {
    case AuditSection.stock:
      final outOfStock = captured
          .expand((p) => (p['items'] as List? ?? const []))
          .whereType<Map<String, dynamic>>()
          .where((i) => (i['unitsAvailable'] as num?) == 0)
          .length;
      return SectionDetail.stock(items, outOfStock);
    case AuditSection.pricing:
      return SectionDetail.skusPriced(items);
    case AuditSection.competitive:
      return SectionDetail.competitors(items);
    case AuditSection.visibility:
    case AuditSection.capability:
    case AuditSection.actionPlan:
      return const SectionDetail.captured();
    case AuditSection.risks:
      return SectionDetail.risks(items);
    case AuditSection.outletInfo:
    case AuditSection.score:
      // Never reached: neither is a capture (no entityType).
      return null;
  }
}
