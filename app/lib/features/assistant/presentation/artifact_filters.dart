import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../territories/data/territories_repository.dart';
import '../data/artifact_repository.dart';
import 'artifact_screen.dart' show FilterSection;

/// The controls that steer an artifact without saying a word to the model.
///
/// **They write through the tool's own params schema** — the same one the model
/// writes through, which is what stops the two control paths from drifting into
/// disagreement about what a valid artifact looks like. Each control composes a
/// whole params bag from the current one and posts it; the server validates,
/// re-runs the same closure at the same tenant, and answers with fresh data.
/// There is no model call, so a drag costs a query rather than three seconds
/// and a paid turn.
///
/// **Every control is labelled for a screen reader**, and the period buttons
/// carry `selected` state rather than relying on the fill to say which one is
/// on.

/// The period vocabulary, taken verbatim from what the practitioner filters by
/// daily. Not a superset: adding "last 7 days" because it seems useful would
/// put a period in this menu with no counterpart in the model's vocabulary, and
/// the two surfaces would disagree about what "recently" means.
const _periods = <(String, String)>[
  ('today', 'Today'),
  ('yesterday', 'Yesterday'),
  ('previous_week', 'Last week'),
  ('mtd', 'Month to date'),
  ('ytd', 'Year to date'),
];

const _comparisons = <(String?, String)>[
  (null, 'None'),
  ('previous_period', 'The period before'),
  ('same_period_last_year', 'Same period last year'),
];

/// Which controls each view-spec type offers.
///
/// Mirrors what the **tool** behind each type declares, and is deliberately
/// conservative: a Zod object strips a key it does not declare rather than
/// rejecting it, so a control offered for a param its tool never had would
/// appear to work and silently change nothing — the worst of the three
/// possible outcomes. `getMetricTrend` takes no territory (the trends service
/// has no territory narrowing) and `getAgentScorecard` takes neither territory
/// nor comparison.
///
/// Comparison is offered only where a comparison can be *drawn* — a second
/// series on the trend, a delta column on the pillar figures. `getStockLevels`
/// accepts one too, but an outlet map of stockout pins has nowhere to put it,
/// and a control that changes nothing visible is worse than an absent one.
const Map<String, Set<ArtifactControl>> artifactControls = {
  'trend_chart': {
    ArtifactControl.period,
    ArtifactControl.interval,
    ArtifactControl.comparison,
  },
  'pillar_metrics': {
    ArtifactControl.period,
    ArtifactControl.territory,
    ArtifactControl.comparison,
  },
  'outlet_map': {ArtifactControl.period, ArtifactControl.territory},
  'agent_scorecard': {ArtifactControl.period},
};

enum ArtifactControl { period, interval, territory, comparison }

class ArtifactFilters extends ConsumerWidget {
  const ArtifactFilters({
    super.key,
    required this.detail,
    required this.params,
    required this.busy,
    required this.onApply,
    required this.onUndo,
  });

  final ArtifactDetail detail;
  final Map<String, dynamic> params;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onApply;
  final VoidCallback onUndo;

  Set<ArtifactControl> get _offered =>
      artifactControls[detail.type] ?? const {ArtifactControl.period};

  Map<String, dynamic> get _period {
    final period = params['period'];
    return period is Map<String, dynamic> ? period : const {'kind': 'mtd'};
  }

  /// A new params bag with one key replaced. Whole bags, never patches: the
  /// server validates the bag against the tool's schema, and half of one is not
  /// a valid bag.
  Map<String, dynamic> _with(String key, dynamic value) {
    final next = Map<String, dynamic>.from(params);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offered = _offered;

    return PanelCard(
      title: 'Filters',
      trailing: detail.canUndo
          ? TextButton(
              // Hidden rather than disabled at the bottom of the stack: a
              // control that never does anything teaches people to ignore it.
              onPressed: busy ? null : onUndo,
              child: const Text('Undo'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offered.contains(ArtifactControl.period))
            FilterSection(
              label: 'Period',
              child: _PeriodControl(
                period: _period,
                busy: busy,
                onChanged: (period) => onApply(_with('period', period)),
              ),
            ),
          if (offered.contains(ArtifactControl.interval))
            FilterSection(
              label: 'Granularity',
              child: _ChoiceRow(
                options: const [('day', 'Daily'), ('week', 'Weekly')],
                selected: params['interval'] is String
                    ? params['interval'] as String
                    : 'day',
                busy: busy,
                onChanged: (value) => onApply(_with('interval', value)),
              ),
            ),
          if (offered.contains(ArtifactControl.comparison))
            FilterSection(
              label: 'Compare with',
              child: _ChoiceRow(
                options: [
                  for (final (kind, label) in _comparisons) (kind ?? '', label),
                ],
                selected: _selectedComparison,
                busy: busy,
                onChanged: (value) => onApply(
                  _with('compareTo', value.isEmpty ? null : {'kind': value}),
                ),
              ),
            ),
          if (offered.contains(ArtifactControl.territory))
            FilterSection(
              label: 'Territory',
              child: _TerritoryControl(
                selected: params['territoryId'] is String
                    ? params['territoryId'] as String
                    : null,
                busy: busy,
                onChanged: (id) => onApply(_with('territoryId', id)),
              ),
            ),
          Text(
            // Says what a control costs, because the honest answer is
            // surprising: this is a re-query, not another question put to the
            // assistant, so it neither spends a turn nor changes the answer
            // above it in the conversation.
            'Changing a filter re-runs the same query. It does not ask the '
            'assistant again.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: context.colors.ink3,
            ),
          ),
        ],
      ),
    );
  }

  String get _selectedComparison {
    final compareTo = params['compareTo'];
    if (compareTo is Map<String, dynamic> && compareTo['kind'] is String) {
      return compareTo['kind'] as String;
    }
    return '';
  }
}

/// The period vocabulary plus a real date range.
class _PeriodControl extends StatelessWidget {
  const _PeriodControl({
    required this.period,
    required this.busy,
    required this.onChanged,
  });

  final Map<String, dynamic> period;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onChanged;

  String get _kind =>
      period['kind'] is String ? period['kind'] as String : 'mtd';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final custom = _kind == 'custom';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChoiceRow(
          options: _periods,
          selected: custom ? '' : _kind,
          busy: busy,
          onChanged: (kind) => onChanged({'kind': kind}),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _pickRange(context),
          icon: const Icon(Icons.date_range_outlined, size: 15),
          label: Text(
            custom ? '${period['from']} → ${period['to']}' : 'Pick dates',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: custom ? colors.ink1 : colors.ink2,
            side: BorderSide(color: custom ? colors.brand : colors.lineStrong),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      // Five years back is well past anything the field data covers, and a
      // picker that offers 1970 makes the useful range harder to reach.
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _currentRange(now),
      helpText: 'Custom period',
    );
    if (picked == null) return;
    onChanged({
      'kind': 'custom',
      // The server takes whole calendar days, `YYYY-MM-DD`, and treats `to` as
      // inclusive. Sending a timestamp would be rejected by the schema.
      'from': _iso(picked.start),
      'to': _iso(picked.end),
    });
  }

  DateTimeRange? _currentRange(DateTime now) {
    final from = DateTime.tryParse('${period['from']}');
    final to = DateTime.tryParse('${period['to']}');
    if (from == null || to == null || to.isBefore(from)) return null;
    return DateTimeRange(start: from, end: to.isAfter(now) ? now : to);
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// A row of mutually exclusive options.
///
/// `Semantics.selected` carries the state, so a screen reader announces which
/// option is on rather than leaving it to the fill colour — the bar the a11y
/// work in #144 set.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.busy,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String selected;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (value, label) in options)
          Semantics(
            selected: value == selected,
            button: true,
            child: InkWell(
              key: ValueKey('artifact-filter-$value'),
              onTap: busy || value == selected ? null : () => onChanged(value),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: value == selected
                      ? colors.surface3
                      : Colors.transparent,
                  border: Border.all(
                    color: value == selected ? colors.brand : colors.line,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: value == selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: value == selected ? colors.ink1 : colors.ink2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Territory scope, from the tenant's own list.
///
/// The id here is the `Territory` row id, which is what the assistant's
/// `territoryId` param means — the service translates it to the free-text code
/// that outlets carry. Passing an outlet's code straight through would match
/// nothing and answer "no data" for a territory that is full of it.
class _TerritoryControl extends ConsumerWidget {
  const _TerritoryControl({
    required this.selected,
    required this.busy,
    required this.onChanged,
  });

  final String? selected;
  final bool busy;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return ref
        .watch(territoriesListProvider)
        .when(
          loading: () => Text(
            'Loading territories…',
            style: TextStyle(fontSize: 12, color: colors.ink3),
          ),
          // The artifact still works unscoped, so a failed territory list is a
          // missing control, not a broken screen.
          error: (_, _) => Text(
            'Territories are unavailable — showing the whole business.',
            style: TextStyle(fontSize: 12, color: colors.ink3),
          ),
          data: (territories) => DropdownButtonFormField<String?>(
            initialValue: territories.any((t) => t.id == selected)
                ? selected
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              labelText: 'Territory',
            ),
            style: TextStyle(fontSize: 12.5, color: colors.ink1),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Whole business'),
              ),
              for (final territory in territories)
                DropdownMenuItem<String?>(
                  value: territory.id,
                  child: Text('${territory.name} (${territory.code})'),
                ),
            ],
            onChanged: busy ? null : onChanged,
          ),
        );
  }
}

/// The applied filters as a sentence.
///
/// Reachable by link, so this screen cannot assume the reader saw the question
/// that produced it — "a chart with no visible date range is a support ticket
/// waiting to happen".
String describeParamsInWords(Map<String, dynamic> params) {
  final parts = <String>[];

  final period = params['period'];
  if (period is Map<String, dynamic>) {
    final kind = period['kind'];
    parts.add(switch (kind) {
      'today' => 'Today',
      'yesterday' => 'Yesterday',
      'previous_week' => 'Last week',
      'mtd' => 'Month to date',
      'ytd' => 'Year to date',
      'custom' => '${period['from']} to ${period['to']}',
      _ => 'Selected period',
    });
  }

  final interval = params['interval'];
  if (interval == 'day') parts.add('daily buckets');
  if (interval == 'week') parts.add('weekly buckets');

  if (params['territoryId'] is String) parts.add('one territory');

  final compareTo = params['compareTo'];
  if (compareTo is Map<String, dynamic>) {
    parts.add(switch (compareTo['kind']) {
      'previous_period' => 'compared with the period before',
      'same_period_last_year' => 'compared with the same period last year',
      'territory' => 'compared with another territory',
      _ => 'compared',
    });
  }

  return parts.isEmpty ? 'No filters applied.' : '${parts.join(' · ')}.';
}
