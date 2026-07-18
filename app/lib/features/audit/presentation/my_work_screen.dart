import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/sync_status.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/theme/tiq_geometry.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';

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

    return AgentScaffold(
      title: 'Your work',
      subtitle: 'What is on this phone, and what is sent',
      onBack: () => context.pop(),
      // The chip lives in the app bar everywhere else; on the screen it opens,
      // it would just be a link to itself.
      showSyncChip: false,
      bottomAction: AgentButton(
        key: const ValueKey('sync-now'),
        label: 'Try sending now',
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
            title: 'Could not read your work',
            subtitle: '$err',
          ),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            _Summary(status: s),
            if (s.needsAttention.isNotEmpty) ...[
              const _Heading('Needs you'),
              _Group(items: s.needsAttention, showError: true),
            ],
            if (s.pending.where((i) => !i.needsAttention).isNotEmpty) ...[
              const _Heading('Waiting to send'),
              _Group(
                items: s.pending.where((i) => !i.needsAttention).toList(),
              ),
            ],
            if (s.sent.isNotEmpty) ...[
              const _Heading('Sent'),
              _Group(items: s.sent.take(20).toList()),
            ],
            if (s.pending.isEmpty && s.sent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Nothing captured yet',
                    style:
                        TextStyle(fontSize: 14, color: context.colors.ink3),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Captures send themselves when you have signal — you never have to '
              'remember to do it. Nothing here is ever lost.',
              style: TextStyle(
                  fontSize: 12.5, color: context.colors.ink3, height: 1.5),
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
    if (syncing && status.pending.isNotEmpty) {
      final n = status.pendingCount;
      return StatusBanner(
        key: const ValueKey('work-summary'),
        level: BannerLevel.info,
        title: 'Sending $n ${n == 1 ? 'item' : 'items'}…',
        subtitle: 'You don’t have to wait for this',
        pulsing: true,
      );
    }
    return _summaryFor(status);
  }

  static Widget _summaryFor(SyncStatus status) {
    if (status.needsAttention.isNotEmpty) {
      final n = status.needsAttention.length;
      return StatusBanner(
        key: const ValueKey('work-summary'),
        level: BannerLevel.bad,
        title: '$n ${n == 1 ? 'item' : 'items'} will not send',
        subtitle: 'Everything else is safe',
      );
    }
    if (status.pending.isNotEmpty) {
      final n = status.pendingCount;
      return StatusBanner(
        key: const ValueKey('work-summary'),
        level: BannerLevel.warn,
        title: '$n ${n == 1 ? 'item' : 'items'} held on this phone',
        subtitle: status.lastSentAt == null
            ? 'They will send themselves'
            : 'Last sent ${formatAgo(status.lastSentAt!)}',
      );
    }
    return StatusBanner(
      key: const ValueKey('work-summary'),
      level: BannerLevel.good,
      title: 'Everything is sent',
      subtitle: status.lastSentAt == null
          ? 'Nothing waiting'
          : 'Last sent ${formatAgo(status.lastSentAt!)}',
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
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface1,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(TiqGeometry.panel),
      ),
      child: Column(
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
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.showError,
    required this.last,
  });

  final SyncItem item;
  final bool showError;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color, state) = switch (item) {
      SyncItem(synced: true) => (Icons.check, c.good, 'Sent'),
      SyncItem(needsAttention: true) => (
          Icons.warning_amber_outlined,
          c.crit,
          'Failed',
        ),
      _ => (Icons.schedule, c.warn, 'Waiting'),
    };

    return Container(
      key: ValueKey('sync-item-${item.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: c.line)),
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
                  style: TextStyle(fontSize: 14, color: c.ink1),
                ),
                const SizedBox(height: 2),
                Text(
                  // Show the reason on the rows that need a human, and the age
                  // on the ones that don't.
                  showError && item.lastError != null
                      ? item.lastError!
                      : formatAgo(item.queuedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: showError ? c.crit : c.ink3,
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
