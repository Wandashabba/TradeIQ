import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/format/person_label.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/contests_repository.dart';

/// THE AGENT'S CONTESTS VIEW (#124): what is running, how long is left, what
/// the prize is, where they stand, and the top of the board.
///
/// ```text
///   Kompetisies                                  ‹
///   ── Lente-stoot ──────────────────────────────
///   1 Okt – 30 Okt                      [• Loop]
///   Prys      R500-geskenkbewys
///   ┌─────────────────┬─────────────────────────┐
///   │ JOU POSISIE   3 │ JOU PUNTE           240 │
///   │ uit 9 agente    │                         │
///   └─────────────────┴─────────────────────────┘
///   ── Ranglys ──────────────────────────────────
///   [TM] Thandi Mokoena                 1 · 320
///   [JY] Jy                             3 · 240
///   [ ☾ ]
/// ```
///
/// ## Agent-safe, and that is not incidental
///
/// `/contests/*` is the manager console's route and the server answers an
/// agent 403 on every one of them. This screen reads `GET /contests/current`,
/// which is the agent's own endpoint, and it is reached from the agent's own
/// record at `/leaderboard/contests`. Nothing on it links into the console.
///
/// ## Unknown versus zero
///
/// An agent who is on the board with nought points renders **0** and keeps
/// their place — it is a measured fact about a week, and hiding it would make
/// the board a list of winners. An agent who is *not on the board at all* has
/// no rank, so the tile renders an **em dash** with the unit suppressed, no
/// delta, and the sentence that says why. A rank is never invented.
///
/// ## The amber, counted
///
/// Pushed, so no nav and no tab: Night has two content grants and Day and Veld
/// have one. This screen declares **none of them**. Nothing here is a commit —
/// a contest is something an agent reads, and the running chip is a `live` dot
/// and a word, which is a label. Night, Day and Veld all paint **zero**.
class MyContestsScreen extends ConsumerWidget {
  const MyContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TorchlightRoute(child: _MyContests());
  }
}

class _MyContests extends ConsumerWidget {
  const _MyContests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contests = ref.watch(currentContestsProvider);

    return contests.when(
      loading: () => _MyContestsFrame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.contestsTitle,
            child: const SkeletonRows(count: 3, rowHeight: 96),
          ),
        ],
      ),
      error: (error, stack) => _MyContestsFrame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'contests',
            child: ErrorState(
              key: const ValueKey<String>('contests-error'),
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.contestsLoadError,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('contests-retry'),
                label: l10n.contestsRetry,
                onPressed: () => ref.invalidate(currentContestsProvider),
              ),
            ),
          ),
        ],
      ),
      data: (list) {
        final active = <CurrentContest>[
          for (final c in list)
            if (c.contest.isActive) c,
        ];
        final ended = <CurrentContest>[
          for (final c in list)
            if (c.contest.isEnded) c,
        ];

        if (active.isEmpty && ended.isEmpty) {
          return _MyContestsFrame(
            phase: 'empty',
            children: <Widget>[
              EmptyState(
                key: const ValueKey<String>('contests-empty'),
                drawing: EmptyDrawing.shelf,
                headline: l10n.contestsEmptyTitle,
                body: l10n.contestsEmptyBody,
              ),
            ],
          );
        }

        return _MyContestsFrame(
          phase: 'loaded',
          children: <Widget>[
            for (final entry in <(String, List<CurrentContest>)>[
              (l10n.contestsActiveHeading, active),
              (l10n.contestsEndedHeading, ended),
            ])
              if (entry.$2.isNotEmpty) ...<Widget>[
                SectionRule(entry.$1),
                const SizedBox(height: TiqSpace.s5),
                for (final c in entry.$2) _ContestBlock(entry: c),
              ],
          ],
        );
      },
    );
  }
}

/// The frame every state of this route wears.
class _MyContestsFrame extends ConsumerWidget {
  const _MyContestsFrame({required this.phase, required this.children});

  final String phase;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canPop = context.canPop();

    return TorchScope(
      skin: context.skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      // Nothing on this route is armed. A contest is something to read.
      claims: const <TorchClaim>[],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: l10n.contestsTitle,
          facts: <String>[l10n.contestsSubtitle],
          back: TorchIconButton(
            key: const ValueKey<String>('contests-back'),
            icon: Icons.arrow_back,
            // A destination, never "Back". Only a deep link has nothing to
            // pop, and then it is Today — which the router resolves per role.
            semanticLabel: canPop
                ? l10n.contestsBackToMe
                : l10n.contestsBackToToday,
            onPressed: () => canPop ? context.pop() : context.go('/today'),
          ),
        ),
        // Not a tab root, so the cycle sits at the leading end of the bottom
        // zone. Never a screen without it.
        skinCycle: const AgentSkinCycle(),
        children: children,
      ),
    );
  }
}

/// One contest: what it is, where the agent stands, and the top of the board.
class _ContestBlock extends StatelessWidget {
  const _ContestBlock({required this.entry});

  final CurrentContest entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final c = entry.contest;
    final me = entry.me;
    final numbers = TiqNumber.of(context);

    final counts = c.eventTypes.isEmpty
        ? l10n.contestEventAll
        : c.eventTypes
              .map(
                (type) => switch (type) {
                  'visit_submitted' => l10n.contestEventVisitSubmitted,
                  'task_closed' => l10n.contestEventTaskClosed,
                  'scorecard' => l10n.contestEventScorecard,
                  _ => type,
                },
              )
              .join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: skin.space.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The contest's own name is the section marker: knocked out of a
          // rule at title.m, sentence case — never an uppercase kicker.
          SectionRule(c.name),
          const SizedBox(height: TiqSpace.s4),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.contestDateRange(
                    _shortDay(context, c.startDate),
                    _shortDay(context, c.endDate),
                  ),
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
              ),
              const SizedBox(width: TiqSpace.s3),
              // Hue, silhouette and word in one token. A running contest is
              // `live`; one that has finished is Oatmeal and a square — never
              // a severity, because ending is not a fault.
              StatusChip(
                key: ValueKey<String>('contest-when-${c.id}'),
                level: c.isActive ? StatusLevel.live : StatusLevel.held,
                label: c.isActive
                    ? l10n.contestDaysLeft(c.daysLeft ?? 0)
                    : l10n.contestEnded,
              ),
            ],
          ),

          if (c.description != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s4),
            Text(
              c.description!,
              style: skin.text.body.style(color: skin.palette.ink1),
            ),
          ],

          const SizedBox(height: TiqSpace.s4),
          if (c.prizeDescription != null)
            _Labelled(
              key: ValueKey<String>('contest-prize-${c.id}'),
              label: l10n.contestPrizeLabel,
              value: c.prizeDescription!,
            ),
          _Labelled(label: l10n.contestCountsLabel, value: counts),

          const SizedBox(height: TiqSpace.s5),
          // WHERE THE AGENT STANDS. No rank is ever invented: an agent who is
          // not on this board gets an em dash, the unit suppressed and the
          // sentence that says why — in both tiles, because "0 points and no
          // rank" would be two different claims about the same absence.
          StatCluster(
            key: ValueKey<String>('contest-me-${c.id}'),
            semanticsLabel: l10n.contestStandingsHeading,
            tiles: <StatTile>[
              StatTile(
                eyebrow: l10n.contestRankEyebrow,
                value: me?.rank,
                noDataReason: me == null ? l10n.contestNotRanked : null,
                stateLine: me == null
                    ? null
                    : l10n.contestRankOutOf(entry.participantCount),
              ),
              StatTile(
                eyebrow: l10n.contestPointsEyebrow,
                value: me?.points,
                noDataReason: me == null ? l10n.contestNotRanked : null,
              ),
            ],
          ),

          const SizedBox(height: TiqSpace.s5),
          SectionRule(
            l10n.contestStandingsHeading,
            count: entry.standings.isEmpty ? null : entry.participantCount,
            emptyLine: entry.standings.isEmpty
                ? l10n.contestNobodyRanked
                : null,
          ),
          if (entry.standings.isNotEmpty) ...<Widget>[
            const SizedBox(height: TiqSpace.s4),
            TorchBleed(
              extra: skin.space.gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < entry.standings.length; i++)
                    _StandingRow(
                      key: ValueKey<String>(
                        'contest-standing-${c.id}-'
                        '${entry.standings[i].agentId}',
                      ),
                      standing: entry.standings[i],
                      isMe: entry.standings[i].agentId == me?.agentId,
                      last: i == entry.standings.length - 1,
                      numbers: numbers,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "1 Oct" in the active locale; falls back to en_US when intl has no symbols
/// loaded for it (a bare test app), as `formatDayHeading` does.
String _shortDay(BuildContext context, String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  try {
    return DateFormat('d MMM', context.l10n.localeName).format(date);
  } on Exception {
    return DateFormat('d MMM', 'en_US').format(date);
  }
}

/// One fact about the contest: the label, then the value.
class _Labelled extends StatelessWidget {
  const _Labelled({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: TiqSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Text(
              value,
              style: skin.text.body.style(color: skin.palette.ink1),
            ),
          ),
        ],
      ),
    );
  }
}

/// One agent on the board. The agent's own row carries the word "You" — never
/// a colour, and never only a weight.
class _StandingRow extends StatelessWidget {
  const _StandingRow({
    super.key,
    required this.standing,
    required this.isMe,
    required this.last,
    required this.numbers,
  });

  final ContestStanding standing;
  final bool isMe;
  final bool last;
  final TiqNumber numbers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final s = standing;
    final name = nonBlankName(s.displayName);
    final points = numbers.format(s.points);
    final rank = numbers.format(s.rank);

    return PersonRow(
      density: SoftRowDensity.compact,
      name: name,
      // The agent's own row says so in a word. A leaderboard that marked it
      // with a tint alone would lose it in greyscale, in glare and to a
      // screen reader — which is the one reader who cannot scan for it.
      role: isMe ? l10n.contestYouTag : null,
      // No display name and not the reader's own row: the sign-in address is
      // all there is, and it becomes the title rather than a blank.
      unknownLabel: s.email,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            rank,
            style: skin.text.figureS.style(color: skin.palette.ink3),
          ),
          const SizedBox(width: TiqSpace.s3),
          Text(
            l10n.contestPoints(points),
            style: skin.text.figureS.style(color: skin.palette.ink1),
          ),
        ],
      ),
      trailingLabel: '$rank · ${l10n.contestPoints(points)}',
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
    );
  }
}
