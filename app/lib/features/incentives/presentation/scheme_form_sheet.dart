import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/incentives_repository.dart';
import '../data/incentives_view.dart';

/// The claim this sheet's commit asks for.
const String kSchemeFormClaimId = 'create-scheme';

/// ADDING A SCHEME — the one modal container, not a dialog.
///
/// `AlertDialog` is deleted outright (unify §1.7): a non-dismissible bottom
/// sheet covers every blocking case a dialog covered, and two modal containers
/// is two sets of insets, two dismissal rules, two scrims and two answers to
/// what happens to the amber underneath.
Future<void> showSchemeFormSheet(BuildContext context, WidgetRef ref) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => const _SchemeFormSheet(),
  );
}

class _SchemeFormSheet extends ConsumerStatefulWidget {
  const _SchemeFormSheet();

  @override
  ConsumerState<_SchemeFormSheet> createState() => _SchemeFormSheetState();
}

class _SchemeFormSheetState extends ConsumerState<_SchemeFormSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _threshold = TextEditingController();
  final TextEditingController _reward = TextEditingController();

  IncentiveMetric? _metric;
  bool _busy = false;
  bool _attempted = false;
  String? _failure;

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    _reward.dispose();
    super.dispose();
  }

  String? get _nameError => _attempted && _name.text.trim().isEmpty
      ? context.l10n.schemeFormNameError
      : null;

  double? get _thresholdValue => double.tryParse(
    // A comma is the decimal mark in Afrikaans, and a manager typing 4,5 on
    // an Afrikaans phone means four and a half.
    _threshold.text.trim().replaceAll(',', '.'),
  );

  int? get _rewardValue => int.tryParse(_reward.text.trim());

  String? get _thresholdError {
    if (!_attempted) return null;
    final value = _thresholdValue;
    if (value == null) return context.l10n.schemeFormThresholdError;
    if (value <= 0) return context.l10n.schemeFormThresholdZero;
    return null;
  }

  String? get _rewardError {
    if (!_attempted) return null;
    final value = _rewardValue;
    if (value == null) return context.l10n.schemeFormRewardError;
    if (value <= 0) return context.l10n.schemeFormRewardZero;
    return null;
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _metric != null &&
      (_thresholdValue ?? 0) > 0 &&
      (_rewardValue ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return TorchSheet(
      title: l10n.schemeFormTitle,
      subtitle: l10n.schemeFormSubtitle,
      claims: const <TorchClaim>[
        TorchClaim.primaryCommit(kSchemeFormClaimId),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('new-name'),
            label: l10n.schemeFormName,
            controller: _name,
            hint: l10n.schemeFormNameHint,
            error: _nameError,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TiqSpace.s5),
          // Nothing-selected is a state and it says so: a metric the manager
          // did not choose must never be silently defaulted to "scorecard",
          // which is a different scheme from the one they meant.
          ChoiceRow<IncentiveMetric>(
            key: const ValueKey<String>('new-metric'),
            label: l10n.schemeFormMetricLabel,
            forceColumn: true,
            notAnsweredLine: l10n.schemeFormMetricNotAnswered,
            error: _attempted && _metric == null
                ? l10n.schemeFormMetricError
                : null,
            value: _metric,
            options: <ChoiceOption<IncentiveMetric>>[
              ChoiceOption<IncentiveMetric>(
                value: IncentiveMetric.scorecard,
                label: IncentiveMetric.scorecard.label(l10n),
                consequence: l10n.schemeFormScorecardConsequence,
              ),
              ChoiceOption<IncentiveMetric>(
                value: IncentiveMetric.tasksClosed,
                label: IncentiveMetric.tasksClosed.label(l10n),
                consequence: l10n.schemeFormTasksConsequence,
              ),
              ChoiceOption<IncentiveMetric>(
                value: IncentiveMetric.visits,
                label: IncentiveMetric.visits.label(l10n),
                consequence: l10n.schemeFormVisitsConsequence,
              ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _metric = value),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchNumericField(
            key: const ValueKey<String>('new-threshold'),
            label: l10n.schemeFormThreshold,
            controller: _threshold,
            decimals: 1,
            help: _metric == null
                ? l10n.schemeFormThresholdHelp
                : l10n.schemeFormThresholdHelpUnit(_metric!.unitWord(l10n)),
            error: _thresholdError,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchNumericField(
            key: const ValueKey<String>('new-reward-points'),
            label: l10n.schemeFormReward,
            controller: _reward,
            unit: TiqUnit.worded(l10n.pointsUnitWord),
            help: l10n.schemeFormRewardHelp,
            error: _rewardError,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          if (_failure != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s4),
            Text(
              _failure!,
              key: const ValueKey<String>('new-scheme-failure'),
              style: skin.text.meta.style(color: skin.palette.bad),
            ),
          ],
          const SizedBox(height: TiqSpace.s6),
          TorchPrimaryButton(
            key: const ValueKey<String>('create-scheme'),
            claimId: kSchemeFormClaimId,
            label: l10n.schemeFormSave,
            busy: _busy,
            blockedReason: _ready ? null : l10n.schemeFormBlocked,
            onPressed: _busy || !_ready ? null : _create,
          ),
          const SizedBox(height: TiqSpace.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('cancel-scheme'),
              label: l10n.schemeFormNotNow,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      _attempted = true;
      _failure = null;
    });
    if (!_ready) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(incentivesRepositoryProvider)
          .createScheme(
            name: _name.text.trim(),
            metric: _metric!.wire,
            threshold: _thresholdValue!,
            rewardPoints: _rewardValue!,
          );
      if (!mounted) return;
      ref.invalidate(incentivesViewProvider);
      ref.invalidate(incentivesListProvider);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      // The sheet stays open on a failure, with what the manager typed still
      // in it: a form that closes and loses four fields is a form nobody
      // retries.
      setState(() {
        _busy = false;
        _failure = TorchErrorMessage.sanitise(error).headline;
      });
    }
  }
}
