import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/human_error.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/glass.dart';
import '../../../l10n/l10n.dart';

/// "Your work" — everything the agent has captured, and whether the server has
/// it yet.
///
/// The app has always been offline-first, and until now it told the agent
/// *nothing*: no pending count, no last-sync time, no failures. "Saved on this
/// phone" is a promise the whole design rests on, so it has to be visible — and
/// the one item that will never send on its own has to be distinguishable from
/// the ones that are simply waiting for signal.
class MyWorkScreen extends ConsumerWidget {
  const MyWorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final l10n = context.l10n;

    return AgentScaffold(
      title: l10n.myWorkTitle,
      subtitle: l10n.myWorkSubtitle,
      onBack: () => context.pop(),
      // The chip lives in the app bar everywhere else; on the screen it opens,
      // it would just be a link to itself.
      showSyncChip: false,
      bottomAction: AgentButton(
        key: const ValueKey('sync-now'),
        label: l10n.myWorkSyncNow,
        icon: Icons.refresh,
        secondary: true,
        onPressed: () => ref.read(syncNowProvider)(),
      ),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: StatusBanner(
            level: BannerLevel.bad,
            title: l10n.myWorkLoadErrorTitle,
            subtitle: humanErrorMessage(err, l10n),
          ),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            _Summary(status: s),
            if (s.needsAttention.isNotEmpty) ...[
              _Heading(l10n.myWorkNeedsYouHeading),
              _Group(items: s.needsAttention, showError: true),
            ],
            if (s.pending.where((i) => !i.needsAttention).isNotEmpty) ...[
              _Heading(l10n.myWorkWaitingHeading),
              _Group(items: s.pending.where((i) => !i.needsAttention).toList()),
            ],
            if (s.sent.isNotEmpty) ...[
              _Heading(l10n.myWorkSentHeading),
              _Group(items: s.sent.take(20).toList()),
            ],
            if (s.pending.isEmpty && s.sent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    l10n.myWorkEmpty,
                    style: TextStyle(fontSize: 14, color: context.colors.ink3),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.myWorkFooter,
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.ink3,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(syncingProvider);
    final l10n = context.l10n;
    if (syncing && status.pending.isNotEmpty) {
      final n = status.pendingCount;
      return StatusBanner(
        key: const ValueKey('work-summary'),
        level: BannerLevel.info,
        title: l10n.myWorkSendingTitle(n),
        subtitle: l10n.myWorkSendingSubtitle,
        pulsing: true,
      );
    }
    return _summaryFor(status, l10n);
  }

  static Widget _summaryFor(SyncStatus status, AppLocalizations l10n) {
    if (status.needsAttention.isNotEmpty) {
      final n = status.needsAttention.length;
      return StatusBanner(
        key: const ValueKey('work-summary'),
        level: BannerLevel.bad,
        title: l10n.myWorkFailedTitle(n),
        subtitle: l10n.myWorkFailedSubtitle,
      );
    }
    if (status.pending.isNotEmpty) {
      final n = status.pendingCount;
      return StatusBanner(
        key: const ValueKey('work-summary'),
        level: BannerLevel.warn,
        title: l10n.myWorkHeldTitle(n),
        subtitle: status.lastSentAt == null
            ? l10n.myWorkHeldSubtitle
            : l10n.syncLastSent(formatAgo(status.lastSentAt!, l10n)),
      );
    }
    return StatusBanner(
      key: const ValueKey('work-summary'),
      level: BannerLevel.good,
      title: l10n.syncAllSentTitle,
      subtitle: status.lastSentAt == null
          ? l10n.syncNothingWaiting
          : l10n.syncLastSent(formatAgo(status.lastSentAt!, l10n)),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
          color: context.colors.ink3,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.items, this.showError = false});

  final List<SyncItem> items;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Reveal(
            index: i,
            child: _Row(
              item: items[i],
              showError: showError,
              last: i == items.length - 1,
            ),
          ),
      ],
    );
    if (colors.glass) {
      // A pane of glass per group; no blur, because the list scrolls.
      return GlassPane(radius: LumenGlass.radiusCard, blur: false, child: rows);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: rows,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.showError, required this.last});

  final SyncItem item;
  final bool showError;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    // Coloured status TEXT must clear 4.5:1 on the surface1 card, so the failed
    // state takes critText (raw crit fails AA in dark) — the recurring lesson.
    final (icon, color, state) = switch (item) {
      SyncItem(synced: true) => (
        Icons.check,
        colors.good,
        l10n.myWorkStateSent,
      ),
      SyncItem(needsAttention: true) => (
        Icons.warning_amber_outlined,
        colors.critText,
        l10n.myWorkStateFailed,
      ),
      _ => (Icons.schedule, colors.warn, l10n.myWorkStateWaiting),
    };

    return Container(
      key: ValueKey('sync-item-${item.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(fontSize: 14, color: colors.ink1),
                ),
                const SizedBox(height: 2),
                Text(
                  // Show the reason on the rows that need a human, and the age
                  // on the ones that don't.
                  showError && item.lastError != null
                      ? item.lastError!
                      : formatAgo(item.queuedAt, l10n),
                  style: TextStyle(
                    fontSize: 12,
                    // The failure reason is coloured status text → critText.
                    color: showError ? colors.critText : colors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            state.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
