import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../data/report_schedules_repository.dart';
import '../data/reports_repository.dart';

/// Splits the recipients box into entries: one per line, or separated by
/// commas or semicolons. Blank entries are dropped, so "a, , b" is two.
List<String> parseRecipients(String raw) => [
      for (final part in raw.split(RegExp(r'[,;\n]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];

/// Manager/admin schedule builder: a saved report, a cadence and recipients.
/// Posts to `POST /report-schedules`, whose validation this mirrors — a report
/// is required, cadence is daily|weekly, recipients is a non-empty list.
class ReportScheduleFormScreen extends ConsumerStatefulWidget {
  const ReportScheduleFormScreen({super.key});

  @override
  ConsumerState<ReportScheduleFormScreen> createState() =>
      _ReportScheduleFormScreenState();
}

class _ReportScheduleFormScreenState
    extends ConsumerState<ReportScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientsCtrl = TextEditingController();
  String? _reportId;
  String _cadence = reportCadences.first;
  bool _submitting = false;

  @override
  void dispose() {
    _recipientsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final reportId = _reportId;
    if (reportId == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reportSchedulesRepositoryProvider).createSchedule(
            reportDefinitionId: reportId,
            cadence: _cadence,
            recipients: parseRecipients(_recipientsCtrl.text),
          );
      ref.invalidate(reportSchedulesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create schedule. ${humanErrorMessage(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reports = ref.watch(reportsListProvider);
    final hasReports = reports.value?.isNotEmpty ?? false;
    final noteStyle = TextStyle(fontSize: 13, color: colors.ink2);

    final reportField = reports.when(
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

    final cadenceField = DropdownButtonFormField<String>(
      key: const ValueKey<String>('schedule-cadence-field'),
      initialValue: _cadence,
      decoration: const InputDecoration(
        labelText: 'Cadence',
        // The cadence is stored, not acted on (#66) — say so where it is set.
        helperText: 'Saved with the schedule. Nothing sends on it yet.',
        helperMaxLines: 2,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in reportCadences)
          DropdownMenuItem(value: c, child: Text(cadenceLabel(c))),
      ],
      onChanged: (v) => setState(() => _cadence = v ?? _cadence),
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

    return GlassPageScaffold(
      title: const Text('New Schedule'),
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
              const SizedBox(height: 18),
              GlassPrimaryButton(
                key: const ValueKey<String>('schedule-save-button'),
                label: 'Create Schedule',
                busy: _submitting,
                // Without a saved report there is nothing to schedule.
                onPressed: hasReports ? _submit : null,
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
