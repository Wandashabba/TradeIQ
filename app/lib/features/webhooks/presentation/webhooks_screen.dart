import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../data/webhooks_repository.dart';

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
      body: webhooks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load webhooks: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(webhooksListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _WebhookCard(webhook: list[index]),
        ),
      ),
    );
  }
}

class _WebhookCard extends ConsumerWidget {
  const _WebhookCard({required this.webhook});

  final Webhook webhook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(webhook.event),
        subtitle: Text(webhook.url),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: ValueKey<String>('toggle-${webhook.id}'),
              value: webhook.active,
              onChanged: (value) async {
                await ref
                    .read(webhooksRepositoryProvider)
                    .setActive(webhook.id, value);
                ref.invalidate(webhooksListProvider);
              },
            ),
            IconButton(
              key: ValueKey<String>('delete-${webhook.id}'),
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await ref
                    .read(webhooksRepositoryProvider)
                    .deleteWebhook(webhook.id);
                ref.invalidate(webhooksListProvider);
              },
            ),
          ],
        ),
      ),
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
        FilledButton(
          key: const ValueKey<String>('create-webhook'),
          onPressed: _submitting ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
