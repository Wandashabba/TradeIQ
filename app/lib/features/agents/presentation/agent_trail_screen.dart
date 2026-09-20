import 'package:flutter/material.dart' show Icons, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to legacy.dart in riverpod 3.x — still the right tool
// for a single piece of client-only UI state (the selected day) with no
// business logic attached.
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/agent_locations_repository.dart';
import '../data/agents_repository.dart';
import 'live_location_layer.dart';
import 'trail_map.dart';

/// The selected day, defaulting to today. Local dates only — the day boundary
/// is a client-side decision, see [dayBoundsLocal].
///
/// `.autoDispose`, like [agentActivityForDayProvider] itself: without it, a
/// manager who picks an earlier day and later navigates away would find the
/// screen re-open on that stale day rather than today, and a long-lived web
/// tab left open across midnight would keep "today" pinned to whenever the
/// tab first built this provider.
final agentTrailDayProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// AGENT TRAIL — where each agent HAS BEEN on one day.
///
/// ```text
///   Agent trail                                   [ ⟳ ]
///   2026-09-20 · 3 agents · 11 stops
///   Pick another day
///   ┌───────────────────────────────────────────┐
///   │         ① ---- ② ---- ③                   │   ← the basemap
///   └───────────────────────────────────────────┘
///   ── How to read it ──────────────────────────
///   Numbered pins are confirmed check-ins. Dashed
///   lines connect them in order — they are not a
///   recorded route.
///   ── Thandi Mokoena ──────────────── 4 stops ──
///   ▏1. Kasi Corner Spaza                 07:12
///   ▏2. Shoprite Klipspruit               09:40
///   …
///   [ nav pill ]
/// ```
///
/// ## Everything the map says, the list says too
///
/// The trail used to BE the map: a full-bleed `FlutterMap` with a legend strip
/// over it and nothing else on the route. That made three ordinary conditions
/// into a blank screen — **Veld** (maps do not render outdoors, unify §4),
/// **no tiles** (a forecourt with no signal), and **a short phone at 2.0×**
/// (the fold budget goes to zero). The list underneath is the same day in the
/// same order, and every one of those three now degrades to a screen rather
/// than to an absence.
///
/// ## A row names a person (#399/#400)
///
/// Each agent's trail is introduced by a [PersonRow] — initials on a tile,
/// never a photograph, the full name as the title and the stop count spoken
/// beside it. The screen before this one put the agent's name in a map tooltip
/// and in nothing else: a manager who could not hover, or could not see, had
/// no way to tell three identical "1" pins apart.
///
/// ## The one amber, counted
///
/// A tab root, so Night's budget is two and the nav's active tab is slot 1.
/// This route nominates nothing: a record of where somebody has been has no
/// commit action, and a trail is not a chart with a focus. Day and Veld paint
/// zero. The stop pins carry no amber either — amber leaves the map entirely
/// (§3.2), and on a map of eleven stops it would be claimed eleven times.
class AgentTrailScreen extends ConsumerWidget {
  const AgentTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(agentTrailDayProvider);
    final activity = ref.watch(agentActivityForDayProvider(day));
    final now = DateTime.now();
    final isToday = day == DateTime(now.year, now.month, now.day);
    // Live positions belong on TODAY's map only: this minute's positions drawn
    // over a past day's trail would put two different moments on one screen.
    final live = isToday ? ref.watch(liveAgentLocationsProvider).value : null;
    final livePositions = <AgentLocation>[
      for (final a in live?.agents ?? const <AgentLocation>[])
        if (a.hasPosition) a,
    ];

    void refresh() {
      ref.invalidate(agentActivityForDayProvider(day));
      if (isToday) ref.invalidate(liveAgentLocationsProvider);
    }

    Future<void> pickDay() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        ref.read(agentTrailDayProvider.notifier).state = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      }
    }

    Widget frame({
      required String phase,
      required List<Widget> children,
      List<String> extraFacts = const <String>[],
    }) => ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Agent trail',
        facts: <String>[_isoDay(day), ...extraFacts],
        trailing: TorchIconButton(
          key: const ValueKey<String>('agent-trail-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh this day',
          onPressed: refresh,
        ),
      ),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('agent-trail-date'),
            label: 'Pick another day',
            icon: Icons.calendar_today,
            onPressed: pickDay,
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        ...children,
      ],
    );

    return activity.when(
      loading: () => frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'this day',
            child: const SkeletonRows(count: 4, rowHeight: 64),
          ),
        ],
      ),
      error: (error, stack) => frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'agent activity',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('agent-trail-retry'),
                label: 'Try again',
                onPressed: refresh,
              ),
            ),
          ),
        ],
      ),
      data: (page) {
        final withStops = <AgentActivity>[
          for (final a in page.agents)
            if (a.stops.isNotEmpty) a,
        ];
        final stops = withStops.fold<int>(0, (n, a) => n + a.stops.length);
        final numbers = TiqNumber.of(context);
        final empty = withStops.isEmpty && livePositions.isEmpty;

        return frame(
          phase: empty ? 'empty' : 'loaded',
          extraFacts: empty
              ? const <String>[]
              : <String>[
                  '${numbers.format(withStops.length)} '
                      '${withStops.length == 1 ? 'agent' : 'agents'}',
                  '${numbers.format(stops)} '
                      '${stops == 1 ? 'stop' : 'stops'}',
                ],
          children: empty
              ? <Widget>[
                  const EmptyState(
                    key: ValueKey<String>('agent-trail-empty'),
                    scope: EmptyScope.inPanel,
                    headline: 'No check-ins on this day.',
                    body: 'A pin appears here when an agent confirms a '
                        'check-in. Pick another day to see one that has some.',
                  ),
                ]
              : <Widget>[
                  TrailMap(
                    day: day,
                    withStops: withStops,
                    live: livePositions,
                  ),
                  const SizedBox(height: TiqSpace.s6),
                  const SectionRule('How to read it'),
                  const SizedBox(height: TiqSpace.s3),
                  _Legend(truncated: page.truncated, live: live),
                  const SizedBox(height: TiqSpace.s7),
                  for (final agent in withStops) ...<Widget>[
                    _AgentTrail(agent: agent),
                    const SizedBox(height: TiqSpace.s6),
                  ],
                  if (page.truncated)
                    TorchBleed(
                      extra: context.skin.space.gutter * 2,
                      child: const PaginationFooter(
                        key: ValueKey<String>('agent-trail-footer'),
                        summary: 'Showing the first 200 agents only.',
                        narrowLine: 'A partial map that looks complete is '
                            'worse than no map: the rest of the day is not '
                            'here.',
                      ),
                    ),
                ],
        );
      },
    );
  }

  static String _isoDay(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }
}

/// What the marks mean, in words.
///
/// Without this the map overstates its own certainty to anyone who does not
/// read a stroke pattern as semantics.
class _Legend extends StatelessWidget {
  const _Legend({required this.truncated, this.live});

  final bool truncated;

  /// Today's live page, or null on a past day — there is no live layer then.
  final AgentLocationsPage? live;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final style = skin.text.meta.style(color: skin.palette.ink2);
    final liveNow = live;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Numbered pins are confirmed check-ins, in order, and the last one '
          'of each agent is filled. Dashed lines connect them — they are not '
          'a recorded route.',
          style: style,
        ),
        if (liveNow != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Text(
            'Squares are live positions from the agent app, labelled with '
            'their age first. Last updated '
            '${formatUpdatedAt(liveNow.serverTime)}.',
            key: const ValueKey<String>('trail-live-legend'),
            style: style,
          ),
        ],
      ],
    );
  }
}

/// One agent's day: who they are, then every stop in order.
class _AgentTrail extends StatelessWidget {
  const _AgentTrail({required this.agent});

  final AgentActivity agent;

  @override
  Widget build(BuildContext context) {
    final gutter = context.skin.space.gutter;
    final numbers = TiqNumber.of(context);
    final stops = agent.stops;
    final count = '${numbers.format(stops.length)} '
        '${stops.length == 1 ? 'stop' : 'stops'}';

    return TorchBleed(
      extra: gutter * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The person, named. The screen this replaced put the agent's name
          // in a map tooltip and nowhere else, so a manager who could not
          // hover had no way to tell three identical "1" pins apart.
          PersonRow(
            key: ValueKey<String>('trail-agent-${agent.agentId}'),
            name: agent.name,
            role: 'Field agent',
            outlet: agent.currentOutletName,
            trailingWord: count,
            separator: SoftRowSeparator.auto,
          ),
          for (var i = 0; i < stops.length; i++)
            _StopRow(
              key: ValueKey<String>('trail-stop-${agent.agentId}-$i'),
              stop: stops[i],
              ordinal: i + 1,
              isLast: i == stops.length - 1,
              endOfList: i == stops.length - 1,
            ),
        ],
      ),
    );
  }
}

/// One confirmed check-in, as a row.
///
/// The ordinal leads the title because the sequence is what the trail is
/// about, and it is the same numeral the pin carries — a manager reading the
/// map and a manager reading the list are reading the same thing.
class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.stop,
    required this.ordinal,
    required this.isLast,
    required this.endOfList,
  });

  final AgentStop stop;
  final int ordinal;

  /// The agent's last stop of the day: where they ended up.
  final bool isLast;

  final bool endOfList;

  @override
  Widget build(BuildContext context) {
    final numbers = TiqNumber.of(context);
    final time = trailStopTime(stop.checkinTs);
    final place = '${numbers.format(ordinal)}. ${stop.outletName}';
    // "Where they ended up" is a word, not a hue and not a glow. An
    // in-progress visit says so too: a check-in without a submit is not a
    // finished visit and the list must not read as though it were.
    final word = stop.inProgress
        ? 'Still in this shop'
        : (isLast ? 'Last stop' : null);

    return SoftRow(
      density: SoftRowDensity.compact,
      title: place,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: word,
      trailing: Text(
        time,
        textAlign: TextAlign.end,
        style: context.skin.text.figureS.style(
          color: context.skin.palette.ink2,
        ),
      ),
      separator: endOfList ? SoftRowSeparator.none : SoftRowSeparator.auto,
      // Every stop is a confirmed visit, so a tap opens it for review (#208).
      onTap: () => context.push('/visits/${stop.visitId}'),
      semanticsLabel: <String?>[
        place,
        word,
        'checked in at $time',
      ].whereType<String>().join(', '),
    );
  }
}
