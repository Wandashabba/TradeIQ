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
import '../data/reports_repository.dart';

/// The four kinds of report the server can build, in the order the API
/// allow-lists them.
const reportTypes = <String>['visits', 'scorecards', 'tasks', 'orders'];

/// What each type is, in words — a slug is what the machine calls it and not
/// what a manager picks it by.
String reportTypeLabel(String type) => switch (type) {
  'visits' => 'Visits',
  'scorecards' => 'Scorecards',
  'tasks' => 'Tasks',
  'orders' => 'Orders',
  _ => type,
};

String reportTypeConsequence(String type) => switch (type) {
  'visits' => 'One row per submitted visit.',
  'scorecards' => 'One row per scored visit.',
  'tasks' => 'One row per task raised.',
  'orders' => 'One row per order captured in store.',
  _ => 'One row per record.',
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
String? filterDateError(String raw) {
  if (raw.trim().isEmpty) return null;
  return parseFilterDate(raw) == null
      ? 'Use the form 2026-09-20, or leave it blank for any date.'
      : null;
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
    if (_name.text.trim().isEmpty) return 'Give the report a name first.';
    if (filterDateError(_from.text) != null) {
      return 'The From date is not a date. Use the form 2026-09-20.';
    }
    if (filterDateError(_to.text) != null) {
      return 'The To date is not a date. Use the form 2026-09-20.';
    }
    final from = parseFilterDate(_from.text);
    final to = parseFilterDate(_to.text);
    if (from != null && to != null && to.isBefore(from)) {
      return 'The To date is before the From date.';
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
      title: 'New report',
      facts: const <String>['It runs on demand against live data.'],
      back: ConsolePage.backTo(
        'Back to Reports',
        () => Navigator.of(context).pop(),
      ),
      primaryArmed: armed,
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('report-save-button'),
        label: 'Create this report',
        claimId: ConsolePage.primaryClaimId,
        busy: _saving,
        blockedReason: blocked ?? (_saving ? 'Saving…' : null),
        onPressed: armed ? _submit : null,
      ),
      children: <Widget>[
        const SectionRule('Report'),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('report-name-field'),
          label: 'Name',
          controller: _name,
          hint: 'Outlet coverage, September',
          help: 'What a manager will look for in the list.',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        ChoiceRow<String>(
          key: const ValueKey<String>('report-type-field'),
          label: 'What it queries',
          value: _type,
          notAnsweredLine: 'Pick what the report is about.',
          options: <ChoiceOption<String>>[
            for (final type in reportTypes)
              ChoiceOption<String>(
                value: type,
                label: reportTypeLabel(type),
                consequence: reportTypeConsequence(type),
              ),
          ],
          onChanged: (value) => setState(() => _type = value),
        ),

        SizedBox(height: context.skin.space.blockGap),
        const SectionRule('Narrowed to'),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('report-from-date'),
          label: 'From',
          controller: _from,
          identifier: true,
          hint: '2026-09-01',
          help: 'Leave blank for any date.',
          error: _shownErrors ? filterDateError(_from.text) : null,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('report-to-date'),
          label: 'To',
          controller: _to,
          identifier: true,
          hint: '2026-09-30',
          help: 'Leave blank for any date.',
          error: _shownErrors ? filterDateError(_to.text) : null,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: TiqSpace.s5),
        SoftRow(
          key: const ValueKey<String>('report-outlet-field'),
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: 'Outlet',
          subtitle: _outletName ?? 'All outlets',
          trailing: const SoftRowChevron(),
          onTap: _pickOutlet,
          semanticsLabel:
              'Outlet. ${_outletName ?? 'All outlets'}. Choose an outlet.',
        ),

        if (failure != null) ...<Widget>[
          SizedBox(height: context.skin.space.blockGap),
          ErrorState(
            key: const ValueKey<String>('report-save-error'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: 'The report was not created.',
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
    final outlets = ref.watch(outletsListProvider);
    return TorchSheet(
      title: 'Outlet',
      subtitle: 'The report is narrowed to the one you pick.',
      child: outlets.when(
        loading: () => Skeleton(
          label: 'outlets',
          child: const SkeletonRows(count: 4, rowHeight: 56),
        ),
        error: (error, stack) => ErrorState(
          scope: ErrorScope.inline,
          message: TorchErrorMessage.sanitise(error),
          action: TorchSecondaryButton(
            key: const ValueKey<String>('outlets-retry'),
            label: 'Try again',
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
              title: 'All outlets',
              onTap: () => Navigator.of(
                context,
              ).pop((id: null, name: null)),
              separator: list.isEmpty
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
            ),
            if (list.isEmpty)
              const EmptyState(
                scope: EmptyScope.inPanel,
                headline: 'No outlets on this client yet.',
                body: 'The report will cover every outlet added later.',
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
