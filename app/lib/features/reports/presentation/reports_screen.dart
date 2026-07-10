import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/reports_repository.dart';
import 'report_form_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
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
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load reports: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(reportsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _ReportCard(report: list[index]),
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.report});

  final ReportDefinition report;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  int? _lastRowCount;

  Future<void> _run() async {
    final result =
        await ref.read(reportsRepositoryProvider).generate(widget.report.id);
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
    return Card(
      child: ListTile(
        title: Text(widget.report.name),
        subtitle: Text(
          '${widget.report.type}'
          '${_lastRowCount != null ? ' · $_lastRowCount rows' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: ValueKey<String>('run-${widget.report.id}'),
              onPressed: _run,
              child: const Text('Run'),
            ),
            IconButton(
              key: ValueKey<String>('delete-${widget.report.id}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete report',
              onPressed: _delete,
            ),
          ],
        ),
      ),
    );
  }
}
