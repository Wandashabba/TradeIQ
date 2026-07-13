import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKpisProvider);

    return ManagerScaffold(
      title: 'Execution overview',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wide;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _FilterBar(),
              const SizedBox(height: 12),
              _TwoColumn(
                wide: wide,
                leftFlex: 19,
                rightFlex: 10,
                left: _ExecutionScorePanel(kpis: kpis),
                right: const _NeedsAttentionPanel(),
              ),
              const SizedBox(height: 12),
              _KpiStrip(kpis: kpis),
              const SizedBox(height: 12),
              const _TwoColumn(
                wide: true,
                leftFlex: 1,
                rightFlex: 1,
                left: _TerritoryPanel(),
                right: _AvailabilityPanel(),
              ),
              const SizedBox(height: 12),
              const _StubCaveat(),
            ],
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
  const _ExecutionScorePanel({required this.kpis});

  final AsyncValue<DashboardKpis> kpis;

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
            kpis.when(
              loading: () => const _InlineLoader(height: 44),
              error: (err, _) => _InlineError(
                message: 'Could not load KPIs',
                onRetry: () => ref.invalidate(dashboardKpisProvider),
              ),
              data: (data) => Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    data.executionScore.toStringAsFixed(1),
                    key: const ValueKey('kpi-execution-score'),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(width: 12),
                  // The delta needs a previous period the API doesn't return
                  // yet, so we derive it from the trend series rather than
                  // inventing a number.
                  trend.maybeWhen(
                    data: (points) => points.length < 2
                        ? const SizedBox.shrink()
                        : DeltaText(
                            points.last.value - points[points.length - 2].value,
                            fontSize: 13,
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
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
              final critical =
                  open.where((a) => a.severity == 'critical').length;
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
              final critical = open.where((t) => t.priority == 'critical').length;
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

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final AsyncValue<DashboardKpis> kpis;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Key indicators',
      padded: false,
      child: kpis.when(
        loading: () => const _InlineLoader(height: 90),
        error: (err, _) => _InlineError(message: 'Could not load KPIs: $err'),
        data: (data) {
          final tiles = <(String, String, String)>[
            ('On-shelf availability', '${data.osaPct.toStringAsFixed(1)}%', 'of all SKU checks'),
            ('Perfect-store rate', '${data.perfectStoreRate.toStringAsFixed(1)}%', 'outlets passing every gate'),
            ('Price compliance', '${data.priceCompliancePct.toStringAsFixed(1)}%', 'within tolerance of RRP'),
            ('Visibility compliance', '${data.visibilityCompliancePct.toStringAsFixed(1)}%', 'planogram threshold'),
            ('Share of shelf', '${data.shareOfShelf.toStringAsFixed(1)}%', 'vs. observed competitors'),
            ('Weighted distribution', '${data.weightedDistribution.toStringAsFixed(1)}%', 'volume-weighted'),
            ('Numeric distribution', '${data.numericDistribution.toStringAsFixed(1)}%', 'outlets stocking'),
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
              final rows = <List<(String, String, String)>>[];
              for (var i = 0; i < tiles.length; i += columns) {
                rows.add(
                  tiles.sublist(i, math.min(i + columns, tiles.length)),
                );
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
                                          : AppColors.line,
                                    ),
                                    bottom: BorderSide(
                                      color: r == rows.length - 1
                                          ? Colors.transparent
                                          : AppColors.line,
                                    ),
                                  ),
                                ),
                                child: StatTile(
                                  key: ValueKey('kpi-${rows[r][c].$1}'),
                                  label: rows[r][c].$1,
                                  value: rows[r][c].$2,
                                  note: rows[r][c].$3,
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

/// One `GET /dashboard?territoryId=…` per territory — see [territoryKpisProvider].
/// Territories still loading are held back rather than plotted as zero, so the
/// chart never shows a bar that isn't a real score.
class _TerritoryScoreBars extends ConsumerWidget {
  const _TerritoryScoreBars({required this.territories});

  final List<Territory> territories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (territories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No territories defined',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
        ),
      );
    }

    final points = <ChartPoint>[];
    var pending = false;
    for (final t in territories) {
      final kpis = ref.watch(territoryKpisProvider(t.id));
      kpis.when(
        loading: () => pending = true,
        error: (_, _) {},
        data: (d) => points.add((label: t.name, value: d.executionScore)),
      );
    }

    if (points.isEmpty) {
      return _InlineLoader(height: pending ? 140 : 40);
    }

    points.sort((a, b) => b.value.compareTo(a.value));
    return BarChart(points: points, target: 75);
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
          points: [
            for (final p in points) (label: p.period, value: p.value),
          ],
          valueSuffix: '%',
          seriesName: 'On-shelf availability',
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Filters — one row, above everything it scopes
// ═══════════════════════════════════════════════════════════════════════

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);

    void update(DashboardFilter next) =>
        ref.read(dashboardFilterProvider.notifier).set(next);

    Future<void> pickRange() async {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (range != null) {
        update(DashboardFilter(
          territoryId: filter.territoryId,
          from: range.start.toIso8601String(),
          to: range.end.toIso8601String(),
        ));
      }
    }

    final territoryDropdown = territories.maybeWhen(
      data: (list) => DropdownButton<String?>(
        key: const ValueKey('filter-territory'),
        value: filter.territoryId,
        hint: const Text('All territories'),
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 12.5, color: AppColors.ink1),
        dropdownColor: AppColors.surface2,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All territories'),
          ),
          for (final t in list)
            DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
        ],
        onChanged: (v) => update(
          DashboardFilter(territoryId: v, from: filter.from, to: filter.to),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
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
          OutlinedButton.icon(
            key: const ValueKey('filter-daterange'),
            icon: const Icon(Icons.date_range, size: 14),
            label: Text(filter.from != null ? 'Custom range' : 'All time'),
            onPressed: pickRange,
          ),
          if (filter.isActive)
            TextButton(
              key: const ValueKey('filter-clear'),
              onPressed: () => update(const DashboardFilter()),
              child: const Text('Clear'),
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
    return const Text(
      'Visibility compliance and share of shelf are derived from the Phase-1 '
      'computer-vision stub — see docs/architecture/stubs-and-interfaces.md.',
      style: TextStyle(fontSize: 11, color: AppColors.ink3),
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
              style: const TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
