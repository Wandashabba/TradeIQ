import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart' show formatAgo;
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/gamification_repository.dart';

/// "How did they earn these?" — one agent's points ledger, opened from their
/// leaderboard row (#124). Each row is one event: what was rewarded, what it
/// added, when, and where. Like the leaderboard it wears one hue: an entry is a
/// record, not a judgement.
class AgentPointsScreen extends ConsumerWidget {
  const AgentPointsScreen({super.key, required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(agentPointsProvider(agentId));
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    return ManagerScaffold(
      title: 'Points history',
      actions: [
        TextButton(
          key: const ValueKey('points-back-to-leaderboard'),
          onPressed: () => canPop ? context.pop() : context.go('/leaderboard'),
          child: const Text('Leaderboard'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Points = average scorecard + 5 per closed task + 2 per submitted '
            'visit. Each entry below is one of those events.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<AgentPointsHistory>(
            value: history,
            label: 'points history',
            onRetry: () => ref.invalidate(agentPointsProvider(agentId)),
            builder: (h) => _HistoryPanel(history: h),
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.history});

  final AgentPointsHistory history;

  @override
  Widget build(BuildContext context) {
    final entries = history.entries;
    return PanelCard(
      title: history.label,
      subtitle: entries.isEmpty
          ? null
          : 'Latest ${entries.length} '
              '${entries.length == 1 ? 'entry' : 'entries'}, newest first',
      padded: false,
      child: entries.isEmpty
          ? const EmptyState(
              message: 'No points yet',
              hint: 'Entries appear as this agent submits visits, closes '
                  'tasks and is scored.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final e in entries) PointsEntryRow(entry: e)],
            ),
    );
  }
}

/// One ledger entry: the reason as the title, then the figure it contributed
/// and its source, and how long ago.
class PointsEntryRow extends StatelessWidget {
  const PointsEntryRow({super.key, required this.entry});

  final PointsEntry entry;

  @override
  Widget build(BuildContext context) {
    final id = entry.sourceId;
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    final where = entry.outletName;

    return WorklistRow(
      key: ValueKey('points-entry-${entry.id}'),
      title: entry.reasonLabel,
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The source record's id, set as a token: the thing to quote when
          // an entry is disputed.
          CodeToken(shortId),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              where == null ? entry.figure : '${entry.figure} · $where',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              // A figure first: glass sets the line in the mono so amounts
              // compare down the column. Null keeps the flat meta style.
              style: context.colors.glass
                  ? const TextStyle(
                      fontFamily: LumenGlass.mono,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )
                  : null,
            ),
          ),
        ],
      ),
      level: StatusLevel.neutral,
      when: formatAgo(entry.occurredAt),
    );
  }
}
