import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../data/report_schedules_repository.dart';
import '../data/reports_repository.dart';

/// The cadence field's hint (#66): the backend fires schedules on their
/// cadence and sends them to webhooks; email is not built yet.
const scheduleCadenceHelp =
    'Runs automatically on this cadence (UTC) and is sent to webhooks '
    'subscribed to $reportGeneratedEvent. Email is not set up yet.';

/// Splits the recipients box into entries: one per line, or separated by
/// commas or semicolons. Blank entries are dropped, so "a, , b" is two.
List<String> parseRecipients(String raw) => [
      for (final part in raw.split(RegExp(r'[,;\n]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];

/// Why the report cannot be picked when editing: `PATCH /report-schedules/:id`
/// accepts only `active`, `cadence` and `recipients`.
const scheduleReportLockedNote =
    'The report on a schedule cannot be changed. To schedule a different '
    'report, create a new schedule.';

/// Manager/admin schedule builder: a saved report, a cadence and recipients.
///
/// Without [schedule] it creates, posting to `POST /report-schedules`. With
/// [schedule] it edits that schedule's cadence and recipients through
/// `PATCH /report-schedules/:id`; the linked report is shown read-only because
/// the API cannot change it. Either way the validation mirrors the backend —
/// cadence is daily|weekly, recipients is a non-empty list.
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recipientsCtrl;
  String? _reportId;

  /// Null only when an edited schedule carries a cadence outside the
  /// allow-list (the column is free text) — the manager must pick one.
  String? _cadence;
  bool _submitting = false;

  /// Why the last save failed, shown above the button until the next try.
  String? _error;

  bool get _editing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _recipientsCtrl = TextEditingController(text: s?.recipients.join('\n'));
    _reportId = s?.reportDefinitionId;
    _cadence = s == null
        ? reportCadences.first
        : (reportCadences.contains(s.cadence) ? s.cadence : null);
  }

  @override
  void dispose() {
    _recipientsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final reportId = _reportId;
    final cadence = _cadence;
    if (reportId == null || cadence == null) return;
    final recipients = parseRecipients(_recipientsCtrl.text);
    setState(() {
      _submitting = true;
      _error = null;
    });
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '${_editing ? 'Failed to save changes.' : 'Failed to '
              'create schedule.'} ${humanErrorMessage(e)}';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final noteStyle = TextStyle(fontSize: 13, color: colors.ink2);
    final editing = widget.schedule;

    final Widget reportField;
    final bool canSave;
    if (editing != null) {
      // The API cannot relink a schedule, so the report is shown, not offered.
      canSave = true;
      reportField = Column(
        key: const ValueKey<String>('schedule-report-readonly'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: colors.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  editing.reportName ?? 'Untitled report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.ink1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(scheduleReportLockedNote, style: noteStyle),
        ],
      );
    } else {
      final reports = ref.watch(reportsListProvider);
      // Without a saved report there is nothing to schedule.
      canSave = reports.value?.isNotEmpty ?? false;
      reportField = reports.when(
        loading: () => const LinearProgressIndicator(),
        error: (err, _) => Text(
          'Failed to load reports. ${humanErrorMessage(err)}',
          style: noteStyle,
        ),
        data: (list) => list.isEmpty
            ? Text(
                'No saved reports yet. Build one on the Reports screen first.',
                key: const ValueKey<String>('schedule-no-reports'),
                style: noteStyle,
              )
            : DropdownButtonFormField<String>(
                key: const ValueKey<String>('schedule-report-field'),
                initialValue: _reportId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Report',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final r in list)
                    DropdownMenuItem(
                      value: r.id,
                      child: Text(r.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _reportId = v),
                validator: (v) => v == null ? 'Pick a report' : null,
              ),
      );
    }

    final cadenceField = DropdownButtonFormField<String>(
      key: const ValueKey<String>('schedule-cadence-field'),
      initialValue: _cadence,
      decoration: const InputDecoration(
        labelText: 'Cadence',
        // The backend fires schedules on this cadence (#66); email is the part
        // still missing — say both where it is set.
        helperText: scheduleCadenceHelp,
        helperMaxLines: 3,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in reportCadences)
          DropdownMenuItem(value: c, child: Text(cadenceLabel(c))),
      ],
      onChanged: (v) => setState(() => _cadence = v ?? _cadence),
      validator: (v) => v == null ? 'Pick a cadence' : null,
    );

    final recipientsField = TextFormField(
      key: const ValueKey<String>('schedule-recipients-field'),
      controller: _recipientsCtrl,
      minLines: 2,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        labelText: 'Recipients',
        helperText: 'One per line, or separated by commas',
        border: OutlineInputBorder(),
      ),
      validator: (v) => parseRecipients(v ?? '').isEmpty
          ? 'Add at least one recipient'
          : null,
    );

    final error = _error;

    return GlassPageScaffold(
      title: Text(_editing ? 'Edit Schedule' : 'New Schedule'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(label: 'Report', children: [reportField]),
              const SizedBox(height: 14),
              _Section(
                label: 'Schedule',
                children: [
                  cadenceField,
                  const SizedBox(height: 14),
                  recipientsField,
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Row(
                  key: const ValueKey<String>('schedule-save-error'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 16, color: colors.critText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(fontSize: 13, color: colors.critText),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              GlassPrimaryButton(
                key: const ValueKey<String>('schedule-save-button'),
                label: _editing ? 'Save Changes' : 'Create Schedule',
                busy: _submitting,
                onPressed: canSave ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A glass panel with its kicker — one group of the form. Flat themes get
/// GlassPane's own flat rendering.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [Kicker(label), const SizedBox(height: 12), ...children],
      ),
    );
  }
}
