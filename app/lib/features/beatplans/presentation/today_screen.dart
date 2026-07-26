import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/status_pill_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/today_route.dart';

/// The agent's day.
///
/// This is where a field agent starts, because the first question of the day is
/// not "which of the 400 outlets in this client would you like to audit" — it is
/// "where am I going, and how much is left". The outlet picker asked the first
/// question. This one answers the second.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(todayRouteProvider);

    return AgentScaffold(
      title: 'Today',
      subtitle: _weekday(DateTime.now()),
      body: routeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _NoRoute(
          title: 'Could not load your route',
          detail: 'You can still start a visit yourself.',
        ),
        data: (route) {
          if (route == null || route.stops.isEmpty) {
            return _NoRoute(
              title: 'No route planned for today',
              detail: route == null
                  ? 'Your manager has not built a beat plan for today. You can '
                        'still visit a store — pick it yourself.'
                  : 'Today’s beat plan has no stops on it yet.',
            );
          }
          return _Route(route: route);
        },
      ),
    );
  }

  static String _weekday(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}

class _Route extends ConsumerWidget {
  const _Route({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = route.next;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(todayRouteProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Header(route: route),
          const SizedBox(height: 18),
          const _Heading('Your route'),
          // Each stop is now its own worklist card (surface1 ground, hairline,
          // state-coloured left edge) rather than a row in one bordered box —
          // the console's worklist language.
          for (final (i, stop) in route.stops.indexed)
            Reveal(
              index: i,
              child: _StopCard(
                stop: stop,
                isNext: next != null && stop.outlet.id == next.outlet.id,
                onTap: () => context.go('/audit/${stop.outlet.id}'),
              ),
            ),
          const SizedBox(height: 8),
          // The plan is a plan, not a cage. A store can be shut, or a manager can
          // phone with something urgent — so visiting an unplanned store is one
          // tap away, not a thing the agent has to fight the app for.
          AgentButton(
            key: const ValueKey('visit-another'),
            label: 'Visit a store not on my route',
            secondary: true,
            onPressed: () => context.go('/audit'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // The screen's one "glass" card: the day's progress is the headline, and the
    // wash is what makes it read as the headline. Same recipe as the console's
    // execution-score hero — theme slots, not spec hexes, so ink1 stays readable
    // on the wash in both modes.
    return _GlassHero(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.planName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.ink1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCount(
                value: route.doneCount,
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.ink1,
                ),
              ),
              Text(
                ' of ${route.total} ${route.total == 1 ? 'store' : 'stores'}',
                style: TextStyle(fontSize: 14, color: colors.ink2),
              ),
              const Spacer(),
              _StatusPill(
                label: route.isComplete
                    ? 'Route done'
                    : '${route.remaining} left',
                complete: route.isComplete,
              ),
            ],
          ),
          const SizedBox(height: 11),
          _ProgressBar(
            done: route.doneCount,
            total: route.total,
            complete: route.isComplete,
          ),
          if (!route.hasLocation) ...[
            const SizedBox(height: 10),
            Text(
              // Not "location error". The agent turned it off, or the phone
              // cannot see the sky. Either way the route still works.
              'Distances are off — this phone will not say where it is.',
              style: TextStyle(fontSize: 11.5, color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// The glass-hero shell — the console's washed-panel recipe, in the agent kit's
/// geometry. Mirrors `PanelCard(gradient:…, borderColor: heroBorder)` but built
/// inline so the agent screen keeps a single dependency-light Container tree.
class _GlassHero extends StatelessWidget {
  const _GlassHero({required this.colors, required this.child});

  final TiqColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.heroWash, colors.surface1],
        ),
        border: Border.all(color: colors.heroBorder),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: child,
    );
  }
}

/// The house "done / positive" pill pair — the shared good status wash. Fixed
/// hexes, not theme slots: a status verdict reads the same in both themes, and
/// the pair is self-contained (it clears 4.5:1 on its own wash in light and
/// dark). Single-sourced — see status_pill_colors.dart.
const _goodPill = statusPillGood;

/// "N left" / "Route done" — a word on a wash, never colour alone AND never
/// below the AA floor. Complete takes the fixed good pair; before that it is a
/// neutral chip (ink2 on surface2, comfortably AA in both themes).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: complete ? _goodPill.bg : colors.surface2,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: complete ? _goodPill.fg : colors.ink2,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.done,
    required this.total,
    required this.complete,
  });

  final int done;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = total == 0 ? 0.0 : done / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 6, color: colors.surface3),
          LayoutBuilder(
            builder: (context, constraints) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: reduceMotion(context) ? Duration.zero : Motion.slow,
              curve: Motion.enter,
              builder: (context, t, _) => AnimatedContainer(
                duration: reduceMotion(context) ? Duration.zero : Motion.base,
                height: 6,
                width: constraints.maxWidth * t,
                // Green the moment the day is done — said in colour before it is
                // said in words.
                color: complete ? colors.good : colors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One route stop, as a console worklist card: surface1 ground, `line`
/// hairline, and a 3px left edge whose colour carries the stop's state.
///
/// Not [WorklistRow]: that row's leading slot is a 44×44 evidence thumbnail,
/// not a sequence badge, and its edge is driven by a four-value [StatusLevel]
/// that has no `brand` — which is exactly the colour the *next* stop's edge
/// needs. So this is a local card in WorklistRow's recipe rather than a forced
/// fit.
class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.isNext,
    required this.onTap,
  });

  final RouteStop stop;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = stop.visited;
    // Channel 1: the left edge — good (visited), brand (next), muted (upcoming).
    final edge = done
        ? colors.good
        : isNext
        ? colors.brand
        : colors.lineStrong;

    return PressFeedback(
      onTap: onTap,
      // The shared card shell single-sources the chrome, the concentric clip
      // and the 3px edge (see WorklistCardShell). This card keeps its own
      // interaction (PressFeedback), sequence badge and DONE/NEXT tags — the
      // parts that diverge from WorklistRow and so stay here.
      child: WorklistCardShell(
        edgeColor: edge,
        margin: const EdgeInsets.only(bottom: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kTapTarget + 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                _Seq(sequence: stop.sequence, done: done, isNext: isNext),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stop.outlet.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          // A visited store recedes. The agent's eye
                          // should land on what is left, not behind.
                          fontWeight: done ? FontWeight.w400 : FontWeight.w600,
                          color: done ? colors.ink2 : colors.ink1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stop.outlet.code,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stop.distanceLabel != null)
                      Text(
                        stop.distanceLabel!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.ink2,
                        ),
                      ),
                    if (done || isNext)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        // DONE takes the fixed good pair; NEXT the
                        // console's active-chip pattern (white on the
                        // solid brand) — both AA-clear, theme-constant.
                        child: done
                            ? _StateTag(
                                label: 'DONE',
                                bg: _goodPill.bg,
                                fg: _goodPill.fg,
                              )
                            : _StateTag(
                                label: 'NEXT',
                                bg: colors.brand,
                                fg: Colors.white,
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A DONE/NEXT tag — the word on a fixed, AA-clear wash/text pair (never a
/// self-tint). The visited card also carries the ✓ glyph in its sequence slot,
/// so state never rides on colour alone.
class _StateTag extends StatelessWidget {
  const _StateTag({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}

class _Seq extends StatelessWidget {
  const _Seq({
    required this.sequence,
    required this.done,
    required this.isNext,
  });

  final int sequence;
  final bool done;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (done) {
      return SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: TickMark(done: true, size: 20, color: colors.good),
        ),
      );
    }

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNext ? colors.brand : colors.surface3,
        shape: BoxShape.circle,
        border: Border.all(color: isNext ? colors.brand : colors.lineStrong),
      ),
      child: Text(
        '$sequence',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isNext ? Colors.white : colors.ink2,
        ),
      ),
    );
  }
}

/// No plan is not an error, and it is not a dead end.
class _NoRoute extends StatelessWidget {
  const _NoRoute({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 34, color: colors.ink3),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink2),
            ),
            const SizedBox(height: 20),
            AgentButton(
              key: const ValueKey('pick-a-store'),
              label: 'Pick a store to visit',
              onPressed: () => context.go('/audit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.88,
          color: context.colors.ink3,
        ),
      ),
    );
  }
}
