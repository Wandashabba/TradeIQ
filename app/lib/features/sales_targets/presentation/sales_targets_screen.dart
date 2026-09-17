import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../data/sales_targets_repository.dart';
import 'sales_attainment_panel.dart';

/// Monthly sell-in targets per SKU (#119), and how the month is tracking.
///
/// "Actual" is units ordered through TradeIQ — sell-in — and the screen says so
/// wherever a figure appears. Managers set a target account-wide, for one
/// territory, or for one outlet; a CSV file sets many at once after a preview.
class SalesTargetsScreen extends ConsumerWidget {
  const SalesTargetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(salesTargetsMonthProvider);
    final report = ref.watch(salesAttainmentProvider);
    final colors = context.colors;
    final muted = colors.glass ? context.lumen.inkMuted : colors.ink3;

    return ManagerScaffold(
      title: 'Sales targets',
      actions: [
        IconButton(
          key: const ValueKey<String>('sales-targets-import'),
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          tooltip: 'Upload CSV',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _CsvImportDialog(),
          ),
        ),
      ],
      floatingActionButton: report.hasValue
          ? FloatingActionButton(
              key: const ValueKey<String>('sales-target-add'),
              tooltip: 'Add target',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    _TargetDialog(skus: report.requireValue.skus, month: month),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Targets are units of $sellInLabel: what outlets ordered through '
            'TradeIQ, not what shoppers bought. Set one per SKU for the whole '
            'account, a territory, or a single outlet.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          FilterRow(
            children: [
              IconButton(
                key: const ValueKey<String>('sales-month-prev'),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: () =>
                    ref.read(salesTargetsMonthProvider.notifier).previous(),
              ),
              Text(
                salesMonthLabel(month),
                key: const ValueKey<String>('sales-month-label'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('sales-month-next'),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: () =>
                    ref.read(salesTargetsMonthProvider.notifier).next(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AsyncSection<SalesAttainmentReport>(
            value: report,
            label: 'sales targets',
            onRetry: () => ref.invalidate(salesAttainmentProvider),
            builder: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                PanelCard(
                  title: '$sellInLabel vs target',
                  subtitle: data.timeZone.isEmpty
                      ? null
                      : 'Local days in ${data.timeZone}',
                  child: data.hasTargets
                      ? AttainmentLevels(report: data)
                      : const EmptyState(
                          message: 'No targets for this month',
                          hint:
                              'Set a target on a SKU below, or upload a CSV '
                              'of targets.',
                        ),
                ),
                const SizedBox(height: 12),
                PanelCard(
                  title:
                      '${data.skus.length} '
                      '${data.skus.length == 1 ? 'SKU' : 'SKUs'}',
                  subtitle: data.truncated
                      ? 'Showing the first ${data.skus.length}'
                      : '$sellInLabel against each target',
                  padded: false,
                  child: data.skus.isEmpty
                      ? const EmptyState(
                          message: 'No SKUs in this account',
                          hint: 'Targets are set per SKU.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final sku in data.skus) ...[
                              _SkuRow(sku: sku, skus: data.skus, month: month),
                              for (final scoped in sku.scoped)
                                _ScopedRow(
                                  sku: sku,
                                  scoped: scoped,
                                  skus: data.skus,
                                  month: month,
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The server's own sentence for a refusal it explained (a 400 or 404 names
/// the field or the missing SKU), otherwise the console's generic wording.
String describeSalesTargetError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final status = error.response?.statusCode ?? 0;
    if (status >= 400 && status < 500 && status != 401 && data is Map) {
      final message = data['error'];
      if (message is String && message.isNotEmpty) return message;
    }
  }
  return humanErrorMessage(error);
}

String _figures(int actualUnits, int? targetUnits) =>
    'Sell-in $actualUnits · target ${targetUnits ?? '—'} units';

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  String targetId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(salesTargetsRepositoryProvider).delete(targetId);
    ref.invalidate(salesAttainmentProvider);
    ref.invalidate(currentMonthAttainmentProvider);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Could not remove target. ${describeSalesTargetError(e)}',
        ),
      ),
    );
  }
}

class _SkuRow extends ConsumerWidget {
  const _SkuRow({required this.sku, required this.skus, required this.month});

  final SkuAttainment sku;
  final List<SkuAttainment> skus;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetId = sku.targetId;
    return WorklistRow(
      key: ValueKey<String>('sku-${sku.skuId}'),
      title: sku.skuName,
      meta: Text(
        _figures(sku.actualUnits, sku.targetUnits),
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      level: attainmentLevel(sku.attainmentPct),
      statusLabel: sku.targetUnits == null
          ? 'No target'
          : formatAttainment(sku.attainmentPct),
      actions: [
        RowAction(
          key: ValueKey<String>('set-target-${sku.skuId}'),
          label: targetId == null ? 'Set target' : 'Edit',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _TargetDialog(
              skus: skus,
              month: month,
              skuId: sku.skuId,
              units: sku.targetUnits,
              locked: true,
            ),
          ),
        ),
        if (targetId != null)
          RowAction(
            key: ValueKey<String>('delete-target-$targetId'),
            label: 'Remove',
            tone: StatusLevel.critical,
            onPressed: () => _delete(context, ref, targetId),
          ),
      ],
    );
  }
}

class _ScopedRow extends ConsumerWidget {
  const _ScopedRow({
    required this.sku,
    required this.scoped,
    required this.skus,
    required this.month,
  });

  final SkuAttainment sku;
  final ScopedAttainment scoped;
  final List<SkuAttainment> skus;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WorklistRow(
      key: ValueKey<String>('scoped-${scoped.targetId}'),
      title: '${sku.skuName} · ${scoped.scopeLabel}',
      meta: Text(
        _figures(scoped.actualUnits, scoped.targetUnits),
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      level: attainmentLevel(scoped.attainmentPct),
      statusLabel: formatAttainment(scoped.attainmentPct),
      actions: [
        RowAction(
          key: ValueKey<String>('edit-target-${scoped.targetId}'),
          label: 'Edit',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _TargetDialog(
              skus: skus,
              month: month,
              skuId: sku.skuId,
              scope: scoped.scope,
              territoryId: scoped.territory?.id,
              outletId: scoped.outlet?.id,
              units: scoped.targetUnits,
              locked: true,
            ),
          ),
        ),
        RowAction(
          key: ValueKey<String>('delete-target-${scoped.targetId}'),
          label: 'Remove',
          tone: StatusLevel.critical,
          onPressed: () => _delete(context, ref, scoped.targetId),
        ),
      ],
    );
  }
}

/// Create or edit one target. Editing locks the SKU and scope, since those are
/// what identify the target; changing them would be a different target.
class _TargetDialog extends ConsumerStatefulWidget {
  const _TargetDialog({
    required this.skus,
    required this.month,
    this.skuId,
    this.scope = 'client',
    this.territoryId,
    this.outletId,
    this.units,
    this.locked = false,
  });

  final List<SkuAttainment> skus;
  final DateTime month;
  final String? skuId;
  final String scope;
  final String? territoryId;
  final String? outletId;
  final int? units;
  final bool locked;

  @override
  ConsumerState<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends ConsumerState<_TargetDialog> {
  late String? _skuId = widget.skuId;
  late String _scope = widget.scope;
  late String? _territoryId = widget.territoryId;
  late String? _outletId = widget.outletId;
  late final _unitsCtrl = TextEditingController(
    text: widget.units?.toString() ?? '',
  );
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _unitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final units = int.tryParse(_unitsCtrl.text.trim());
    final String? problem = switch (null) {
      _ when _skuId == null => 'Choose a SKU',
      _ when units == null || units < 0 => 'Enter a whole number of units',
      _ when _scope == 'territory' && _territoryId == null =>
        'Choose a territory',
      _ when _scope == 'outlet' && _outletId == null => 'Choose an outlet',
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(salesTargetsRepositoryProvider)
          .upsert(
            skuId: _skuId!,
            month: salesMonthKey(widget.month),
            targetUnits: units!,
            territoryId: _scope == 'territory' ? _territoryId : null,
            outletId: _scope == 'outlet' ? _outletId : null,
          );
      ref.invalidate(salesAttainmentProvider);
      ref.invalidate(currentMonthAttainmentProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = describeSalesTargetError(e);
        });
      }
    }
  }

  Widget _scopePicker() {
    if (_scope == 'territory') {
      return ref
          .watch(territoriesListProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text('Failed to load territories. ${humanErrorMessage(e)}'),
            data: (territories) => DropdownButtonFormField<String>(
              key: const ValueKey<String>('target-territory'),
              initialValue: _territoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Territory'),
              items: [
                for (final t in territories)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text('${t.name} (${t.code})'),
                  ),
              ],
              onChanged: widget.locked
                  ? null
                  : (v) => setState(() => _territoryId = v),
            ),
          );
    }
    if (_scope == 'outlet') {
      return ref
          .watch(outletsListProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text('Failed to load outlets. ${humanErrorMessage(e)}'),
            data: (outlets) => DropdownButtonFormField<String>(
              key: const ValueKey<String>('target-outlet'),
              initialValue: _outletId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Outlet'),
              items: [
                for (final o in outlets)
                  DropdownMenuItem(
                    value: o.id,
                    child: Text('${o.name} (${o.code})'),
                  ),
              ],
              onChanged: widget.locked
                  ? null
                  : (v) => setState(() => _outletId = v),
            ),
          );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text(widget.locked ? 'Edit sales target' : 'Set sales target'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Units of $sellInLabel for ${salesMonthLabel(widget.month)}.',
                style: TextStyle(fontSize: 12, color: colors.ink3),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('target-sku'),
                initialValue: _skuId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'SKU'),
                items: [
                  for (final s in widget.skus)
                    DropdownMenuItem(value: s.skuId, child: Text(s.skuName)),
                ],
                onChanged: widget.locked
                    ? null
                    : (v) => setState(() => _skuId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('target-scope'),
                initialValue: _scope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Applies to'),
                items: const [
                  DropdownMenuItem(
                    value: 'client',
                    child: Text('Whole account'),
                  ),
                  DropdownMenuItem(
                    value: 'territory',
                    child: Text('One territory'),
                  ),
                  DropdownMenuItem(value: 'outlet', child: Text('One outlet')),
                ],
                onChanged: widget.locked
                    ? null
                    : (v) => setState(() => _scope = v ?? 'client'),
              ),
              if (_scope != 'client') ...[
                const SizedBox(height: 12),
                _scopePicker(),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('target-units'),
                controller: _unitsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target units'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  key: const ValueKey<String>('target-error'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: StatusLevel.critical.colorOf(colors),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('target-save'),
          onPressed: _submitting ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Choose a `.csv` — or paste one — preview what it would do (every row error
/// included), then apply the valid rows.
///
/// Apply is only ever offered for exactly the text that was previewed: pick a
/// different file, edit the paste, or clear the file, and it must be previewed
/// again. What gets written is always what was shown.
class _CsvImportDialog extends ConsumerStatefulWidget {
  const _CsvImportDialog();

  @override
  ConsumerState<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<_CsvImportDialog> {
  static const _maxErrorsShown = 50;

  final _csvCtrl = TextEditingController();

  /// The chosen file, while one is held. A file and the paste box are the two
  /// ways in, and only one is live at a time: while a file is held the box is
  /// hidden, so there is never a question about which of the two would upload.
  PickedCsv? _picked;
  SalesTargetImportResult? _preview;
  String? _previewedCsv;
  String? _fileError;
  bool _busy = false;

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  /// The CSV the buttons act on: the chosen file, else whatever was pasted.
  String get _csv => _picked?.contents ?? _csvCtrl.text;

  bool get _canApply =>
      !_busy &&
      _preview != null &&
      _previewedCsv == _csv &&
      _preview!.validRows > 0;

  /// Any change of source retires the preview: what was shown is no longer
  /// what would be written, so Apply goes back to being unavailable.
  void _dropPreview() {
    _preview = null;
    _previewedCsv = null;
  }

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _fileError = null;
    });
    try {
      final picked = await ref.read(csvFilePickerProvider)();
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Cancelling leaves everything as it was, preview included.
        if (picked != null) {
          _picked = picked;
          _csvCtrl.clear();
          _dropPreview();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fileError = e is CsvFileException
            ? e.message
            : 'Could not read that file.';
      });
    }
  }

  void _clearFile() {
    setState(() {
      _picked = null;
      _fileError = null;
      _dropPreview();
    });
  }

  Future<void> _runPreview() async {
    final csv = _csv;
    setState(() {
      _busy = true;
      _fileError = null;
    });
    try {
      final result = await ref
          .read(salesTargetsRepositoryProvider)
          .importCsv(csv, dryRun: true);
      if (!mounted) return;
      setState(() {
        _preview = result;
        _previewedCsv = csv;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dropPreview();
        _fileError = describeSalesTargetError(e);
        _busy = false;
      });
    }
  }

  Future<void> _apply() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(salesTargetsRepositoryProvider)
          .importCsv(_previewedCsv!, dryRun: false);
      ref.invalidate(salesAttainmentProvider);
      ref.invalidate(currentMonthAttainmentProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      final skipped = result.invalidRows > 0
          ? ' · ${result.invalidRows} rows skipped'
          : '';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Targets saved: ${result.created} created, '
            '${result.updated} updated$skipped',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fileError = describeSalesTargetError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = colors.glass ? context.lumen.inkMuted : colors.ink3;
    final crit = StatusLevel.critical.colorOf(colors);
    final preview = _preview;
    final picked = _picked;

    return AlertDialog(
      title: const Text('Upload sales targets'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a .csv file, or paste one below. It needs a header '
                'row: month (YYYY-MM), sku (id or name), targetUnits, and '
                'optionally territory or outlet (id or code). Units are '
                '$sellInLabel. Existing targets for the same SKU, month and '
                'scope are replaced.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey<String>('csv-choose-file'),
                    onPressed: _busy ? null : _chooseFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: Text(
                      picked == null ? 'Choose CSV file' : 'Choose another',
                    ),
                  ),
                  if (picked != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        picked.name,
                        key: const ValueKey<String>('csv-file-name'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey<String>('csv-clear-file'),
                      onPressed: _busy ? null : _clearFile,
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (picked == null)
                TextField(
                  key: const ValueKey<String>('csv-input'),
                  controller: _csvCtrl,
                  minLines: 5,
                  maxLines: 10,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'CSV',
                    alignLabelWithHint: true,
                    hintText:
                        'month,sku,targetUnits,territory,outlet\n'
                        '2026-09,Cola 2L,1200,,',
                  ),
                )
              else
                Text(
                  'Preview to see what this file would do. Remove it to paste '
                  'a CSV instead.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              if (_fileError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _fileError!,
                  key: const ValueKey<String>('csv-file-error'),
                  style: TextStyle(fontSize: 12.5, color: crit),
                ),
              ],
              if (preview != null) ...[
                const SizedBox(height: 12),
                GlassPane(
                  key: const ValueKey<String>('csv-preview-pane'),
                  kind: GlassKind.tile,
                  blur: false,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${preview.validRows} ready · '
                        '${preview.invalidRows} with errors · would create '
                        '${preview.created}, update ${preview.updated}',
                        key: const ValueKey<String>('csv-summary'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final (i, error)
                          in preview.errors.take(_maxErrorsShown).indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Row ${error.row}'
                            '${error.column == null ? '' : ' · ${error.column}'}'
                            ': ${error.message}',
                            key: ValueKey<String>('csv-error-$i'),
                            style: TextStyle(fontSize: 12, color: crit),
                          ),
                        ),
                      if (preview.errors.length > _maxErrorsShown)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '…and ${preview.errors.length - _maxErrorsShown} '
                            'more errors',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          key: const ValueKey<String>('csv-preview'),
          onPressed: _busy || _csv.trim().isEmpty ? null : _runPreview,
          child: const Text('Preview'),
        ),
        FilledButton(
          key: const ValueKey<String>('csv-apply'),
          onPressed: _canApply ? _apply : null,
          child: Text(
            preview == null || preview.validRows == 0
                ? 'Apply'
                : 'Apply ${preview.validRows} '
                      '${preview.validRows == 1 ? 'row' : 'rows'}',
          ),
        ),
      ],
    );
  }
}
