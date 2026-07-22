import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart' show formatAgo;
import '../../../core/widgets/agent_motion.dart' show Motion, reduceMotion;
import '../../../core/widgets/agent_state_glyph.dart';
import '../../../core/widgets/basemap.dart';
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

/// Below this the map and list sit side by side; below it they stack. Same
/// reasoning as [DashboardShellScreen._wide] — this panel is rendered at the
/// dashboard's full content width, not inside a [_TwoColumn], so it earns its
/// own constant rather than reusing that private one across classes.
const _panelWide = 1080.0;

/// Fixed so the map never dominates a screen whose real subject is the
/// execution score above it. Tall enough to place a handful of pins usefully,
/// short enough to still read as "one panel among several".
const _mapHeight = 260.0;

/// The panel's fixed fallback/single-pin zoom — close enough to read
/// individual outlets, used both for `MapOptions.initialZoom` and the
/// `onMapReady` `move()` fallback so the two never drift apart.
const _mapZoom = 11.0;

/// Label and colour for one agent state — the single source both the list
/// rows and the map pins read from, so the two halves of the panel can never
/// quietly disagree about what a state looks like. Colour is never the only
/// carrier (#144): every state also gets a distinct [AgentStateGlyph] shape
/// (`core/widgets/agent_state_glyph.dart`) and a word.
({String label, Color color}) _agentStateVisual(
  AgentState state,
  TiqColors colors,
) => switch (state) {
  AgentState.atStore => (label: 'At store', color: colors.good),
  AgentState.inTransit => (label: 'In transit', color: colors.warn),
  AgentState.idle => (label: 'No check-in', color: colors.ink4),
};

/// Glyph colour for the map pin specifically — fixed rather than read from
/// the ambient theme, because the pin's disc is *also* fixed white (see
/// `_AgentMapPin`'s decoration comment) and a colour tuned for a dark panel
/// does not necessarily read on a literal white circle. `colors.warn` in
/// dark theme is a bright amber meant to sit on `AppColors.surface1`
/// (#14161C) — on white it measures ~1.8:1, effectively invisible, the same
/// fixed-background/theme-dependent-foreground mistake `_StopPin`'s numeral
/// had. `TiqColors.light`'s good/warn were tuned against a near-white panel
/// already and clear 5:1+ on the disc, so those literals are pinned here for
/// every theme; `ink4` is already one shared literal in both palettes (it is
/// documented as "marks only", meant to be theme-invariant) so it needs no
/// override.
Color _pinGlyphColor(AgentState state) => switch (state) {
  AgentState.atStore => TiqColors.light.good,
  AgentState.inTransit => TiqColors.light.warn,
  AgentState.idle => TiqColors.light.ink4,
};

/// This agent's most recent confirmed stop. Sorts defensively rather than
/// trusting `stops` to already be in order, for the same reason
/// [AgentActivity.lastOutletName] does: a caller-trusted ordering that
/// silently breaks would place the pin at a confidently wrong spot with no
/// throw and no signal. Callers must only pass agents with `stops.isNotEmpty`.
AgentStop _latestStop(AgentActivity agent) {
  final sorted = [...agent.stops]
    ..sort((a, b) => a.checkinTs.compareTo(b.checkinTs));
  return sorted.last;
}

/// The empty-state copy for [AgentActivityPanel] when the filtered page has
/// zero agents. An empty list with no explanation reads as "the app is
/// broken" — which is exactly what got reported here: a manager filtered to
/// a territory nobody happens to be assigned to, the query was correct, and
/// the fixed string gave them no way to tell the two apart. Naming the
/// territory turns a dead end into something actionable; when no filter is
/// active, the territory cannot be the reason, so the wording does not
/// imply one.
///
/// [DashboardFilter.territoryId] is a Territory *id* — the client-facing
/// contract every dashboard endpoint shares (see
/// `dashboard.service.ts`'s `getDashboardSummary` comment on the backend),
/// not a name, so the name has to come from [territoriesListProvider] —
/// which is async and can still be loading or errored, and even once loaded
/// may simply not contain the id (a
/// deleted or stale territory). Every one of those cases falls back to
/// wording that names no territory: a blank, "null", or the raw id would
/// all be worse than the message this replaced.
String _emptyActivityMessage(WidgetRef ref, String? territoryId) {
  if (territoryId == null) return 'No field agents yet.';

  final territories = ref.watch(territoriesListProvider);
  final name = territories.maybeWhen(
    data: (list) {
      for (final t in list) {
        if (t.id == territoryId) return t.name;
      }
      return null;
    },
    orElse: () => null,
  );

  return name == null
      ? 'No agents match this territory filter.'
      : 'No agents are assigned to $name.';
}

/// Map + compact list, side by side — the map is the hero, the list is what
/// keeps it honest.
///
/// Pins mark the last *confirmed* check-in, never a live position (#153 is
/// T0 — there is no heartbeat to plot). An agent with no stops today gets no
/// pin; the list is the only reason they do not simply vanish from the
/// panel, and the footer line beneath the map says how many that is.
///
/// Public rather than private so the widget test can pump it on its own.
class AgentActivityPanel extends ConsumerWidget {
  const AgentActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(agentActivityTodayProvider);
    final filter = ref.watch(dashboardFilterProvider);

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
          // A territory-filter change re-runs this provider (it watches
          // `dashboardFilterProvider`) — without this, that reload would
          // flash the whole panel back to the loading spinner, tearing the
          // map down and rebuilding it fresh once the new page lands. That
          // would make `_AgentMap`'s camera-easing a snap in practice: there
          // would be nothing continuously mounted left to animate. Keeping
          // the last page on screen during the refetch is what lets
          // `_CameraDriver` travel the SAME map to the new fit instead.
          skipLoadingOnReload: true,
          builder: (page) {
            if (page.agents.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_emptyActivityMessage(ref, filter.territoryId)),
              );
            }

            final withStops = [
              for (final a in page.agents)
                if (a.stops.isNotEmpty) a,
            ];
            final notPlotted = page.agents.length - withStops.length;
            final list = _AgentList(agents: page.agents);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (withStops.isEmpty) ...[
                  // No pins to plot: a grey, empty map would look broken
                  // rather than honest, so the list carries the panel alone
                  // and says in words why there is nothing to draw.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nobody has checked in yet today.',
                      style: TextStyle(fontSize: 12, color: context.colors.ink3),
                    ),
                  ),
                  list,
                ] else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= _panelWide;
                      final map = SizedBox(
                        height: _mapHeight,
                        child: _AgentMap(agentsWithStops: withStops),
                      );
                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [map, const SizedBox(height: 10), list],
                        );
                      }
                      return SizedBox(
                        height: _mapHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 2, child: map),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: SingleChildScrollView(child: list),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                // Says who is plotted and who is not in one line, so the map
                // can never quietly read as "the whole team" when some
                // agents have no confirmed stop to draw.
                Text(
                  '${withStops.length} on the map · $notPlotted not checked in today',
                  style: TextStyle(fontSize: 12, color: context.colors.ink3),
                ),
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

/// The compact list half of the panel — every agent, idle ones included.
/// Unchanged behaviour from the list-only panel; it is what stops an agent
/// with no stops from vanishing when the map cannot place them.
class _AgentList extends StatelessWidget {
  const _AgentList({required this.agents});

  final List<AgentActivity> agents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [for (final agent in agents) _AgentRow(agent: agent)],
    );
  }
}

/// The map half — one pin per agent with at least one confirmed stop today,
/// placed at their latest one. No polylines here: the drill-in trail map
/// (`agent_trail_screen.dart`) carries the day's route, this one only answers
/// "where are they now" (as of their last check-in).
class _AgentMap extends StatelessWidget {
  const _AgentMap({required this.agentsWithStops});

  /// Must all have `stops.isNotEmpty` — callers filter before constructing.
  final List<AgentActivity> agentsWithStops;

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final a in agentsWithStops)
        LatLng(_latestStop(a).lat, _latestStop(a).lng),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      // This panel lives inside DashboardShellScreen's ListView, below the
      // fold on a typical screen — a scrollable can lay a child out before it
      // is ever scrolled into view, sometimes on a transient pass with a
      // zero or unbounded size. The LayoutBuilder + degenerate guard below
      // exist for that: skip the map entirely rather than mount it against a
      // viewport it can't use.
      //
      // The centre/zoom are computed OURSELVES, by `fitFor` — not by
      // flutter_map's own `CameraFit.bounds`/`initialCameraFit`, and not by
      // calling `fitCamera` from `onMapReady` either. Both of those depend
      // on flutter_map's own internal camera size, which — confirmed against
      // the running web build, with a live debug overlay reading correct
      // points, a real bounds `CameraFit`, and a non-degenerate widget
      // viewport already measured here — was STILL zero at the moment
      // `onMapReady` fired, silently producing a near-world zoom centred
      // nowhere near the data. `fitFor` uses the real pixel `size` this
      // `LayoutBuilder` already has in hand and plain Web Mercator maths
      // (see core/geo/mercator_fit.dart), so there is no flutter_map camera
      // state left to race — the result is handed to flutter_map as plain
      // `initialCenter`/`initialZoom`, values it applies synchronously and
      // unconditionally on every mount.
      //
      // The key is now SIZE ONLY, not a fingerprint of the plotted
      // coordinates: a genuine size change (the panel's real first layout
      // once scrolled into view, or a later resize) still mounts a fresh
      // State — flutter_map creates a brand new internal controller, which
      // seeds its camera fresh from that mount's `initialCenter`/
      // `initialZoom`, exactly as before. A moved set of pins (a
      // territory-filter change, same size) no longer remounts anything:
      // `_CameraDriver` below drives the SAME map's camera to the new
      // `fitFor` target as an eased `MapController.move()` instead, so the
      // camera travels rather than snaps. `fitFor` is still the only source
      // of truth for WHERE the camera ends up; only how it gets there
      // changed. (The stale-controller trap the `onMapReady` version of
      // this fix had — see git history — still does not apply: nothing
      // here holds `mapController:` on `FlutterMap` itself, so
      // `map.mapController` stays null, as the tests pin down.)
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
              // Correctness fix, not a preference — do NOT restore the
              // missing flag. This map is a passenger inside
              // DashboardShellScreen's ListView, not a full-screen map like
              // agent_trail_screen.dart: a manager reaching this
              // below-the-fold panel scrolls the page with their mouse
              // wheel, exactly as they would over any other panel. flutter_map's
              // default interactionOptions treat that same wheel as a zoom
              // gesture — so the wheel that was meant to keep scrolling the
              // page instead zooms the map AND silently destroys the fit
              // `fitFor` computed, leaving a manager staring at empty ocean
              // with no idea why. Drag, pinch, and double-tap zoom all stay
              // on; only the wheel is disabled, because the wheel is the one
              // gesture this map cannot own without breaking the page around
              // it.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              const TiqTileLayer(),
              MarkerLayer(
                markers: [
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
                ],
              ),
              const TiqBasemapAttribution(),
              // Not a visual layer — a headless widget living inside the
              // `FlutterMap` subtree purely so it can reach
              // `MapController.of(context)`, the map's own INTERNAL
              // controller (we deliberately never pass `mapController:`
              // above, which is what keeps `map.mapController` null for the
              // regression test). It compares this build's `fitFor` target
              // against the previous one and, when they differ, eases the
              // SAME map's camera across via `.move()` instead of a snap.
              _CameraDriver(target: (center, zoom)),
            ],
          );
        },
      ),
    );
  }
}

/// Drives one mounted [FlutterMap]'s camera toward each new `fitFor` target
/// as an eased travel rather than a snap, when [target] changes under an
/// unchanged `FlutterMap` key (a territory-filter change moving the pins,
/// not a real resize). See `_AgentMap`'s doc comment for why this is safe
/// against the `onMapReady`/`mapController` timing bug this file's history
/// already paid for: this never touches `FlutterMap.mapController`,
/// `initialCameraFit`, or `onMapReady` — it only calls the public
/// `MapController.of(context)`/`.move()` API from a descendant already
/// inside the map's own subtree, after the map has already mounted with a
/// correct `fitFor`-computed `initialCenter`/`initialZoom`.
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
    // The map has ALREADY mounted with `initialCenter`/`initialZoom` equal
    // to `widget.target` at this point (see `_AgentMap`) — nothing to
    // travel on first build, only on a later target change.
    _controller = AnimationController(vsync: this, duration: Motion.slow)
      ..addListener(_onTick);
    _eased = CurvedAnimation(parent: _controller, curve: Motion.enter);
  }

  @override
  void didUpdateWidget(_CameraDriver old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _travelTo(widget.target);
  }

  void _travelTo((LatLng, double) target) {
    final controller = MapController.of(context);
    if (reduceMotion(context)) {
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

/// One agent's latest confirmed stop, on the panel's map.
///
/// Deliberately not numbered like the trail screen's stops — this map shows
/// one point per agent, not a sequence, so a plain state glyph says more than
/// an ordinal would.
///
/// Stateful only to track hover: the disc lifts a couple of pixels under the
/// mouse, a real affordance on a web console driven with a pointer.  Gated
/// on [reduceMotion] like every other transition in this file.
class _AgentMapPin extends StatefulWidget {
  const _AgentMapPin({super.key, required this.agent});

  final AgentActivity agent;

  @override
  State<_AgentMapPin> createState() => _AgentMapPinState();
}

class _AgentMapPinState extends State<_AgentMapPin> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final agent = widget.agent;
    final visual = _agentStateVisual(agent.state, colors);
    final stop = _latestStop(agent);
    final lift = _hovering ? 3.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Semantics(
        label: '${agent.name}, ${visual.label}, ${stop.outletName}',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : Motion.fast,
          curve: Motion.enter,
          transform: Matrix4.translationValues(0, -lift, 0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            // A white disc under the glyph, same as agent_trail_screen.dart's
            // _StopPin and territory_map_screen.dart's _OutletPin: CARTO's
            // dark and light basemaps both range from near-black roads to
            // pale open land, so a bare glyph has no background it can rely
            // on everywhere.
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: colors.line, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0x33000000),
                blurRadius: _hovering ? 6 : 3,
                offset: Offset(0, _hovering ? 2 : 1),
              ),
            ],
          ),
          child: Center(
            child: AgentStateGlyph(
              state: agent.state,
              color: _pinGlyphColor(agent.state),
              size: 16,
              pulse: true,
            ),
          ),
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
///
/// Stateful only to track hover/press: a subtle surface change under the
/// mouse and on press, the same web-console affordance the map pins get.
/// Purely visual — the row has no `onTap` action of its own today — and
/// gated on [reduceMotion] like every other transition in this file.
class _AgentRow extends StatefulWidget {
  const _AgentRow({required this.agent});

  final AgentActivity agent;

  @override
  State<_AgentRow> createState() => _AgentRowState();
}

class _AgentRowState extends State<_AgentRow> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final colors = context.colors;
    final visual = _agentStateVisual(agent.state, colors);
    final (label, color) = (visual.label, visual.color);

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

    final background = _pressed
        ? colors.surface3
        : _hovering
        ? colors.surface2
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Semantics(
          label: '${agent.name}, $secondLine, ${_age(agent.lastSeenAt)}',
          // The row underneath is three live Text widgets, each of which
          // would otherwise contribute its own implicit semantics node —
          // without this a screen reader announces the curated label, then
          // reads the name, status line and age again on the next three
          // swipes.
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: reduceMotion(context) ? Duration.zero : Motion.fast,
            curve: Motion.enter,
            color: background,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                AgentStateGlyph(
                  key: ValueKey<String>('agent-state-icon-${agent.agentId}'),
                  state: agent.state,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // `name` is an email — one unbroken token — and outlet
                      // names run long, so both lines must ellipsize rather
                      // than paint past their bound; the age column stays
                      // unbounded since it must never be the thing that
                      // gets clipped.
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
