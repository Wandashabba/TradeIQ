import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import '../sync/sync_status.dart';
import '../theme/app_colors.dart';
import 'agent_kit.dart';
import 'agent_motion.dart';

/// The field agent's shell.
///
/// Deliberately not the manager's. A manager is at a desk with a mouse, so
/// their actions live top-right. An agent is standing in an aisle with one hand
/// on a shelf — so the primary action lives at the BOTTOM, where the thumb
/// already is, and nothing interactive is smaller than 48px.
class AgentScaffold extends ConsumerWidget {
  const AgentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.bottomAction,
    this.onBack,
    this.showSyncChip = true,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  /// The one primary action, pinned to the thumb zone.
  final Widget? bottomAction;

  /// Where back goes. Null on a root screen (no back arrow).
  final VoidCallback? onBack;

  /// The agent's most-asked question, answered on every screen.
  final bool showSyncChip;

  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A section is pushed as a plain route on top of the visit hub, which puts
    // it OUTSIDE the GoRoute subtree — and `GoRouterState.of` throws there. So
    // only ask GoRouter where we are when we actually need to know (to decide
    // whether this is the root screen); a screen given its own `onBack` has
    // already answered that question, and must never ask.
    final isRoot = onBack == null && _matchedLocation(context) == '/audit';

    return Scaffold(
      backgroundColor: AppColors.plane,
      appBar: AppBar(
        toolbarHeight: subtitle == null ? 56 : 64,
        leading: isRoot && onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                tooltip: 'Back',
                onPressed: onBack ?? () => context.go('/audit'),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.ink1,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.ink3),
              ),
          ],
        ),
        actions: [
          ...?actions,
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Log out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showSyncChip)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SyncChip(),
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: bottomAction == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                // Opaque, never a fade — the note explaining why an action is
                // disabled has to stay readable over whatever is scrolling
                // underneath it.
                color: AppColors.surface1,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(top: false, child: bottomAction!),
            ),
    );
  }
}

/// GoRouter's state is only reachable inside a GoRoute subtree. A pushed section
/// sits outside one, so asking is an error rather than a miss — hence the catch.
String? _matchedLocation(BuildContext context) {
  try {
    return GoRouterState.of(context).matchedLocation;
  } on Object {
    return null;
  }
}

/// "Is my work safe?" — answered wherever the agent is.
///
/// Tapping it opens the full queue. The app is offline-first, so this is not an
/// error indicator: holding work on the phone is the *normal* state in a shop
/// with no signal, and the copy says so rather than alarming anyone.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final syncing = ref.watch(syncingProvider);

    return status.maybeWhen(
      data: (s) {
        final (level, title, sub) = _describe(s, syncing);
        return PressFeedback(
          onTap: () => context.push('/my-work'),
          child: StatusBanner(
            key: const ValueKey('sync-chip'),
            level: level,
            title: title,
            subtitle: sub,
            // Breathing means "sending, right now" — never merely "pending".
            pulsing: syncing,
          ),
        );
      },
      // Never guess. If we cannot read the queue we say nothing rather than
      // claim everything is fine.
      orElse: () => const SizedBox.shrink(),
    );
  }

  static (BannerLevel, String, String) _describe(SyncStatus s, bool syncing) {
    if (syncing && s.pending.isNotEmpty) {
      final n = s.pendingCount;
      return (
        BannerLevel.info,
        'Sending $n ${n == 1 ? 'capture' : 'captures'}…',
        'Keep going — you don’t have to wait',
      );
    }
    if (s.needsAttention.isNotEmpty) {
      final n = s.needsAttention.length;
      return (
        BannerLevel.bad,
        '$n ${n == 1 ? 'item needs' : 'items need'} your attention',
        'They will not send on their own — tap to see',
      );
    }
    if (s.pending.isNotEmpty) {
      final n = s.pendingCount;
      return (
        BannerLevel.warn,
        '$n ${n == 1 ? 'capture' : 'captures'} held on this phone',
        'They will send themselves · nothing is lost',
      );
    }
    return (
      BannerLevel.good,
      'Everything is sent',
      s.lastSentAt == null
          ? 'Nothing waiting'
          : 'Last sent ${formatAgo(s.lastSentAt!)}',
    );
  }
}
