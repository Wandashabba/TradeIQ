import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
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
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppColors.radiusPanel),
            ),
            child: Column(
              children: [
                for (final (i, stop) in route.stops.indexed)
                  Reveal(
                    index: i,
                    child: _StopRow(
                      stop: stop,
                      isNext: next != null &&
                          stop.outlet.id == next.outlet.id,
                      isLast: i == route.stops.length - 1,
                      onTap: () => context.go('/audit/${stop.outlet.id}'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.planName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCount(
                value: route.doneCount,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.ink1,
                ),
              ),
              Text(
                ' of ${route.total} ${route.total == 1 ? 'store' : 'stores'}',
                style: const TextStyle(fontSize: 14, color: AppColors.ink2),
              ),
              const Spacer(),
              Text(
                route.isComplete
                    ? 'Route done'
                    : '${route.remaining} left',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: route.isComplete ? AppColors.good : AppColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ProgressBar(
            done: route.doneCount,
            total: route.total,
            complete: route.isComplete,
          ),
          if (!route.hasLocation) ...[
            const SizedBox(height: 10),
            const Text(
              // Not "location error". The agent turned it off, or the phone
              // cannot see the sky. Either way the route still works.
              'Distances are off — this phone will not say where it is.',
              style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
            ),
          ],
        ],
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
    final fraction = total == 0 ? 0.0 : done / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 6, color: AppColors.surface3),
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
                color: complete ? AppColors.good : AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.isNext,
    required this.isLast,
    required this.onTap,
  });

  final RouteStop stop;
  final bool isNext;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = stop.visited;

    return PressFeedback(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: kTapTarget + 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            _Seq(sequence: stop.sequence, done: done, isNext: isNext),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.outlet.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      // A visited store recedes. The agent's eye should land on
                      // what is left, not on what is behind them.
                      fontWeight: done ? FontWeight.w400 : FontWeight.w600,
                      color: done ? AppColors.ink2 : AppColors.ink1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stop.outlet.code,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink3,
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
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppColors.ink2,
                    ),
                  ),
                if (done || isNext)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      done ? 'DONE' : 'NEXT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: done ? AppColors.good : AppColors.brand,
                      ),
                    ),
                  ),
              ],
            ),
          ],
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
    if (done) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: Center(child: TickMark(done: true, size: 20)),
      );
    }

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNext ? AppColors.brand : AppColors.surface3,
        shape: BoxShape.circle,
        border: Border.all(
          color: isNext ? AppColors.brand : AppColors.lineStrong,
        ),
      ),
      child: Text(
        '$sequence',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isNext ? Colors.white : AppColors.ink2,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 34, color: AppColors.ink3),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.ink2,
              ),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.88,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}
