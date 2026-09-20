import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/console_page.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../../l10n/l10n.dart';
import '../data/reports_repository.dart';

/// The four kinds of report the server can build, in the order the API
/// allow-lists them.
const reportTypes = <String>['visits', 'scorecards', 'tasks', 'orders'];

/// What each type is, in words — a slug is what the machine calls it and not
/// what a manager picks it by.
///
/// The SLUG is the wire's and stays English; the word beside it is the
/// reader's. A type the app does not know by name falls back to the slug,
/// which is honest: inventing a translation for it would be worse.
String reportTypeLabel(String type, AppLocalizations l10n) => switch (type) {
  'visits' => l10n.reportTypeVisits,
  'scorecards' => l10n.reportTypeScorecards,
  'tasks' => l10n.reportTypeTasks,
  'orders' => l10n.reportTypeOrders,
  _ => type,
};

String reportTypeConsequence(String type, AppLocalizations l10n) =>
    switch (type) {
      'visits' => l10n.reportTypeVisitsConsequence,
      'scorecards' => l10n.reportTypeScorecardsConsequence,
      'tasks' => l10n.reportTypeTasksConsequence,
      'orders' => l10n.reportTypeOrdersConsequence,
      _ => l10n.reportTypeOtherConsequence,
    };

/// A date the filters accept, or null when the box is empty.
///
/// `YYYY-MM-DD` and nothing else: the server stores the filters verbatim and
/// reads them back as ISO dates, so a locale-shaped "09/10" that means two
/// different days on two desks is a bug waiting in the data rather than in
/// the form.
DateTime? parseFilterDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  // `DateTime.tryParse` accepts 2026-02-31 and rolls it into March. A date a
  // manager cannot point at on a calendar is not a date they typed.
  final rebuilt =
      '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return rebuilt == text ? parsed : null;
}

/// Why a date box cannot be saved, or null when it can.
String? filterDateError(String raw, AppLocalizations l10n) {
  if (raw.trim().isEmpty) return null;
  return parseFilterDate(raw) == null ? l10n.reportFilterDateFormat : null;
}

/// NEW REPORT — a saved definition: what it queries, and what it is narrowed
/// to.
///
/// ## The button says why it cannot save
///
/// Not a greyed rectangle with nothing beside it: [TorchPrimaryButton]
/// requires a `blockedReason` whenever it is disabled, and renders it as a
/// `TorchBarNote` **above** the button, as a live region. A manager who cannot
/// press Create reads the sentence that says which box is still empty.
///
/// ## Amber, counted
///
/// Untabbed and no nav, so Night has two content grants and Day and Veld one.
/// The claim is declared **only while the primary is armed**, so an empty form
/// carries zero amber in every skin and a fillable one exactly one.
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key});

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _name = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();

  String _type = reportTypes.first;
  String? _outletId;
  String? _outletName;

  bool _saving = false;
  String? _failure;

  /// True once Create has been pressed with a malformed date, so a half-typed
  /// "2026-09" does not go red under the thumb that is still typing it.
  bool _shownErrors = false;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[_name, _from, _to]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() => _failure = null);
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_name, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Why this cannot be saved yet, in one sentence, or null when it can.
  String? get _blocked {
    final l10n = context.l10n;
    if (_name.text.trim().isEmpty) return l10n.reportFormBlockedName;
    if (filterDateError(_from.text, l10n) != null) {
      return l10n.reportFormBlockedFrom;
    }
    if (filterDateError(_to.text, l10n) != null) {
      return l10n.reportFormBlockedTo;
    }
    final from = parseFilterDate(_from.text);
    final to = parseFilterDate(_to.text);
    if (from != null && to != null && to.isBefore(from)) {
      return l10n.reportFormBlockedOrder;
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _shownErrors = true;
      _failure = null;
    });
    if (_blocked != null) return;
    setState(() => _saving = true);
    final filters = <String, dynamic>{
      if (_from.text.trim().isNotEmpty) 'from': _from.text.trim(),
      if (_to.text.trim().isNotEmpty) 'to': _to.text.trim(),
      if (_outletId != null) 'outletId': _outletId,
    };
    try {
      await ref
          .read(reportsRepositoryProvider)
          .createReport(
            name: _name.text.trim(),
            type: _type,
            filters: filters,
          );
      ref.invalidate(reportsPageProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage.sanitise(error).body;
      });
    }
  }

  Future<void> _pickOutlet() async {
    final picked = await showTorchSheet<({String? id, String? name})>(
      context,
      builder: (_) => const _OutletPickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _outletId = picked.id;
      _outletName = picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocked = _blocked;
    final armed = blocked == null && !_saving;
    final failure = _failure;

    return ConsolePage(
      phase: _saving
          ? 'saving'
          : failure != null
          ? 'error'
          : armed
          ? 'armed'
          : 'blocked',
      title: l10n.reportFormTitle,
      facts: <String>[l10n.reportFormFact],
      back: ConsolePage.backTo(
        l10n.reportFormBack,
        () => Navigator.of(context).pop(),
      ),
      primaryArmed: armed,
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('report-save-button'),
        label: l10n.reportFormCommit,
        claimId: ConsolePage.primaryClaimId,
        busy: _saving,
        blockedReason: blocked ?? (_saving ? l10n.reportFormSaving : null),
        onPressed: armed ? _submit : null,
      ),
      children: <Widget>[
        SectionRule(l10n.reportFormSectionReport),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('report-name-field'),
          label: l10n.reportFormName,
          controller: _name,
          hint: l10n.reportFormNameHint,
          help: l10n.reportFormNameHelp,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        ChoiceRow<String>(
          key: const ValueKey<String>('report-type-field'),
          label: l10n.reportFormType,
          value: _type,
          notAnsweredLine: l10n.reportFormTypeNotAnswered,
          options: <ChoiceOption<String>>[
            for (final type in reportTypes)
              ChoiceOption<String>(
                value: type,
                label: reportTypeLabel(type, l10n),
                consequence: reportTypeConsequence(type, l10n),
              ),
          ],
          onChanged: (value) => setState(() => _type = value),
        ),

        SizedBox(height: context.skin.space.blockGap),
        SectionRule(l10n.reportFormSectionNarrowed),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('report-from-date'),
          label: l10n.reportFormFrom,
          controller: _from,
          identifier: true,
          // Not localised: the server stores the filter verbatim and reads it
          // back as an ISO date, so the SHAPE is the message.
          hint: '2026-09-01',
          help: l10n.reportFormDateHelp,
          error: _shownErrors ? filterDateError(_from.text, l10n) : null,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('report-to-date'),
          label: l10n.reportFormTo,
          controller: _to,
          identifier: true,
          hint: '2026-09-30',
          help: l10n.reportFormDateHelp,
          error: _shownErrors ? filterDateError(_to.text, l10n) : null,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: TiqSpace.s5),
        SoftRow(
          key: const ValueKey<String>('report-outlet-field'),
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: l10n.reportFormOutlet,
          subtitle: _outletName ?? l10n.reportFormAllOutlets,
          trailing: const SoftRowChevron(),
          onTap: _pickOutlet,
          semanticsLabel: l10n.reportFormOutletSemantics(
            _outletName ?? l10n.reportFormAllOutlets,
          ),
        ),

        if (failure != null) ...<Widget>[
          SizedBox(height: context.skin.space.blockGap),
          ErrorState(
            key: const ValueKey<String>('report-save-error'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: l10n.reportFormFailed,
              body: failure,
              offersRetry: false,
            ),
          ),
        ],
      ],
    );
  }
}

/// Which outlet to narrow to — or all of them, which is a real choice and the
/// first row rather than an absence.
class _OutletPickerSheet extends ConsumerWidget {
  const _OutletPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final outlets = ref.watch(outletsListProvider);
    return TorchSheet(
      title: l10n.reportFormOutlet,
      subtitle: l10n.reportOutletSheetSubtitle,
      child: outlets.when(
        loading: () => Skeleton(
          label: l10n.reportOutletSheetSkeleton,
          child: const SkeletonRows(count: 4, rowHeight: 56),
        ),
        error: (error, stack) => ErrorState(
          scope: ErrorScope.inline,
          message: TorchErrorMessage.sanitise(error),
          action: TorchSecondaryButton(
            key: const ValueKey<String>('outlets-retry'),
            label: l10n.torchTryAgain,
            onPressed: () => ref.invalidate(outletsListProvider),
          ),
        ),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SoftRow(
              key: const ValueKey<String>('outlet-any'),
              density: SoftRowDensity.compact,
              title: l10n.reportFormAllOutlets,
              onTap: () => Navigator.of(
                context,
              ).pop((id: null, name: null)),
              separator: list.isEmpty
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
            ),
            if (list.isEmpty)
              EmptyState(
                scope: EmptyScope.inPanel,
                headline: l10n.reportOutletSheetEmptyHeadline,
                body: l10n.reportOutletSheetEmptyBody,
              )
            else
              for (var i = 0; i < list.length; i++)
                SoftRow(
                  key: ValueKey<String>('outlet-${list[i].id}'),
                  density: SoftRowDensity.compact,
                  title: list[i].name,
                  titleTruncation: SoftRowTruncation.middle,
                  onTap: () => Navigator.of(
                    context,
                  ).pop((id: list[i].id, name: list[i].name)),
                  separator: i == list.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                ),
          ],
        ),
      ),
    );
  }
}
