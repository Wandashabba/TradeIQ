import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_kit.dart' show formatAgo;
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/gamification_repository.dart';

/// "HOW DID THEY EARN THESE?" — one agent's points ledger (#124).
///
/// ```text
///   Sipho Ndlovu                            [ ⟳ ]
///   Field agent · Rank 2
///   Back to the leaderboard
///   ┌────────────────────────────────────────┐
///   │ POINTS EARNED                    94 pts│
///   ├────────────────────────────────────────┤
///   │ AVERAGE SCORECARD                    85│
///   │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▌                    │
///   └────────────────────────────────────────┘
///   12 visits submitted · 3 tasks closed
///   ── Ledger ─────────────────────────── 20 ──
///   Visit submitted                     +2 pts
///   Kasi Corner Spaza                      2 h
///   …
///   [ nav pill ]
/// ```
///
/// ## The two figures are in different units, and the screen says so
///
/// `points` is `mean(scorecard) + 5 × tasks + 2 × visits` — a 0–100 mean added
/// to two counts. The average is a 0–100 mean on its own. Put side by side
/// with no separation they read as a pair; the cluster's rule between the
/// cells and the two different eyebrows are what stop that, and the average
/// carries the meter that makes its scale visible while the payout does not.
///
/// ## The average is unknown when nobody has scored them
///
/// `mean([])` is 0 on the wire, so `avgScorecard: 0` used to mean both "this
/// agent scored nothing" and "nobody has scored this agent". `scorecardsCounted`
/// separates them: zero scorecards renders the em dash and the sentence, one
/// or two greys the figure and says how thin it is (an average needs n ≥ 3),
/// and three or more is a figure at full commitment.
///
/// ## The one amber, counted
///
/// Nothing on a ledger is armed, so this route nominates no content amber. In
/// Night the nav's active tab is the only lit object; Day and Veld paint zero.
class AgentPointsScreen extends ConsumerWidget {
  const AgentPointsScreen({super.key, required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(agentPointsProvider(agentId));
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    // The board is a base layer and never a blocker: it carries the standing
    // this agent's ledger adds up to, and a slow or failed board must not take
    // their history down with it. Absent, the figures simply do not render —
    // never a zero standing in of a number nobody fetched.
    final standing = ref
        .watch(leaderboardProvider)
        .maybeWhen(
          data: (list) {
            for (final e in list) {
              if (e.agentId == agentId) return e;
            }
            return null;
          },
          orElse: () => null,
        );

    void refresh() {
      ref.invalidate(agentPointsProvider(agentId));
      ref.invalidate(leaderboardProvider);
    }

    void back() => canPop ? context.pop() : context.go('/leaderboard');

    Widget frame({
      required String phase,
      required String title,
      required List<String> facts,
      required List<Widget> children,
    }) => ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: title,
        facts: facts,
        trailing: TorchIconButton(
          key: const ValueKey<String>('points-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh this points history',
          onPressed: refresh,
        ),
      ),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('points-back-to-leaderboard'),
            label: 'Back to the leaderboard',
            onPressed: back,
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        ...children,
      ],
    );

    return history.when(
      loading: () => frame(
        phase: 'loading',
        title: 'Points history',
        facts: const <String>[],
        children: <Widget>[
          Skeleton(
            label: 'this points history',
            child: const SkeletonRows(count: 5, rowHeight: 64),
          ),
        ],
      ),
      error: (error, stack) => frame(
        phase: 'error',
        title: 'Points history',
        facts: const <String>[],
        children: <Widget>[
          TorchErrorRegion(
            name: 'points history',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('points-retry'),
                label: 'Try again',
                onPressed: refresh,
              ),
            ),
          ),
        ],
      ),
      data: (h) {
        final entries = h.entries;
        return frame(
          phase: entries.isEmpty ? 'empty' : 'loaded',
          // The person is the title. The screen used to be called "Points
          // history" with the agent's name buried in a panel heading, which is
          // the same failure as a UUID in a row: the reader has to work out
          // whose record they opened.
          title: h.label,
          facts: <String>[
            'Field agent',
            if (standing?.rank != null) 'Rank ${standing!.rank}',
            if (standing != null && standing.rank == null) 'Not ranked yet',
          ],
          children: <Widget>[
            if (standing != null) ...<Widget>[
              _Standing(entry: standing),
              const SizedBox(height: TiqSpace.s7),
            ],
            SectionRule(
              'Ledger',
              count: entries.isEmpty ? null : entries.length,
              emptyLine: entries.isEmpty ? 'Nothing recorded yet.' : null,
            ),
            const SizedBox(height: TiqSpace.s5),
            if (entries.isEmpty)
              const EmptyState(
                key: ValueKey<String>('points-empty'),
                scope: EmptyScope.inPanel,
                headline: 'No points yet.',
                body: 'Entries appear as this agent submits visits, closes '
                    'tasks and is scored.',
              )
            else
              _Ledger(entries: entries, hasMore: h.nextCursor != null),
          ],
        );
      },
    );
  }
}

/// What the ledger adds up to: the payout, and the average it contains.
class _Standing extends StatelessWidget {
  const _Standing({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final scored = entry.scorecardsCounted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StatCluster(
          semanticsLabel: 'Two figures for ${entry.label}.',
          tiles: <StatTile>[
            StatTile(
              key: const ValueKey<String>('points-total'),
              eyebrow: 'Points earned',
              // The board refuses to print this number for an unranked agent
              // and so does this screen: `points` is 0 for them because the
              // window holds no ledger entry at all, which is an absence and
              // not a payout of nought. Both screens read the one decision on
              // the entry rather than each making their own (#464).
              value: entry.measuredPoints,
              decimals: 0,
              unit: TiqUnit.worded('pts'),
              noDataReason: entry.payoutIsMeasured
                  ? null
                  : LeaderboardEntry.payoutAbsentReason,
              // A payout has no 0–100 scale, so it gets no meter. The average
              // beneath it does, and the difference is the point.
              stateLine: entry.payoutIsMeasured
                  ? 'The average scorecard, plus 5 a closed task and 2 a '
                        'submitted visit.'
                  : null,
            ),
            StatTile(
              key: const ValueKey<String>('points-average'),
              eyebrow: 'Average scorecard',
              // mean([]) is 0 on the wire. Zero scorecards is an absence, not
              // a score of nought, and the two must not render alike.
              value: scored == 0 ? null : entry.avgScorecard,
              decimals: 1,
              noDataReason: scored == 0
                  ? 'No scored visit in this window.'
                  : null,
              sampling: FigureSampling(
                kind: MetricKind.average,
                n: scored,
              ),
              meter: scored == 0
                  ? const MeterData(value: null)
                  : MeterData(value: entry.avgScorecard),
            ),
          ],
        ),
        const SizedBox(height: TiqSpace.s4),
        Text(
          '${numbers.format(entry.visitsSubmitted)} visits submitted · '
          '${numbers.format(entry.tasksClosed)} tasks closed',
          key: const ValueKey<String>('points-counts'),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.entries, required this.hasMore});

  final List<PointsEntry> entries;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final gutter = context.skin.space.gutter;
    final numbers = TiqNumber.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < entries.length; i++)
                PointsEntryRow(
                  key: ValueKey<String>('points-entry-${entries[i].id}'),
                  entry: entries[i],
                  last: i == entries.length - 1,
                ),
            ],
          ),
        ),
        if (hasMore) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter * 2,
            child: PaginationFooter(
              key: const ValueKey<String>('points-footer'),
              summary: 'Showing the '
                  '${numbers.format(entries.length)} newest entries. '
                  'There are more.',
            ),
          ),
        ],
      ],
    );
  }
}

/// One ledger entry: what was rewarded, what it contributed, where, and when.
///
/// The row carries no severity and no hue. An entry is a record of something
/// that happened, not a judgement of it — a scorecard of 41 is not a crimson
/// row, it is a number the agent can go and read.
class PointsEntryRow extends StatelessWidget {
  const PointsEntryRow({
    super.key,
    required this.entry,
    this.last = false,
  });

  final PointsEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final when = formatAgo(entry.occurredAt);
    // A scorecard entry earns no points of its own — the board averages the
    // score — so the figure it shows is the score that feeds that average,
    // and it is not a signed payout.
    final isScorecard = entry.reason == 'scorecard' && entry.score != null;
    final value = isScorecard ? entry.score! : entry.points;
    final unit = isScorecard
        ? TiqUnit.none
        : TiqUnit.worded('pts');
    final spoken = isScorecard
        ? 'scored ${numbers.format(entry.score!)}'
        : '${numbers.format(entry.points, signed: true)} points';

    return SoftRow(
      density: SoftRowDensity.standard,
      title: entry.reasonLabel,
      subtitle: entry.outletName,
      meta: Text(when),
      trailing: FigureSlot(
        value: value,
        role: skin.text.figureS,
        decimals: isScorecard ? 1 : 0,
        signed: !isScorecard,
        unit: unit,
        textAlign: TextAlign.end,
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      // The row is one node and excludes what is under it, so the figure and
      // the age are spelled here or they are never spoken.
      semanticsLabel: <String?>[
        entry.reasonLabel,
        spoken,
        entry.outletName,
        when,
      ].whereType<String>().join(', '),
    );
  }
}
