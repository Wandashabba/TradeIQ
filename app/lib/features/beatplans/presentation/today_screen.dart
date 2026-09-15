import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/status_pill_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/worklist.dart';
import '../../../l10n/l10n.dart';
import '../../contests/presentation/contests_entry_action.dart';
import '../data/today_route.dart';
import '../../../core/theme/lumen_palette.dart';

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
    final l10n = context.l10n;

    return AgentScaffold(
      title: l10n.todayTitle,
      subtitle: formatDayHeading(context, DateTime.now()),
      // Contests (#124): the agent's way in, with a running-count badge.
      actions: const [ContestsEntryAction()],
      body: routeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _NoRoute(
          title: l10n.todayLoadErrorTitle,
          detail: l10n.todayLoadErrorDetail,
        ),
        data: (route) {
          if (route == null || route.stops.isEmpty) {
            return _NoRoute(
              title: l10n.todayNoRouteTitle,
              detail: route == null
                  ? l10n.todayNoPlanDetail
                  : l10n.todayEmptyPlanDetail,
            );
          }
          return _Route(route: route);
        },
      ),
    );
  }
}

class _Route extends ConsumerWidget {
  const _Route({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.colors.glass) return _GlassRoute(route: route);
    final next = route.next;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(todayRouteProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Header(route: route),
          const SizedBox(height: 18),
          _Heading(context.l10n.todayYourRouteHeading),
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
            label: context.l10n.todayVisitAnotherStore,
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
                context.l10n.todayStoresOfTotal(route.total),
                style: TextStyle(fontSize: 14, color: colors.ink2),
              ),
              const Spacer(),
              _StatusPill(
                label: route.isComplete
                    ? context.l10n.todayRouteDone
                    : context.l10n.todayStoresLeft(route.remaining),
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
              context.l10n.todayDistancesOff,
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
                                label: context.l10n.todayStopDoneTag,
                                bg: _goodPill.bg,
                                fg: _goodPill.fg,
                              )
                            : _StateTag(
                                label: context.l10n.todayStopNextTag,
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
              label: context.l10n.todayPickStore,
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

// ═══════════════════════════════════════════════════════════════════════
// Lumen Glass — the day as one dark card, the next store as the hero
// ═══════════════════════════════════════════════════════════════════════

/// The route in glass. The model changes with the material: the next store is
/// not a row in a list but its own card with the check-in on it, because it is
/// the one thing the agent is about to do; the rest of the day follows.
class _GlassRoute extends ConsumerWidget {
  const _GlassRoute({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = route.next;
    final rest = [
      for (final stop in route.stops)
        if (next == null || stop.outlet.id != next.outlet.id) stop,
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(todayRouteProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _DayCard(route: route),
          if (next != null) ...[
            const SizedBox(height: 22),
            Kicker(context.l10n.todayNextUpHeading),
            const SizedBox(height: 10),
            _NextCard(
              stop: next,
              onTap: () => context.go('/audit/${next.outlet.id}'),
            ),
          ],
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 22),
            Kicker(
              next == null
                  ? context.l10n.todayYourRouteHeading
                  : context.l10n.todayRestOfDayHeading,
            ),
            const SizedBox(height: 10),
            for (final (i, stop) in rest.indexed)
              Reveal(
                index: i,
                child: _GlassStopRow(
                  stop: stop,
                  onTap: () => context.go('/audit/${stop.outlet.id}'),
                ),
              ),
          ],
          const SizedBox(height: 12),
          // The plan is a plan, not a cage.
          AgentButton(
            key: const ValueKey('visit-another'),
            label: context.l10n.todayVisitAnotherStore,
            secondary: true,
            onPressed: () => context.go('/audit'),
          ),
        ],
      ),
    );
  }
}

/// The day on the product's dark pane: a ring of stores done, the headline
/// count, and what is left — said in words on a pill.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context) {
    final done = route.doneCount;
    final total = route.total;
    return GlassPane(
      kind: GlassKind.dark,
      radius: LumenGlass.radiusHero,
      padding: const EdgeInsets.all(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -100,
            right: -80,
            child: GlassBloom(diameter: 220),
          ),
          Row(
            children: [
              _DayRing(done: done, total: total),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      route.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedCount(
                          value: done,
                          style: LumenGlass.hero(size: 31, color: Colors.white),
                        ),
                        Flexible(
                          child: Text(
                            context.l10n.todayStoresOfTotal(total),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: LumenGlass.onDarkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DayPill(
                      label: route.isComplete
                          ? context.l10n.todayRouteDone
                          : context.l10n.todayStoresLeft(route.remaining),
                      complete: route.isComplete,
                    ),
                    if (!route.hasLocation) ...[
                      const SizedBox(height: 10),
                      Text(
                        // Not "location error" — the route still works.
                        context.l10n.todayDistancesOff,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: LumenGlass.onDarkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 96px ring: stores done as an arc of light around "done/total".
class _DayRing extends StatelessWidget {
  const _DayRing({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: reduceMotion(context) ? Duration.zero : Motion.slow,
            curve: Motion.enter,
            builder: (context, t, _) => CustomPaint(
              size: const Size.square(96),
              painter: _RingPainter(t),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$done/$total',
                style: const TextStyle(
                  fontSize: 21,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Kicker(
                context.l10n.todayStoresRingLabel,
                color: LumenGlass.onDarkMuted,
                size: 8.5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(4);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0x29FFFFFF);
    canvas.drawArc(rect, 0, 6.2832, false, track);
    if (fraction <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = LumenGlass.accentLight
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    canvas.drawArc(rect, -1.5708, 6.2832 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// "N left" / "Route done" on the dark pane — opaque, so the pair is its own
/// ground: white clears 8.7:1 on the neutral and 5.3:1 on the green.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: complete ? const Color(0xFF1F7A4D) : const Color(0xFF4A4B5C),
        borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: LumenGlass.mono,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The next store, as the card the agent acts on.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.stop, required this.onTap});

  final RouteStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassPane(
      key: const ValueKey('next-stop'),
      radius: LumenGlass.radiusHero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StopTag(
                label: context.l10n.todayStopNextTag,
                bg: Color.alphaBlend(
                  LumenStatus.current.swatchOf(colors).tint,
                  colors.surface1,
                ),
                fg: context.lumen.accentInk,
              ),
              if (stop.distanceLabel != null) ...[
                const SizedBox(width: 9),
                Text(
                  stop.distanceLabel!,
                  style: LumenGlass.figure(size: 11.5, color: context.lumen.kicker),
                ),
              ],
              const Spacer(),
              Kicker(
                context.l10n.todayStopNumber(
                  stop.sequence.toString().padLeft(2, '0'),
                ),
                size: 9.5,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(stop.outlet.name, style: LumenGlass.title(color: context.lumen.ink, size: 25)),
          const SizedBox(height: 5),
          Text(
            stop.outlet.code,
            style: TextStyle(fontSize: 12.5, color: context.lumen.inkMuted),
          ),
          const SizedBox(height: 17),
          GlassPrimaryButton(
            key: const ValueKey('check-in-next'),
            label: context.l10n.todayCheckInHere,
            trailingIcon: Icons.chevron_right,
            height: 50,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// One stop after the next: a status tile, the store, the distance, and DONE
/// once it is visited. A visited store recedes.
class _GlassStopRow extends StatelessWidget {
  const _GlassStopRow({required this.stop, required this.onTap});

  final RouteStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = stop.visited;
    final good = LumenStatus.good.swatchOf(colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: PressFeedback(
        onTap: onTap,
        child: GlassPane(
          kind: GlassKind.tile,
          blur: false,
          radius: LumenGlass.radiusControl,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              StatusTile(
                status: done ? LumenStatus.good : LumenStatus.none,
                glyph: done ? '✓' : '${stop.sequence}',
                mono: !done,
              ),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: done ? context.lumen.inkMuted : context.lumen.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.outlet.code,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.lumen.inkMuted,
                      ),
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
                      style: LumenGlass.figure(
                        size: 11.5,
                        color: context.lumen.inkMuted,
                      ),
                    ),
                  if (done)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _StopTag(
                        label: context.l10n.todayStopDoneTag,
                        bg: Color.alphaBlend(good.tint, colors.surface1),
                        fg: good.ink,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A DONE / NEXT tag — a word on an OPAQUE wash, so the pair clears AA on its
/// own rather than depending on whatever glass sits beneath it.
class _StopTag extends StatelessWidget {
  const _StopTag({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: LumenGlass.mono,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: fg,
        ),
      ),
    );
  }
}

