import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_db.dart';
import '../../../l10n/l10n.dart';
import 'skus_repository.dart' show skusListProvider;
import 'template_section_repository.dart';

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

/// Where one section stands.
///
/// Named `CaptureState` and not `SectionState` because the design system owns
/// that name: `SectionStateGlyph` draws the four silhouettes and this enum is
/// what the data layer maps onto them. Two `SectionState`s in one codebase,
/// one of them the design system's, is a footgun with a rename attached.
enum CaptureState {
  notStarted,
  partial,
  done,

  /// The app could not establish what this section holds — #389.
  ///
  /// Not a failure and not the agent's fault: the product list did not load,
  /// or the client's questions could not be pinned to this visit. The
  /// distinction that matters is that it is **not `done`**. Before this
  /// existed, a stock section with the SKU list missing reported `done` on
  /// zero captures, and a visit with nothing in it went through the gate
  /// printing "This store is clean".
  cantConfirm,
}

/// Why a section cannot be confirmed. A code, worded by the screen.
enum CantConfirmReason {
  /// `GET /outlets/:id/skus` did not answer. Without the list the app cannot
  /// say what was counted, what was priced, or what was missed.
  productListUnavailable,

  /// The client's audit template could not be pinned to this visit.
  clientTemplateUnavailable,
}

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

/// The client-questions section (#122): the client's own audit template,
/// pinned to this visit, and how far the agent has got with it.
///
/// Not an [AuditSection]: it exists only for a client that uses a template,
/// it is named with the client's own words, and it supplements S1–S10 rather
/// than being one of them. It never feeds the perfect-store score.
class TemplateSectionProgress {
  const TemplateSectionProgress({
    required this.template,
    required this.state,
    required this.answered,
    required this.questions,
    required this.requiredLeft,
    this.answers = const {},
  });

  /// [saved] is the newest saved answers, or null when never saved.
  factory TemplateSectionProgress.of(
    ClientTemplate template,
    Map<String, Object?>? saved,
  ) {
    final answers = saved ?? const <String, Object?>{};
    final schema = template.schema;
    final left = schema.missingRequired(answers).length;
    return TemplateSectionProgress(
      template: template,
      // Saved with a required question still open is PARTIAL, never done:
      // that is the state the submit gate refuses.
      state: saved == null
          ? CaptureState.notStarted
          : left > 0
          ? CaptureState.partial
          : CaptureState.done,
      answered: schema.answeredCount(answers),
      questions: schema.questionCount(answers),
      requiredLeft: left,
      answers: answers,
    );
  }

  final ClientTemplate template;
  final CaptureState state;
  final int answered;
  final int questions;

  /// Visible required questions still unanswered — the submit blocks on these,
  /// exactly as it blocks on an unfinished required fixed section.
  final int requiredLeft;
  final Map<String, Object?> answers;

  /// Whether the template asks anything that must be answered. A template of
  /// only optional questions never blocks, like an optional fixed section.
  bool get isRequired => template.schema.hasRequired;

  bool get blocking => requiredLeft > 0;

  /// "Client questions · 2 of 5 answered" (or Not started / Optional).
  String detailIn(AppLocalizations l10n) => l10n.visitTemplateTileDetail(
    state == CaptureState.notStarted
        ? (isRequired ? l10n.visitSectionNotStarted : l10n.visitSectionOptional)
        : l10n.visitTemplateProgressAnswered(answered, questions),
  );
}

class VisitProgress {
  const VisitProgress({
    required this.states,
    required this.details,
    this.detailCodes = const {},
    this.template,
    this.cantConfirm = const {},
    this.templateCantConfirm,
  });

  final Map<AuditSection, CaptureState> states;

  /// Why each can't-confirm section cannot be confirmed. A section in
  /// [CaptureState.cantConfirm] always has an entry here — the row names the
  /// reason in words and the submit gate repeats it, because "can't confirm"
  /// with no reason is indistinguishable from "did not bother".
  final Map<AuditSection, CantConfirmReason> cantConfirm;

  /// Set when the client's questions exist for this client but could not be
  /// pinned to this visit. The row renders can't-confirm rather than
  /// vanishing: a section that disappears when it fails to load is a section
  /// nobody knows is missing.
  final CantConfirmReason? templateCantConfirm;

  /// A short line per section — "12 SKUs · 2 out of stock" — so the hub says
  /// what was captured, not just that something was. English; screens use
  /// [detailIn].
  final Map<AuditSection, String> details;

  /// The same lines as codes, for wording in the agent's language.
  final Map<AuditSection, SectionDetail> detailCodes;

  /// The client-questions section, when this visit's client uses an audit
  /// template. Null — and the hub exactly as it has always been — otherwise.
  final TemplateSectionProgress? template;

  /// A section's line in [l10n]'s language, or null when it has none.
  String? detailIn(AuditSection s, AppLocalizations l10n) =>
      detailCodes[s]?.text(l10n) ?? details[s];

  CaptureState stateOf(AuditSection s) => states[s] ?? CaptureState.notStarted;

  /// Required sections that are not finished. The submit button is blocked on
  /// exactly this, and it names them rather than just going grey.
  ///
  /// A required section in [CaptureState.cantConfirm] blocks too, and that is
  /// deliberate. unify §4 says a section the *agent* could not confirm drops
  /// out of the readiness count rather than blocking — but the two reasons in
  /// [CantConfirmReason] are not the agent declining a section, they are the
  /// app failing to load one. #389: the fix for "silently reports Done" is a
  /// named blocker, not a silent exclusion. When the skip-reason picker lands
  /// (Phase 2) an agent-declared can't-confirm will carry its own reason and
  /// stop blocking; these two never will.
  List<AuditSection> get blocking => AuditSection.values
      .where((s) => s.required && stateOf(s) != CaptureState.done)
      .toList();

  /// Whether the client's required questions still block the submit.
  bool get templateBlocking =>
      templateCantConfirm != null || (template?.blocking ?? false);

  /// Everything that blocks the submit: the fixed sections in [blocking], plus
  /// the client-questions section when it has required questions left.
  int get blockingCount => blocking.length + (templateBlocking ? 1 : 0);

  bool get canSubmit => blocking.isEmpty && !templateBlocking;

  int get doneCount =>
      AuditSection.values
          .where((s) => s.entityType != null && stateOf(s) == CaptureState.done)
          .length +
      (template?.state == CaptureState.done ? 1 : 0);

  /// The eight capturable sections (score is an outcome, not a section), plus
  /// the client-questions section when there is one.
  int get captureCount =>
      AuditSection.values.where((s) => s.entityType != null).length +
      (template == null && templateCantConfirm == null ? 0 : 1);

  /// Sections the app could not establish. Counted and named separately from
  /// the readiness numerator: "5 captured · 1 can't confirm" is two facts and
  /// folding them into one figure loses the one that needs acting on.
  int get cantConfirmCount =>
      cantConfirm.length + (templateCantConfirm == null ? 0 : 1);
}

/// Whether pinning the client's audit template to this visit threw.
///
/// The hub calls `pinForVisit` once, at check-in, and it used to swallow the
/// failure with a `catchError` and a `debugPrint` — so a client whose
/// questions could not be loaded got a hub with the row silently absent and a
/// submit that went straight through. This is the seam that makes the failure
/// a *state* instead: the hub sets it, [visitProgressProvider] reads it, and
/// the row renders can't-confirm.
///
/// Per visit draft, so a retry at a second store starts clean.
class TemplatePinFailures extends FamilyNotifier<bool, String> {
  @override
  bool build(String visitDraftId) => false;

  void failed() => state = true;
}

final templatePinFailedProvider =
    NotifierProvider.family<TemplatePinFailures, bool, String>(
      TemplatePinFailures.new,
    );

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
      final skus = ref.watch(skusListProvider(key.outletId));
      final skuCount = skus.maybeWhen(data: (list) => list.length, orElse: () => 0);
      // #389. A SKU list that FAILED is not a SKU list of length zero, and the
      // difference is the whole bug: with `orElse: 0` a part-counted stock
      // section fell through the `skuCount > 0` guard and reported *done*, so
      // a visit that had counted three of forty SKUs submitted as complete.
      // A failed read now makes the two per-SKU sections can't-confirm, which
      // blocks the submit and names why.
      final productListGone = skus.hasError;
      // The client template pinned to this visit — local, so offline too.
      final template = ref
          .watch(visitTemplateProvider(key.visitDraftId))
          .maybeWhen(data: (t) => t, orElse: () => null);
      // Whether the pin at check-in failed outright. The hub tells us; the
      // repository's own fallbacks (no signal → the last template this agent
      // was given → nothing) are not failures and do not set it.
      final templatePinFailed = ref.watch(
        templatePinFailedProvider(key.visitDraftId),
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

        final states = <AuditSection, CaptureState>{};
        final details = <AuditSection, SectionDetail>{};
        final unconfirmable = <AuditSection, CantConfirmReason>{};

        // Outlet info is confirmed by the act of checking in — there is nothing to
        // capture, so it is done the moment the agent is inside the fence.
        states[AuditSection.outletInfo] = CaptureState.done;
        details[AuditSection.outletInfo] =
            const SectionDetail.confirmedAtCheckIn();

        for (final section in AuditSection.values) {
          final type = section.entityType;
          if (type == null) continue;

          final perSku =
              section == AuditSection.stock || section == AuditSection.pricing;

          // Without the product list there is no denominator, so there is no
          // honest answer about a per-SKU section — captured or not.
          if (perSku && productListGone) {
            states[section] = CaptureState.cantConfirm;
            unconfirmable[section] = CantConfirmReason.productListUnavailable;
            continue;
          }

          final captured = payloads[type] ?? const [];
          if (captured.isEmpty) {
            states[section] = CaptureState.notStarted;
            continue;
          }

          final items = captured
              .expand((p) => (p['items'] as List? ?? const []))
              .length;

          // A per-SKU section that covers only some of the SKUs is PARTIAL, not
          // done. Saying "done" when five SKUs were never priced would quietly let
          // an incomplete visit through the submit gate.
          if (perSku && skuCount > 0 && items < skuCount) {
            states[section] = CaptureState.partial;
            details[section] = SectionDetail.skusOfTotal(items, skuCount);
          } else {
            states[section] = CaptureState.done;
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
          cantConfirm: unconfirmable,
          // A pin that failed outranks a template that is simply absent: the
          // row renders can't-confirm and blocks, rather than disappearing and
          // taking the client's questions with it.
          templateCantConfirm: templatePinFailed && template == null
              ? CantConfirmReason.clientTemplateUnavailable
              : null,
          template: template == null
              ? null
              : TemplateSectionProgress.of(
                  template,
                  latestTemplateAnswers(
                    rows,
                    visitDraftId: key.visitDraftId,
                    templateId: template.templateId,
                  ),
                ),
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
