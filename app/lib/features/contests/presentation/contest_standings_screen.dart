import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/format/person_label.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/contests_repository.dart';
import 'contest_labels.dart';

/// ONE CONTEST'S STANDINGS, for a manager (#124).
///
/// ```text
///   Spring push                          [ Active ]
///   Active · 3 days left
///   ── The contest ───────────────────────────────
///   Dates      2026-09-01 → 2026-09-30 (inclusive)
///   Prize      R500 voucher for first place
///   ── Ranked                                  9 ──
///   [TM] Thandi Mokoena                        1
///        Field agent · 4 visits · 2 tasks    240
///   …
/// ```
///
/// ## Rank is the ordering, so it is the only thing ranked
///
/// The rows wear one hue. A leaderboard that colours its top three has decided
/// something about the bottom three that nobody measured, and equal points
/// share a rank here — so a podium would be a lie about ties as well.
///
/// The rank itself is the row's trailing **figure**, in mono through
/// [FigureSlot], and it is announced as part of the row's one sentence — a
/// figure in a trailing slot is inside the row's excluded label and would
/// otherwise be painted and said nowhere, which is why [PersonRow] takes a
/// `trailingLabel`.
///
/// ## Unknown versus zero
///
/// A standing with zero points renders `0` and keeps its place: an active
/// agent who has earned nothing is a fact a manager needs, and dropping them
/// would make the board a list of winners. There is no null here — the server
/// sends every agent in scope — so no em dash and no invented total.
///
/// ## The amber, counted
///
/// A tab root under the Menu, so Night paints the nav's active tab and nothing
/// else: no primary, no plate, no chart focus. Day and Veld paint zero.
class ContestStandingsScreen extends ConsumerWidget {
  const ContestStandingsScreen({super.key, required this.contestId});

  final String contestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standings = ref.watch(contestStandingsProvider(contestId));

    return standings.when(
      loading: () => _frame(
        context,
        phase: 'loading',
        title: 'Contest standings',
        children: <Widget>[
          Skeleton(
            label: 'standings',
            child: const SkeletonRows(count: 5, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        phase: 'error',
        title: 'Contest standings',
        children: <Widget>[
          TorchErrorRegion(
            name: 'standings',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('standings-retry'),
                label: 'Try again',
                onPressed: () =>
                    ref.invalidate(contestStandingsProvider(contestId)),
              ),
            ),
          ),
        ],
      ),
      data: (s) => _loaded(context, s),
    );
  }

  Widget _frame(
    BuildContext context, {
    required String phase,
    required String title,
    List<String> facts = const <String>[],
    List<Widget> flagChips = const <Widget>[],
    required List<Widget> children,
  }) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: title,
        facts: facts,
        // Names where it goes, never just "Back".
        back: TorchIconButton(
          key: const ValueKey<String>('standings-back-to-contests'),
          icon: Icons.arrow_back,
          semanticLabel: 'Back to Contests',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/contests'),
        ),
        flagChips: flagChips,
      ),
      children: children,
    );
  }

  Widget _loaded(BuildContext context, ContestStandings s) {
    final c = s.contest;
    final rows = s.standings;
    final gutter = context.skin.space.gutter;
    final statusWord = contestStatusWord(c.status);

    return _frame(
      context,
      phase: rows.isEmpty ? 'empty' : 'loaded',
      title: c.name,
      facts: <String>[statusWord, contestWhenSummary(c)],
      flagChips: <Widget>[
        StatusChip(
          key: const ValueKey<String>('standings-status'),
          level: contestLevel(c.status),
          label: statusWord,
        ),
      ],
      children: <Widget>[
        SectionRule('The contest'),
        const SizedBox(height: TiqSpace.s5),
        if (c.description != null) ...<Widget>[
          Text(
            c.description!,
            style: context.skin.text.body.style(
              color: context.skin.palette.ink2,
            ),
          ),
          const SizedBox(height: TiqSpace.s5),
        ],
        _Fact('Dates', '${c.startDate} → ${c.endDate} (inclusive)'),
        // Never invented: a contest with no prize says so in words rather than
        // showing a blank a manager would read as "loading".
        _Fact('Prize', c.prizeDescription ?? 'None set'),
        _Fact('Territory', contestScopeSummary(c)),
        _Fact('Counts', contestCountsSummary(c)),

        const SizedBox(height: TiqSpace.s7),
        SectionRule('Ranked', count: rows.isEmpty ? null : s.participantCount),
        const SizedBox(height: TiqSpace.s5),
        if (rows.isEmpty)
          const EmptyState(
            key: ValueKey<String>('standings-empty'),
            scope: EmptyScope.inPanel,
            headline: 'Nobody on the board.',
            body:
                'Active field agents in scope appear here, even before they '
                'earn points.',
          )
        else ...<Widget>[
          Text(
            'Ranked by points in the window · equal points share a rank',
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
          const SizedBox(height: TiqSpace.s4),
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < rows.length; i++)
                  _StandingRow(
                    key: ValueKey<String>('standing-${rows[i].agentId}'),
                    standing: rows[i],
                    last: i == rows.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One fact about the contest: the label, then the value.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: TiqSpace.s3),
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

/// One agent's standing. A row names a person, never a database id.
class _StandingRow extends StatelessWidget {
  const _StandingRow({super.key, required this.standing, required this.last});

  final ContestStanding standing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final s = standing;
    final numbers = TiqNumber.of(context);
    final name = nonBlankName(s.displayName);
    final work =
        '${numbers.format(s.visitsSubmitted)} visits · '
        '${numbers.format(s.tasksClosed)} tasks closed';
    final points = numbers.format(s.points, decimals: 0);

    return PersonRow(
      // Named, the name is the title and "Field agent · …" the reason line.
      // Unnamed, the sign-in address is the identifier line — never a UUID.
      name: name,
      role: 'Field agent',
      outlet: work,
      identifier: name == null ? s.email : null,
      identifierLabel: name == null ? 'Signed in as' : null,
      // The rank is the ordering and the points are the reason for it: both
      // in mono, the rank above so a column of them reads down the edge.
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FigureSlot(
            value: s.rank,
            role: skin.text.figureM,
            color: skin.palette.ink1,
            textAlign: TextAlign.end,
          ),
          FigureSlot(
            value: s.points,
            decimals: 0,
            role: skin.text.figureS,
            color: skin.palette.ink3,
            textAlign: TextAlign.end,
          ),
        ],
      ),
      trailingLabel: 'Rank ${numbers.format(s.rank)}, $points points',
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
    );
  }
}
