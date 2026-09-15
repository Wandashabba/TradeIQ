import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../l10n/l10n.dart';
import '../data/contests_repository.dart';

/// The agent's way into Contests (#124): a trophy in the Today app bar, beside
/// the language and theme controls every agent screen already carries.
///
/// When contests are running it wears their count as a badge, and its tooltip
/// (which is also its screen-reader label) says so in words. Pushed, not gone
/// to, so the Contests view's back returns to Today.
class ContestsEntryAction extends ConsumerWidget {
  const ContestsEntryAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final running = ref.watch(runningContestsCountProvider).value ?? 0;

    return IconButton(
      key: const ValueKey('today-contests'),
      tooltip: running > 0
          ? l10n.contestsRunningHint(running)
          : l10n.contestsTitle,
      onPressed: () => context.push('/leaderboard/contests'),
      icon: Badge(
        key: const ValueKey('today-contests-badge'),
        isLabelVisible: running > 0,
        label: Text('$running'),
        // The theme's action pair: the brand fill with its own legible ink,
        // in glass and flat palettes alike.
        backgroundColor: colors.action,
        textColor: colors.onAction,
        child: const Icon(Icons.emoji_events_outlined, size: 20),
      ),
    );
  }
}
