import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/sales_targets_repository.dart';
import 'sales_targets_screen.dart' show describeSalesTargetError;

/// Choose a `.csv` — or paste one — preview what it would do, then apply the
/// rows that are good.
Future<void> showSalesImportSheet(BuildContext context, WidgetRef ref) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => const _SalesImportSheet(),
  );
}

/// THE DRY RUN IS A DESIGNED STATE, not a paragraph of red text.
///
/// ```text
///   Upload sales targets                        ✕
///   Preview what a file would do, then apply the
///   rows that are good.
///   [ Choose a CSV file ]  september.csv  [Remove]
///   ┌──────────────────┐┌──────────────────┐
///   │ ROWS READY   118 ││ ROWS WITH ERR  4 │
///   └──────────────────┘└──────────────────┘
///   Would create 96 and update 22.
///   ── What is wrong ────────────────────────
///   ▌ Row 12 · sku: no SKU called "Cola 2l"
///   [        Apply 118 rows        ]
/// ```
///
/// Two figures rather than a run-on sentence: how many rows would be written,
/// and how many would not. The errors are **rows**, each one severity-barred
/// with the word, so a manager can read down them the way they read any other
/// worklist.
///
/// **Apply is only ever offered for exactly the text that was previewed.** Pick
/// a different file, edit the paste, or clear the file, and it must be
/// previewed again — what gets written is always what was shown, and the
/// button's blocked reason says so.
class _SalesImportSheet extends ConsumerStatefulWidget {
  const _SalesImportSheet();

  /// The commit's claim id. Rung 1, inside the sheet's own scope.
  static const String applyClaimId = 'sales-import-apply';

  @override
  ConsumerState<_SalesImportSheet> createState() => _SalesImportSheetState();
}

class _SalesImportSheetState extends ConsumerState<_SalesImportSheet> {
  static const int _maxErrorsShown = 50;

  final TextEditingController _csvCtrl = TextEditingController();

  /// The chosen file, while one is held. A file and the paste box are the two
  /// ways in, and only one is live at a time: while a file is held the box is
  /// hidden, so there is never a question about which of the two would upload.
  PickedCsv? _picked;
  SalesTargetImportResult? _preview;
  String? _previewedCsv;
  String? _fileError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _csvCtrl.addListener(_onTyped);
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    _csvCtrl
      ..removeListener(_onTyped)
      ..dispose();
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
    final l10n = context.l10n;
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fileError = error is CsvFileException
            ? error.message
            : l10n.salesImportFileUnreadable;
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
    final l10n = context.l10n;
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dropPreview();
        _fileError = describeSalesTargetError(error, l10n);
        _busy = false;
      });
    }
  }

  Future<void> _apply() async {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    setState(() => _busy = true);
    final SalesTargetImportResult result;
    try {
      result = await ref
          .read(salesTargetsRepositoryProvider)
          .importCsv(_previewedCsv!, dryRun: false);
      ref.invalidate(salesAttainmentProvider);
      ref.invalidate(currentMonthAttainmentProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fileError = describeSalesTargetError(error, l10n);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final message = result.invalidRows > 0
        ? l10n.salesImportAppliedSkipped(
            numbers.format(result.created),
            numbers.format(result.updated),
            numbers.format(result.invalidRows),
          )
        : l10n.salesImportApplied(
            numbers.format(result.created),
            numbers.format(result.updated),
          );
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    showTorchToast(context, message: message, kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final preview = _preview;
    final picked = _picked;

    return TorchSheet(
      title: l10n.salesImportTitle,
      subtitle: l10n.salesImportSubtitle,
      claims: <TorchClaim>[
        TorchPrimaryButton.claim(_SalesImportSheet.applyClaimId),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.salesImportFormat,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s5),

          TorchSecondaryButton(
            key: const ValueKey<String>('csv-choose-file'),
            label: picked == null
                ? l10n.salesImportChooseFile
                : l10n.salesImportChooseAnother,
            icon: Icons.folder_open_outlined,
            onPressed: _busy ? null : _chooseFile,
          ),
          if (picked != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            SoftRow(
              key: const ValueKey<String>('csv-file-name'),
              form: SoftRowForm.standalone,
              density: SoftRowDensity.compact,
              title: picked.name,
              trailingIsControl: true,
              trailing: TorchIconButton(
                key: const ValueKey<String>('csv-clear-file'),
                icon: Icons.close,
                semanticLabel: l10n.salesImportRemoveFile,
                onPressed: _busy ? null : _clearFile,
              ),
            ),
            const SizedBox(height: TiqSpace.s3),
            Text(
              l10n.salesImportFileHeld,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ] else ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            TorchTextField(
              key: const ValueKey<String>('csv-input'),
              label: l10n.salesImportPasteLabel,
              controller: _csvCtrl,
              hint: l10n.salesImportPasteHint,
              minLines: 5,
              maximumLines: 10,
              autocorrect: false,
              identifier: true,
              onChanged: (_) => setState(_dropPreview),
            ),
          ],

          if (_fileError != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            ErrorState(
              key: const ValueKey<String>('csv-file-error'),
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.rejected,
                headline: l10n.salesImportTitle,
                body: _fileError!,
                offersRetry: false,
              ),
            ),
          ],

          if (preview != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s7),
            _DryRun(result: preview, maxErrorsShown: _maxErrorsShown),
          ],

          const SizedBox(height: TiqSpace.s7),
          TorchSecondaryButton(
            key: const ValueKey<String>('csv-preview'),
            label: l10n.salesImportPreview,
            busy: _busy && _preview == null,
            onPressed: _busy || _csv.trim().isEmpty ? null : _runPreview,
          ),
          const SizedBox(height: TiqSpace.s3),
          TorchPrimaryButton(
            key: const ValueKey<String>('csv-apply'),
            label: preview == null || preview.validRows == 0
                ? l10n.salesImportApply
                : l10n.salesImportApplyRows(preview.validRows),
            claimId: _SalesImportSheet.applyClaimId,
            busy: _busy && _preview != null,
            blockedReason: _canApply
                ? null
                : (preview != null &&
                          _previewedCsv == _csv &&
                          preview.validRows == 0
                      ? l10n.salesImportBlockedNoRows
                      : l10n.salesImportBlockedPreview),
            onPressed: _canApply ? _apply : null,
          ),
        ],
      ),
    );
  }
}

/// WHAT THE FILE WOULD DO — two figures and a worklist of what is wrong.
class _DryRun extends StatelessWidget {
  const _DryRun({required this.result, required this.maxErrorsShown});

  final SalesTargetImportResult result;
  final int maxErrorsShown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final shown = result.errors.take(maxErrorsShown).toList();
    final hidden = result.errors.length - shown.length;

    return Column(
      key: const ValueKey<String>('csv-preview-pane'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StatCluster(
          semanticsLabel: l10n.salesImportTitle,
          tiles: <StatTile>[
            StatTile(
              key: const ValueKey<String>('csv-ready'),
              eyebrow: l10n.salesImportReadyEyebrow,
              // A measured zero: a file where nothing can be written says 0,
              // and the Apply button says why it is dead.
              value: result.validRows,
              severity: result.validRows == 0
                  ? SeverityMarkKind.critical
                  : null,
            ),
            StatTile(
              key: const ValueKey<String>('csv-errors'),
              eyebrow: l10n.salesImportErrorsEyebrow,
              value: result.invalidRows,
              severity: result.invalidRows > 0 ? SeverityMarkKind.watch : null,
            ),
          ],
        ),
        const SizedBox(height: TiqSpace.s4),
        Text(
          key: const ValueKey<String>('csv-summary'),
          l10n.salesImportWouldDo(
            numbers.format(result.created),
            numbers.format(result.updated),
          ),
          style: skin.text.body.style(color: skin.palette.ink2),
        ),
        const SizedBox(height: TiqSpace.s6),

        SectionRule(
          l10n.salesImportErrorsHeading,
          count: result.errors.isEmpty ? null : result.errors.length,
          emptyLine: result.errors.isEmpty
              ? l10n.salesImportNothingWrong
              : null,
        ),
        if (shown.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s4),
          for (var i = 0; i < shown.length; i++)
            SoftRow(
              key: ValueKey<String>('csv-error-$i'),
              density: SoftRowDensity.compact,
              title: shown[i].column == null
                  ? l10n.salesImportRowError(
                      numbers.format(shown[i].row),
                      shown[i].message,
                    )
                  : l10n.salesImportRowErrorColumn(
                      numbers.format(shown[i].row),
                      shown[i].column!,
                      shown[i].message,
                    ),
              severity: SoftRowSeverity.watch,
              severityLabel: l10n.salesImportErrorsEyebrow,
              separator: i == shown.length - 1
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
            ),
          if (hidden > 0) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            Text(
              l10n.salesImportMoreErrors(numbers.format(hidden)),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],
        ],
      ],
    );
  }
}
