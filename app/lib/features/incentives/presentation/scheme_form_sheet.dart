import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
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

  String? get _nameError =>
      _attempted && _name.text.trim().isEmpty ? 'Give the scheme a name.' : null;

  double? get _thresholdValue => double.tryParse(
    // A comma is the decimal mark in Afrikaans, and a manager typing 4,5 on
    // an Afrikaans phone means four and a half.
    _threshold.text.trim().replaceAll(',', '.'),
  );

  int? get _rewardValue => int.tryParse(_reward.text.trim());

  String? get _thresholdError {
    if (!_attempted) return null;
    final value = _thresholdValue;
    if (value == null) return 'Say the figure an agent has to reach.';
    if (value <= 0) {
      return 'A threshold of nought is a scheme that pays out to everybody '
          'the moment it is created.';
    }
    return null;
  }

  String? get _rewardError {
    if (!_attempted) return null;
    final value = _rewardValue;
    if (value == null) return 'Say how many points it awards.';
    if (value <= 0) return 'A reward of nought is not a reward.';
    return null;
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _metric != null &&
      (_thresholdValue ?? 0) > 0 &&
      (_rewardValue ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchSheet(
      title: 'Add a scheme',
      subtitle: 'It starts awarding as soon as it is saved.',
      claims: const <TorchClaim>[
        TorchClaim.primaryCommit(kSchemeFormClaimId),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('new-name'),
            label: 'Name',
            controller: _name,
            hint: 'What a manager will call it — "Twenty visits"',
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
            label: 'What it pays on',
            forceColumn: true,
            notAnsweredLine: 'No metric chosen yet',
            error: _attempted && _metric == null
                ? 'Choose what the scheme pays on.'
                : null,
            value: _metric,
            options: const <ChoiceOption<IncentiveMetric>>[
              ChoiceOption<IncentiveMetric>(
                value: IncentiveMetric.scorecard,
                label: 'Average scorecard',
                consequence: 'Pays when the agent\'s 0–100 mean clears the '
                    'threshold.',
              ),
              ChoiceOption<IncentiveMetric>(
                value: IncentiveMetric.tasksClosed,
                label: 'Tasks closed',
                consequence: 'Pays on a count of closures.',
              ),
              ChoiceOption<IncentiveMetric>(
                value: IncentiveMetric.visits,
                label: 'Visits submitted',
                consequence: 'Pays on a count of submitted visits.',
              ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _metric = value),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchNumericField(
            key: const ValueKey<String>('new-threshold'),
            label: 'Threshold',
            controller: _threshold,
            decimals: 1,
            help: _metric == null
                ? 'What an agent has to reach.'
                : 'What an agent has to reach, in ${_metric!.unitWord}.',
            error: _thresholdError,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchNumericField(
            key: const ValueKey<String>('new-reward-points'),
            label: 'Reward',
            controller: _reward,
            unit: TiqUnit.worded('pts'),
            help: 'What clearing it awards.',
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
            label: 'Save this scheme',
            busy: _busy,
            blockedReason: _ready
                ? null
                : 'A scheme needs a name, a metric, a threshold and a reward.',
            onPressed: _busy || !_ready ? null : _create,
          ),
          const SizedBox(height: TiqSpace.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('cancel-scheme'),
              label: 'Not now',
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
