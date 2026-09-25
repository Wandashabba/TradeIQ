import 'package:flutter/material.dart' show DateTimeRange, showDateRangePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../l10n/l10n.dart';
import '../../territories/data/territories_repository.dart';
import '../data/artifact_repository.dart';

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
/// **Selected has one vocabulary.** A chosen period, granularity or comparison
/// is a `TorchFilterChip`: lifted fill, a 1px ink-1 border, a tick and weight
/// 700 — three channels, never amber, on any screen (unify §1.6). The old
/// controls said "where you are" with an accent rim, which is a hue doing a
/// state's job.
///
/// **Every control is labelled for a screen reader**, and the chips carry
/// `selected` rather than relying on the fill to say which one is on.

/// The period vocabulary, taken verbatim from what the practitioner filters by
/// daily. Not a superset: adding "last 7 days" because it seems useful would
/// put a period in this menu with no counterpart in the model's vocabulary, and
/// the two surfaces would disagree about what "recently" means.
const List<String> artifactPeriods = <String>[
  'today',
  'yesterday',
  'previous_week',
  'mtd',
  'ytd',
];

const List<String?> artifactComparisons = <String?>[
  null,
  'previous_period',
  'same_period_last_year',
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

/// The period's name in the reader's own language.
String artifactPeriodLabel(AppLocalizations l10n, String kind) =>
    switch (kind) {
      'today' => l10n.artifactPeriodToday,
      'yesterday' => l10n.artifactPeriodYesterday,
      'previous_week' => l10n.artifactPeriodLastWeek,
      'mtd' => l10n.artifactPeriodMonthToDate,
      'ytd' => l10n.artifactPeriodYearToDate,
      _ => l10n.artifactPeriodSelected,
    };

String artifactComparisonLabel(AppLocalizations l10n, String? kind) =>
    switch (kind) {
      'previous_period' => l10n.artifactComparePreviousPeriod,
      'same_period_last_year' => l10n.artifactCompareLastYear,
      'territory' => l10n.artifactCompareTerritory,
      null || '' => l10n.artifactCompareNone,
      _ => l10n.artifactCompared,
    };

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

  String get _selectedComparison {
    final compareTo = params['compareTo'];
    if (compareTo is Map<String, dynamic> && compareTo['kind'] is String) {
      return compareTo['kind'] as String;
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final offered = _offered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(
          l10n.artifactFilters,
          // Hidden rather than disabled when there is nothing to undo: a
          // control that never does anything teaches people to ignore it.
          action: detail.canUndo
              ? SectionRuleAction(
                  l10n.artifactUndo,
                  key: const ValueKey<String>('artifact-undo'),
                  onTap: busy ? () {} : onUndo,
                )
              : null,
        ),
        const SizedBox(height: TiqSpace.s4),
        if (offered.contains(ArtifactControl.period))
          _Group(
            label: l10n.artifactPeriod,
            child: _PeriodControl(
              period: _period,
              busy: busy,
              onChanged: (period) => onApply(_with('period', period)),
            ),
          ),
        if (offered.contains(ArtifactControl.interval))
          _Group(
            label: l10n.artifactGranularity,
            child: _ChipRow(
              semanticsLabel: l10n.artifactGranularity,
              options: <(String, String)>[
                ('day', l10n.artifactDaily),
                ('week', l10n.artifactWeekly),
              ],
              selected: params['interval'] is String
                  ? params['interval'] as String
                  : 'day',
              busy: busy,
              onChanged: (value) => onApply(_with('interval', value)),
            ),
          ),
        if (offered.contains(ArtifactControl.comparison))
          _Group(
            label: l10n.artifactCompareWith,
            child: _ChipRow(
              semanticsLabel: l10n.artifactCompareWith,
              options: <(String, String)>[
                for (final kind in artifactComparisons)
                  (kind ?? '', artifactComparisonLabel(l10n, kind)),
              ],
              selected: _selectedComparison,
              busy: busy,
              onChanged: (value) => onApply(
                _with('compareTo', value.isEmpty ? null : {'kind': value}),
              ),
            ),
          ),
        if (offered.contains(ArtifactControl.territory))
          _Group(
            label: l10n.artifactTerritory,
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
          l10n.artifactRerunsTheQuery,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// One control and the block label above it.
///
/// An eyebrow, which unify §1.17 allows as a block label inside a panel — the
/// filters are one block and these name its parts. A full section rule per
/// control would be four rules in a 300dp rail.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TiqSpace.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Eyebrow(label),
        const SizedBox(height: TiqSpace.s3),
        child,
      ],
    ),
  );
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
    final l10n = context.l10n;
    final custom = _kind == 'custom';

    return _ChipRow(
      semanticsLabel: l10n.artifactPeriod,
      options: <(String, String)>[
        for (final kind in artifactPeriods)
          (kind, artifactPeriodLabel(l10n, kind)),
        // The picker is a chip in the same rail rather than a button beside
        // it: it chooses a period like the other five, and a chosen range is
        // as selected as "Month to date" is.
        (
          'custom',
          custom
              ? l10n.artifactCustomRange('${period['from']}', '${period['to']}')
              : l10n.artifactPickDates,
        ),
      ],
      selected: custom ? 'custom' : _kind,
      busy: busy,
      // The date picker is the one Material control left on a Torchlight
      // route, for the reason §18.9 gives: the kit has no calendar, a date is
      // the one value nobody should have to type, and building one for two
      // call sites would be a component nobody else reviewed.
      reselectable: const <String>{'custom'},
      onChanged: (kind) => kind == 'custom'
          ? _pickRange(context)
          : onChanged(<String, dynamic>{'kind': kind}),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      // Five years back is well past anything the field data covers, and a
      // picker that offers 1970 makes the useful range harder to reach.
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _currentRange(now),
      helpText: l10n.artifactCustomPeriod,
    );
    if (picked == null) return;
    onChanged(<String, dynamic>{
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

/// A rail of mutually exclusive options.
///
/// The selected chip carries the tick, the weight and the `selected` flag, so
/// a screen reader announces which option is on rather than leaving it to the
/// fill.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.semanticsLabel,
    required this.options,
    required this.selected,
    required this.busy,
    required this.onChanged,
    this.reselectable = const <String>{},
  });

  final String semanticsLabel;
  final List<(String, String)> options;
  final String selected;
  final bool busy;
  final ValueChanged<String> onChanged;

  /// Options that stay pressable while they are the selected one, because
  /// pressing them does something other than select — the date picker.
  final Set<String> reselectable;

  @override
  Widget build(BuildContext context) {
    return TorchFilterRail(
      semanticsLabel: semanticsLabel,
      chips: <Widget>[
        for (final (value, label) in options)
          TorchFilterChip(
            key: ValueKey<String>('artifact-filter-$value'),
            label: label,
            selected: value == selected,
            onSelected:
                busy || (value == selected && !reselectable.contains(value))
                ? null
                : () => onChanged(value),
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
///
/// A picker rather than a chip rail: a territory list is forty long, which is
/// exactly the case §18.1 built `TorchPickerField` for. It offers the name a
/// person says out loud with the code beneath it in the identifier face — a
/// picker that offers uuids is a picker nobody can use.
class _TerritoryControl extends ConsumerWidget {
  const _TerritoryControl({
    required this.selected,
    required this.busy,
    required this.onChanged,
  });

  final String? selected;
  final bool busy;
  final ValueChanged<String?> onChanged;

  /// The "no scope" answer. A null pop from the sheet is a dismissal, so the
  /// clear travels as a token.
  static const String wholeBusiness = '__whole_business__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;

    return ref
        .watch(territoriesListProvider)
        .when(
          loading: () => Text(
            l10n.artifactTerritoriesLoading,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          // The artifact still works unscoped, so a failed territory list is a
          // missing control, not a broken screen.
          error: (_, _) => Text(
            l10n.artifactTerritoriesUnavailable,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          data: (territories) => TorchPickerField<String>(
            key: const ValueKey<String>('artifact-territory'),
            label: l10n.artifactTerritory,
            options: <PickerOption<String>>[
              PickerOption<String>(
                value: wholeBusiness,
                label: l10n.artifactWholeBusiness,
              ),
              for (final territory in territories)
                PickerOption<String>(
                  value: territory.id,
                  label: territory.name,
                  identifier: territory.code,
                ),
            ],
            value: territories.any((t) => t.id == selected)
                ? selected
                : wholeBusiness,
            // Nothing selected is a state, and here it has a name: the whole
            // business. The trough never holds a grey instruction.
            notChosenLine: l10n.artifactWholeBusiness,
            sheetSubtitle: l10n.artifactTerritorySheetBody,
            emptyHeadline: l10n.artifactNoTerritoriesHeadline,
            emptyBody: l10n.artifactNoTerritoriesBody,
            enabled: !busy,
            disabledReason: busy ? l10n.artifactBusyReason : null,
            onChanged: busy
                ? null
                : (id) => onChanged(id == wholeBusiness ? null : id),
          ),
        );
  }
}

/// The applied filters as a sentence.
///
/// Reachable by link, so this screen cannot assume the reader saw the question
/// that produced it — "a chart with no visible date range is a support ticket
/// waiting to happen".
String describeParamsInWords(AppLocalizations l10n, Map<String, dynamic> params) {
  final parts = <String>[];

  final period = params['period'];
  if (period is Map<String, dynamic>) {
    final kind = period['kind'];
    parts.add(
      kind == 'custom'
          ? l10n.artifactRangeInWords('${period['from']}', '${period['to']}')
          : artifactPeriodLabel(l10n, kind is String ? kind : ''),
    );
  }

  final interval = params['interval'];
  if (interval == 'day') parts.add(l10n.artifactDailyBuckets);
  if (interval == 'week') parts.add(l10n.artifactWeeklyBuckets);

  if (params['territoryId'] is String) parts.add(l10n.artifactOneTerritory);

  final compareTo = params['compareTo'];
  if (compareTo is Map<String, dynamic>) {
    final kind = compareTo['kind'];
    parts.add(switch (kind) {
      'previous_period' => l10n.artifactComparedPreviousPeriod,
      'same_period_last_year' => l10n.artifactComparedLastYear,
      'territory' => l10n.artifactComparedTerritory,
      _ => l10n.artifactCompared,
    });
  }

  return parts.isEmpty ? l10n.artifactNoFilters : '${parts.join(' · ')}.';
}
