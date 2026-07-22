import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart' show formatAgo;
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../../agents/data/agents_repository.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../tasks/data/tasks_admin_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../../trends/data/trends_repository.dart';
import '../data/dashboard_repository.dart';

/// The manager's morning screen. It answers one question — *what is broken, and
/// who is fixing it?* — so the execution score and the alerts dragging it down
/// sit side by side rather than a scroll apart.
class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  /// Below this the two-column rows stack. Matches the console's rail
  /// breakpoint so the layout never fights the nav.
  static const _wide = 1080.0;

  /// Refetches every panel together.
  ///
  /// All of them, not just the one that looks stale: panels that refreshed at
  /// different moments would quietly disagree with each other, and a dashboard
  /// that contradicts itself is worse than one that is uniformly a minute old.
  ///
  /// [dashboardFilterProvider] is deliberately excluded — it holds the
  /// manager's filter selection rather than server data, and resetting it here
  /// would silently throw away what they asked to see.
  static Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardByTerritoryProvider);
    ref.invalidate(scorecardsTrendProvider);
    ref.invalidate(perfectStoreTrendProvider);
    ref.invalidate(availabilityTrendProvider);
    ref.invalidate(alertsListProvider);
    ref.invalidate(tasksListProvider);
    ref.invalidate(territoriesListProvider);
    ref.invalidate(agentActivityTodayProvider);
    // Awaited last so the progress indicator tracks the headline number; the
    // rest refetch in parallel behind it.
    ref.invalidate(dashboardSnapshotProvider);
    await ref.read(dashboardSnapshotProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardSnapshotProvider);

    return ManagerScaffold(
      title: 'Execution overview',
      // Managers are on Flutter web, where pull-to-refresh is neither obvious
      // nor comfortable with a mouse — so the gesture below is the shortcut and
      // this button is the actual affordance.
      actions: [
        IconButton(
          key: const ValueKey<String>('dashboard-refresh'),
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Refresh',
          onPressed: () => _refresh(ref),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wide;
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _FilterBar(),
                const SizedBox(height: 12),
                _TwoColumn(
                  wide: wide,
                  leftFlex: 19,
                  rightFlex: 10,
                  left: _ExecutionScorePanel(snapshot: snapshot),
                  right: const _NeedsAttentionPanel(),
                ),
                const SizedBox(height: 12),
                _KpiStrip(snapshot: snapshot),
                const SizedBox(height: 12),
                const _TwoColumn(
                  wide: true,
                  leftFlex: 1,
                  rightFlex: 1,
                  left: _TerritoryPanel(),
                  right: _AvailabilityPanel(),
                ),
                const SizedBox(height: 12),
                const AgentActivityPanel(),
                const SizedBox(height: 12),
                const _StubCaveat(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lays two panels side by side when there's width, stacked when there isn't.
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({
    required this.wide,
    required this.left,
    required this.right,
    required this.leftFlex,
    required this.rightFlex,
  });

  final bool wide;
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 12),
          Expanded(flex: rightFlex, child: right),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Hero — execution score + its trend
// ═══════════════════════════════════════════════════════════════════════

class _ExecutionScorePanel extends ConsumerWidget {
  const _ExecutionScorePanel({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(scorecardsTrendProvider);

    return PanelCard(
      title: 'Execution score',
      subtitle: 'Weighted S2–S8, all outlets',
      padded: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            snapshot.when(
              loading: () => const _InlineLoader(height: 44),
              error: (err, _) => _InlineError(
                message: 'Could not load KPIs',
                onRetry: () => ref.invalidate(dashboardSnapshotProvider),
              ),
              data: (snap) => Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // The headline figure counts up to its value. Not a flourish:
                  // it makes the number the thing the eye lands on first, which
                  // is the whole point of a hero figure.
                  TweenAnimationBuilder<double>(
                    key: const ValueKey('kpi-execution-score'),
                    tween: Tween(begin: 0, end: snap.current.executionScore),
                    duration:
                        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                        ? Duration.zero
                        : const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      v.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Measured against the window immediately before this one — the
                  // same comparison every tile below makes, so the whole screen
                  // is answering one question consistently.
                  switch (snap.of((k) => k.executionScore)) {
                    final d when d.hasDelta => DeltaBadge(
                      value: d.change!,
                      fontSize: 13,
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
            const SizedBox(height: 10),
            trend.when(
              loading: () => const _InlineLoader(height: 208),
              error: (err, _) => _InlineError(
                message: 'Could not load the score trend',
                onRetry: () => ref.invalidate(scorecardsTrendProvider),
              ),
              data: (points) => LineChart(
                points: [
                  for (final p in points) (label: p.period, value: p.value),
                ],
                target: 75,
                seriesName: 'Execution score',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Needs attention — the cause, next to the score
// ═══════════════════════════════════════════════════════════════════════

class _NeedsAttentionPanel extends ConsumerWidget {
  const _NeedsAttentionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsListProvider);
    final tasks = ref.watch(tasksListProvider);

    return PanelCard(
      title: 'Needs attention',
      padded: false,
      trailing: TextButton(
        onPressed: () => context.go('/alerts'),
        child: const Text('View all'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          alerts.when(
            loading: () => const _InlineLoader(height: 60),
            error: (err, _) => _InlineError(
              message: 'Could not load alerts',
              onRetry: () => ref.invalidate(alertsListProvider),
            ),
            data: (list) {
              final open = list.where((a) => !a.acknowledged).toList();
              final critical = open
                  .where((a) => a.severity == 'critical')
                  .length;
              final warning = open.length - critical;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AttentionRow(
                    key: const ValueKey('attention-critical-alerts'),
                    count: critical,
                    title: 'Critical alerts open',
                    meta: _metricBreakdown(
                      open.where((a) => a.severity == 'critical'),
                    ),
                    level: StatusLevel.critical,
                    onTap: () => context.go('/alerts'),
                  ),
                  AttentionRow(
                    key: const ValueKey('attention-warning-alerts'),
                    count: warning,
                    title: 'Warnings awaiting acknowledgement',
                    meta: warning == 0
                        ? 'Nothing outstanding'
                        : _metricBreakdown(
                            open.where((a) => a.severity != 'critical'),
                          ),
                    level: StatusLevel.warning,
                    onTap: () => context.go('/alerts'),
                  ),
                ],
              );
            },
          ),
          tasks.when(
            loading: () => const _InlineLoader(height: 30),
            error: (err, _) => _InlineError(
              message: 'Could not load tasks',
              onRetry: () => ref.invalidate(tasksListProvider),
            ),
            // GET /tasks has no dueAt, so an "SLA breach" count is not
            // computable client-side. Report what we can actually stand behind.
            data: (list) {
              final open = list.where((t) => t.status != 'closed').toList();
              final critical = open
                  .where((t) => t.priority == 'critical')
                  .length;
              return AttentionRow(
                key: const ValueKey('attention-open-tasks'),
                count: open.length,
                title: 'Tasks still open',
                meta: critical == 0
                    ? 'None at critical priority'
                    : '$critical at critical priority',
                level: critical > 0 ? StatusLevel.warning : StatusLevel.neutral,
                onTap: () => context.go('/tasks'),
                showDivider: false,
              );
            },
          ),
        ],
      ),
    );
  }

  static String _metricBreakdown(Iterable<AlertItem> alerts) {
    if (alerts.isEmpty) return 'Nothing outstanding';
    final counts = <String, int>{};
    for (final a in alerts) {
      counts[a.metric] = (counts[a.metric] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => '${e.value} ${e.key.replaceAll('_', ' ')}')
        .join(' · ');
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KPI strip
// ═══════════════════════════════════════════════════════════════════════

/// One KPI, in the order the console reads them.
typedef _Kpi = ({
  String label,
  double Function(DashboardKpis) read,
  String note,
});

const _kpis = <_Kpi>[
  (label: 'On-shelf availability', read: _osa, note: 'of all SKU checks'),
  (
    label: 'Perfect-store rate',
    read: _perfect,
    note: 'outlets passing every gate',
  ),
  (label: 'Price compliance', read: _price, note: 'within tolerance of RRP'),
  (
    label: 'Visibility compliance',
    read: _visibility,
    note: 'planogram threshold',
  ),
  (label: 'Share of shelf', read: _sos, note: 'vs. observed competitors'),
  (label: 'Weighted distribution', read: _weighted, note: 'volume-weighted'),
  (label: 'Numeric distribution', read: _numeric, note: 'outlets stocking'),
];

double _osa(DashboardKpis k) => k.osaPct;
double _perfect(DashboardKpis k) => k.perfectStoreRate;
double _price(DashboardKpis k) => k.priceCompliancePct;
double _visibility(DashboardKpis k) => k.visibilityCompliancePct;
double _sos(DashboardKpis k) => k.shareOfShelf;
double _weighted(DashboardKpis k) => k.weightedDistribution;
double _numeric(DashboardKpis k) => k.numericDistribution;

class _KpiStrip extends ConsumerWidget {
  const _KpiStrip({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  /// A sparkline is only drawn where a real history series exists.
  ///
  /// `/trends` serves three series and no more (#95). The other five KPIs have
  /// no history endpoint, so they get no sparkline — a fabricated shape would be
  /// the most confident-looking lie on the screen.
  List<double>? _series(WidgetRef ref, String label) {
    List<double>? read(AsyncValue<List<TrendPoint>> v) => v.maybeWhen(
      data: (points) =>
          points.length < 2 ? null : [for (final p in points) p.value],
      orElse: () => null,
    );

    return switch (label) {
      'On-shelf availability' => read(ref.watch(availabilityTrendProvider)),
      'Perfect-store rate' => read(ref.watch(perfectStoreTrendProvider)),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return PanelCard(
      title: 'Key indicators',
      subtitle: 'Change vs. the window before',
      padded: false,
      child: snapshot.when(
        loading: () => const _InlineLoader(height: 90),
        error: (err, _) => _InlineError(message: 'Could not load KPIs: $err'),
        data: (snap) {
          final tiles = [
            for (final k in _kpis)
              (
                k.label,
                '${k.read(snap.current).toStringAsFixed(1)}%',
                k.note,
                snap.of(k.read),
              ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 3
                  : 2;

              // Chunk into rows and let each row divide the full width, so a
              // short final row fills instead of leaving a ragged empty cell.
              final rows = <List<(String, String, String, KpiDelta)>>[];
              for (var i = 0; i < tiles.length; i += columns) {
                rows.add(tiles.sublist(i, math.min(i + columns, tiles.length)));
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < rows.length; r++)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < rows[r].length; c++)
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: c == rows[r].length - 1
                                          ? Colors.transparent
                                          : colors.line,
                                    ),
                                    bottom: BorderSide(
                                      color: r == rows.length - 1
                                          ? Colors.transparent
                                          : colors.line,
                                    ),
                                  ),
                                ),
                                child: StatTile(
                                  key: ValueKey('kpi-${rows[r][c].$1}'),
                                  label: rows[r][c].$1,
                                  value: rows[r][c].$2,
                                  note: rows[r][c].$3,
                                  // Measured against the window immediately
                                  // before this one — a second real request, not
                                  // an invented baseline. Null when there is
                                  // nothing to compare to (all-time has no
                                  // "before"), and the tile then shows no arrow.
                                  delta: rows[r][c].$4.hasDelta
                                      ? rows[r][c].$4.change
                                      : null,
                                  spark: switch (_series(ref, rows[r][c].$1)) {
                                    final values? => Sparkline(values: values),
                                    _ => null,
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Territory bars + availability columns
// ═══════════════════════════════════════════════════════════════════════

class _TerritoryPanel extends ConsumerWidget {
  const _TerritoryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territories = ref.watch(territoriesListProvider);

    return PanelCard(
      title: 'Execution score by territory',
      subtitle: 'Target 75',
      child: territories.when(
        loading: () => const _InlineLoader(height: 140),
        error: (err, _) => _InlineError(
          message: 'Could not load territories',
          onRetry: () => ref.invalidate(territoriesListProvider),
        ),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red below target is a *threshold status*, not a second series —
            // so it is labelled here and never carried by colour alone.
            BarChart.legend(),
            const SizedBox(height: 8),
            _TerritoryScoreBars(territories: list),
          ],
        ),
      ),
    );
  }
}

/// Fetches every territory's KPIs in a single `GET /dashboard/by-territory`
/// call — see #97.
class _TerritoryScoreBars extends ConsumerWidget {
  const _TerritoryScoreBars({required this.territories});

  final List<Territory> territories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (territories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No territories defined',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
        ),
      );
    }

    final byTerritoryAsync = ref.watch(dashboardByTerritoryProvider);

    return byTerritoryAsync.when(
      loading: () => const _InlineLoader(height: 140),
      // An error must never render as a loader: a spinner reads as "still
      // loading" and never recovers. Say what failed and offer the way back,
      // like every sibling panel.
      error: (_, _) => _InlineError(
        message: 'Could not load territory scores',
        onRetry: () => ref.invalidate(dashboardByTerritoryProvider),
      ),
      data: (summaries) {
        final byId = {for (final s in summaries) s.territoryId: s};
        final points = <ChartPoint>[
          for (final t in territories)
            if (byId[t.id] != null)
              (label: t.name, value: byId[t.id]!.kpis.executionScore),
        ];
        if (points.isEmpty) return const _InlineLoader(height: 40);
        points.sort((a, b) => b.value.compareTo(a.value));
        return BarChart(points: points, target: 75);
      },
    );
  }
}

class _AvailabilityPanel extends ConsumerWidget {
  const _AvailabilityPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(availabilityTrendProvider);

    return PanelCard(
      title: 'On-shelf availability',
      subtitle: 'By period',
      child: availability.when(
        loading: () => const _InlineLoader(height: 208),
        error: (err, _) => _InlineError(
          message: 'Could not load availability',
          onRetry: () => ref.invalidate(availabilityTrendProvider),
        ),
        data: (points) => ColumnChart(
          points: [for (final p in points) (label: p.period, value: p.value)],
          valueSuffix: '%',
          seriesName: 'On-shelf availability',
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Where are my agents — today's confirmed stops
// ═══════════════════════════════════════════════════════════════════════

/// A list, deliberately — no map tiles on the manager's morning screen.
///
/// The question "which store is each agent at" is answered by text; rendering
/// OpenStreetMap tiles to answer it would cost every dashboard load a set of
/// network round-trips for information the list already carries. The map is
/// one tap away for when geography actually matters.
///
/// Public rather than private so the widget test can pump it on its own.
class AgentActivityPanel extends ConsumerWidget {
  const AgentActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(agentActivityTodayProvider);

    return PanelCard(
      title: 'Where are my agents',
      subtitle: "Today's check-ins",
      padded: false,
      trailing: TextButton(
        key: const ValueKey<String>('agent-activity-view-map'),
        onPressed: () => context.go('/agents/activity'),
        child: const Text('View map'),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: AsyncSection<AgentActivityPage>(
          value: activity,
          label: 'agent activity',
          onRetry: () => ref.invalidate(agentActivityTodayProvider),
          builder: (page) {
            if (page.agents.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No agents to show for this filter.'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final agent in page.agents) _AgentRow(agent: agent),
                // Never let a cut list read as the whole team. A manager who
                // cannot see an agent concludes they did not work, not that
                // the list ran out.
                if (page.truncated)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing the first 200 agents. Filter by territory to narrow.',
                      style: TextStyle(fontSize: 12, color: context.colors.ink3),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One agent, one line.
///
/// Every row leads with WHEN, not just where. A row that says "Sandton Spar"
/// with no age reads as live; this data is never live, and the age is the
/// only thing that keeps the row honest.
class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final AgentActivity agent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, label, color) = switch (agent.state) {
      AgentState.atStore => (Icons.storefront, 'At store', colors.good),
      AgentState.inTransit => (Icons.trending_flat, 'In transit', colors.warn),
      AgentState.idle => (Icons.remove_circle_outline, 'No check-in', colors.ink4),
    };

    // Idle carries no location line: the age column already reads "no
    // check-in today", and repeating that fact here would say the same thing
    // twice in exactly the row where space is tightest.
    final secondLine = switch (agent.state) {
      AgentState.atStore =>
        '$label · ${agent.currentOutletName ?? 'unknown store'}',
      AgentState.inTransit =>
        '$label · ${agent.lastOutletName == null ? 'in transit' : 'left ${agent.lastOutletName}'}',
      AgentState.idle => label,
    };

    return Semantics(
      label: '${agent.name}, $secondLine, ${_age(agent.lastSeenAt)}',
      // The row underneath is three live Text widgets, each of which would
      // otherwise contribute its own implicit semantics node — without this a
      // screen reader announces the curated label, then reads the name,
      // status line and age again on the next three swipes.
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              key: ValueKey<String>('agent-state-icon-${agent.agentId}'),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // `name` is an email — one unbroken token — and outlet
                  // names run long, so both lines must ellipsize rather than
                  // paint past their bound; the age column stays unbounded
                  // since it must never be the thing that gets clipped.
                  Text(
                    agent.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    secondLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.ink3),
                  ),
                ],
              ),
            ),
            Text(
              _age(agent.lastSeenAt),
              style: TextStyle(fontSize: 12, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/// How stale this row is, in words. Delegates to the same [formatAgo] every
/// other "time since" line in the app uses (`agent_scaffold.dart`,
/// `my_work_screen.dart`, `audit_shell_screen.dart`) — a second bucketing
/// implementation here would silently drift from that wording. Only the
/// "never checked in" case is specific to this panel.
String _age(DateTime? at) => at == null ? 'no check-in today' : formatAgo(at);

// ═══════════════════════════════════════════════════════════════════════
// Filters — one row, above everything it scopes
// ═══════════════════════════════════════════════════════════════════════

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);

    void update(DashboardFilter next) =>
        ref.read(dashboardFilterProvider.notifier).set(next);

    final territoryDropdown = territories.maybeWhen(
      data: (list) => DropdownButton<String?>(
        key: const ValueKey('filter-territory'),
        value: filter.territoryId,
        hint: const Text('All territories'),
        underline: const SizedBox.shrink(),
        isDense: true,
        style: TextStyle(fontSize: 12.5, color: colors.ink1),
        dropdownColor: colors.surface2,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All territories'),
          ),
          for (final t in list)
            DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
        ],
        onChanged: (v) => update(
          v == null
              ? filter.copyWith(clearTerritory: true)
              : filter.copyWith(territoryId: v),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          const SectionLabel('Territory'),
          territoryDropdown,
          const SizedBox(width: 4),
          // The window is what makes every delta on this screen possible: without
          // a bounded range there is no previous period, and every arrow would be
          // invented. "All" is offered, and honestly shows no arrows at all.
          _RangeControl(
            key: const ValueKey('filter-daterange'),
            selected: filter.range,
            onChanged: (r) => update(filter.copyWith(range: r)),
          ),
        ],
      ),
    );
  }
}

class _RangeControl extends StatelessWidget {
  const _RangeControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DashboardRange selected;
  final ValueChanged<DashboardRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.lineStrong),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, r) in DashboardRange.values.indexed)
            InkWell(
              key: ValueKey('range-${r.name}'),
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: r == selected ? colors.surface3 : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: i == DashboardRange.values.length - 1
                          ? Colors.transparent
                          : colors.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: r == selected ? colors.ink1 : colors.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Shared bits
// ═══════════════════════════════════════════════════════════════════════

class _StubCaveat extends StatelessWidget {
  const _StubCaveat();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Visibility compliance and share of shelf are derived from the Phase-1 '
      'computer-vision stub — see docs/architecture/stubs-and-interfaces.md.',
      style: TextStyle(fontSize: 11, color: context.colors.ink3),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      child: Row(
        children: [
          const StatusChip(label: 'Error', level: StatusLevel.critical),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: context.colors.ink2),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
