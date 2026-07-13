import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/alerts_repository.dart';

/// The severities the console understands. The API takes any string, but these
/// are the three the rest of the app renders — Alerts triages 'critical' apart
/// from everything else, and the column defaults to 'normal' — so offering a
/// fourth would produce alerts no screen has a word for.
const _severities = <String>['critical', 'warning', 'normal'];

String _metricLabel(String metric) => switch (metric) {
      'out_of_stock' => 'Out of stock',
      'price_deviation' => 'Price deviation',
      'low_scorecard' => 'Low scorecard',
      _ => metric,
    };

/// Thresholds arrive as floats but are almost always whole numbers; a rule that
/// reads "threshold 60" beats one that reads "threshold 60.0".
String _threshold(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// What raises an alert. The worklist shape from Alerts, one level up: these
/// are the rules that produce the rows a manager triages there.
class AlertRulesScreen extends ConsumerStatefulWidget {
  const AlertRulesScreen({super.key});

  @override
  ConsumerState<AlertRulesScreen> createState() => _AlertRulesScreenState();
}

class _AlertRulesScreenState extends ConsumerState<AlertRulesScreen> {
  String? _metric;

  /// Only one active rule drives each metric — the evaluator takes the newest
  /// and ignores the rest. GET /alerts/rules returns newest-first, so the first
  /// active rule seen for a metric is the winner and any later one is dead
  /// config. Say so on the row rather than let it fail silently.
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

    return ManagerScaffold(
      title: 'Alert rules',
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('add-rule'),
        tooltip: 'Add rule',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateRuleDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Rules evaluate on every visit submit. Where two active rules share '
            'a metric, the newest one wins.',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<AlertRule>>(
            value: rules,
            label: 'alert rules',
            onRetry: () => ref.invalidate(alertRulesListProvider),
            builder: (list) {
              // Shadowing is a property of the whole list, so it is computed
              // before the filter narrows what is on screen.
              final shadowed = _shadowed(list);
              final visible = _metric == null
                  ? list
                  : list.where((r) => r.metric == _metric).toList();
              final active = visible.where((r) => r.active).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Filters(
                    metric: _metric,
                    onMetric: (m) => setState(() => _metric = m),
                  ),
                  const SizedBox(height: 12),
                  PanelCard(
                    title: '${visible.length} '
                        '${visible.length == 1 ? 'rule' : 'rules'}',
                    subtitle: '$active active',
                    padded: false,
                    child: visible.isEmpty
                        ? EmptyState(
                            message: list.isEmpty
                                ? 'No rules configured'
                                : 'No rules for this metric',
                            hint: list.isEmpty
                                ? 'Add a rule to start raising alerts on '
                                    'submitted visits.'
                                : 'Clear the filter to see the rest.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final rule in visible)
                                _RuleRow(
                                  rule: rule,
                                  shadowed: shadowed.contains(rule.id),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.metric, required this.onMetric});

  final String? metric;
  final ValueChanged<String?> onMetric;

  @override
  Widget build(BuildContext context) {
    return FilterRow(
      children: [
        const SectionLabel('Metric'),
        DropdownButton<String?>(
          key: const ValueKey<String>('filter-metric'),
          value: metric,
          hint: const Text('All metrics'),
          underline: const SizedBox.shrink(),
          isDense: true,
          style: const TextStyle(fontSize: 12.5, color: AppColors.ink1),
          dropdownColor: AppColors.surface2,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All metrics'),
            ),
            for (final m in alertRuleMetrics)
              DropdownMenuItem<String?>(value: m, child: Text(_metricLabel(m))),
          ],
          onChanged: onMetric,
        ),
      ],
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow({required this.rule, required this.shadowed});

  final AlertRule rule;

  /// True when an active rule is outranked by a newer active rule on the same
  /// metric — it is configured, but it will never fire.
  final bool shadowed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> setActive(bool value) async {
      await ref.read(alertRulesRepositoryProvider).updateRule(
            rule.id,
            active: value,
          );
      ref.invalidate(alertRulesListProvider);
    }

    return WorklistRow(
      key: ValueKey<String>('rule-${rule.id}'),
      title: rule.name,
      // The metric is what the evaluator matches on, so it wears the mono token
      // — a manager can quote it straight back at the API.
      meta: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          CodeToken(rule.metric),
          const Text('·'),
          Text('Severity ${rule.severity}'),
          if (rule.threshold != null) ...[
            const Text('·'),
            Text('Threshold ${_threshold(rule.threshold!)}'),
          ],
          if (shadowed) ...[
            const Text('·'),
            const Text('Shadowed by a newer active rule'),
          ],
        ],
      ),
      level: rule.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: rule.active ? 'Active' : 'Inactive',
      resolved: !rule.active,
      actions: [
        Switch(
          key: ValueKey<String>('toggle-${rule.id}'),
          value: rule.active,
          onChanged: setActive,
        ),
        RowAction(
          key: ValueKey<String>('edit-${rule.id}'),
          label: 'Edit',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _EditRuleDialog(rule: rule),
          ),
        ),
      ],
    );
  }
}

class _CreateRuleDialog extends ConsumerStatefulWidget {
  const _CreateRuleDialog();

  @override
  ConsumerState<_CreateRuleDialog> createState() => _CreateRuleDialogState();
}

class _CreateRuleDialogState extends ConsumerState<_CreateRuleDialog> {
  final _nameCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  String _metric = alertRuleMetrics.first;
  String _severity = 'normal';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _fail(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _fail('Name is required');
      return;
    }

    // Blank means "let the server pick its default"; anything else must parse,
    // because the API only accepts a number.
    final raw = _thresholdCtrl.text.trim();
    final threshold = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && threshold == null) {
      _fail('Threshold must be a number');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(alertRulesRepositoryProvider).createRule(
            name: name,
            metric: _metric,
            threshold: threshold,
            severity: _severity,
          );
      ref.invalidate(alertRulesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _fail('Failed to create rule: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Alert Rule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey<String>('new-rule-name'),
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('new-rule-metric'),
            initialValue: _metric,
            decoration: const InputDecoration(labelText: 'Metric'),
            items: [
              for (final m in alertRuleMetrics)
                DropdownMenuItem<String>(value: m, child: Text(_metricLabel(m))),
            ],
            onChanged: (value) => setState(() => _metric = value ?? _metric),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('new-rule-severity'),
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: [
              for (final s in _severities)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: (value) => setState(() => _severity = value ?? _severity),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('new-rule-threshold'),
            controller: _thresholdCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Threshold',
              helperText: 'Optional — blank uses the server default.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('create-rule'),
          onPressed: _submitting ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditRuleDialog extends ConsumerStatefulWidget {
  const _EditRuleDialog({required this.rule});

  final AlertRule rule;

  @override
  ConsumerState<_EditRuleDialog> createState() => _EditRuleDialogState();
}

class _EditRuleDialogState extends ConsumerState<_EditRuleDialog> {
  late final TextEditingController _thresholdCtrl = TextEditingController(
    text: widget.rule.threshold == null
        ? ''
        : _threshold(widget.rule.threshold!),
  );
  late String _severity = _severities.contains(widget.rule.severity)
      ? widget.rule.severity
      : 'normal';
  bool _submitting = false;

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _fail(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final raw = _thresholdCtrl.text.trim();
    final threshold = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && threshold == null) {
      _fail('Threshold must be a number');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Severity always goes, so the PATCH never sends an empty body — the API
      // rejects one that changes nothing.
      await ref.read(alertRulesRepositoryProvider).updateRule(
            widget.rule.id,
            threshold: threshold,
            severity: _severity,
          );
      ref.invalidate(alertRulesListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _fail('Failed to update rule: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('edit-rule-severity'),
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: [
              for (final s in _severities)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: (value) => setState(() => _severity = value ?? _severity),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('edit-rule-threshold'),
            controller: _thresholdCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Threshold',
              // The API has no way to unset a threshold, only to overwrite one,
              // so blank cannot mean "clear it" without lying about the result.
              helperText: 'Blank leaves the threshold unchanged.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('save-rule'),
          onPressed: _submitting ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
