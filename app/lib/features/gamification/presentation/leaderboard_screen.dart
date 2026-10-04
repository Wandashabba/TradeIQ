import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/figure_slot.dart';
import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
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
/// commit action and no chart focus. Day paints zero — their one rung
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
    final l10n = context.l10n;
    final board = ref.watch(leaderboardProvider);
    void refresh() => ref.invalidate(leaderboardProvider);

    Widget frame({
      required String phase,
      required List<Widget> children,
      ConsoleDeskRecords? desk,
    }) => ConsoleFrame(
          phase: phase,
          // Null on the skeleton, on the error and on a board with nobody on
          // it: none of the three is a list of records, and the empty phase
          // has no filter to widen.
          desk: desk,
          header: TorchAppHeader(
            title: l10n.leaderboardTitle,
            facts: <String>[l10n.leaderboardFact],
            trailing: TorchIconButton(
              key: const ValueKey<String>('leaderboard-refresh'),
              icon: Icons.refresh,
              semanticLabel: l10n.leaderboardRefresh,
              onPressed: refresh,
            ),
          ),
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TorchTertiaryButton(
                key: const ValueKey<String>('leaderboard-contests'),
                label: l10n.leaderboardContests,
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
            label: l10n.leaderboardSkeleton,
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
                label: l10n.leaderboardRetry,
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
            children: <Widget>[
              EmptyState(
                key: const ValueKey<String>('leaderboard-empty'),
                scope: EmptyScope.inPanel,
                headline: l10n.leaderboardEmptyHeadline,
                body: l10n.leaderboardEmptyBody,
              ),
            ],
          );
        }
        final entries = <LeaderboardEntry>[...view.ranked, ...view.unranked];
        return frame(
          phase: view.ranked.isEmpty ? 'nobody-measured' : 'loaded',
          // ── WHAT THE DESK GETS, AND WHAT IT DOES NOT ─────────────────────
          //
          // **Both sections are records.** An unranked agent is still an
          // agent on this board — the whole of #398 is that they are listed
          // rather than dropped — so they are selectable here in the same
          // order the phone puts them in, ranked first.
          //
          // The rows are the same `_AgentRow` the phone draws, minus the push
          // to `/leaderboard/:agentId`, which the frame's own gesture takes
          // over: a row that opened the ledger route would replace the pane
          // the manager is reading with a full screen, which is the one thing
          // three panes exist to stop. That route is not lost — it is the
          // tertiary at the foot of the pane.
          //
          // **The ledger screen's body is NOT reused**, and that is the
          // decision worth writing down. `AgentPointsScreen` watches
          // `agentPointsProvider(agentId)`, so dropping its body into the
          // pane would make *selecting a row* fire a request — which
          // `ConsoleDeskRecord.detail` exists to prevent in as many words
          // ("selecting a record cannot refetch"). Separating a read-only
          // body out of it would not help: the fetch is the body. So the pane
          // is built from the row's own facts, which the screen already has
          // in hand, and the full ledger stays one click away.
          //
          // `Contests` is not in `lead`. It resolves to `/contests` for a
          // manager, which is a rail destination, and the rail is now where
          // destinations live — `alerts_screen.dart`'s argument for dropping
          // its own `Manage rules`. (The `/leaderboard/contests` arm is the
          // agent's, and the agent side gets no desk at all.)
          //
          // **The second section marker is not drawn.** `lead` is above the
          // whole list, and a marker belongs above the rows it counts; the
          // ranked marker's count is true of the rows it heads, and a
          // "Not ranked yet · 2" above all of them would not be. What that
          // marker carried that matters is its note, and the note is not
          // lost: it is the footer, directly under the unranked rows it is
          // about, and it is in the pane of every unranked agent as well.
          // Every unranked row already prints the words "Not ranked yet"
          // where a rank would be.
          desk: ConsoleDeskRecords(
            toolbar: ConsoleDeskToolbar.marker,
            lead: <Widget>[
              SectionRule(
                l10n.leaderboardRanked,
                listAction: true,
                count: view.ranked.isEmpty ? null : view.ranked.length,
                emptyLine: view.ranked.isEmpty
                    ? l10n.leaderboardRankedEmptyLine
                    : null,
              ),
              const SizedBox(height: TiqSpace.s5),
            ],
            footer: view.unranked.isEmpty
                ? null
                : const _UnrankedNote(key: ValueKey<String>('unranked-desk')),
            records: <ConsoleDeskRecord>[
              for (var i = 0; i < entries.length; i++)
                ConsoleDeskRecord(
                  id: entries[i].agentId,
                  row: (context, selected) => _AgentRow(
                    key: ValueKey<String>('leaderboard-${entries[i].agentId}'),
                    entry: entries[i],
                    last: i == entries.length - 1,
                    onDesk: true,
                  ),
                  detail: (context) => _AgentPane(
                    key: ValueKey<String>('agent-pane-${entries[i].agentId}'),
                    entry: entries[i],
                  ),
                ),
            ],
          ),
          children: <Widget>[
            SectionRule(
              l10n.leaderboardRanked,
              count: view.ranked.isEmpty ? null : view.ranked.length,
              emptyLine: view.ranked.isEmpty
                  ? l10n.leaderboardRankedEmptyLine
                  : null,
            ),
            const SizedBox(height: TiqSpace.s5),
            if (view.ranked.isNotEmpty)
              _Rows(
                entries: view.ranked,
                keyPrefix: 'leaderboard',
              ),
            if (view.unranked.isNotEmpty) ...<Widget>[
              const SizedBox(height: TiqSpace.s7),
              SectionRule(
                l10n.leaderboardNotRanked,
                count: view.unranked.length,
              ),
              const SizedBox(height: TiqSpace.s3),
              const _UnrankedNote(),
              const SizedBox(height: TiqSpace.s4),
              _Rows(
                entries: view.unranked,
                keyPrefix: 'leaderboard-unranked',
              ),
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
  const _UnrankedNote({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      context.l10n.leaderboardUnrankedNote,
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
    return TorchBleed(
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
  const _AgentRow({
    super.key,
    required this.entry,
    required this.last,
    this.onDesk = false,
  });

  final LeaderboardEntry entry;
  final bool last;

  /// True in the desk's list pane, where the row's tap is the **selection**
  /// and the agent's standing is already on screen in the detail pane.
  ///
  /// Pushing `/leaderboard/:agentId` from there would cover the list the
  /// manager chose from with a full screen, which is the move three panes
  /// exist to remove. So the tap goes to the frame — `_Record` in
  /// `console_desk.dart` — and the ledger route is the tertiary at the foot of
  /// the pane instead. Nothing else about the row changes: the same name, the
  /// same role, the same rank and the same payout, minus a gesture it is no
  /// longer the owner of.
  final bool onDesk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        role: l10n.roleFieldAgent,
        trailingWord: l10n.leaderboardNotRanked,
        separator: separator,
        onTap: onDesk
            ? null
            : () => context.push('/leaderboard/${entry.agentId}'),
      );
    }

    final points = numbers.format(entry.points, decimals: 0);
    return PersonRow(
      name: entry.label,
      role: l10n.roleFieldAgent,
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
            l10n.leaderboardRank(numbers.format(rank)),
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
            unit: TiqUnit.worded(l10n.pointsUnitWord),
            textAlign: TextAlign.end,
          ),
        ],
      ),
      // The row is one semantics node and it excludes everything beneath it,
      // so the two figures above are painted and never spoken unless they are
      // spelled here.
      trailingLabel: l10n.leaderboardRowTrailing(numbers.format(rank), points),
      onTap: onDesk
          ? null
          : () => context.push('/leaderboard/${entry.agentId}'),
    );
  }
}

/// ── ONE AGENT'S STANDING, IN THE DETAIL PANE ───────────────────────────
///
/// The row's own four facts — who, their role, their place and their payout —
/// at the pane's width, with the ledger route at the foot.
///
/// It reads **nothing new**. Every value here comes off the
/// [LeaderboardEntry] the list was already holding, through the same
/// `TiqNumber` call the row's own `FigureSlot` resolves, so the pane and the
/// row cannot print two different payouts for one agent. In particular the
/// payout is read through [LeaderboardEntry.payoutIsMeasured] rather than
/// re-decided here: `points` is 0 for an unranked agent because the window
/// holds no ledger entry at all, and that absence must not render as a
/// measured nought on a third screen (#464).
class _AgentPane extends StatelessWidget {
  const _AgentPane({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final rank = entry.rank;

    return ConsoleRecordDetail(
      title: entry.label,
      // The row's own trailing word: their place, or the words that say there
      // is not one.
      kicker: Text(
        rank == null
            ? l10n.leaderboardNotRanked
            : l10n.leaderboardRank(numbers.format(rank)),
        style: skin.text.meta.style(color: skin.palette.ink3),
      ),
      lede: l10n.roleFieldAgent,
      facts: <RecordFact>[
        RecordFact(
          l10n.pointsEarnedEyebrow,
          entry.payoutIsMeasured
              ? numbers.format(
                  entry.points,
                  decimals: 0,
                  unit: TiqUnit.worded(l10n.pointsUnitWord),
                )
              : l10n.pointsPayoutAbsent,
        ),
      ],
      // THE SENTENCE THE SECTION'S NOTE CARRIED, for the agent it is about.
      // The same widget the phone draws above the unranked rows: an absence
      // read as a bottom is the whole defect #398 was filed for, and a pane
      // is where there is finally room to say so in full.
      blocks: <Widget>[if (rank == null) const _UnrankedNote()],
      // The row's push, lifted — the one place the full ledger lives, and the
      // only verb this board has.
      actions: <Widget>[
        TorchTertiaryButton(
          key: ValueKey<String>('leaderboard-ledger-${entry.agentId}-pane'),
          label: l10n.pointsTitle,
          onPressed: () => context.push('/leaderboard/${entry.agentId}'),
        ),
      ],
    );
  }
}
