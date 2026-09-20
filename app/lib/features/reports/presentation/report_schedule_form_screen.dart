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
import '../data/report_schedules_repository.dart';
import '../data/reports_repository.dart';

/// The cadence field's hint (#66): the backend fires schedules on their
/// cadence, sends them to webhooks, and emails the recipients when the server
/// has email (SMTP) set up.
const scheduleCadenceHelp =
    'Runs automatically on this cadence (UTC), is sent to webhooks '
    'subscribed to $reportGeneratedEvent, and is emailed to the recipients '
    'when email is set up on the server.';

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
String? recipientsError(String raw) {
  final recipients = parseRecipients(raw);
  if (recipients.isEmpty) return 'Add at least one recipient';
  final invalid = recipients.where((r) => !_emailAddress.hasMatch(r)).toList();
  if (invalid.isNotEmpty) return 'Not an email address: ${invalid.first}';
  if (recipients.length > maxScheduleRecipients) {
    return 'At most $maxScheduleRecipients recipients';
  }
  return null;
}

/// Why the report cannot be picked when editing: `PATCH /report-schedules/:id`
/// accepts only `active`, `cadence` and `recipients`.
const scheduleReportLockedNote =
    'The report on a schedule cannot be changed. To schedule a different '
    'report, create a new schedule.';

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
    if (!_editing) {
      if (reports.isLoading) return 'Loading the saved reports.';
      if (reports.hasError) {
        return 'The saved reports could not be loaded, so there is nothing '
            'to schedule yet.';
      }
      if ((reports.value ?? const <ReportDefinition>[]).isEmpty) {
        return 'There are no saved reports yet. Build one on Reports first.';
      }
      if (_reportId == null) return 'Pick the report this schedule runs.';
    }
    if (_cadence == null) return 'Pick how often it runs.';
    final recipients = recipientsError(_recipients.text);
    if (recipients != null) return recipients;
    return null;
  }

  Future<void> _submit() async {
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
        _failure =
            '${_editing ? 'The changes were not saved.' : 'The schedule was '
                      'not created.'} '
            '${TorchErrorMessage.sanitise(error).body}';
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
    final reports = _editing
        ? const AsyncValue<List<ReportDefinition>>.data(<ReportDefinition>[])
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
      title: _editing ? 'Edit schedule' : 'New schedule',
      facts: const <String>['It runs server-side and delivers the result.'],
      back: ConsolePage.backTo(
        'Back to Report schedules',
        () => Navigator.of(context).pop(),
      ),
      primaryArmed: armed,
      primary: TorchPrimaryButton(
        key: const ValueKey<String>('schedule-save-button'),
        label: _editing ? 'Save these changes' : 'Create this schedule',
        claimId: ConsolePage.primaryClaimId,
        busy: _saving,
        blockedReason: blocked ?? (_saving ? 'Saving…' : null),
        onPressed: armed ? _submit : null,
      ),
      children: <Widget>[
        const SectionRule('Report'),
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
                title: _reportName ?? 'Untitled report',
                subtitle: 'Locked',
                semanticsLabel:
                    '${_reportName ?? 'Untitled report'}. Locked. '
                    '$scheduleReportLockedNote',
              ),
              const SizedBox(height: TiqSpace.s3),
              Text(
                scheduleReportLockedNote,
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
            ],
          )
        else
          reports.when(
            loading: () => Skeleton(
              label: 'saved reports',
              child: const SkeletonRows(count: 1, rowHeight: 64),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('schedule-reports-retry'),
                label: 'Try again',
                onPressed: () => ref.invalidate(reportsPageProvider),
              ),
            ),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    key: ValueKey<String>('schedule-no-reports'),
                    scope: EmptyScope.inPanel,
                    headline: 'No saved reports yet.',
                    body: 'Build one on the Reports screen, then schedule it.',
                  )
                : SoftRow(
                    key: const ValueKey<String>('schedule-report-field'),
                    form: SoftRowForm.standalone,
                    density: SoftRowDensity.standard,
                    title: 'Report',
                    subtitle: _reportName ?? 'Not picked yet',
                    trailing: const SoftRowChevron(),
                    onTap: () => _pickReport(list),
                    semanticsLabel:
                        'Report. ${_reportName ?? 'Not picked yet'}. '
                        'Choose the report this schedule runs.',
                  ),
          ),

        SizedBox(height: skin.space.blockGap),
        const SectionRule('Schedule'),
        const SizedBox(height: TiqSpace.s5),
        ChoiceRow<String>(
          key: const ValueKey<String>('schedule-cadence-field'),
          label: 'How often',
          value: _cadence,
          notAnsweredLine: 'Pick how often it runs.',
          options: <ChoiceOption<String>>[
            for (final cadence in reportCadences)
              ChoiceOption<String>(
                value: cadence,
                label: cadenceLabel(cadence),
                consequence: cadence == 'daily'
                    ? 'Every day, 06:00 UTC.'
                    : 'Every Monday, 06:00 UTC.',
              ),
          ],
          onChanged: (value) => setState(() => _cadence = value),
        ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          scheduleCadenceHelp,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchTextField(
          key: const ValueKey<String>('schedule-recipients-field'),
          label: 'Recipients',
          controller: _recipients,
          identifier: true,
          minLines: 2,
          maximumLines: 5,
          keyboardType: TextInputType.multiline,
          help: 'Email addresses, one per line or separated by commas.',
          error: recipientsError(_recipients.text),
        ),

        if (failure != null) ...<Widget>[
          SizedBox(height: skin.space.blockGap),
          ErrorState(
            key: const ValueKey<String>('schedule-save-error'),
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.rejected,
              headline: _editing
                  ? 'The changes were not saved.'
                  : 'The schedule was not created.',
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
    return TorchSheet(
      title: 'Report',
      subtitle: 'The schedule runs this definition on its cadence.',
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
