import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/contests_repository.dart';
import 'contest_labels.dart';

/// One contest's full standings, for a manager (#124). Like the leaderboard
/// the rows wear one hue: rank is already the ordering.
class ContestStandingsScreen extends ConsumerWidget {
  const ContestStandingsScreen({super.key, required this.contestId});

  final String contestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standings = ref.watch(contestStandingsProvider(contestId));
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    return ManagerScaffold(
      title: 'Contest standings',
      actions: [
        TextButton(
          key: const ValueKey<String>('standings-back-to-contests'),
          onPressed: () => canPop ? context.pop() : context.go('/contests'),
          child: const Text('Contests'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<ContestStandings>(
            value: standings,
            label: 'standings',
            onRetry: () => ref.invalidate(contestStandingsProvider(contestId)),
            builder: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ContestSummary(contest: s.contest),
                const SizedBox(height: 14),
                _StandingsPanel(standings: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestSummary extends StatelessWidget {
  const _ContestSummary({required this.contest});

  final Contest contest;

  @override
  Widget build(BuildContext context) {
    final c = contest;
    return PanelCard(
      title: c.name,
      subtitle: '${contestStatusWord(c.status)} · ${contestWhenSummary(c)}',
      trailing: StatusChip(
        label: contestStatusWord(c.status),
        level: contestLevel(c.status),
      ),
      child: Column(
        key: ValueKey<String>('contest-summary-${c.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.description != null) ...[
            Text(c.description!, style: TextStyle(color: context.colors.ink2)),
            const SizedBox(height: 10),
          ],
          _Fact('Dates', '${c.startDate} → ${c.endDate} (inclusive)'),
          _Fact('Prize', c.prizeDescription ?? 'None set'),
          _Fact('Territory', contestScopeSummary(c)),
          _Fact('Counts', contestCountsSummary(c)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: colors.ink3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: colors.ink1),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingsPanel extends StatelessWidget {
  const _StandingsPanel({required this.standings});

  final ContestStandings standings;

  @override
  Widget build(BuildContext context) {
    final rows = standings.standings;
    final count = standings.participantCount;
    return PanelCard(
      title: '$count ${count == 1 ? 'agent' : 'agents'}',
      subtitle: 'Ranked by points in the window · equal points share a rank',
      padded: false,
      child: rows.isEmpty
          ? const EmptyState(
              message: 'Nobody on the board',
              hint: 'Active field agents in scope appear here, even before '
                  'they earn points.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in rows)
                  WorklistRow(
                    key: ValueKey<String>('standing-${s.agentId}'),
                    title: s.label,
                    meta: Text(
                      '${s.pointsFigure} pts · ${s.visitsSubmitted} visits · '
                      '${s.tasksClosed} tasks closed',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      // Figures compare down the column in glass's mono; null
                      // keeps the row's own meta style in dark.
                      style: context.colors.glass
                          ? const TextStyle(
                              fontFamily: LumenGlass.mono,
                              fontFeatures: [FontFeature.tabularFigures()],
                            )
                          : null,
                    ),
                    level: StatusLevel.neutral,
                    statusLabel: 'Rank ${s.rank}',
                  ),
              ],
            ),
    );
  }
}
