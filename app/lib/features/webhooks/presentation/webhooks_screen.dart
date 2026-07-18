import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/webhooks_repository.dart';

/// Outbound endpoints, as a worklist: the event is the subject, the URL is the
/// machine-facing token, and delivery state is a mark *and* a word.
class WebhooksScreen extends ConsumerWidget {
  const WebhooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webhooks = ref.watch(webhooksListProvider);

    return ManagerScaffold(
      title: 'Webhooks',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add webhook',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateWebhookDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Each endpoint receives a POST when its event fires. '
            'Pausing keeps the endpoint but stops delivery.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<Webhook>>(
            value: webhooks,
            label: 'webhooks',
            onRetry: () => ref.invalidate(webhooksListProvider),
            builder: (list) {
              final live = list.where((w) => w.active).length;
              return PanelCard(
                title: '${list.length} '
                    '${list.length == 1 ? 'endpoint' : 'endpoints'}',
                subtitle: '$live receiving',
                padded: false,
                child: list.isEmpty
                    ? const EmptyState(
                        message: 'No endpoints registered',
                        hint: 'Add one to forward events to an external system.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final w in list) _WebhookRow(webhook: w),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WebhookRow extends ConsumerWidget {
  const _WebhookRow({required this.webhook});

  final Webhook webhook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> setActive(bool value) async {
      await ref.read(webhooksRepositoryProvider).setActive(webhook.id, value);
      ref.invalidate(webhooksListProvider);
    }

    Future<void> delete() async {
      await ref.read(webhooksRepositoryProvider).deleteWebhook(webhook.id);
      ref.invalidate(webhooksListProvider);
    }

    return WorklistRow(
      title: webhook.event,
      // The URL is a thing the system calls, not prose — mono token.
      meta: Row(
        children: [Flexible(child: CodeToken(webhook.url))],
      ),
      level: webhook.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: webhook.active ? 'Active' : 'Paused',
      resolved: !webhook.active,
      actions: [
        Switch(
          key: ValueKey<String>('toggle-${webhook.id}'),
          value: webhook.active,
          onChanged: (value) => setActive(value),
        ),
        RowAction(
          key: ValueKey<String>('delete-${webhook.id}'),
          label: 'Delete',
          tone: StatusLevel.critical,
          onPressed: delete,
        ),
      ],
    );
  }
}

class _CreateWebhookDialog extends ConsumerStatefulWidget {
  const _CreateWebhookDialog();

  @override
  ConsumerState<_CreateWebhookDialog> createState() =>
      _CreateWebhookDialogState();
}

class _CreateWebhookDialogState extends ConsumerState<_CreateWebhookDialog> {
  final _urlCtrl = TextEditingController();
  final _eventCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _eventCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _submitting = true);
    try {
      await ref.read(webhooksRepositoryProvider).createWebhook(
            url: _urlCtrl.text.trim(),
            event: _eventCtrl.text.trim(),
          );
      ref.invalidate(webhooksListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create webhook: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Webhook'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('new-url'),
            controller: _urlCtrl,
            decoration: const InputDecoration(labelText: 'URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('new-event'),
            controller: _eventCtrl,
            decoration: const InputDecoration(labelText: 'Event'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('create-webhook'),
          onPressed: _submitting ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
