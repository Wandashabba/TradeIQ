import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../data/sales_targets_repository.dart';
import 'sales_attainment_panel.dart' show salesMetricLabel, salesMonthLabelIn;
import 'sales_targets_screen.dart' show describeSalesTargetError;

/// Delete one target, and say what is still true if it will not go.
Future<void> deleteSalesTarget(
  BuildContext context,
  WidgetRef ref,
  String targetId,
) async {
  final l10n = context.l10n;
  try {
    await ref.read(salesTargetsRepositoryProvider).delete(targetId);
    ref.invalidate(salesAttainmentProvider);
    ref.invalidate(currentMonthAttainmentProvider);
  } catch (error) {
    if (!context.mounted) return;
    showTorchToast(
      context,
      message: l10n.salesRemoveFailed,
      kind: ToastKind.failure,
    );
  }
}

/// CREATE OR EDIT ONE TARGET — the one modal container, not a dialog.
///
/// Editing **locks** the SKU and the scope, because those are what identify
/// the target: changing them would be a different target. A locked picker says
/// why rather than simply refusing (unify §1.10 deletes the dialog; §15.2
/// makes the sheet the one place a blocking decision is taken).
///
/// ## The amber
///
/// While this sheet is up every amber on the route beneath goes out, so the
/// sheet's own commit — declared like any other primary — is the single lit
/// object on the frame in Night, Day and Veld alike.
Future<void> showSalesTargetSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<SkuAttainment> skus,
  required DateTime month,
  String? skuId,
  String scope = 'client',
  String? territoryId,
  String? outletId,
  int? units,
  bool locked = false,
}) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => _SalesTargetSheet(
      skus: skus,
      month: month,
      skuId: skuId,
      scope: scope,
      territoryId: territoryId,
      outletId: outletId,
      units: units,
      locked: locked,
    ),
  );
}

class _SalesTargetSheet extends ConsumerStatefulWidget {
  const _SalesTargetSheet({
    required this.skus,
    required this.month,
    required this.skuId,
    required this.scope,
    required this.territoryId,
    required this.outletId,
    required this.units,
    required this.locked,
  });

  /// The commit's claim id. Rung 1, inside the sheet's own scope.
  static const String saveClaimId = 'sales-target-save';

  final List<SkuAttainment> skus;
  final DateTime month;
  final String? skuId;
  final String scope;
  final String? territoryId;
  final String? outletId;
  final int? units;
  final bool locked;

  @override
  ConsumerState<_SalesTargetSheet> createState() => _SalesTargetSheetState();
}

class _SalesTargetSheetState extends ConsumerState<_SalesTargetSheet> {
  late String? _skuId = widget.skuId;
  late String _scope = widget.scope;
  late String? _territoryId = widget.territoryId;
  late String? _outletId = widget.outletId;
  late final TextEditingController _unitsCtrl = TextEditingController(
    text: widget.units?.toString() ?? '',
  )..addListener(_onTyped);

  bool _submitting = false;
  String? _error;

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    _unitsCtrl
      ..removeListener(_onTyped)
      ..dispose();
    super.dispose();
  }

  int? get _units {
    final parsed = int.tryParse(_unitsCtrl.text.trim());
    return parsed == null || parsed < 0 ? null : parsed;
  }

  bool get _complete =>
      _skuId != null &&
      _units != null &&
      (_scope != 'territory' || _territoryId != null) &&
      (_scope != 'outlet' || _outletId != null);

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_complete) return;

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
            targetUnits: _units!,
            territoryId: _scope == 'territory' ? _territoryId : null,
            outletId: _scope == 'outlet' ? _outletId : null,
          );
      ref.invalidate(salesAttainmentProvider);
      ref.invalidate(currentMonthAttainmentProvider);
    } catch (error) {
      if (!mounted) return;
      // The sheet stays open with the server's own reason in it: a refusal
      // that closes the form has thrown away the thing the manager has to
      // fix.
      setState(() {
        _submitting = false;
        _error = describeSalesTargetError(error, l10n);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TorchSheet(
      title: widget.locked
          ? l10n.salesTargetSheetEdit
          : l10n.salesTargetSheetSet,
      subtitle: l10n.salesTargetSheetSubtitle(
        salesMetricLabel(l10n, null),
        salesMonthLabelIn(context, widget.month),
      ),
      claims: <TorchClaim>[
        TorchPrimaryButton.claim(_SalesTargetSheet.saveClaimId),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchPickerField<String>(
            key: const ValueKey<String>('target-sku'),
            label: l10n.salesTargetSku,
            value: _skuId,
            options: <PickerOption<String>>[
              for (final sku in widget.skus)
                PickerOption<String>(value: sku.skuId, label: sku.skuName),
            ],
            notChosenLine: l10n.salesTargetSkuNotChosen,
            enabled: !widget.locked,
            disabledReason: l10n.salesTargetSkuLocked,
            onChanged: (id) => setState(() => _skuId = id),
          ),
          const SizedBox(height: TiqSpace.s5),

          // Three options with a consequence each: a choice row, which is
          // exactly what unify §C.38 is for.
          ChoiceRow<String>(
            key: const ValueKey<String>('target-scope'),
            label: l10n.salesTargetScope,
            value: _scope,
            notAnsweredLine: l10n.salesTargetScopeLocked,
            options: <ChoiceOption<String>>[
              ChoiceOption<String>(
                value: 'client',
                label: l10n.salesScopeAccount,
                consequence: l10n.salesTargetScopeAccountConsequence,
                enabled: !widget.locked,
                disabledReason: l10n.salesTargetScopeLocked,
              ),
              ChoiceOption<String>(
                value: 'territory',
                label: l10n.salesScopeTerritory,
                consequence: l10n.salesTargetScopeTerritoryConsequence,
                enabled: !widget.locked,
                disabledReason: l10n.salesTargetScopeLocked,
              ),
              ChoiceOption<String>(
                value: 'outlet',
                label: l10n.salesScopeOutlet,
                consequence: l10n.salesTargetScopeOutletConsequence,
                enabled: !widget.locked,
                disabledReason: l10n.salesTargetScopeLocked,
              ),
            ],
            onChanged: widget.locked
                ? null
                : (value) => setState(() => _scope = value),
          ),
          if (_scope == 'territory') ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            _TerritoryPicker(
              value: _territoryId,
              locked: widget.locked,
              onChanged: (id) => setState(() => _territoryId = id),
            ),
          ],
          if (_scope == 'outlet') ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            _OutletPicker(
              value: _outletId,
              locked: widget.locked,
              onChanged: (id) => setState(() => _outletId = id),
            ),
          ],
          const SizedBox(height: TiqSpace.s5),

          TorchTextField(
            key: const ValueKey<String>('target-units'),
            label: l10n.salesTargetUnits,
            controller: _unitsCtrl,
            help: l10n.salesTargetUnitsHelp,
            error: _unitsCtrl.text.trim().isEmpty || _units != null
                ? null
                : l10n.salesTargetUnitsMissing,
            keyboardType: const TextInputType.numberWithOptions(),
            autocorrect: false,
            identifier: true,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s5),
            ErrorState(
              key: const ValueKey<String>('target-error'),
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.rejected,
                headline: l10n.salesTargetsLoadErrorHeadline,
                body: _error!,
                offersRetry: false,
              ),
            ),
          ],
          const SizedBox(height: TiqSpace.s7),

          TorchPrimaryButton(
            key: const ValueKey<String>('target-save'),
            label: l10n.salesTargetSave,
            claimId: _SalesTargetSheet.saveClaimId,
            busy: _submitting,
            blockedReason: _complete ? null : l10n.salesTargetBlocked,
            onPressed: _complete && !_submitting ? _save : null,
          ),
          const SizedBox(height: TiqSpace.s3),
          TorchSecondaryButton(
            key: const ValueKey<String>('target-cancel'),
            label: l10n.salesTargetCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _TerritoryPicker extends ConsumerWidget {
  const _TerritoryPicker({
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  final String? value;
  final bool locked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final territories = ref.watch(territoriesListProvider);

    return territories.when(
      loading: () => Skeleton(
        label: l10n.salesScopeTerritory,
        child: const SkeletonShell(height: 72, outlined: true),
      ),
      error: (error, stack) => ErrorState(
        scope: ErrorScope.inline,
        message: TorchErrorMessage(
          kind: TorchErrorKind.unknown,
          headline: l10n.createOutletTerritoriesFailed,
          body: describeSalesTargetError(error, l10n),
          offersRetry: true,
        ),
        action: TorchSecondaryButton(
          key: const ValueKey<String>('target-territories-retry'),
          label: l10n.salesTargetsRetry,
          onPressed: () => ref.invalidate(territoriesListProvider),
        ),
      ),
      data: (list) => TorchPickerField<String>(
        key: const ValueKey<String>('target-territory'),
        label: l10n.salesScopeTerritory,
        value: value,
        options: <PickerOption<String>>[
          for (final territory in list)
            PickerOption<String>(
              value: territory.id,
              label: territory.name,
              identifier: territory.code,
            ),
        ],
        notChosenLine: l10n.salesTargetTerritoryNotChosen,
        enabled: !locked,
        disabledReason: l10n.salesTargetScopeLocked,
        onChanged: onChanged,
      ),
    );
  }
}

class _OutletPicker extends ConsumerWidget {
  const _OutletPicker({
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  final String? value;
  final bool locked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final outlets = ref.watch(outletsListProvider);

    return outlets.when(
      loading: () => Skeleton(
        label: l10n.salesScopeOutlet,
        child: const SkeletonShell(height: 72, outlined: true),
      ),
      error: (error, stack) => ErrorState(
        scope: ErrorScope.inline,
        message: TorchErrorMessage(
          kind: TorchErrorKind.unknown,
          headline: l10n.orderFormStoresFailed,
          body: describeSalesTargetError(error, l10n),
          offersRetry: true,
        ),
        action: TorchSecondaryButton(
          key: const ValueKey<String>('target-outlets-retry'),
          label: l10n.salesTargetsRetry,
          onPressed: () => ref.invalidate(outletsListProvider),
        ),
      ),
      data: (list) => TorchPickerField<String>(
        key: const ValueKey<String>('target-outlet'),
        label: l10n.salesScopeOutlet,
        value: value,
        options: <PickerOption<String>>[
          for (final outlet in list)
            PickerOption<String>(
              value: outlet.id,
              label: outlet.name,
              identifier: outlet.code,
            ),
        ],
        notChosenLine: l10n.salesTargetOutletNotChosen,
        enabled: !locked,
        disabledReason: l10n.salesTargetScopeLocked,
        onChanged: onChanged,
      ),
    );
  }
}
