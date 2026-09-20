import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/figure_slot.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/gamification_repository.dart';
import '../data/leaderboard_view.dart';

/// LEADERBOARD — a ranking of people, so every row names one.
///
/// ```text
///   Leaderboard                                   [ ⟳ ]
///   Points: the average scorecard, plus 5 a closed
///   task and 2 a submitted visit.
///   Contests
///   ── Ranked ─────────────────────────────── 3 ──
///   ┌──┐
///   │TM│ Thandi Mokoena              Rank 1
///   └──┘ Field agent                  94 pts
///   ┌──┐
///   │BD│ Busi Dlamini                Rank 2
///   └──┘ Field agent                  62 pts
///   ── Not ranked yet ─────────────────────── 2 ──
///   Nothing measured for these agents in this
///   window. They are not last — nobody has
///   measured them.
///   ┌──┐
///   │SN│ Sipho Ndlovu           Not ranked yet
///   └──┘ Field agent
///   [ nav pill ]
/// ```
///
/// ## Why the name is the title and the id is nowhere
///
/// The board before this one printed `entry.label` into a generic worklist row
/// and the figures into a mono meta line. [PersonRow] makes the two rules
/// explicit: initials on a tile (never a photograph — POPIA), the full name as
/// the title, middle-truncated so "Dlamini-Mkhize" and "Dlamini-Ndlovu" are
/// still two different people on a 200dp row, and no database id anywhere.
///
/// ## Unranked is not last (#398)
///
/// An agent with no submitted visit, no closed task and no scorecard in the
/// window has `rank: null` on the wire and sits in its own section here. Last
/// place is a comparison against people they were never measured beside; the
/// board used to compute it from the length of the list and an agent read it
/// as a verdict. They are still listed — an agent missing from a board reads
/// as an agent who left — and the section says in words what the absence is.
///
/// ## The payout is on the board; the 0–100 average is not
///
/// `points` is `mean(scorecard) + 5 × tasks + 2 × visits`, so it is a mean and
/// two counts added together. Printing `94 pts` beside `85` would read as a
/// fraction of something. The average, with the sample size that makes it
/// believable, is on the agent's own ledger one tap away.
///
/// ## The one amber, counted
///
/// A tab root, so Night's budget is two and the nav's active tab is slot 1.
/// This route nominates **no content amber**: a ranking has nothing armed, no
/// commit action and no chart focus. Day and Veld paint zero — their one rung
/// is the primary commit block, and there is none here.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  /// Contests (#124). An agent opens their own view; a manager goes to the
  /// console where contests are run. The role is read on tap, not watched:
  /// the board itself does not depend on who is looking.
  static void _openContests(BuildContext context, WidgetRef ref) {
    final role = ref.read(sessionControllerProvider).value?.role;
    if (role == 'field_agent') {
      context.push('/leaderboard/contests');
    } else {
      context.go('/contests');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);
    void refresh() => ref.invalidate(leaderboardProvider);

    Widget frame({required String phase, required List<Widget> children}) =>
        ConsoleFrame(
          phase: phase,
          active: ConsoleSlot.menu,
          header: TorchAppHeader(
            title: 'Leaderboard',
            facts: const <String>[
              'Points: the average scorecard, plus 5 a closed task and 2 a '
                  'submitted visit.',
            ],
            trailing: TorchIconButton(
              key: const ValueKey<String>('leaderboard-refresh'),
              icon: Icons.refresh,
              semanticLabel: 'Refresh the leaderboard',
              onPressed: refresh,
            ),
          ),
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TorchTertiaryButton(
                key: const ValueKey<String>('leaderboard-contests'),
                label: 'Contests',
                icon: Icons.emoji_events_outlined,
                onPressed: () => _openContests(context, ref),
              ),
            ),
            const SizedBox(height: TiqSpace.s6),
            ...children,
          ],
        );

    return board.when(
      loading: () => frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'the leaderboard',
            child: const SkeletonRows(count: 5, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'leaderboard',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('leaderboard-retry'),
                label: 'Try again',
                onPressed: refresh,
              ),
            ),
          ),
        ],
      ),
      data: (list) {
        final view = LeaderboardView.of(list);
        if (view.isEmpty) {
          return frame(
            phase: 'empty',
            children: const <Widget>[
              EmptyState(
                key: ValueKey<String>('leaderboard-empty'),
                scope: EmptyScope.inPanel,
                headline: 'Nobody on the board yet.',
                body:
                    'Agents appear here once there is a field agent on this '
                    'client to measure.',
              ),
            ],
          );
        }
        return frame(
          phase: view.ranked.isEmpty ? 'nobody-measured' : 'loaded',
          children: <Widget>[
            SectionRule(
              'Ranked',
              count: view.ranked.isEmpty ? null : view.ranked.length,
              emptyLine: view.ranked.isEmpty
                  ? 'Nobody has a place in this window yet.'
                  : null,
            ),
            const SizedBox(height: TiqSpace.s5),
            if (view.ranked.isNotEmpty)
              _Rows(entries: view.ranked, keyPrefix: 'leaderboard'),
            if (view.unranked.isNotEmpty) ...<Widget>[
              const SizedBox(height: TiqSpace.s7),
              SectionRule('Not ranked yet', count: view.unranked.length),
              const SizedBox(height: TiqSpace.s3),
              const _UnrankedNote(),
              const SizedBox(height: TiqSpace.s4),
              _Rows(entries: view.unranked, keyPrefix: 'leaderboard-unranked'),
            ],
          ],
        );
      },
    );
  }
}

/// Why a name is in this section, in words — because the section rule's own
/// label is three of them and this is the sentence that stops a manager
/// reading the group as a bottom.
class _UnrankedNote extends StatelessWidget {
  const _UnrankedNote();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      'Nothing measured for these agents in this window — no submitted visit, '
      'no closed task, no scorecard. They are not last; nobody has measured '
      'them.',
      key: const ValueKey<String>('leaderboard-unranked-note'),
      style: skin.text.meta.style(color: skin.palette.ink3),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.entries, required this.keyPrefix});

  final List<LeaderboardEntry> entries;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final gutter = context.skin.space.gutter;
    return TorchBleed(
      extra: gutter * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < entries.length; i++)
            _AgentRow(
              key: ValueKey<String>('$keyPrefix-${entries[i].agentId}'),
              entry: entries[i],
              last: i == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

/// One agent, named.
class _AgentRow extends StatelessWidget {
  const _AgentRow({super.key, required this.entry, required this.last});

  final LeaderboardEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final rank = entry.rank;
    final numbers = TiqNumber.of(context);
    final separator = last ? SoftRowSeparator.none : SoftRowSeparator.auto;

    // An unranked agent has no payout to show either: `points` is 0 because
    // the window holds no ledger entry at all, which is an absence and not a
    // measured nought. The word is the whole of the trailing.
    if (rank == null) {
      return PersonRow(
        name: entry.label,
        role: 'Field agent',
        trailingWord: 'Not ranked yet',
        separator: separator,
        onTap: () => context.push('/leaderboard/${entry.agentId}'),
      );
    }

    final points = numbers.format(entry.points, decimals: 0);
    return PersonRow(
      name: entry.label,
      role: 'Field agent',
      separator: separator,
      // Rank above, payout beneath — both right-aligned, the payout in mono so
      // a column of them compares. Neither is a hue: position is the ranking
      // and colouring first place green would say the last agent is failing
      // when all the data says is that somebody else scored more.
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Rank ${numbers.format(rank)}',
            textAlign: TextAlign.end,
            style: skin.text.label
                .copyWith(weight: FontWeight.w600)
                .style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s1),
          FigureSlot(
            value: entry.points,
            role: skin.text.figureS,
            decimals: 0,
            unit: TiqUnit.worded('pts'),
            textAlign: TextAlign.end,
          ),
        ],
      ),
      // The row is one semantics node and it excludes everything beneath it,
      // so the two figures above are painted and never spoken unless they are
      // spelled here.
      trailingLabel: 'Rank ${numbers.format(rank)}, $points points',
      onTap: () => context.push('/leaderboard/${entry.agentId}'),
    );
  }
}
