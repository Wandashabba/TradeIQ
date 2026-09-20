import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/reports_repository.dart';
import 'report_form_screen.dart';

/// Saved report definitions, as a worklist: what exists, what it queries, and
/// whether it has been run in this session.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsListProvider);
    return ManagerScaffold(
      title: 'Reports',
      // Schedules hang off their reports rather than taking a menu slot of
      // their own; the rail keeps Reports lit on /reports/schedules.
      actions: [
        TextButton.icon(
          key: const ValueKey<String>('reports-schedules'),
          icon: const Icon(Icons.schedule_outlined, size: 16),
          label: const Text('Schedules'),
          onPressed: () => context.go('/reports/schedules'),
        ),
      ],
      // The whole /reports surface is manager/admin only (route-guarded), so the
      // build action does not need a further role check here.
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('report-create-fab'),
        tooltip: 'New report',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const ReportFormScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<List<ReportDefinition>>(
            value: reports,
            label: 'reports',
            onRetry: () => ref.invalidate(reportsListProvider),
            builder: (list) => PanelCard(
              title:
                  '${list.length} ${list.length == 1 ? 'report' : 'reports'}',
              subtitle: 'Definitions run on demand against live data',
              padded: false,
              child: list.isEmpty
                  ? const EmptyState(
                      message: 'No saved reports',
                      hint:
                          'Build one, then run it to see how many rows it '
                          'returns.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final report in list)
                          _ReportRow(
                            key: ValueKey<String>('report-${report.id}'),
                            report: report,
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends ConsumerStatefulWidget {
  const _ReportRow({super.key, required this.report});

  final ReportDefinition report;

  @override
  ConsumerState<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends ConsumerState<_ReportRow> {
  int? _lastRowCount;

  Future<void> _run() async {
    final result = await ref
        .read(reportsRepositoryProvider)
        .generate(widget.report.id);
    if (mounted) {
      setState(() => _lastRowCount = result.rowCount);
    }
  }

  Future<void> _delete() async {
    await ref.read(reportsRepositoryProvider).deleteReport(widget.report.id);
    ref.invalidate(reportsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _lastRowCount;

    return WorklistRow(
      title: widget.report.name,
      // The type slug is what the backend keys on, so it wears the mono token —
      // a manager can quote it straight back into a report definition. Once run,
      // the token carries the result too: the query and its size, in one place.
      meta: CodeToken(
        rows == null
            ? widget.report.type
            : '${widget.report.type} · $rows rows',
      ),
      // A report has no severity — the only real state is whether it has been
      // generated yet in this session. Mark plus word, never colour alone.
      level: rows == null ? StatusLevel.neutral : StatusLevel.good,
      statusLabel: rows == null ? 'Ready' : 'Generated',
      actions: [
        RowAction(
          key: ValueKey<String>('run-${widget.report.id}'),
          label: 'Run',
          onPressed: _run,
        ),
        RowAction(
          key: ValueKey<String>('delete-${widget.report.id}'),
          label: 'Delete',
          tone: StatusLevel.critical,
          onPressed: _delete,
        ),
      ],
    );
  }
}
