import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/alerts_repository.dart';

/// The severities the console understands. The API takes any string, but these
/// are the three the rest of the app renders — Alerts triages `critical` apart
/// from everything else, and the column defaults to `normal` — so offering a
/// fourth would produce alerts no screen has a word for.
const List<String> _severities = <String>['critical', 'warning', 'normal'];

String _metricLabel(String metric) => switch (metric) {
  'out_of_stock' => 'Out of stock',
  'price_deviation' => 'Price deviation',
  'low_scorecard' => 'Low scorecard',
  _ => metric,
};

/// The condition as a sentence. The number lives beside it as a figure rather
/// than inside the prose, so the sentence is language and the threshold is a
/// measurement.
String _conditionSentence(AlertRule rule) => switch (rule.metric) {
  'out_of_stock' => 'Fires when a product is found out of stock on a visit.',
  'price_deviation' =>
    'Fires when a shelf price deviates from the published band.',
  'low_scorecard' => 'Fires when a submitted visit scores below the line.',
  _ => 'Fires on every submitted visit that matches this metric.',
};

/// WHAT RAISES THE ROWS — visible and editable, one hop from the worklist.
///
/// ```text
///   ← Back to alerts
///   Alert rules
///   A rule evaluates on every visit submit. Turning one off
///   stops new alerts; it does not clear existing ones.
///   ( All metrics )( Out of stock )( Price deviation )…
///   ── Active 6 ─────────────────────────────
///   Out of stock alert                   [ On ]
///   Fires when a product is found out of stock on a visit.
///   ▲ Critical · out_of_stock · threshold 50
///   ── Off 2 ────────────────────────────────
///   …
///   New rule
/// ```
///
/// ## The one amber
///
/// The nav pill's active block, and nothing else: a configuration list has
/// nothing happening in it. The create and edit forms are sheets, and each
/// spends its own single grant on its commit action while the route beneath
/// goes dark.
///
/// **The dialog is gone.** Unify §1.7 deleted it outright — `Create Alert
/// Rule` and `Edit rule` are the one modal container, with the trough grammar
/// inside them.
class AlertRulesScreen extends ConsumerStatefulWidget {
  const AlertRulesScreen({super.key});

  @override
  ConsumerState<AlertRulesScreen> createState() => _AlertRulesScreenState();
}

class _AlertRulesScreenState extends ConsumerState<AlertRulesScreen> {
  String? _metric;

  void _refresh() => ref.invalidate(alertRulesListProvider);

  /// Only one active rule drives each metric — the evaluator takes the newest
  /// and ignores the rest. `GET /alerts/rules` returns newest-first, so the
  /// first active rule seen for a metric is the winner and any later one is
  /// dead config. Say so on the row rather than let it fail silently.
  Set<String> _shadowed(List<AlertRule> rules) {
    final winners = <String>{};
    final shadowed = <String>{};
    for (final rule in rules) {
      if (!rule.active) continue;
      if (!winners.add(rule.metric)) shadowed.add(rule.id);
    }
    return shadowed;
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(alertRulesListProvider);

    return rules.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(label: 'alert rules', child: const SkeletonRows(count: 4)),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'alert rules',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('rules-retry'),
                label: 'Try again',
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: _loaded,
    );
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Alert rules',
        facts: const <String>[
          'A rule evaluates on every visit submit. Turning one off stops new '
              'alerts; it does not clear existing ones.',
        ],
        back: TorchIconButton(
          key: const ValueKey<String>('back-to-alerts'),
          icon: Icons.arrow_back,
          semanticLabel: 'Back to alerts',
          onPressed: () => context.go('/alerts'),
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(List<AlertRule> list) {
    // Shadowing is a property of the whole list, so it is computed before the
    // filter narrows what is on screen.
    final shadowed = _shadowed(list);
    final visible = _metric == null
        ? list
        : list.where((r) => r.metric == _metric).toList();
    final active = visible.where((r) => r.active).toList();
    final off = visible.where((r) => !r.active).toList();
    final gutter = context.skin.space.gutter;

    return _frame(
      phase: list.isEmpty
          ? 'empty'
          : visible.isEmpty
          ? 'filtered-empty'
          : 'loaded',
      children: <Widget>[
        TorchBleed(
          extra: gutter * 2,
          child: TorchFilterRail(
            semanticsLabel: 'Filter by metric',
            chips: <Widget>[
              TorchFilterChip(
                key: const ValueKey<String>('filter-metric-all'),
                label: 'All metrics',
                count: list.length,
                selected: _metric == null,
                onSelected: () => setState(() => _metric = null),
              ),
              for (final metric in alertRuleMetrics)
                TorchFilterChip(
                  key: ValueKey<String>('filter-metric-$metric'),
                  label: _metricLabel(metric),
                  count: list.where((r) => r.metric == metric).length,
                  selected: _metric == metric,
                  onSelected: () => setState(() => _metric = metric),
                ),
            ],
          ),
        ),
        const SizedBox(height: TiqSpace.s6),

        if (list.isEmpty)
          const EmptyState(
            scope: EmptyScope.inPanel,
            headline: 'No rules yet.',
            body: 'Alerts only exist because a rule says so.',
          )
        else if (visible.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: 'No rules for ${_metricLabel(_metric!).toLowerCase()}.',
            body: 'Clear the filter to see the rest.',
            action: TorchSecondaryButton(
              key: const ValueKey<String>('clear-metric-filter'),
              label: 'Show all metrics',
              onPressed: () => setState(() => _metric = null),
            ),
          )
        else ...<Widget>[
          // A section that vanishes when empty makes a manager think the
          // feature is gone, so both rules render whatever the counts are.
          SectionRule('Active', count: active.isEmpty ? null : active.length),
          const SizedBox(height: TiqSpace.s5),
          if (active.isEmpty)
            const EmptyState(
              scope: EmptyScope.inline,
              headline: 'Nothing is active.',
              body: 'No alert will be raised until one of these is turned on.',
            )
          else
            TorchBleed(
              extra: gutter * 2,
              child: _RuleList(rules: active, shadowed: shadowed),
            ),
          const SizedBox(height: TiqSpace.s8),
          SectionRule('Off', count: off.isEmpty ? null : off.length),
          const SizedBox(height: TiqSpace.s5),
          if (off.isEmpty)
            const EmptyState(
              scope: EmptyScope.inline,
              headline: 'Nothing is switched off.',
              body: 'Every rule you have configured is evaluating.',
            )
          else
            TorchBleed(
              extra: gutter * 2,
              child: _RuleList(rules: off, shadowed: shadowed),
            ),
        ],

        const SizedBox(height: TiqSpace.s7),
        // A ghost at the foot of the list, not a floating button: a FAB here
        // would collide with the nav circle's position vocabulary.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('add-rule'),
            label: 'New rule',
            onPressed: () => showRuleFormSheet(context, rule: null),
          ),
        ),
      ],
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({required this.rules, required this.shadowed});

  final List<AlertRule> rules;
  final Set<String> shadowed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < rules.length; i++)
          _RuleRow(
            key: ValueKey<String>('rule-row-${rules[i].id}'),
            rule: rules[i],
            shadowed: shadowed.contains(rules[i].id),
            last: i == rules.length - 1,
          ),
      ],
    );
  }
}

/// One rule, as a row.
///
/// Severity is a mark plus a word on the second line, never the row's colour:
/// a rule's configured severity is a fact about future alerts, not a verdict
/// about this row.
class _RuleRow extends ConsumerStatefulWidget {
  const _RuleRow({
    super.key,
    required this.rule,
    required this.shadowed,
    required this.last,
  });

  final AlertRule rule;

  /// True when an active rule is outranked by a newer active rule on the same
  /// metric — it is configured, but it will never fire.
  final bool shadowed;

  final bool last;

  @override
  ConsumerState<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends ConsumerState<_RuleRow> {
  bool _busy = false;

  Future<void> _setActive(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(alertRulesRepositoryProvider)
          .updateRule(widget.rule.id, active: value);
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(alertRulesListProvider);
    } catch (error) {
      if (!mounted) return;
      // The switch reverts because the list never changed — and the toast
      // says so, rather than leaving a control showing a state the server
      // does not hold.
      setState(() => _busy = false);
      showTorchToast(
        context,
        message: value
            ? 'That rule was not turned on.'
            : 'That rule was not turned off.',
        kind: ToastKind.failure,
        action: TorchTertiaryButton(
          label: 'Try again',
          onPressed: () => _setActive(value),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final rule = widget.rule;
    final severity = switch (rule.severity) {
      'critical' => SeverityMarkKind.critical,
      'warning' => SeverityMarkKind.watch,
      _ => SeverityMarkKind.held,
    };
    final word = SeverityMarkToken.of(skin, severity).word;
    final metaInk = rule.active ? p.ink3 : p.inkMute;

    return SoftRow(
      key: ValueKey<String>('rule-${rule.id}'),
      density: SoftRowDensity.tall,
      title: rule.name,
      subtitle: _conditionSentence(rule),
      enabled: rule.active,
      meta: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TiqSpace.s2,
        children: <Widget>[
          SeverityMark(kind: severity),
          Text(word, style: skin.text.meta.style(color: metaInk)),
          // The metric is what the evaluator matches on, so it wears the
          // identifier face — a manager can quote it straight back at the API.
          Text(rule.metric, style: skin.text.monoIdent.style(color: metaInk)),
          if (rule.threshold == null)
            Text(
              'the server’s own threshold',
              style: skin.text.meta.style(color: metaInk),
            )
          else ...<Widget>[
            // Two `Wrap` children rather than a `Row`, so at 2.0× the word and
            // the figure break onto separate lines instead of a fixed-width
            // pair running off the text column.
            Text('threshold', style: skin.text.meta.style(color: metaInk)),
            FigureSlot(
              value: rule.threshold,
              role: skin.text.figureS,
              // The metric's precision, not the value's: a threshold of 60 is
              // "60", never "60.0".
              decimals: rule.threshold! == rule.threshold!.roundToDouble()
                  ? 0
                  : 1,
              color: metaInk,
            ),
          ],
          if (widget.shadowed)
            Text(
              '· shadowed by a newer active rule',
              style: skin.text.meta.style(color: p.ink3),
            ),
        ],
      ),
      trailing: TorchIconButton(
        key: ValueKey<String>('toggle-${rule.id}'),
        icon: rule.active
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        toggledOn: rule.active,
        stateWord: rule.active ? 'On' : null,
        semanticLabel: rule.active
            ? 'Turn ${rule.name} off'
            : 'Turn ${rule.name} on',
        onPressed: _busy ? null : () => _setActive(!rule.active),
      ),
      // The whole row opens the form. No inline threshold editing in a list:
      // a stray tap must never change what raises an alert.
      onTap: () => showRuleFormSheet(context, rule: rule),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        rule.name,
        rule.active ? 'On' : 'Off',
        word,
        _conditionSentence(rule),
        if (widget.shadowed) 'Shadowed by a newer active rule',
      ].join('. '),
    );
  }
}

/// CREATE OR EDIT A RULE — the one modal container, with the trough grammar
/// inside it.
///
/// A form is a form, and it is the one place on the console a panel-shaped
/// block is legal. It opens as a sheet rather than a dialog because unify §1.7
/// deleted the dialog: one set of insets, one dismissal rule, one answer to
/// what happens to the amber underneath.
Future<void> showRuleFormSheet(
  BuildContext context, {
  required AlertRule? rule,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _RuleFormSheet(rule: rule),
  );
}

class _RuleFormSheet extends ConsumerStatefulWidget {
  const _RuleFormSheet({required this.rule});

  /// Null creates; non-null edits.
  final AlertRule? rule;

  @override
  ConsumerState<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends ConsumerState<_RuleFormSheet> {
  static const String commitClaimId = 'save-alert-rule';

  final TextEditingController _name = TextEditingController();
  late final TextEditingController _threshold = TextEditingController(
    text: widget.rule?.threshold == null ? '' : _plain(widget.rule!.threshold!),
  );

  late String _metric = widget.rule?.metric ?? alertRuleMetrics.first;
  late String _severity = _severities.contains(widget.rule?.severity)
      ? widget.rule!.severity
      : 'normal';

  bool _submitting = false;
  String? _nameError;
  String? _thresholdError;
  TorchErrorMessage? _failure;

  bool get _isEdit => widget.rule != null;

  static String _plain(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final raw = _threshold.text.trim();
    // Blank means "let the server pick its default"; anything else must parse,
    // because the API only accepts a number.
    final threshold = raw.isEmpty
        ? null
        : double.tryParse(raw.replaceAll(',', '.'));

    setState(() {
      _nameError = !_isEdit && name.isEmpty ? 'A rule needs a name.' : null;
      _thresholdError = raw.isNotEmpty && threshold == null
          ? 'A threshold is a number.'
          : null;
      _failure = null;
    });
    if (_nameError != null || _thresholdError != null) return;

    setState(() => _submitting = true);
    try {
      final repository = ref.read(alertRulesRepositoryProvider);
      if (_isEdit) {
        // Severity always goes, so the PATCH never sends an empty body — the
        // API rejects one that changes nothing.
        await repository.updateRule(
          widget.rule!.id,
          threshold: threshold,
          severity: _severity,
        );
      } else {
        await repository.createRule(
          name: name,
          metric: _metric,
          threshold: threshold,
          severity: _severity,
        );
      }
      ref.invalidate(alertRulesListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      // The sheet stays open with everything typed still in it.
      setState(() {
        _submitting = false;
        _failure = TorchErrorMessage.sanitise(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TorchSheet(
      title: _isEdit ? widget.rule!.name : 'New alert rule',
      subtitle: _isEdit
          ? 'A rule evaluates on every visit submit.'
          : 'A rule is the only thing that raises an alert.',
      claims: const <TorchClaim>[TorchClaim.primaryCommit(commitClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!_isEdit) ...<Widget>[
            TorchTextField(
              key: const ValueKey<String>('new-rule-name'),
              label: 'Name',
              controller: _name,
              error: _nameError,
              help: 'What a manager will read on the worklist.',
            ),
            const SizedBox(height: TiqSpace.s5),
            ChoiceRow(
              key: const ValueKey<String>('new-rule-metric'),
              label: 'Metric',
              value: _metric,
              options: <ChoiceOption<String>>[
                for (final metric in alertRuleMetrics)
                  ChoiceOption<String>(
                    value: metric,
                    label: _metricLabel(metric),
                  ),
              ],
              onChanged: (value) => setState(() => _metric = value),
            ),
            const SizedBox(height: TiqSpace.s5),
          ],
          ChoiceRow(
            key: const ValueKey<String>('rule-severity'),
            label: 'Severity',
            value: _severity,
            options: <ChoiceOption<String>>[
              for (final severity in _severities)
                ChoiceOption<String>(
                  value: severity,
                  label: severity[0].toUpperCase() + severity.substring(1),
                ),
            ],
            onChanged: (value) => setState(() => _severity = value),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchNumericField(
            key: const ValueKey<String>('rule-threshold'),
            label: 'Threshold',
            controller: _threshold,
            error: _thresholdError,
            // The API has no way to unset a threshold, only to overwrite one,
            // so blank cannot mean "clear it" without lying about the result.
            help: _isEdit
                ? 'Blank leaves the threshold unchanged.'
                : 'Blank uses the server’s own default.',
          ),

          if (_failure != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s4),
            TorchErrorRegion(
              name: 'alert rule form',
              child: ErrorState(scope: ErrorScope.inline, message: _failure!),
            ),
          ],

          const SizedBox(height: TiqSpace.s6),
          TorchPrimaryButton(
            key: ValueKey<String>(_isEdit ? 'save-rule' : 'create-rule'),
            claimId: commitClaimId,
            label: _isEdit ? 'Save the rule' : 'Create the rule',
            busy: _submitting,
            onPressed: _submitting ? null : _submit,
            blockedReason: _submitting ? 'Saving.' : null,
          ),
          const SizedBox(height: TiqSpace.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('cancel-rule'),
              label: 'Cancel',
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
