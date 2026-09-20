import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/lumen_glass.dart';
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
      actions: [
        // Contests (#124). An agent opens their own view; a manager goes to
        // the console where contests are run. The role is read on tap, not
        // watched: the board itself does not depend on who is looking.
        TextButton.icon(
          key: const ValueKey('leaderboard-contests'),
          icon: const Icon(Icons.emoji_events_outlined, size: 18),
          label: const Text('Contests'),
          onPressed: () {
            final role = ref.read(sessionControllerProvider).value?.role;
            if (role == 'field_agent') {
              context.push('/leaderboard/contests');
            } else {
              context.go('/contests');
            }
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Points accrue from scorecards, submitted visits and closed '
            'tasks. Tap an agent to see how they earned theirs.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<LeaderboardEntry>>(
            value: leaderboard,
            label: 'leaderboard',
            onRetry: () => ref.invalidate(leaderboardProvider),
            builder: (list) {
              final ranked = [...list]
                ..sort((a, b) => a.rank.compareTo(b.rank));
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
      title: entry.label,
      meta: Text(
        '${entry.points.toStringAsFixed(0)} pts · '
        '${entry.visitsSubmitted} visits · '
        '${entry.tasksClosed} tasks closed',
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        // A line of figures: glass sets it in the mono so ranks compare down
        // the column. Null keeps the row's own meta style in dark.
        style: context.colors.glass
            ? const TextStyle(
                fontFamily: LumenGlass.mono,
                fontFeatures: [FontFeature.tabularFigures()],
              )
            : null,
      ),
      // One hue for every rank — position is the ranking, colour would only
      // restate it as a judgement.
      level: StatusLevel.neutral,
      statusLabel: 'Rank ${entry.rank}',
      // The ledger behind the number (#124): how this agent earned it.
      onTap: () => context.push('/leaderboard/${entry.agentId}'),
    );
  }
}
