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
import '../../../l10n/l10n.dart';
import '../data/report_schedules_repository.dart';
import '../data/reports_repository.dart';

/// Splits the recipients box into entries: one per line, or separated by
/// commas or semicolons. Blank entries are dropped, so "a, , b" is two.
List<String> parseRecipients(String raw) => <String>[
  for (final part in raw.split(RegExp(r'[,;\n]')))
    if (part.trim().isNotEmpty) part.trim(),
];

/// The most recipients the API accepts on a schedule.
const maxScheduleRecipients = 50;

final _emailAddress = RegExp(
  r'^[^\s@<>()\[\],;:"\\]+@[^\s@<>()\[\],;:"\\]+\.[^\s@<>()\[\],;:"\\]+$',
);

/// Why the recipients box cannot be saved, or null when it can. Mirrors the
/// backend: 1–50 email addresses.
String? recipientsError(String raw, AppLocalizations l10n) {
  final recipients = parseRecipients(raw);
  if (recipients.isEmpty) return l10n.scheduleFormRecipientsEmpty;
  final invalid = recipients.where((r) => !_emailAddress.hasMatch(r)).toList();
  if (invalid.isNotEmpty) {
    return l10n.scheduleFormRecipientsInvalid(invalid.first);
  }
  if (recipients.length > maxScheduleRecipients) {
    return l10n.scheduleFormRecipientsTooMany(maxScheduleRecipients);
  }
  return null;
}

/// NEW / EDIT SCHEDULE — a saved report, a cadence and recipients.
///
/// Without [schedule] it creates, posting to `POST /report-schedules`. With
/// [schedule] it edits that schedule's cadence and recipients through
/// `PATCH /report-schedules/:id`; the linked report is shown read-only because
/// the API cannot change it.
///
/// ## The button says why it cannot save
///
/// Every reason this form cannot be committed is a sentence on the button,
/// above it, as a live region: no saved reports to schedule, no report picked,
/// no cadence, a recipients box that is empty or holds something that is not
/// an email address. A disabled commit with nothing beside it is the thing
/// `blockedReason` exists to make impossible.
class ReportScheduleFormScreen extends ConsumerStatefulWidget {
  const ReportScheduleFormScreen({super.key, this.schedule});

  /// The schedule being edited, or null to create one.
  final ReportSchedule? schedule;

  @override
  ConsumerState<ReportScheduleFormScreen> createState() =>
      _ReportScheduleFormScreenState();
}

class _ReportScheduleFormScreenState
    extends ConsumerState<ReportScheduleFormScreen> {
  late final TextEditingController _recipients;
  String? _reportId;
  String? _reportName;

  /// Null only when an edited schedule carries a cadence outside the
  /// allow-list (the column is free text) — the manager must pick one.
  String? _cadence;
  bool _saving = false;

  /// Why the last save failed, shown above the button until the next try.
  String? _failure;

  bool get _editing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _recipients = TextEditingController(text: s?.recipients.join('\n'))
      ..addListener(_changed);
    _reportId = s?.reportDefinitionId;
    _reportName = s?.reportName;
    _cadence = s == null
        ? reportCadences.first
        : (reportCadences.contains(s.cadence) ? s.cadence : null);
  }

  void _changed() {
    if (mounted) setState(() => _failure = null);
  }

  @override
  void dispose() {
    _recipients.dispose();
    super.dispose();
  }

  /// Why this cannot be saved yet, or null when it can.
  String? _blocked(AsyncValue<List<ReportDefinition>> reports) {
    final l10n = context.l10n;
    if (!_editing) {
      if (reports.isLoading) return l10n.scheduleFormBlockedLoading;
      if (reports.hasError) return l10n.scheduleFormBlockedReportsFailed;
      if ((reports.value ?? const <ReportDefinition>[]).isEmpty) {
        return l10n.scheduleFormBlockedNoReports;
      }
      if (_reportId == null) return l10n.scheduleFormBlockedNoReport;
    }
    if (_cadence == null) return l10n.scheduleFormBlockedNoCadence;
    return recipientsError(_recipients.text, l10n);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final reportId = _reportId;
    final cadence = _cadence;
    if (reportId == null || cadence == null) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final recipients = parseRecipients(_recipients.text);
    final repo = ref.read(reportSchedulesRepositoryProvider);
    try {
      final editing = widget.schedule;
      if (editing == null) {
        await repo.createSchedule(
          reportDefinitionId: reportId,
          cadence: cadence,
          recipients: recipients,
        );
      } else {
        await repo.updateSchedule(
          editing.id,
          cadence: cadence,
          recipients: recipients,
        );
      }
      ref.invalidate(reportSchedulesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = l10n.scheduleFormFailedBody(
          _editing
              ? l10n.scheduleFormFailedEdit
              : l10n.scheduleFormFailedNew,
          TorchErrorMessage.sanitise(error).body,
        );
      });
    }
  }

  Future<void> _pickReport(List<ReportDefinition> list) async {
    final picked = await showTorchSheet<ReportDefinition>(
      context,
      builder: (_) => _ReportPickerSheet(reports: list),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reportId = picked.id;
      _reportName = picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final reports = _editing
        ? const AsyncValue<List<ReportDefinition>>.data(
            <ReportDefinition>[],
          )
        : ref.watch(reportsListProvider);
    final blocked = _blocked(reports);
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
      title: _editing
          ? l10n.scheduleFormTitleEdit
          : l10n.scheduleFormTitleNew,
      facts: <String>[l10n.scheduleFormFact],
      back: ConsolePage.backTo(
        l10n.scheduleFormBack,
        () => Navigator.of(context).pop(),
      ),
      primaryArmed: armed,
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('schedule-save-button'),
        label: _editing
            ? l10n.scheduleFormCommitEdit
            : l10n.scheduleFormCommitNew,
        claimId: ConsolePage.primaryClaimId,
        busy: _saving,
        blockedReason: blocked ?? (_saving ? l10n.scheduleFormSaving : null),
        onPressed: armed ? _submit : null,
      ),
      children: <Widget>[
        SectionRule(l10n.scheduleFormSectionReport),
        const SizedBox(height: TiqSpace.s5),
        if (_editing)
          Column(
            key: const ValueKey<String>('schedule-report-readonly'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SoftRow(
                form: SoftRowForm.standalone,
                density: SoftRowDensity.standard,
                title: _reportName ?? l10n.scheduleUntitledReport,
                subtitle: l10n.scheduleFormReportLocked,
                semanticsLabel: l10n.scheduleFormReportLockedSemantics(
                  _reportName ?? l10n.scheduleUntitledReport,
                  l10n.scheduleFormReportLockedNote,
                ),
              ),
              const SizedBox(height: TiqSpace.s3),
              Text(
                l10n.scheduleFormReportLockedNote,
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
            ],
          )
        else
          reports.when(
            loading: () => Skeleton(
              label: l10n.scheduleFormReportsSkeleton,
              child: const SkeletonRows(count: 1, rowHeight: 64),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('schedule-reports-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(reportsPageProvider),
              ),
            ),
            data: (list) => list.isEmpty
                ? EmptyState(
                    key: const ValueKey<String>('schedule-no-reports'),
                    scope: EmptyScope.inPanel,
                    headline: l10n.scheduleFormNoReportsHeadline,
                    body: l10n.scheduleFormNoReportsBody,
                  )
                : SoftRow(
                    key: const ValueKey<String>('schedule-report-field'),
                    form: SoftRowForm.standalone,
                    density: SoftRowDensity.standard,
                    title: l10n.scheduleFormSectionReport,
                    subtitle:
                        _reportName ?? l10n.scheduleFormReportNotPicked,
                    trailing: const SoftRowChevron(),
                    onTap: () => _pickReport(list),
                    semanticsLabel: l10n.scheduleFormReportSemantics(
                      _reportName ?? l10n.scheduleFormReportNotPicked,
                    ),
                  ),
          ),

        SizedBox(height: skin.space.blockGap),
        SectionRule(l10n.scheduleFormSectionSchedule),
        const SizedBox(height: TiqSpace.s5),
        ChoiceRow<String>(
          key: const ValueKey<String>('schedule-cadence-field'),
          label: l10n.scheduleFormCadence,
          value: _cadence,
          notAnsweredLine: l10n.scheduleFormBlockedNoCadence,
          options: <ChoiceOption<String>>[
            for (final cadence in reportCadences)
              ChoiceOption<String>(
                value: cadence,
                label: cadenceLabel(cadence, l10n),
                consequence: cadence == 'daily'
                    ? l10n.scheduleFormCadenceDailyConsequence
                    : l10n.scheduleFormCadenceWeeklyConsequence,
              ),
          ],
          onChanged: (value) => setState(() => _cadence = value),
        ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.scheduleFormCadenceHelp,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('schedule-recipients-field'),
          label: l10n.scheduleFormRecipients,
          controller: _recipients,
          identifier: true,
          minLines: 2,
          maximumLines: 5,
          keyboardType: TextInputType.multiline,
          help: l10n.scheduleFormRecipientsHelp,
          error: recipientsError(_recipients.text, l10n),
        ),

        if (failure != null) ...<Widget>[
          SizedBox(height: skin.space.blockGap),
          ErrorState(
            key: const ValueKey<String>('schedule-save-error'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: _editing
                  ? l10n.scheduleFormFailedEdit
                  : l10n.scheduleFormFailedNew,
              body: failure,
              offersRetry: false,
            ),
          ),
        ],
      ],
    );
  }
}

/// Which saved report this schedule runs.
class _ReportPickerSheet extends StatelessWidget {
  const _ReportPickerSheet({required this.reports});

  final List<ReportDefinition> reports;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return TorchSheet(
      title: l10n.scheduleFormSectionReport,
      subtitle: l10n.scheduleReportSheetSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < reports.length; i++)
            SoftRow(
              key: ValueKey<String>('schedule-report-${reports[i].id}'),
              density: SoftRowDensity.standard,
              title: reports[i].name,
              meta: Text(
                reports[i].type,
                style: skin.text.monoIdent.style(color: skin.palette.ink3),
              ),
              onTap: () => Navigator.of(context).pop(reports[i]),
              separator: i == reports.length - 1
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
            ),
        ],
      ),
    );
  }
}
