import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_db.dart';
import 'skus_repository.dart' show skusListProvider;

/// One section of the audit, as the agent sees it.
enum AuditSection {
  outletInfo(
    label: 'Outlet info',
    entityType: null,
    required: false,
  ),
  stock(
    label: 'Stock & availability',
    entityType: 'stock',
    required: true,
  ),
  visibility(
    label: 'Visibility & display',
    entityType: 'visibility',
    required: true,
  ),
  pricing(
    label: 'Pricing & promotions',
    entityType: 'pricing',
    required: true,
  ),
  competitive(
    label: 'Competitive',
    entityType: 'competitive',
    required: false,
  ),
  capability(
    label: 'Team capability',
    entityType: 'capability',
    required: true,
  ),
  risks(
    label: 'Risks',
    entityType: 'risk',
    required: false,
  ),
  actionPlan(
    label: 'Action plan',
    entityType: 'task',
    required: false,
  ),
  score(
    label: 'Score',
    entityType: null,
    required: false,
  );

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

class VisitProgress {
  const VisitProgress({required this.states, required this.details});

  final Map<AuditSection, SectionState> states;

  /// A short line per section — "12 SKUs · 2 out of stock" — so the hub says
  /// what was captured, not just that something was.
  final Map<AuditSection, String> details;

  SectionState stateOf(AuditSection s) =>
      states[s] ?? SectionState.notStarted;

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
    StreamProvider.family<VisitProgress, String>((ref, visitDraftId) {
  final db = ref.read(localDbProvider);
  // Item counts are only meaningful against the SKU list; without it we can
  // still say done/not-started, just not "7 of 12".
  final skuCount = ref.watch(skusListProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
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
      if (payload['visitDraftId'] != visitDraftId) continue;
      payloads.putIfAbsent(row.entityType, () => []).add(payload);
    }

    final states = <AuditSection, SectionState>{};
    final details = <AuditSection, String>{};

    // Outlet info is confirmed by the act of checking in — there is nothing to
    // capture, so it is done the moment the agent is inside the fence.
    states[AuditSection.outletInfo] = SectionState.done;
    details[AuditSection.outletInfo] = 'Confirmed at check-in';

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
        details[section] = '$items of $skuCount SKUs';
      } else {
        states[section] = SectionState.done;
        details[section] = _describe(section, captured, items);
      }
    }

    return VisitProgress(states: states, details: details);
  });
});

String _describe(
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
      return outOfStock == 0
          ? '$items SKUs counted'
          : '$items SKUs · $outOfStock out of stock';
    case AuditSection.pricing:
      return '$items SKUs priced';
    case AuditSection.competitive:
      return items == 0 ? 'None on shelf' : '$items competitor(s)';
    case AuditSection.visibility:
      return 'Captured';
    case AuditSection.capability:
      return 'Captured';
    case AuditSection.risks:
      return items == 0 ? 'None raised' : '$items raised';
    case AuditSection.actionPlan:
      return 'Captured';
    case AuditSection.outletInfo:
    case AuditSection.score:
      return '';
  }
}
