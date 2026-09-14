import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/format/period_label.dart';
import '../../../core/geo/mercator_fit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart' show formatAgo;
import '../../../core/widgets/agent_motion.dart' show Motion, reduceMotion;
import '../../../core/widgets/agent_state_glyph.dart';
import '../../../core/widgets/basemap.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/delta_pill.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/pill_segment.dart';
import '../../../core/widgets/worklist.dart';
import '../../agents/data/agents_repository.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../tasks/data/tasks_admin_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../../trends/data/trends_repository.dart';
import '../data/dashboard_repository.dart';
import '../../../core/theme/lumen_palette.dart';

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
    final glass = context.colors.glass;
    final bands = snapshot.maybeWhen(
      data: (snap) => snap.current.scoreBands,
      orElse: () => const <ScoreBand>[],
    );

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
                // Lumen Glass reports distance from the published standard
                // rather than raw numbers — each KPI against its target tick.
                if (glass)
                  _BenchmarkPanel(snapshot: snapshot)
                else
                  _KpiStrip(snapshot: snapshot),
                const SizedBox(height: 12),
                if (glass) ...[
                  // What a manager acts on is how many doors sit in which
                  // band, not the average. Hidden until the server sends it.
                  if (bands.isNotEmpty)
                    _TwoColumn(
                      wide: wide,
                      leftFlex: 1,
                      rightFlex: 1,
                      left: _DistributionPanel(bands: bands),
                      right: const _TerritoryPanel(),
                    )
                  else
                    const _TerritoryPanel(),
                  const SizedBox(height: 12),
                  const _AvailabilityPanel(),
                ] else
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

class _ExecutionScorePanel extends ConsumerStatefulWidget {
  const _ExecutionScorePanel({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  ConsumerState<_ExecutionScorePanel> createState() =>
      _ExecutionScorePanelState();
}

class _ExecutionScorePanelState extends ConsumerState<_ExecutionScorePanel>
    with AutomaticKeepAliveClientMixin {
  /// Flipped on the panel's first data build — a during-build write,
  /// deliberately not setState: nothing rendered depends on it until a LATER
  /// build (a filter change remounting the row through the loading arm),
  /// which must come up entrance-free. This State outlives those remounts,
  /// so the latch survives where the animated subtree does not.
  bool _entered = false;

  /// The latch's storage guarantee. The dashboard body is a lazy ListView
  /// whose sliver DISPOSES children scrolled past its cache extent — without
  /// keep-alive, a scroll to the bottom and back would take this State (and
  /// the latch) with it, replaying the entire entrance. Keeping the panel
  /// alive also preserves the hero chart's completed draw-in and the pill's
  /// settled entrance, so scrolling back restores the settled screen instead
  /// of re-performing it. Cheap: this pins one text-and-one-chart row, not
  /// the heavy map panel (a separate ListView child, untouched).
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = widget.snapshot;
    final trend = ref.watch(scorecardsTrendProvider);
    final colors = context.colors;

    if (colors.glass) return _glassPanel(snapshot, trend);

    return PanelCard(
      title: 'Execution score',
      subtitle: 'Weighted S2–S8, all outlets',
      padded: false,
      // The screen's one "glass" card: the score is the product's headline
      // number, and the wash is what makes it read as the headline. Theme
      // slots, not spec hexes: light carries the spec's `#F2F7FF → #FFFFFF`
      // + `#DBE7FA` border, dark a navy wash its own ink1 stays readable on
      // (the hard-coded light wash once made the dark score ~1.1:1 —
      // dashboard test 'dark theme: the hero score…' pins the fix).
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.heroWash, colors.surface1],
      ),
      borderColor: colors.heroBorder,
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
              data: (snap) {
                final animate = !_entered;
                _entered = true;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // The headline figure counts up to its value ONCE. Not a
                    // flourish: it makes the number the thing the eye lands on
                    // first, which is the whole point of a hero figure.
                    _HeroScore(
                      key: const ValueKey('kpi-execution-score'),
                      value: snap.current.executionScore,
                      animate: animate,
                    ),
                    const SizedBox(width: 12),
                    // Measured against the window immediately before this one —
                    // the same comparison every tile below makes, so the whole
                    // screen is answering one question consistently. Tone
                    // follows the sign: the snapshot carries no other verdict
                    // to wire. The entrance wrap lives HERE, not inside
                    // DeltaPill — the pill is shared chrome and other screens
                    // may not want entrance motion.
                    switch (snap.of((k) => k.executionScore)) {
                      final d when d.hasDelta => OneShotEntrance.pill(
                        enabled: animate,
                        child: DeltaPill(
                          delta: d.change!,
                          tone: d.change! < 0 ? DeltaTone.bad : DeltaTone.good,
                        ),
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ],
                );
              },
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
                  for (final p in points)
                    (label: formatPeriodLabel(p.period), value: p.value),
                ],
                target: 75,
                seriesName: 'Execution score',
                lineWidth: 2.5,
                gradientFill: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _ExecutionScorePanelState {
  /// The execution score on Lumen Glass's one dark pane: the kicker, the 56px
  /// figure with its delta against the previous window, and the trend drawn in
  /// light over the glass.
  Widget _glassPanel(
    AsyncValue<DashboardSnapshot> snapshot,
    AsyncValue<List<TrendPoint>> trend,
  ) {
    return GlassPane(
      kind: GlassKind.dark,
      radius: LumenGlass.radiusHero,
      padding: const EdgeInsets.all(22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -110,
            right: -90,
            child: GlassBloom(diameter: 250, strength: 0.45),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Kicker(
                'Execution score · weighted S2–S8',
                color: LumenGlass.onDarkMuted,
              ),
              const SizedBox(height: 10),
              snapshot.when(
                loading: () => const _OnDarkPane(child: _InlineLoader(height: 56)),
                error: (err, _) => _OnDarkPane(
                  child: _InlineError(
                    message: 'Could not load KPIs',
                    onRetry: () => ref.invalidate(dashboardSnapshotProvider),
                  ),
                ),
                data: (snap) {
                  final animate = !_entered;
                  _entered = true;
                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _HeroScore(
                        key: const ValueKey('kpi-execution-score'),
                        value: snap.current.executionScore,
                        animate: animate,
                      ),
                      switch (snap.of((k) => k.executionScore)) {
                        final d when d.hasDelta => OneShotEntrance.pill(
                          enabled: animate,
                          child: DeltaPill(
                            delta: d.change!,
                            tone: d.change! < 0 ? DeltaTone.bad : DeltaTone.good,
                          ),
                        ),
                        _ => const SizedBox.shrink(),
                      },
                      const Text(
                        'vs. the window before · target 75.0',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: LumenGlass.onDarkMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _OnDarkPane(
                child: trend.when(
                  loading: () => const _InlineLoader(height: 208),
                  error: (err, _) => _InlineError(
                    message: 'Could not load the score trend',
                    onRetry: () => ref.invalidate(scorecardsTrendProvider),
                  ),
                  data: (points) => LineChart(
                    points: [
                      for (final p in points)
                        (label: formatPeriodLabel(p.period), value: p.value),
                    ],
                    target: 75,
                    seriesName: 'Execution score',
                    lineWidth: 2.4,
                    gradientFill: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Re-themes a subtree for the dark glass pane. The console's charts and
/// inline states read the ambient palette, and in light that palette's inks
/// would be dark on dark — so beneath the pane they get the instrument
/// palette, with the chart line in the handoff's #CFC7FF.
class _OnDarkPane extends StatelessWidget {
  const _OnDarkPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.dark();
    return Theme(
      data: base.copyWith(
        extensions: [
          TiqColors.dark.copyWith(
            series1: LumenGlass.chartLine,
            brand: LumenGlass.accentLight, // lumen-sweep: keep
            grid: const Color(0x1AFFFFFF), // lumen-sweep: keep
            axis: const Color(0x33FFFFFF), // lumen-sweep: keep
            ink3: const Color(0xB3FFFFFF), // lumen-sweep: keep
            ink4: const Color(0x80FFFFFF), // lumen-sweep: keep
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}

/// The hero figure. Counts 0 → value over ~600ms ease-out exactly once — on
/// the panel's first data build — then renders as plain text for the rest of
/// the session, so refreshes and filter changes swap the number without
/// re-performing it. Under reduced motion there is no tween at all: the final
/// figure IS the first frame.
class _HeroScore extends StatefulWidget {
  const _HeroScore({super.key, required this.value, required this.animate});

  final double value;

  /// Whether this mount is the entrance. Latched at mount (see State): a
  /// rebuild mid-count-up cannot cut the animation short, and a remount after
  /// the entrance epoch renders statically.
  final bool animate;

  @override
  State<_HeroScore> createState() => _HeroScoreState();
}

class _HeroScoreState extends State<_HeroScore> {
  late final bool _entrance = widget.animate;

  /// Set when the count-up completes; from then on the tween is gone from the
  /// tree entirely, so a later value change (a refresh landing new data into
  /// this same State) renders directly instead of animating toward it.
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final style = context.colors.glass
        // On the dark pane: 56px white with the accent's glow behind it.
        ? LumenGlass.hero(size: 56, color: Colors.white).copyWith(
            shadows: const [Shadow(color: Color(0x8CB5ABFC), blurRadius: 38)],
          )
        : TextStyle(
            fontSize: 31,
            height: 1.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: context.colors.ink1,
          );

    if (_done || !_entrance) {
      return Text(widget.value.toStringAsFixed(1), style: style);
    }
    if (reduceMotion(context)) {
      // The entrance moment is consumed, not deferred: flipping reduced
      // motion off later must not perform the count-up mid-session.
      _done = true;
      return Text(widget.value.toStringAsFixed(1), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.value),
      duration: Motion.countUp,
      curve: Curves.easeOutCubic,
      onEnd: () => setState(() => _done = true),
      builder: (context, v, _) => Text(v.toStringAsFixed(1), style: style),
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

/// The one KPI figure format — one decimal, a trailing percent. Shared by the
/// static string and the count-up so the sweeping number and its final value
/// are always the same shape.
String _fmtPct(num v) => '${v.toStringAsFixed(1)}%';

double _osa(DashboardKpis k) => k.osaPct;
double _perfect(DashboardKpis k) => k.perfectStoreRate;
double _price(DashboardKpis k) => k.priceCompliancePct;
double _visibility(DashboardKpis k) => k.visibilityCompliancePct;
double _sos(DashboardKpis k) => k.shareOfShelf;
double _weighted(DashboardKpis k) => k.weightedDistribution;
double _numeric(DashboardKpis k) => k.numericDistribution;

class _KpiStrip extends ConsumerStatefulWidget {
  const _KpiStrip({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  ConsumerState<_KpiStrip> createState() => _KpiStripState();
}

class _KpiStripState extends ConsumerState<_KpiStrip>
    with AutomaticKeepAliveClientMixin {
  /// Same first-data-build latch as the hero panel: pills enter once, and a
  /// filter change remounting the strip comes up entrance-free.
  bool _entered = false;

  /// Same storage guarantee as [_ExecutionScorePanelState.wantKeepAlive]:
  /// the ListView's sliver would otherwise dispose this State — latches and
  /// all — on a scroll past the cache extent, replaying the entrance on the
  /// way back. Seven text tiles and two sparklines; cheap to pin.
  @override
  bool get wantKeepAlive => true;

  /// Sparklines latch per label, separately from [_entered]: their trend
  /// providers can resolve a frame or two AFTER the snapshot, and by then the
  /// strip-level latch has already flipped — a shared flag would silently
  /// cancel their fade. A label re-entering after a filter change is already
  /// in the set, so nothing replays.
  final Set<String> _sparkEntered = {};

  /// A sparkline is only drawn where a real history series exists.
  ///
  /// `/trends` serves three series and no more (#95). The other five KPIs have
  /// no history endpoint, so they get no sparkline — a fabricated shape would be
  /// the most confident-looking lie on the screen.
  List<double>? _series(String label) {
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
  Widget build(BuildContext context) {
    super.build(context);
    final snapshot = widget.snapshot;
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
                _fmtPct(k.read(snap.current)),
                k.note,
                snap.of(k.read),
                k.read(snap.current),
              ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              // Latched INSIDE the layout builder, not in the data arm above:
              // this closure re-runs on a constraints-only relayout without a
              // fresh data build, and a stale `animate` captured on the
              // entrance frame would replay the pills when a breakpoint
              // change remounts the tiles.
              final animate = !_entered;
              _entered = true;

              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 3
                  : 2;

              // Chunk into rows and let each row divide the full width, so a
              // short final row fills instead of leaving a ragged empty cell.
              final rows = <List<(String, String, String, KpiDelta, double)>>[];
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
                                  // The figure counts up to its value once, on
                                  // this first data build — the spec's motion
                                  // table wants stat-tile numbers to sweep like
                                  // the hero score. Same `animate` epoch as the
                                  // pill below, so a reload remounting the tile
                                  // comes up sweep-free (latched at mount).
                                  countUpValue: rows[r][c].$5,
                                  countUpFormat: _fmtPct,
                                  animateCountUp: animate,
                                  // Measured against the window immediately
                                  // before this one — a second real request, not
                                  // an invented baseline. Null when there is
                                  // nothing to compare to (all-time has no
                                  // "before"), and the tile then shows no pill.
                                  delta: rows[r][c].$4.hasDelta
                                      ? rows[r][c].$4.change
                                      : null,
                                  animateDelta: animate,
                                  spark: switch (_series(rows[r][c].$1)) {
                                    final values? => OneShotEntrance(
                                      // Set.add IS the latch: true only the
                                      // first time this label's series
                                      // actually renders, false on every
                                      // later build or remount.
                                      enabled: _sparkEntered.add(rows[r][c].$1),
                                      // Staggered by flat tile position, so
                                      // the strip reads left-to-right.
                                      delay: Motion.stagger * (r * columns + c),
                                      child: Sparkline(
                                        values: values,
                                        width: null,
                                        gradient: true,
                                      ),
                                    ),
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
            // Glass draws each bar in its status word's colour with the
            // target tick on it, so the legend's job is done in the bars.
            if (!context.colors.glass) ...[
              BarChart.legend(),
              const SizedBox(height: 8),
            ],
            _TerritoryScoreBars(territories: list),
          ],
        ),
      ),
    );
  }
}

/// The panel's two settled-but-nothing-to-plot states: no territories at all,
/// and territories with no scores yet. Both are *answers*, so neither may
/// render as a loader (#222).
class _TerritoryPlaceholder extends StatelessWidget {
  const _TerritoryPlaceholder(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: context.colors.ink3),
      ),
    ),
  );
}

/// Fetches every territory's KPIs in a single `GET /dashboard/by-territory`
/// call — see #97.
class _TerritoryScoreBars extends ConsumerWidget {
  const _TerritoryScoreBars({required this.territories});

  final List<Territory> territories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (territories.isEmpty) {
      return _TerritoryPlaceholder('No territories defined');
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
        // Territories exist but no summary overlaps them — a real backend
        // state, not a pending fetch. The future already completed, so a
        // loader here would spin forever (#222); same rule as the error arm.
        if (points.isEmpty) {
          return _TerritoryPlaceholder('No territory scores yet');
        }
        points.sort((a, b) => b.value.compareTo(a.value));
        if (context.colors.glass) return _GlassTerritoryBars(points: points);
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
          points: [
            for (final p in points)
              (label: formatPeriodLabel(p.period), value: p.value),
          ],
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
/// The map is ALWAYS present once there is anything at all to draw. It used
/// to disappear entirely whenever nobody had checked in yet, leaving only the
/// list and a "View map" button that led nowhere useful — reported as "the
/// map is not showing". Now the tenant's outlets (`outletsListProvider`) form
/// a base layer of muted place pins under the agent glyphs, so a manager
/// always sees their store network; agent pins layer on top as people check
/// in. `outletsListProvider` is NOT territory-scoped — it returns every
/// outlet in the tenant regardless of `dashboardFilterProvider`, so a
/// territory-filtered view can show more outlets than the (scoped) agents
/// beside them. Acceptable for a base layer: the outlets are real, just not
/// narrowed the way the agent list is.
///
/// Public rather than private so the widget test can pump it on its own.
class AgentActivityPanel extends ConsumerWidget {
  const AgentActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(agentActivityTodayProvider);
    final filter = ref.watch(dashboardFilterProvider);
    // `maybeWhen` rather than `AsyncSection`/`.when`: outlets are a base
    // layer, not the panel's primary data. A slow or failed outlet fetch
    // must never blank the whole panel or block the agent map — it just
    // means the base layer is thinner (or absent) until the fetch lands.
    final outlets = ref
        .watch(outletsListProvider)
        .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);

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
            // The map can draw as long as there is EITHER a checked-in agent
            // OR an outlet to place — a base layer of stores is still a map
            // worth showing on a quiet morning. Only a brand-new tenant with
            // neither has genuinely nothing to plot.
            final hasMapContent = withStops.isNotEmpty || outlets.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasMapContent) ...[
                  // Nothing to plot at all: a grey, empty map would look
                  // broken rather than honest, so the list carries the panel
                  // alone and says in words why there is nothing to draw.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No outlets yet — add outlets to see them here.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.ink3,
                      ),
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
                        ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.ink3,
                      ),
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
/// placed at their latest one, over a base layer of the tenant's outlets. No
/// polylines here: the drill-in trail map (`agent_trail_screen.dart`) carries
/// the day's route, this one only answers "where are they now" (as of their
/// last check-in) — and, on a quiet day with no check-ins yet, "where is my
/// store network at all".
///
/// Caller (`AgentActivityPanel`) guarantees at least one of [agentsWithStops]
/// or [outlets] is non-empty before constructing this — `fitFor` asserts a
/// non-empty point list, and there is nothing this widget could sensibly draw
/// with neither.
class _AgentMap extends StatelessWidget {
  const _AgentMap({required this.agentsWithStops, required this.outlets});

  /// Must all have `stops.isNotEmpty` — callers filter before constructing.
  final List<AgentActivity> agentsWithStops;

  /// The tenant's outlets, unfiltered by territory — see
  /// [AgentActivityPanel]'s doc comment on why that is acceptable for a base
  /// layer.
  final List<Outlet> outlets;

  @override
  Widget build(BuildContext context) {
    final agentPoints = [
      for (final a in agentsWithStops)
        LatLng(_latestStop(a).lat, _latestStop(a).lng),
    ];
    final outletPoints = [for (final o in outlets) LatLng(o.lat, o.lng)];
    // Agents are the priority signal, but a fit that includes nearby stores
    // too is harmless — and when nobody has checked in yet, the outlets are
    // the ONLY points there are to fit against.
    final points = [...agentPoints, ...outletPoints];

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
              // The navy wash that makes the island the same Tide Guide
              // world as the full-screen trail map — between the tiles and
              // the markers so pins stay at full brightness.
              const TiqNavyTint(),
              MarkerLayer(
                // Outlets first, agents last: marker paint order follows
                // list order, so a checked-in agent standing at (or near) an
                // outlet is never hidden underneath that outlet's base-layer
                // dot.
                markers: [
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

/// One outlet on the panel's map — the base layer under the agent pins.
///
/// Deliberately NOT a scaled-down [_AgentMapPin]: #144's rule that state must
/// differ by SILHOUETTE, not colour or size, cuts both ways here — a place
/// marker must be just as unmistakably NOT a person's state. [AgentStateGlyph]
/// draws a literal storefront for [AgentState.atStore]; reusing anything
/// storefront-shaped for an outlet would recreate exactly the confusion #144
/// already cost this feature twice. So this is a plain small dot with a
/// hollow centre — a place marker's silhouette, not a state's — sized and
/// coloured to read as quiet background context: an agent glyph should
/// always be the eye's first stop.
///
/// Stateless, unlike [_AgentMapPin] — a base layer of outlets is not an
/// interactive affordance the way an agent's live state is, so there is
/// nothing here worth a hover response.
class _OutletBasePin extends StatelessWidget {
  const _OutletBasePin({super.key, required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${outlet.name} outlet',
      excludeSemantics: true,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // A dim navy from the same family as the basemap's tint —
            // deliberately muted, with only a faint glow, next to the agent
            // pins' bright glowing discs, so this reads as background
            // rather than competing for attention.
            color: const Color(0xFF39557E),
            boxShadow: [
              BoxShadow(
                // rgba(64,120,200,.35) — a quieter, dimmer blue than the
                // agent pins' rgba(64,156,255,.55) halo.
                color: const Color(0xFF4078C8).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
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
            shape: BoxShape.circle,
            // The glowing lit-sphere disc, same recipe as
            // agent_trail_screen.dart's _StopPin at panel scale: the small
            // highlight is pushed to the top-left so the glyph sits on the
            // deep core — the colour the white glyph is contrast-guarded
            // against (≥3:1, this panel's own test). The glow is STATIC
            // here: the trail's breathing loop is the design's only looping
            // animation, and this below-the-fold island earns none.
            gradient: const RadialGradient(
              center: Alignment(-0.4, -0.5),
              radius: 1.0,
              colors: [Color(0xFF7CC0FF), Color(0xFF1F7AE0)],
              stops: [0.0, 0.75],
            ),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                // rgba(64,156,255,.55) — the trail pins' glow blue, halo
                // scaled down with the disc.
                color: const Color(0xFF409CFF).withValues(alpha: 0.55),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: AgentStateGlyph(
              state: agent.state,
              // White on the deep core for every state: on this disc the
              // per-state colours would be near-invisible, and colour was
              // never the carrier anyway — the SHAPE is the state (#144),
              // exactly as on the white disc this replaces.
              color: Colors.white,
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

/// Sentinel for the "All territories" menu entry. A null [PopupMenuItem] value
/// would be swallowed as a cancel, so the null filter travels as this token and
/// is mapped back to `clearTerritory` at selection.
const _allTerritoriesValue = '__all_territories__';

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
      data: (list) {
        // Territories are an arbitrary-length list, so this is a pill-STYLED
        // menu trigger, not a segmented pill row. It wears the inactive
        // range-pill look (surface1 + hairline + radiusPill) so it reads as a
        // control that shares the bar's idiom.
        var selectedLabel = 'All territories';
        for (final t in list) {
          if (t.id == filter.territoryId) {
            selectedLabel = t.name;
            break;
          }
        }
        return PopupMenuButton<String>(
          key: const ValueKey('filter-territory'),
          // PopupMenuButton treats a null selected value as a cancel, so the
          // "All territories" option carries a sentinel rather than null; it is
          // mapped back to clearTerritory below. The provider wiring is
          // unchanged.
          initialValue: filter.territoryId ?? _allTerritoriesValue,
          tooltip: 'Filter by territory',
          color: colors.surface2,
          onSelected: (v) => update(
            v == _allTerritoriesValue
                ? filter.copyWith(clearTerritory: true)
                : filter.copyWith(territoryId: v),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: _allTerritoriesValue,
              child: Text(
                'All territories',
                style: TextStyle(fontSize: 12.5, color: colors.ink1),
              ),
            ),
            for (final t in list)
              PopupMenuItem<String>(
                value: t.id,
                child: Text(
                  t.name,
                  style: TextStyle(fontSize: 12.5, color: colors.ink1),
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surface1,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedLabel,
                  style: TextStyle(fontSize: 12.5, color: colors.ink2),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 18, color: colors.ink2),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );

    final filters = Wrap(
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
      );

    // One glass bar scopes everything beneath it — never a filter in a panel.
    if (colors.glass) {
      return GlassPane(
        radius: LumenGlass.radiusControl,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: filters,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: filters,
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in DashboardRange.values)
          PillSegment(
            key: ValueKey('range-${r.name}'),
            label: r.label,
            selected: r == selected,
            onTap: () => onChanged(r),
          ),
      ],
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

// ═══════════════════════════════════════════════════════════════════════
// Lumen Glass — against the published standard
// ═══════════════════════════════════════════════════════════════════════

/// One KPI and the standard it is judged by.
///
/// On-shelf availability and the perfect-store band are published industry
/// reference points (the design handoff sources them); the rest are the
/// handoff's internal standards. They are drawn as a tick on each bar so a
/// figure is never read without the line it is measured against.
typedef _Benchmark = ({
  String label,
  double Function(DashboardKpis) read,
  double target,
  String note,
});

const _benchmarks = <_Benchmark>[
  (
    label: 'On-shelf availability',
    read: _osa,
    target: 95,
    note: 'Floor 95% · target 97–99%',
  ),
  (
    label: 'Perfect-store rate',
    read: _perfect,
    target: 80,
    note: 'Healthy 80–90% · below 70% is an execution gap',
  ),
  (
    label: 'Price compliance',
    read: _price,
    target: 95,
    note: 'Within tolerance of RRP',
  ),
  (
    label: 'Visibility compliance',
    read: _visibility,
    target: 80,
    note: 'Planogram threshold',
  ),
  (
    label: 'Share of shelf',
    read: _sos,
    target: 33,
    note: 'Category fair share',
  ),
  (
    label: 'Weighted distribution',
    read: _weighted,
    target: 85,
    note: 'Volume-weighted',
  ),
];

/// On the standard, within ten points of it, or breaching it.
LumenStatus _againstStandard(double value, double target) => value >= target
    ? LumenStatus.good
    : value >= target - 10
    ? LumenStatus.warn
    : LumenStatus.crit;

class _BenchmarkPanel extends StatelessWidget {
  const _BenchmarkPanel({required this.snapshot});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Where we sit against the standard',
      subtitle: 'Tick marks the target',
      child: snapshot.when(
        loading: () => const _InlineLoader(height: 120),
        error: (err, _) => const _InlineError(message: 'Could not load KPIs'),
        data: (snap) => LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 900
                ? 3
                : box.maxWidth >= 560
                ? 2
                : 1;
            const gap = 28.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 18,
              children: [
                for (final b in _benchmarks)
                  SizedBox(
                    width: width,
                    child: _BenchmarkCell(
                      benchmark: b,
                      value: b.read(snap.current),
                      delta: snap.of(b.read),
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

class _BenchmarkCell extends StatelessWidget {
  const _BenchmarkCell({
    required this.benchmark,
    required this.value,
    required this.delta,
  });

  final _Benchmark benchmark;
  final double value;
  final KpiDelta delta;

  @override
  Widget build(BuildContext context) {
    final status = _againstStandard(value, benchmark.target);
    final ink = status.swatchOf(context.colors).ink;
    return Column(
      key: ValueKey('benchmark-${benchmark.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                benchmark.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.lumen.ink,
                ),
              ),
            ),
            LumenStatusPill(status: status),
            const SizedBox(width: 9),
            Text(_fmtPct(value), style: LumenGlass.figure(size: 14, color: ink)),
            if (delta.hasDelta) ...[
              const SizedBox(width: 7),
              DeltaPill(
                delta: delta.change!,
                tone: delta.change! < 0 ? DeltaTone.bad : DeltaTone.good,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        BenchmarkBar(
          value: value,
          target: benchmark.target,
          status: status,
          height: 8,
        ),
        const SizedBox(height: 6),
        Text(
          benchmark.note,
          style: TextStyle(fontSize: 10.5, color: context.lumen.inkMuted),
        ),
      ],
    );
  }
}

/// How many outlets sit in each perfect-store band, by their latest scored
/// visit — five columns, each coloured by the band it counts.
class _DistributionPanel extends StatelessWidget {
  const _DistributionPanel({required this.bands});

  final List<ScoreBand> bands;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final most = bands.fold<int>(0, (m, b) => math.max(m, b.outlets));
    final total = bands.fold<int>(0, (sum, b) => sum + b.outlets);

    return PanelCard(
      title: 'Perfect-store distribution',
      subtitle: '$total outlets · healthy band 80–90',
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final band in bands)
              Expanded(
                child: Semantics(
                  label: '${band.outlets} outlets scoring ${band.label}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${band.outlets}',
                          style: LumenGlass.figure(
                            size: 12,
                            color: _bandStatus(band).swatchOf(colors).ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: most == 0 ? 0 : band.outlets / most,
                          ),
                          duration: reduceMotion(context)
                              ? Duration.zero
                              : Motion.slow,
                          curve: Motion.enter,
                          builder: (context, t, _) => Container(
                            height: math.max(2, 118 * t),
                            decoration: BoxDecoration(
                              color: _bandStatus(band).swatchOf(colors).fill,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                                bottom: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          band.label,
                          style: LumenGlass.figure(
                            size: 10,
                            color: context.lumen.inkMuted,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static LumenStatus _bandStatus(ScoreBand band) => band.minScore >= 80
      ? LumenStatus.good
      : band.minScore >= 70
      ? LumenStatus.warn
      : LumenStatus.crit;
}

/// Each territory's execution score against the 75 target.
class _GlassTerritoryBars extends StatelessWidget {
  const _GlassTerritoryBars({required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        for (final p in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    p.label,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.lumen.inkMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BenchmarkBar(
                    value: p.value,
                    target: 75,
                    status: _againstStandard(p.value, 75),
                    height: 15,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  child: Text(
                    p.value.toStringAsFixed(1),
                    style: LumenGlass.figure(
                      size: 12,
                      color: _againstStandard(p.value, 75).swatchOf(colors).ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

