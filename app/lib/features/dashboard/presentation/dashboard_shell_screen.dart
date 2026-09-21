import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/motion_budget.dart';
import '../../../core/format/period_label.dart';
import '../../../core/format/relative_time.dart';
import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_state_glyph.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/figure/chart/chart.dart';
import '../../../core/widgets/torchlight/figure/sparkline.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../agents/data/agent_locations_repository.dart';
import '../../agents/data/agents_repository.dart';
import '../../agents/presentation/live_location_layer.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../sales_targets/data/sales_targets_repository.dart';
import '../../sales_targets/presentation/sales_attainment_panel.dart';
import '../../tasks/data/tasks_admin_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../../trends/data/trends_repository.dart';
import '../data/dashboard_repository.dart';

/// EXECUTION OVERVIEW — the manager's multi-panel console, in Torchlight.
///
/// The Floor (`/dashboard`) is the home and answers *what is broken, and who
/// is fixing it?* on one fold. This route answers the other half — *how are we
/// doing, and against what?* — and holds the four panels The Floor
/// deliberately did not absorb: the score and its trend, the indicators
/// against their published standards, the score by territory, and where the
/// agents are.
///
/// ```text
///   Execution overview                                   [ ⟳ ]
///   Gauteng North · last 30 days
///   (7 days)(30 days)(90 days)(Year to date)(All time) | (Gauteng North)
///   ── Execution score ─────────────────────────────────
///   EXECUTION SCORE                                  72,4
///   ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│▁▁▁▁▁   ▲ 1,8 vs the window before
///   ── Needs attention 3 ───────────────────────────────
///   ▌ Critical alerts open                              4
///   ── Where we sit against the standard ───────────────
///   ── Execution score by territory ────────────────────
///   ── On-shelf availability ───────────────────────────
///   ── Where are my agents ─────────────────────────────
///   [ nav pill ]
/// ```
///
/// ## The amber, counted
///
/// A tab root reached from the Menu, so the nav's active tab is slot 1 and the
/// content has one grant left. **Every phase declines it.** There is no commit
/// action on this route — nothing here is armed — the chart-focus rung is
/// declined for the reason the trends screen declines it (three plots on one
/// route is three focus objects asking, and the budget is counted per route
/// rather than per viewport), the selected filter chip is `lifted` like every
/// other selected chip in the product, and every severity on the screen is
/// crimson at two commitment levels with a word beside it. Night: 1. Day and
/// Veld: 0. On every phase.
///
/// ## Unknown is not zero
///
/// `GET /dashboard` answers with figures whatever it was asked, so a window
/// with no visits in it comes back as a wall of confident noughts. `totals` is
/// the only thing that can tell those apart from eight real zeros, and it is
/// what this screen branches on: no outlets at all is a first-run tenant, a
/// tenant with outlets and no visits renders em dashes, the unit suppressed,
/// no deltas and a sentence in words. A measured `0` renders `0` and keeps its
/// place.
///
/// ## Veld
///
/// Veld draws no plot and no map (unify §4). Both trend panels fall back to
/// their `TableTwin` — which is also what a screen reader and a printer get —
/// and the agent panel falls back to its list, which was always the half that
/// kept the map honest.
class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  /// Refetches every panel together.
  ///
  /// All of them, not just the one that looks stale: panels that refreshed at
  /// different moments would quietly disagree with each other, and a dashboard
  /// that contradicts itself is worse than one that is uniformly a minute old.
  ///
  /// [dashboardFilterProvider] is deliberately excluded — it holds the
  /// manager's filter selection rather than server data, and resetting it here
  /// would silently throw away what they asked to see.
  static Future<void> refresh(WidgetRef ref) async {
    ref.invalidate(dashboardByTerritoryProvider);
    ref.invalidate(scorecardsTrendProvider);
    ref.invalidate(perfectStoreTrendProvider);
    ref.invalidate(availabilityTrendProvider);
    ref.invalidate(alertsListProvider);
    ref.invalidate(tasksListProvider);
    ref.invalidate(territoriesListProvider);
    ref.invalidate(agentActivityTodayProvider);
    ref.invalidate(liveAgentLocationsProvider);
    ref.invalidate(currentMonthAttainmentProvider);
    // Awaited last so the caller tracks the headline number; the rest refetch
    // in parallel behind it.
    ref.invalidate(dashboardSnapshotProvider);
    await ref.read(dashboardSnapshotProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final gutter = context.skin.space.gutter;
    final blockGap = context.skin.space.blockGap;

    // Resolved once, from the view model, per declared phase — never from a
    // figure that happens to be 0.
    final phase = snapshot.when(
      loading: () => 'loading',
      error: (_, _) => 'error',
      data: (snap) => snap.current.hasNoOutlets
          ? 'first-run'
          : snap.current.measuredSomething
          ? 'loaded'
          : 'window-empty',
    );

    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.dashOverviewTitle,
        facts: <String>[
          _territoryFact(ref, l10n, filter.territoryId),
          rangeLabel(l10n, filter.range),
        ],
        // The header allows exactly one trailing control, and on a console
        // route the one worth having is the refetch — the same choice Alerts
        // and Territories made, for the same reason. Managers are on Flutter
        // web, where a pull-to-refresh gesture is neither obvious nor
        // comfortable with a mouse.
        trailing: TorchIconButton(
          key: const ValueKey<String>('dashboard-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.dashRefresh,
          onPressed: () => refresh(ref),
        ),
      ),
      children: <Widget>[
        TorchBleed(extra: gutter * 2, child: const _DashboardFilters()),
        SizedBox(height: blockGap),
        if (phase == 'first-run')
          const _FirstRun()
        else ...<Widget>[
          _ExecutionScoreSection(snapshot: snapshot),
          SizedBox(height: blockGap),
          const _NeedsAttentionSection(),
          SizedBox(height: blockGap),
          _StandardsSection(snapshot: snapshot),
          SizedBox(height: blockGap),
          _DistributionSection(snapshot: snapshot),
          const _TerritorySection(),
          SizedBox(height: blockGap),
          const _AvailabilitySection(),
          SizedBox(height: blockGap),
          const AgentActivityPanel(),
          SizedBox(height: blockGap),
          const SalesAttainmentPanel(),
          SizedBox(height: blockGap),
          const _StubCaveat(),
        ],
      ],
    );
  }

  /// The header's first fact: which territory the figures below are about.
  static String _territoryFact(
    WidgetRef ref,
    AppLocalizations l10n,
    String? territoryId,
  ) {
    if (territoryId == null) return l10n.dashAllTerritories;
    return territoryName(ref, territoryId) ?? l10n.dashOneTerritory;
  }
}

/// The window's own name, localised. `DashboardRange.label` is the wire-ish
/// abbreviation the old pills wore; a fact line and a filter chip are read out
/// loud, so they get words.
String rangeLabel(AppLocalizations l10n, DashboardRange range) =>
    switch (range) {
      DashboardRange.last7 => l10n.dashRangeLast7,
      DashboardRange.last30 => l10n.dashRangeLast30,
      DashboardRange.last90 => l10n.dashRangeLast90,
      DashboardRange.ytd => l10n.dashRangeYtd,
      DashboardRange.allTime => l10n.dashRangeAll,
    };

/// A territory's name from the loaded list, or null when the list has not
/// loaded, failed, or simply does not contain the id — a deleted or stale
/// territory. Never the raw id: a uuid is not a name (unify §1.15).
String? territoryName(WidgetRef ref, String id) =>
    ref.watch(territoriesListProvider).maybeWhen(
      data: (list) {
        for (final t in list) {
          if (t.id == id) return t.name;
        }
        return null;
      },
      orElse: () => null,
    );

// ═══════════════════════════════════════════════════════════════════════
// Filters — one rail, above everything it scopes
// ═══════════════════════════════════════════════════════════════════════

/// One filter rail scoping every panel below it — the window and the
/// territory.
///
/// A per-panel control would let two figures silently disagree about which
/// slice of time they show, which is worse than no control at all. Selected is
/// `lifted` + ink-1 border + tick + weight 700 — three channels, never amber,
/// on any screen (unify §1.6).
class _DashboardFilters extends ConsumerWidget {
  const _DashboardFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);

    void update(DashboardFilter next) =>
        ref.read(dashboardFilterProvider.notifier).set(next);

    final selectedName = filter.territoryId == null
        ? null
        : territoryName(ref, filter.territoryId!);

    return TorchFilterRail(
      semanticsLabel: l10n.dashFilters,
      chips: <Widget>[
        for (final range in DashboardRange.values)
          TorchFilterChip(
            key: ValueKey<String>('range-${range.name}'),
            label: rangeLabel(l10n, range),
            selected: range == filter.range,
            onSelected: () => update(filter.copyWith(range: range)),
          ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-territory'),
          // Loading is a state, not a blank: the chip says "All territories"
          // and is not selected, which is exactly what the screen is showing.
          label:
              selectedName ??
              (filter.territoryId == null
                  ? l10n.dashAllTerritories
                  : l10n.dashOneTerritory),
          selected: filter.territoryId != null,
          onSelected: territories.hasValue
              ? () => _pick(context, ref, filter)
              : null,
        ),
      ],
    );
  }

  /// The territory list is arbitrary-length, so it is a sheet of rows rather
  /// than a `ChoiceRow` — unify §1.10 gives this product one modal container
  /// and §18.1 is why a long list opens it.
  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    DashboardFilter filter,
  ) async {
    final l10n = context.l10n;
    final list = ref.read(territoriesListProvider).value ?? const <Territory>[];
    final chosen = await showTorchSheet<String>(
      context,
      builder: (sheetContext) => TorchSheet(
        title: l10n.dashTerritory,
        subtitle: l10n.dashTerritorySheetBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SoftRow(
              key: const ValueKey<String>('territory-option-all'),
              density: SoftRowDensity.compact,
              title: l10n.dashAllTerritories,
              semanticsLabel: filter.territoryId == null
                  ? '${l10n.dashAllTerritories}. ${l10n.dashSelected}'
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(_allTerritories),
            ),
            for (var i = 0; i < list.length; i++)
              SoftRow(
                key: ValueKey<String>('territory-option-${list[i].id}'),
                density: SoftRowDensity.compact,
                title: list[i].name,
                subtitle: list[i].code,
                semanticsLabel: list[i].id == filter.territoryId
                    ? '${list[i].name}. ${l10n.dashSelected}'
                    : null,
                separator: i == list.length - 1
                    ? SoftRowSeparator.none
                    : SoftRowSeparator.auto,
                onTap: () => Navigator.of(sheetContext).pop(list[i].id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    ref
        .read(dashboardFilterProvider.notifier)
        .set(
          chosen == _allTerritories
              ? filter.copyWith(clearTerritory: true)
              : filter.copyWith(territoryId: chosen),
        );
  }

  /// The sheet's "all" answer. A null pop is a dismissal, so the clear
  /// travels as a token — the same reason the old popup menu carried one.
  static const String _allTerritories = '__all_territories__';
}

// ═══════════════════════════════════════════════════════════════════════
// The execution score, and its trend
// ═══════════════════════════════════════════════════════════════════════

/// The client's published execution-score standard. A figure is never read
/// without the line it is measured against.
const double executionScoreTarget = 75;

class _ExecutionScoreSection extends ConsumerStatefulWidget {
  const _ExecutionScoreSection({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  ConsumerState<_ExecutionScoreSection> createState() =>
      _ExecutionScoreSectionState();
}

class _ExecutionScoreSectionState
    extends ConsumerState<_ExecutionScoreSection> {
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trend = ref.watch(scorecardsTrendProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.dashExecutionScore),
        const SizedBox(height: TiqSpace.s4),
        widget.snapshot.when(
          loading: () => Skeleton(
            label: l10n.dashExecutionScore,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonShell(height: 96),
          ),
          error: (error, _) => TorchErrorRegion(
            name: l10n.dashExecutionScore,
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                key: const ValueKey<String>('kpi-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(dashboardSnapshotProvider),
              ),
            ),
          ),
          data: (snap) => _ScoreTile(snapshot: snap),
        ),
        const SizedBox(height: TiqSpace.s6),
        _TrendPanel(
          heading: l10n.dashScoreTrend,
          seriesName: l10n.dashExecutionScore,
          provider: scorecardsTrendProvider,
          // A mean of weighted scores, so n >= 3 — not a rate.
          kind: MetricKind.average,
          threshold: ChartThreshold(
            value: executionScoreTarget,
            label: l10n.trendsTarget,
          ),
          asTable: _asTable,
          onViewChanged: (v) => setState(() => _asTable = v),
          async: trend,
          chartKey: const ValueKey<String>('dashboard-score-chart'),
          tableKey: const ValueKey<String>('dashboard-score-table'),
        ),
      ],
    );
  }
}

/// The headline figure: the execution score, its distance from the published
/// standard, and the like-for-like movement.
///
/// No count-up. The spec deleted it in Phase 1: the figure is present at first
/// paint, which removes the horizontal jitter of a delta beside a growing
/// digit count and the heaviest frame sequence on a cold start.
class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = snapshot.current;
    final measured = current.measuredSomething;
    final delta = snapshot.of((k) => k.executionScore);
    final status = againstStandard(
      current.executionScore,
      executionScoreTarget,
    );

    return StatCluster(
      semanticsLabel: l10n.dashExecutionScore,
      tiles: <StatTile>[
        StatTile(
          key: const ValueKey<String>('kpi-execution-score'),
          eyebrow: l10n.dashExecutionScore,
          // A window with no visits is an absence, not a score of nought.
          value: measured ? current.executionScore : null,
          decimals: 1,
          noDataReason: measured ? null : l10n.dashNoVisitsInWindow,
          sampling: FigureSampling(
            kind: MetricKind.average,
            n: current.sampleSizes.executionScore,
            baselineN: snapshot.previous?.sampleSizes.executionScore,
          ),
          meter: MeterData(
            value: measured ? current.executionScore : null,
            target: executionScoreTarget,
          ),
          delta: measured ? deltaFor(l10n, delta) : null,
          lead: true,
          severity: measured ? severityFor(status) : null,
          subordinates: l10n.dashExecutionScoreSupports(
            executionScoreTarget.round(),
          ),
        ),
      ],
    );
  }
}

/// One series, as a chart or as its table twin — the same two-chip toggle the
/// trends screen carries, and for the same reasons: the plot's only other way
/// in is a horizontal drag-scrub, which a screen reader cannot perform and a
/// printed page does not carry.
class _TrendPanel extends ConsumerWidget {
  const _TrendPanel({
    required this.heading,
    required this.seriesName,
    required this.provider,
    required this.kind,
    required this.asTable,
    required this.onViewChanged,
    required this.async,
    required this.chartKey,
    required this.tableKey,
    this.unit = TiqUnit.none,
    this.threshold,
  });

  final String heading;
  final String seriesName;
  final FutureProvider<List<TrendPoint>> provider;
  final MetricKind kind;
  final TiqUnit unit;
  final ChartThreshold? threshold;
  final bool asTable;
  final ValueChanged<bool> onViewChanged;
  final AsyncValue<List<TrendPoint>> async;
  final Key chartKey;
  final Key tableKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Veld draws no chart, so the toggle would be a control with one working
    // position. The table is simply what Veld shows.
    final veld = context.skin.mode == SkinMode.veld;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(heading),
        const SizedBox(height: TiqSpace.s3),
        if (!veld) ...<Widget>[
          _ViewToggle(
            heading: heading,
            asTable: asTable,
            onChanged: onViewChanged,
          ),
          const SizedBox(height: TiqSpace.s4),
        ],
        async.when(
          loading: () => Skeleton(
            label: heading,
            slowLine: l10n.torchStillFetching,
            child: SkeletonShell(
              height: veld ? 120 : trendChartHeight(context),
            ),
          ),
          error: (error, _) => TorchErrorRegion(
            name: heading,
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                key: ValueKey<String>('$heading-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(provider),
              ),
            ),
          ),
          data: (points) {
            if (points.isEmpty) {
              // Not "every bucket scored 0" — `/trends/*` omits an empty
              // bucket rather than sending one, so nothing in this window was
              // measured at all.
              return EmptyState(
                scope: EmptyScope.inPanel,
                headline: l10n.trendsEmptyHeadline,
                body: l10n.trendsEmptyBody,
              );
            }
            final series = ChartSeries(
              name: seriesName,
              readings: <ChartReading>[
                for (final p in points)
                  ChartReading(
                    label: formatPeriodLabel(p.period),
                    longLabel: p.period,
                    value: p.value,
                    sampleSize: p.count <= 0 ? null : p.count,
                  ),
              ],
            );
            if (veld || asTable) {
              return TableTwin(
                key: tableKey,
                series: <ChartSeries>[series],
                unit: unit,
                decimals: 1,
                periodHeading: l10n.trendsPeriod,
                notMeasuredWord: l10n.trendsNotMeasured,
                sampleKind: kind,
                lowSampleWord: l10n.trendsSmallSample,
                semanticsLabel: heading,
              );
            }
            return TrendChart(
              key: chartKey,
              series: <ChartSeries>[series],
              unit: unit,
              decimals: 1,
              threshold: threshold,
              semanticsLabel: l10n.trendsChartHint(heading, points.length),
              notMeasuredWord: l10n.trendsNotMeasured,
              dashedWord: l10n.trendsDashed,
              sampleKind: kind,
              lowSampleWord: l10n.trendsSmallSample,
              scrubHint: l10n.trendsScrubHint,
            );
          },
        ),
      ],
    );
  }
}

/// Chart or table. Two filter chips, which is the one selected vocabulary in
/// this system.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.heading,
    required this.asTable,
    required this.onChanged,
  });

  final String heading;
  final bool asTable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TorchFilterRail(
        semanticsLabel: l10n.trendsViewAs,
        chips: <Widget>[
          TorchFilterChip(
            key: ValueKey<String>('$heading-view-chart'),
            label: l10n.trendsAsChart,
            selected: !asTable,
            onSelected: () => onChanged(false),
          ),
          TorchFilterChip(
            key: ValueKey<String>('$heading-view-table'),
            label: l10n.trendsAsTable,
            selected: asTable,
            onSelected: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Needs attention — the cause, under the score
// ═══════════════════════════════════════════════════════════════════════

class _NeedsAttentionSection extends ConsumerWidget {
  const _NeedsAttentionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alerts = ref.watch(alertsListProvider);
    final tasks = ref.watch(tasksListProvider);
    final gutter = context.skin.space.gutter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(
          l10n.dashNeedsAttention,
          action: SectionRuleAction(
            l10n.dashViewAllAlerts,
            key: const ValueKey<String>('needs-attention-view-all'),
            onTap: () => context.go('/alerts'),
          ),
        ),
        const SizedBox(height: TiqSpace.s4),
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              alerts.when(
                loading: () => Skeleton(
                  label: l10n.dashCriticalAlerts,
                  slowLine: l10n.torchStillFetching,
                  child: const SkeletonRows(count: 2, rowHeight: 64),
                ),
                error: (error, _) => TorchErrorRegion(
                  name: l10n.dashCriticalAlerts,
                  child: ErrorState(
                    scope: ErrorScope.inline,
                    message: TorchErrorMessage.sanitise(error),
                    action: TorchTertiaryButton(
                      key: const ValueKey<String>('alerts-retry'),
                      label: l10n.torchTryAgain,
                      onPressed: () => ref.invalidate(alertsListProvider),
                    ),
                  ),
                ),
                data: (list) => _alertRows(context, l10n, list),
              ),
              tasks.when(
                loading: () => Skeleton(
                  label: l10n.dashTasksOpen,
                  slowLine: l10n.torchStillFetching,
                  child: const SkeletonRows(count: 1, rowHeight: 64),
                ),
                error: (error, _) => TorchErrorRegion(
                  name: l10n.dashTasksOpen,
                  child: ErrorState(
                    scope: ErrorScope.inline,
                    message: TorchErrorMessage.sanitise(error),
                    action: TorchTertiaryButton(
                      key: const ValueKey<String>('tasks-retry'),
                      label: l10n.torchTryAgain,
                      onPressed: () => ref.invalidate(tasksListProvider),
                    ),
                  ),
                ),
                data: (list) => _taskRow(context, l10n, list),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alertRows(
    BuildContext context,
    AppLocalizations l10n,
    List<AlertItem> list,
  ) {
    final open = list.where((a) => !a.acknowledged).toList();
    final critical = open.where((a) => a.severity == 'critical').toList();
    final warnings = open.where((a) => a.severity != 'critical').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _AttentionRow(
          rowKey: const ValueKey<String>('attention-critical-alerts'),
          title: l10n.dashCriticalAlerts,
          count: critical.length,
          detail: _metricBreakdown(l10n, critical),
          // Crimson at two commitment levels, plus the silhouette the bar
          // draws, plus the word — never the hue alone.
          severity: critical.isEmpty
              ? SoftRowSeverity.none
              : SoftRowSeverity.critical,
          severityLabel: l10n.dashSeverityCritical,
          onTap: () => context.go('/alerts'),
        ),
        _AttentionRow(
          rowKey: const ValueKey<String>('attention-warning-alerts'),
          title: l10n.dashWarningAlerts,
          count: warnings.length,
          detail: warnings.isEmpty
              ? l10n.dashNothingOutstanding
              : _metricBreakdown(l10n, warnings),
          severity: warnings.isEmpty
              ? SoftRowSeverity.none
              : SoftRowSeverity.watch,
          severityLabel: l10n.dashSeverityWatch,
          onTap: () => context.go('/alerts'),
        ),
      ],
    );
  }

  Widget _taskRow(
    BuildContext context,
    AppLocalizations l10n,
    List<TaskItem> list,
  ) {
    final open = list.where((t) => t.status != 'closed').toList();
    final critical = open.where((t) => t.priority == 'critical').length;
    return _AttentionRow(
      rowKey: const ValueKey<String>('attention-open-tasks'),
      title: l10n.dashTasksOpen,
      count: open.length,
      // GET /tasks has no dueAt, so an "SLA breach" count is not computable
      // client-side. Report what we can actually stand behind.
      detail: critical == 0
          ? l10n.dashNoneAtCritical
          : l10n.dashNAtCritical(critical),
      severity: critical > 0 ? SoftRowSeverity.watch : SoftRowSeverity.none,
      severityLabel: l10n.dashSeverityWatch,
      last: true,
      onTap: () => context.go('/tasks'),
    );
  }

  static String _metricBreakdown(
    AppLocalizations l10n,
    List<AlertItem> alerts,
  ) {
    if (alerts.isEmpty) return l10n.dashNothingOutstanding;
    final counts = <String, int>{};
    for (final a in alerts) {
      counts[a.metric] = (counts[a.metric] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => '${e.value} ${e.key.replaceAll('_', ' ')}')
        .join(' · ');
  }
}

/// One counted thing that needs a manager, as a row.
///
/// A measured zero renders `0` and keeps its place — an all-zero list is a
/// finding, not an empty state, and a row that vanished when its count reached
/// nought would make a manager think the check had stopped running.
class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.rowKey,
    required this.title,
    required this.count,
    required this.detail,
    required this.severity,
    required this.severityLabel,
    required this.onTap,
    this.last = false,
  });

  final Key rowKey;
  final String title;
  final int count;
  final String detail;
  final SoftRowSeverity severity;
  final String severityLabel;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final armed = severity != SoftRowSeverity.none;
    return SoftRow(
      key: rowKey,
      density: SoftRowDensity.tall,
      title: title,
      subtitle: detail,
      severity: severity,
      severityLabel: armed ? severityLabel : null,
      trailing: FigureSlot(
        value: count,
        role: skin.text.figureM,
        unit: TiqUnit.none,
        state: FigureState.measured,
        textAlign: TextAlign.end,
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      onTap: onTap,
      semanticsLabel: <String>[
        title,
        '$count',
        if (armed) severityLabel,
        detail,
      ].join('. '),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Where we sit against the standard
// ═══════════════════════════════════════════════════════════════════════

/// One KPI and the standard it is judged by.
///
/// On-shelf availability and the perfect-store band are published industry
/// reference points (the design handoff sources them); the rest are the
/// handoff's internal standards. Each is drawn as a tick on the row's meter,
/// so a figure is never read without the line it is measured against.
typedef _Indicator = ({
  String id,
  double Function(DashboardKpis) read,
  int? Function(DashboardSampleSizes) sample,
  double target,
});

const List<_Indicator> _indicators = <_Indicator>[
  (id: 'osa', read: _osa, sample: _nOsa, target: 95),
  (id: 'perfect', read: _perfect, sample: _nPerfect, target: 80),
  (id: 'price', read: _price, sample: _nPrice, target: 95),
  (id: 'visibility', read: _visibility, sample: _nVisibility, target: 80),
  (id: 'sos', read: _sos, sample: _nSos, target: 33),
  (id: 'weighted', read: _weighted, sample: _nWeighted, target: 85),
  (id: 'numeric', read: _numeric, sample: _nNumeric, target: 85),
];

double _osa(DashboardKpis k) => k.osaPct;
double _perfect(DashboardKpis k) => k.perfectStoreRate;
double _price(DashboardKpis k) => k.priceCompliancePct;
double _visibility(DashboardKpis k) => k.visibilityCompliancePct;
double _sos(DashboardKpis k) => k.shareOfShelf;
double _weighted(DashboardKpis k) => k.weightedDistribution;
double _numeric(DashboardKpis k) => k.numericDistribution;

int? _nOsa(DashboardSampleSizes s) => s.osaPct;
int? _nPerfect(DashboardSampleSizes s) => s.perfectStoreRate;
int? _nPrice(DashboardSampleSizes s) => s.priceCompliancePct;
int? _nVisibility(DashboardSampleSizes s) => s.visibilityCompliancePct;
int? _nSos(DashboardSampleSizes s) => s.shareOfShelf;
int? _nWeighted(DashboardSampleSizes s) => s.weightedDistribution;
int? _nNumeric(DashboardSampleSizes s) => s.numericDistribution;

String indicatorLabel(AppLocalizations l10n, String id) => switch (id) {
  'osa' => l10n.dashKpiOsa,
  'perfect' => l10n.dashKpiPerfectStore,
  'price' => l10n.dashKpiPrice,
  'visibility' => l10n.dashKpiVisibility,
  'sos' => l10n.dashKpiShareOfShelf,
  'weighted' => l10n.dashKpiWeighted,
  _ => l10n.dashKpiNumeric,
};

String indicatorNote(AppLocalizations l10n, String id) => switch (id) {
  'osa' => l10n.dashKpiOsaNote,
  'perfect' => l10n.dashKpiPerfectStoreNote,
  'price' => l10n.dashKpiPriceNote,
  'visibility' => l10n.dashKpiVisibilityNote,
  'sos' => l10n.dashKpiShareOfShelfNote,
  'weighted' => l10n.dashKpiWeightedNote,
  _ => l10n.dashKpiNumericNote,
};

/// On the standard, within ten points of it, or breaching it.
StatusLevel againstStandard(double value, double target) => value >= target
    ? StatusLevel.onTarget
    : value >= target - 10
    ? StatusLevel.watch
    : StatusLevel.critical;

/// The severity mark a standing maps onto. `onTarget` is not a severity, so it
/// draws no mark at all rather than a green one — a verdict is only ever
/// crimson in this system.
SeverityMarkKind? severityFor(StatusLevel level) => switch (level) {
  StatusLevel.critical => SeverityMarkKind.critical,
  StatusLevel.watch => SeverityMarkKind.watch,
  _ => null,
};

String standingWord(AppLocalizations l10n, StatusLevel level) =>
    switch (level) {
      StatusLevel.critical => l10n.dashStandingCritical,
      StatusLevel.watch => l10n.dashStandingWatch,
      _ => l10n.dashStandingOnTarget,
    };

/// The movement against the like-for-like window before this one (#365).
///
/// `direction` is the shape and `sentiment` is the colour, and neither is
/// derived from the other. These seven are all rates where up is good, so the
/// mapping is stated once here rather than guessed per call site.
DeltaData? deltaFor(AppLocalizations l10n, KpiDelta delta) {
  if (!delta.hasDelta) return null;
  final change = delta.change!;
  return DeltaData(
    direction: change > 0
        ? DeltaDirection.up
        : change < 0
        ? DeltaDirection.down
        : DeltaDirection.flat,
    sentiment: change > 0
        ? TiqSentiment.good
        : change < 0
        ? TiqSentiment.bad
        : TiqSentiment.neutral,
    magnitude: change.abs(),
    unit: TiqUnit.worded('pts'),
    decimals: 1,
    comparedTo: l10n.dashVsWindowBefore,
  );
}

class _StandardsSection extends ConsumerWidget {
  const _StandardsSection({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final gutter = context.skin.space.gutter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.dashAgainstStandard),
        const SizedBox(height: TiqSpace.s3),
        Padding(
          padding: const EdgeInsets.only(bottom: TiqSpace.s4),
          child: Text(
            l10n.dashTickMarksTarget,
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
        ),
        snapshot.when(
          loading: () => Skeleton(
            label: l10n.dashAgainstStandard,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
          error: (error, _) => TorchErrorRegion(
            name: l10n.dashAgainstStandard,
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                key: const ValueKey<String>('standards-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(dashboardSnapshotProvider),
              ),
            ),
          ),
          data: (snap) => TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < _indicators.length; i++)
                  _IndicatorRow(
                    indicator: _indicators[i],
                    snapshot: snap,
                    // `/trends` serves three series and no more (#95). The
                    // other indicators have no history endpoint, so they get
                    // no sparkline — a fabricated shape would be the most
                    // confident-looking lie on the screen.
                    series: _series(ref, _indicators[i].id),
                    last: i == _indicators.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<double>? _series(WidgetRef ref, String id) {
    List<double>? read(AsyncValue<List<TrendPoint>> v) => v.maybeWhen(
      data: (points) =>
          points.length < 2 ? null : <double>[for (final p in points) p.value],
      orElse: () => null,
    );
    return switch (id) {
      'osa' => read(ref.watch(availabilityTrendProvider)),
      'perfect' => read(ref.watch(perfectStoreTrendProvider)),
      _ => null,
    };
  }
}

/// One indicator, its standard, its movement and its shape.
class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({
    required this.indicator,
    required this.snapshot,
    required this.series,
    required this.last,
  });

  final _Indicator indicator;
  final DashboardSnapshot snapshot;
  final List<double>? series;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final current = snapshot.current;
    final measured = current.measuredSomething;
    final value = indicator.read(current);
    final label = indicatorLabel(l10n, indicator.id);
    final n = indicator.sample(current.sampleSizes);
    final sampling = FigureSampling(
      kind: MetricKind.rate,
      n: n,
      baselineN: snapshot.previous == null
          ? null
          : indicator.sample(snapshot.previous!.sampleSizes),
    );
    final thin = measured && sampling.isLowSample;
    final status = againstStandard(value, indicator.target);
    final numbers = TiqNumber.of(context);

    // A delta never stands beside nothing, and never beside a figure this
    // thin: unify line 271 removes it for a low sample and for a thin
    // baseline alike.
    final delta = measured && !thin
        ? deltaFor(l10n, snapshot.of(indicator.read))
        : null;

    return SoftRow(
      key: ValueKey<String>('kpi-${indicator.id}'),
      density: SoftRowDensity.tall,
      title: label,
      subtitle: indicatorNote(l10n, indicator.id),
      // A severity bar would be four crimson bars on one list; the standing
      // is carried by the meter's tick, by the word in the trailing column
      // and by the mark beside it instead.
      meta: Row(
        children: <Widget>[
          Expanded(
            child: Meter(
              value: measured ? value : null,
              target: indicator.target,
              state: !measured
                  ? MeterState.missing
                  : thin
                  ? MeterState.lowSample
                  : MeterState.filled,
            ),
          ),
          if (series != null) ...<Widget>[
            const SizedBox(width: TiqSpace.s3),
            Sparkline(points: series!, severity: severityFor(status)),
          ],
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FigureSlot(
            value: measured ? value : null,
            role: skin.text.figureM,
            unit: measured ? TiqUnit.percent : TiqUnit.none,
            decimals: 1,
            state: !measured
                ? FigureState.missing
                : thin
                ? FigureState.lowSample
                : FigureState.measured,
            textAlign: TextAlign.end,
            // An em dash announced as "em dash" is not a sentence. The row's
            // own label carries the whole reading, and this is the figure's
            // half of it.
            semanticsLabel: !measured
                ? l10n.dashNoVisitsInWindow
                : thin
                ? '${numbers.format(value, unit: TiqUnit.percent, decimals: 1)}, '
                      '${l10n.trendsSmallSample}'
                : null,
          ),
          if (measured)
            // Wraps rather than overflows: at 2.0x "Close to the standard"
            // beside a 24dp mark is wider than a trailing column has.
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TiqSpace.s1,
              children: <Widget>[
                if (severityFor(status) != null)
                  SeverityMark(kind: severityFor(status)!),
                Text(
                  standingWord(l10n, status),
                  textAlign: TextAlign.end,
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
              ],
            ),
          if (measured && delta != null)
            DeltaSlot(
              data: delta,
              figureState: thin
                  ? FigureState.lowSample
                  : FigureState.measured,
              sampling: sampling,
            ),
        ],
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      // `meta` sits inside the row's excluded label, so the meter and the
      // sparkline are silent to a reader. The whole reading goes here.
      semanticsLabel: <String>[
        label,
        if (!measured)
          l10n.dashNoVisitsInWindow
        else ...<String>[
          numbers.format(value, unit: TiqUnit.percent, decimals: 1),
          if (thin) l10n.trendsSmallSample,
          standingWord(l10n, status),
          l10n.dashTargetIs(
            numbers.format(indicator.target, unit: TiqUnit.percent),
          ),
        ],
        indicatorNote(l10n, indicator.id),
      ].join('. '),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Perfect-store distribution
// ═══════════════════════════════════════════════════════════════════════

/// How many outlets sit in each perfect-store band, by their latest scored
/// visit — doors, not visits.
///
/// Rows and meters, not columns: a bar chart does not render in Veld and this
/// is a comparison of five counted categories, which is a list of five rows in
/// every skin. The panel is hidden when the server sends no bands at all —
/// five zero-height bars would be a picture of a field that does not exist,
/// which is not the same thing as five measured noughts.
class _DistributionSection extends StatelessWidget {
  const _DistributionSection({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bands = snapshot.maybeWhen(
      data: (snap) => snap.current.scoreBands,
      orElse: () => const <ScoreBand>[],
    );
    if (bands.isEmpty) return const SizedBox.shrink();

    final total = bands.fold<int>(0, (sum, b) => sum + b.outlets);
    final most = bands.fold<int>(0, (m, b) => m > b.outlets ? m : b.outlets);
    final gutter = context.skin.space.gutter;
    final skin = context.skin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.dashDistribution, count: total),
        const SizedBox(height: TiqSpace.s3),
        Padding(
          padding: const EdgeInsets.only(bottom: TiqSpace.s4),
          child: Text(
            l10n.dashHealthyBand,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ),
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < bands.length; i++)
                SoftRow(
                  key: ValueKey<String>('band-${bands[i].label}'),
                  density: SoftRowDensity.compact,
                  title: bands[i].label,
                  meta: Meter(
                    value: bands[i].outlets.toDouble(),
                    maximum: most == 0 ? 1 : most.toDouble(),
                  ),
                  trailing: FigureSlot(
                    value: bands[i].outlets,
                    role: skin.text.figureS,
                    unit: TiqUnit.none,
                    state: FigureState.measured,
                    textAlign: TextAlign.end,
                  ),
                  separator: i == bands.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                  semanticsLabel: l10n.dashBandOutlets(
                    bands[i].outlets,
                    bands[i].label,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: skin.space.blockGap),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Execution score by territory
// ═══════════════════════════════════════════════════════════════════════

class _TerritorySection extends ConsumerWidget {
  const _TerritorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final territories = ref.watch(territoriesListProvider);
    final gutter = context.skin.space.gutter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.dashByTerritory),
        const SizedBox(height: TiqSpace.s3),
        Padding(
          padding: const EdgeInsets.only(bottom: TiqSpace.s4),
          child: Text(
            l10n.dashTargetIs(executionScoreTarget.round().toString()),
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
        ),
        territories.when(
          loading: () => Skeleton(
            label: l10n.dashByTerritory,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 3, rowHeight: 64),
          ),
          error: (error, _) => TorchErrorRegion(
            name: l10n.dashByTerritory,
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                key: const ValueKey<String>('territories-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(territoriesListProvider),
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                scope: EmptyScope.inPanel,
                headline: l10n.dashNoTerritories,
                body: l10n.dashNoTerritoriesBody,
              );
            }
            return TorchBleed(
              extra: gutter * 2,
              child: _TerritoryScores(territories: list),
            );
          },
        ),
      ],
    );
  }
}

/// Every territory's KPIs in a single `GET /dashboard/by-territory` call —
/// see #97.
class _TerritoryScores extends ConsumerWidget {
  const _TerritoryScores({required this.territories});

  final List<Territory> territories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final byTerritory = ref.watch(dashboardByTerritoryProvider);

    return byTerritory.when(
      loading: () => Skeleton(
        label: l10n.dashByTerritory,
        slowLine: l10n.torchStillFetching,
        child: const SkeletonRows(count: 3, rowHeight: 64),
      ),
      // An error must never render as a loader: a spinner reads as "still
      // loading" and never recovers (#222).
      error: (error, _) => TorchErrorRegion(
        name: l10n.dashByTerritory,
        child: ErrorState(
          scope: ErrorScope.inline,
          message: TorchErrorMessage.sanitise(error),
          action: TorchTertiaryButton(
            key: const ValueKey<String>('territory-scores-retry'),
            label: l10n.torchTryAgain,
            onPressed: () => ref.invalidate(dashboardByTerritoryProvider),
          ),
        ),
      ),
      data: (summaries) {
        final byId = <String, TerritoryDashboardKpis>{
          for (final s in summaries) s.territoryId: s,
        };
        final scored = <({String name, double value})>[
          for (final t in territories)
            if (byId[t.id] != null)
              (name: t.name, value: byId[t.id]!.kpis.executionScore),
        ];
        // Territories exist but no summary overlaps them — a real backend
        // state, not a pending fetch. The future already completed, so a
        // loader here would spin forever (#222); the same rule as the error
        // arm above.
        if (scored.isEmpty) {
          return EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.dashNoTerritoryScores,
            body: l10n.dashNoTerritoryScoresBody,
          );
        }
        // Worst first, always: a ranked comparison a manager reads to decide
        // where to go is read from the top.
        scored.sort((a, b) => a.value.compareTo(b.value));
        final numbers = TiqNumber.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < scored.length; i++)
              _territoryRow(
                context,
                l10n,
                skin,
                numbers,
                scored[i],
                i == scored.length - 1,
              ),
          ],
        );
      },
    );
  }

  Widget _territoryRow(
    BuildContext context,
    AppLocalizations l10n,
    TiqSkin skin,
    TiqNumber numbers,
    ({String name, double value}) entry,
    bool last,
  ) {
    final status = againstStandard(entry.value, executionScoreTarget);
    return SoftRow(
      key: ValueKey<String>('territory-score-${entry.name}'),
      density: SoftRowDensity.tall,
      title: entry.name,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: standingWord(l10n, status),
      meta: Meter(value: entry.value, target: executionScoreTarget),
      trailing: FigureSlot(
        value: entry.value,
        role: skin.text.figureS,
        unit: TiqUnit.none,
        decimals: 1,
        state: FigureState.measured,
        textAlign: TextAlign.end,
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        entry.name,
        numbers.format(entry.value, decimals: 1),
        standingWord(l10n, status),
        l10n.dashTargetIs(executionScoreTarget.round().toString()),
      ].join('. '),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// On-shelf availability by period
// ═══════════════════════════════════════════════════════════════════════

class _AvailabilitySection extends ConsumerStatefulWidget {
  const _AvailabilitySection();

  @override
  ConsumerState<_AvailabilitySection> createState() =>
      _AvailabilitySectionState();
}

class _AvailabilitySectionState extends ConsumerState<_AvailabilitySection> {
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _TrendPanel(
      heading: l10n.dashAvailabilityByPeriod,
      seriesName: l10n.dashKpiOsa,
      provider: availabilityTrendProvider,
      kind: MetricKind.rate,
      unit: TiqUnit.percent,
      threshold: ChartThreshold(value: 95, label: l10n.trendsTarget),
      asTable: _asTable,
      onViewChanged: (v) => setState(() => _asTable = v),
      async: ref.watch(availabilityTrendProvider),
      chartKey: const ValueKey<String>('dashboard-availability-chart'),
      tableKey: const ValueKey<String>('dashboard-availability-table'),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Where are my agents — today's confirmed stops
// ═══════════════════════════════════════════════════════════════════════

/// Below this the map and list sit side by side; below it they stack.
const _panelWide = 1080.0;

/// Fixed so the map never dominates a screen whose real subject is the
/// execution score above it.
const _mapHeight = 260.0;

/// The panel's fixed fallback/single-pin zoom — close enough to read
/// individual outlets, used both for `MapOptions.initialZoom` and the
/// `onMapReady` `move()` fallback so the two never drift apart.
const _mapZoom = 11.0;

/// This agent's most recent confirmed stop. Sorts defensively rather than
/// trusting `stops` to already be in order, for the same reason
/// [AgentActivity.lastOutletName] does. Callers must only pass agents with
/// `stops.isNotEmpty`.
AgentStop _latestStop(AgentActivity agent) {
  final sorted = <AgentStop>[...agent.stops]
    ..sort((a, b) => a.checkinTs.compareTo(b.checkinTs));
  return sorted.last;
}

/// The word for a check-in state. Colour is never the carrier (#144) — every
/// state also gets its own [AgentStateGlyph] silhouette.
String agentStateWord(AppLocalizations l10n, AgentState state) =>
    switch (state) {
      AgentState.atStore => l10n.liveStateAtStore,
      AgentState.inTransit => l10n.liveStateInTransit,
      AgentState.idle => l10n.dashNoCheckIn,
    };

/// The ink for a check-in state, from the tokens. In transit is
/// `chartNeutral` and never amber: Burning Flame is emitted light, and a list
/// of eleven agents would be eleven of them.
Color agentStateInk(AgentState state, TiqPalette palette) => switch (state) {
  AgentState.atStore => palette.good,
  AgentState.inTransit => palette.chartNeutral,
  AgentState.idle => palette.inkMute,
};

/// The empty-state copy when the filtered page has zero agents.
///
/// An empty list with no explanation reads as "the app is broken" — which is
/// exactly what got reported here: a manager filtered to a territory nobody
/// happens to be assigned to, the query was correct, and the fixed string gave
/// them no way to tell the two apart. Naming the territory turns a dead end
/// into something actionable; when no filter is active the territory cannot be
/// the reason, so the wording does not imply one. A territory the list has not
/// loaded, or no longer contains, falls back to wording that names none — a
/// blank, "null" or a raw id would all be worse.
String emptyActivityMessage(
  WidgetRef ref,
  AppLocalizations l10n,
  String? territoryId,
) {
  if (territoryId == null) return l10n.dashNoAgentsYet;
  final name = territoryName(ref, territoryId);
  return name == null
      ? l10n.dashNoAgentsForFilter
      : l10n.dashNoAgentsIn(name);
}

/// Map + compact list — the map is the hero, the list is what keeps it honest.
///
/// Pins mark the last *confirmed* check-in, never a live position (#153 is
/// T0 — there is no heartbeat to plot). An agent with no stops today gets no
/// pin; the list is the only reason they do not simply vanish from the panel,
/// and the line beneath the map says how many that is.
///
/// The map is ALWAYS present once there is anything at all to draw. It used to
/// disappear entirely whenever nobody had checked in yet, leaving only the
/// list and a "View map" button that led nowhere useful — reported as "the map
/// is not showing". The tenant's outlets form a base layer of muted place pins
/// under the agent glyphs, so a manager always sees their store network.
/// `outletsListProvider` is NOT territory-scoped, so a territory-filtered view
/// can show more outlets than the (scoped) agents beside them. Acceptable for
/// a base layer: the outlets are real, just not narrowed the way the agent
/// list is.
///
/// **Veld draws no map at all** (unify §4). The list is the replacement, which
/// is what it always was for a screen reader.
///
/// Public rather than private so the widget test can pump it on its own.
class AgentActivityPanel extends ConsumerWidget {
  const AgentActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final gutter = skin.space.gutter;
    final activity = ref.watch(agentActivityTodayProvider);
    final filter = ref.watch(dashboardFilterProvider);
    // `maybeWhen` rather than `.when`: outlets are a base layer, not the
    // panel's primary data. A slow or failed outlet fetch must never blank
    // the whole panel or block the agent map.
    final outlets = ref
        .watch(outletsListProvider)
        .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);
    // The live layer (#153 T1) — a layer, like the outlets. `.value` keeps the
    // last positions on screen while a poll is in flight, so pins do not blink
    // every 30 seconds.
    final livePositions = <AgentLocation>[
      for (final a
          in ref.watch(liveAgentLocationsProvider).value?.agents ??
              const <AgentLocation>[])
        if (a.hasPosition) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(
          l10n.dashWhereAgents,
          action: SectionRuleAction(
            l10n.dashViewMap,
            key: const ValueKey<String>('agent-activity-view-map'),
            onTap: () => context.go('/agents/activity'),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        Padding(
          padding: const EdgeInsets.only(bottom: TiqSpace.s4),
          child: Text(
            l10n.dashTodaysCheckIns,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ),
        activity.when(
          skipLoadingOnReload: true,
          loading: () => Skeleton(
            label: l10n.dashWhereAgents,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 3, rowHeight: 64),
          ),
          error: (error, _) => TorchErrorRegion(
            name: l10n.dashWhereAgents,
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                key: const ValueKey<String>('agent-activity-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(agentActivityTodayProvider),
              ),
            ),
          ),
          data: (page) {
            if (page.agents.isEmpty) {
              return EmptyState(
                scope: EmptyScope.inPanel,
                headline: l10n.dashNoAgentsHeadline,
                body: emptyActivityMessage(ref, l10n, filter.territoryId),
              );
            }

            final withStops = <AgentActivity>[
              for (final a in page.agents)
                if (a.stops.isNotEmpty) a,
            ];
            final notPlotted = page.agents.length - withStops.length;
            final list = TorchBleed(
              extra: gutter * 2,
              child: _AgentList(agents: page.agents),
            );
            // Veld draws no map. Everywhere else the map draws as long as
            // there is EITHER a checked-in agent OR an outlet to place — a
            // base layer of stores is still a map worth showing on a quiet
            // morning.
            final hasMapContent =
                skin.mode != SkinMode.veld &&
                (withStops.isNotEmpty ||
                    outlets.isNotEmpty ||
                    livePositions.isNotEmpty);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!hasMapContent) ...<Widget>[
                  // Nothing to plot at all: a grey, empty map would look
                  // broken rather than honest, so the list carries the panel
                  // alone and says in words why there is nothing to draw.
                  if (skin.mode != SkinMode.veld)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TiqSpace.s3),
                      child: Text(
                        l10n.dashNoOutletsToPlot,
                        style: skin.text.meta.style(color: skin.palette.ink3),
                      ),
                    ),
                  list,
                ] else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= _panelWide;
                      final map = SizedBox(
                        height: _mapHeight,
                        child: _AgentMap(
                          agentsWithStops: withStops,
                          outlets: outlets,
                          live: livePositions,
                        ),
                      );
                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            map,
                            const SizedBox(height: TiqSpace.s4),
                            list,
                          ],
                        );
                      }
                      return SizedBox(
                        height: _mapHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(flex: 2, child: map),
                            const SizedBox(width: TiqSpace.s4),
                            Expanded(
                              flex: 1,
                              child: SingleChildScrollView(child: list),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: TiqSpace.s3),
                // Says who is plotted and who is not in one line, so the map
                // can never quietly read as "the whole team" when some agents
                // have no confirmed stop to draw.
                Text(
                  l10n.dashOnTheMap(withStops.length, notPlotted),
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
                // Never let a cut list read as the whole team. A manager who
                // cannot see an agent concludes they did not work, not that
                // the list ran out.
                if (page.truncated)
                  Padding(
                    padding: const EdgeInsets.only(top: TiqSpace.s2),
                    child: Text(
                      l10n.dashFirst200Agents,
                      style: skin.text.meta.style(color: skin.palette.ink3),
                    ),
                  ),
                SizedBox(height: skin.space.blockGap),
                const LiveLocationsSection(),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The compact list half of the panel — every agent, idle ones included. It is
/// what stops an agent with no stops from vanishing when the map cannot place
/// them, and in Veld it is the whole panel.
class _AgentList extends StatelessWidget {
  const _AgentList({required this.agents});

  final List<AgentActivity> agents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < agents.length; i++)
          _AgentRow(agent: agents[i], last: i == agents.length - 1),
      ],
    );
  }
}

/// One agent, one row.
///
/// Every row leads with WHEN, not just where. A row that says "Sandton Spar"
/// with no age reads as live; this data is never live, and the age is the only
/// thing that keeps the row honest.
class _AgentRow extends ConsumerWidget {
  const _AgentRow({required this.agent, required this.last});

  final AgentActivity agent;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final word = agentStateWord(l10n, agent.state);

    // Idle carries no location line: the age column already reads "no
    // check-in today", and repeating that fact here would say the same thing
    // twice in exactly the row where space is tightest.
    final secondLine = switch (agent.state) {
      AgentState.atStore => '$word · ${agent.currentOutletName ?? l10n.dashUnknownStore}',
      AgentState.inTransit =>
        '$word · ${agent.lastOutletName == null ? l10n.dashInTransit : l10n.dashLeft(agent.lastOutletName!)}',
      AgentState.idle => word,
    };
    final age = agent.lastSeenAt == null
        ? l10n.dashNoCheckInToday
        : formatAgo(agent.lastSeenAt!, l10n);

    return SoftRow(
      key: ValueKey<String>('agent-row-${agent.agentId}'),
      density: SoftRowDensity.compact,
      leading: AgentStateGlyph(
        key: ValueKey<String>('agent-state-icon-${agent.agentId}'),
        state: agent.state,
        color: agentStateInk(agent.state, skin.palette),
        size: 16,
      ),
      title: agent.name,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: secondLine,
      trailing: Text(
        age,
        style: skin.text.meta.style(color: skin.palette.ink3),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: '${agent.name}, $secondLine, $age',
    );
  }
}

/// The map half — one pin per agent with at least one confirmed stop today,
/// placed at their latest one, over a base layer of the tenant's outlets. No
/// polylines here: the drill-in trail map carries the day's route, this one
/// only answers "where are they now" (as of their last check-in).
///
/// Caller guarantees at least one of [agentsWithStops], [outlets] or [live] is
/// non-empty before constructing this — `fitFor` asserts a non-empty point
/// list, and there is nothing this widget could sensibly draw with neither.
class _AgentMap extends StatelessWidget {
  const _AgentMap({
    required this.agentsWithStops,
    required this.outlets,
    this.live = const <AgentLocation>[],
  });

  /// Must all have `stops.isNotEmpty` — callers filter before constructing.
  final List<AgentActivity> agentsWithStops;

  /// Live positions (#153 T1). Must all have `hasPosition`.
  final List<AgentLocation> live;

  /// The tenant's outlets, unfiltered by territory.
  final List<Outlet> outlets;

  @override
  Widget build(BuildContext context) {
    final agentPoints = <LatLng>[
      for (final a in agentsWithStops)
        LatLng(_latestStop(a).lat, _latestStop(a).lng),
    ];
    final outletPoints = <LatLng>[for (final o in outlets) LatLng(o.lat, o.lng)];
    // Agents are the priority signal, but a fit that includes nearby stores
    // too is harmless — and when nobody has checked in yet, the outlets are
    // the ONLY points there are to fit against. Live positions move every
    // poll; fitting the camera to them would drag the map out from under a
    // manager every 30 seconds, so they decide the fit only when there is
    // nothing else to fit to.
    final points = agentPoints.isEmpty && outletPoints.isEmpty
        ? <LatLng>[for (final a in live) LatLng(a.lat!, a.lng!)]
        : <LatLng>[...agentPoints, ...outletPoints];

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.skin.radii.panel),
      // This panel lives below the fold on a typical screen — a scrollable can
      // lay a child out before it is ever scrolled into view, sometimes on a
      // transient pass with a zero or unbounded size. The LayoutBuilder plus
      // the degenerate guard below exist for that: skip the map entirely
      // rather than mount it against a viewport it can't use.
      //
      // The centre/zoom are computed OURSELVES, by `fitFor` — not by
      // flutter_map's own `CameraFit.bounds`/`initialCameraFit`, and not by
      // calling `fitCamera` from `onMapReady` either. Both of those depend on
      // flutter_map's own internal camera size, which — confirmed against the
      // running web build — was STILL zero at the moment `onMapReady` fired,
      // silently producing a near-world zoom centred nowhere near the data.
      // `fitFor` uses the real pixel `size` this `LayoutBuilder` already has
      // in hand and plain Web Mercator maths (core/geo/mercator_fit.dart), so
      // there is no flutter_map camera state left to race.
      //
      // The key is SIZE ONLY, not a fingerprint of the plotted coordinates: a
      // genuine size change still mounts a fresh State, while a moved set of
      // pins (a territory-filter change, same size) is travelled to by
      // `_CameraDriver` on the SAME map instead of snapping.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final degenerate =
              !size.width.isFinite ||
              !size.height.isFinite ||
              size.width <= 0 ||
              size.height <= 0;
          if (degenerate) return const SizedBox.shrink();

          final (center, zoom) = fitFor(
            points,
            size: size,
            padding: 24,
            singleZoom: _mapZoom,
          );

          return FlutterMap(
            key: ValueKey<Size>(size),
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              // Correctness fix, not a preference — do NOT restore the missing
              // flag. This map is a passenger inside a scroll view, not a
              // full-screen map: a manager reaching this below-the-fold panel
              // scrolls the page with their mouse wheel. flutter_map's default
              // interaction options treat that same wheel as a zoom gesture —
              // so the wheel that was meant to keep scrolling the page instead
              // zooms the map AND silently destroys the fit `fitFor` computed.
              // Drag, pinch and double-tap zoom all stay on.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: <Widget>[
              const TiqTileLayer(),
              const TiqNavyTint(),
              const TiqBasemapLabels(),
              MarkerLayer(
                // Outlets first, agents last: marker paint order follows list
                // order, so a checked-in agent standing at (or near) an outlet
                // is never hidden underneath that outlet's base-layer dot.
                markers: <Marker>[
                  for (final o in outlets)
                    Marker(
                      point: LatLng(o.lat, o.lng),
                      width: 14,
                      height: 14,
                      child: _OutletBasePin(
                        key: ValueKey<String>('outlet-base-pin-${o.id}'),
                        outlet: o,
                      ),
                    ),
                  for (final a in agentsWithStops)
                    Marker(
                      point: LatLng(_latestStop(a).lat, _latestStop(a).lng),
                      width: 30,
                      height: 30,
                      child: _AgentMapPin(
                        key: ValueKey<String>('agent-pin-${a.agentId}'),
                        agent: a,
                      ),
                    ),
                  // Live squares last, on top of check-in discs and outlets.
                  ...liveAgentMarkers(live),
                ],
              ),
              const TiqBasemapAttribution(),
              // Not a visual layer — a headless widget living inside the
              // `FlutterMap` subtree purely so it can reach
              // `MapController.of(context)`, the map's own INTERNAL controller
              // (we deliberately never pass `mapController:` above, which is
              // what keeps `map.mapController` null for the regression test).
              _CameraDriver(target: (center, zoom)),
            ],
          );
        },
      ),
    );
  }
}

/// Drives one mounted [FlutterMap]'s camera toward each new `fitFor` target as
/// an eased travel rather than a snap, when [target] changes under an
/// unchanged `FlutterMap` key (a territory-filter change moving the pins, not
/// a real resize).
///
/// Renders nothing — [build] returns [SizedBox.shrink].
class _CameraDriver extends StatefulWidget {
  const _CameraDriver({required this.target});

  final (LatLng, double) target;

  @override
  State<_CameraDriver> createState() => _CameraDriverState();
}

class _CameraDriverState extends State<_CameraDriver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _eased;
  (LatLng, double)? _from;
  (LatLng, double)? _to;

  @override
  void initState() {
    super.initState();
    // The map has ALREADY mounted with `initialCenter`/`initialZoom` equal to
    // `widget.target` at this point — nothing to travel on first build, only
    // on a later target change.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_onTick);
    _eased = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(_CameraDriver old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _travelTo(widget.target);
  }

  void _travelTo((LatLng, double) target) {
    final controller = MapController.of(context);
    // The one motion switch in the system: reduce-motion, Veld and power save
    // all resolve into `MotionBudget.still`, and a still frame moves the
    // camera rather than travelling it.
    if (MotionBudget.of(context).still) {
      controller.move(target.$1, target.$2);
      return;
    }
    _from = (controller.camera.center, controller.camera.zoom);
    _to = target;
    _controller
      ..stop()
      ..value = 0
      ..forward();
  }

  void _onTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = _eased.value;
    final center = LatLng(
      from.$1.latitude + (to.$1.latitude - from.$1.latitude) * t,
      from.$1.longitude + (to.$1.longitude - from.$1.longitude) * t,
    );
    final zoom = from.$2 + (to.$2 - from.$2) * t;
    MapController.of(context).move(center, zoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// One outlet on the panel's map — the base layer under the agent pins.
///
/// Deliberately NOT a scaled-down [_AgentMapPin]: #144's rule that state must
/// differ by SILHOUETTE, not colour or size, cuts both ways here — a place
/// marker must be just as unmistakably NOT a person's state. [AgentStateGlyph]
/// draws a literal storefront for [AgentState.atStore]; reusing anything
/// storefront-shaped for an outlet would recreate exactly the confusion #144
/// already cost this feature twice. So this is a plain small dot with a hollow
/// centre — a place marker's silhouette, not a state's — in the basemap's own
/// quiet ink so an agent glyph is always the eye's first stop.
class _OutletBasePin extends StatelessWidget {
  const _OutletBasePin({super.key, required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = basemapPalette;
    return Semantics(
      label: l10n.dashOutletPin(outlet.name),
      excludeSemantics: true,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Quiet next to the agent pins, and no glow: the basemap is the
            // one place in this product with a paint budget it can lose, and a
            // shadow per outlet is a shadow per outlet.
            color: p.lifted,
            border: Border.all(color: p.edgeStructure),
          ),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.ink1,
            ),
          ),
        ),
      ),
    );
  }
}

/// One agent's latest confirmed stop, on the panel's map.
///
/// Deliberately not numbered like the trail screen's stops — this map shows
/// one point per agent, not a sequence, so a plain state glyph says more than
/// an ordinal would. Night tokens in every skin, like every other pin on the
/// basemap.
class _AgentMapPin extends StatelessWidget {
  const _AgentMapPin({super.key, required this.agent});

  final AgentActivity agent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = basemapPalette;
    final stop = _latestStop(agent);

    return Semantics(
      label:
          '${agent.name}, ${agentStateWord(l10n, agent.state)}, '
          '${stop.outletName}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.surface,
          border: Border.all(color: p.ink1, width: 1.5),
        ),
        child: Center(
          child: AgentStateGlyph(
            state: agent.state,
            // The SHAPE is the state (#144); on a 30dp disc over a dark
            // basemap the per-state inks are near-invisible and colour was
            // never the carrier anyway.
            color: p.ink1,
            size: 16,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Shared bits
// ═══════════════════════════════════════════════════════════════════════

/// A brand-new tenant: nothing on the books at all. Not a scoreboard of
/// noughts — a tenant with no outlets has not performed badly, it has not
/// started.
class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      headline: l10n.dashFirstRunHeadline,
      body: l10n.dashFirstRunBody,
      drawing: EmptyDrawing.shelf,
    );
  }
}

class _StubCaveat extends StatelessWidget {
  const _StubCaveat();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      context.l10n.dashStubCaveat,
      style: skin.text.meta.style(color: skin.palette.ink3),
    );
  }
}
