import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/gamification_repository.dart';

/// A ranking, not a triage queue. Rank is already an ordering, so the rows wear
/// one hue: colouring first place green and last place red would say an agent
/// is *failing* when all the data says is that someone else scored more.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider);

    return ManagerScaffold(
      title: 'Leaderboard',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Points accrue from submitted visits and closed tasks.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<LeaderboardEntry>>(
            value: leaderboard,
            label: 'leaderboard',
            onRetry: () => ref.invalidate(leaderboardProvider),
            builder: (list) {
              final ranked = [...list]..sort((a, b) => a.rank.compareTo(b.rank));
              return _LeaderboardList(entries: ranked);
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${entries.length} ${entries.length == 1 ? 'agent' : 'agents'}',
      subtitle: 'Ranked by points',
      padded: false,
      child: entries.isEmpty
          ? const EmptyState(
              message: 'Nobody ranked yet',
              hint: 'Agents appear here once they submit their first visit.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final e in entries) _LeaderboardRow(entry: e)],
            ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return WorklistRow(
      key: ValueKey('leaderboard-${entry.agentId}'),
      title: entry.email,
      meta: Text(
        '${entry.points.toStringAsFixed(0)} pts · '
        '${entry.visitsSubmitted} visits · '
        '${entry.tasksClosed} tasks closed',
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      // One hue for every rank — position is the ranking, colour would only
      // restate it as a judgement.
      level: StatusLevel.neutral,
      statusLabel: 'Rank ${entry.rank}',
    );
  }
}
