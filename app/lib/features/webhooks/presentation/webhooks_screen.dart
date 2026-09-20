import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/webhooks_repository.dart';

/// Outbound endpoints, as a worklist: the event is the subject, the URL is the
/// machine-facing token, and delivery state is a mark *and* a word.
///
/// Each row also says whether the endpoint is actually receiving (#100) —
/// Healthy, Failing or Unhealthy, always as a word — and opens onto its recent
/// deliveries.
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
            'Each endpoint receives a POST when its event fires. Failed '
            'deliveries retry for about eight hours. Open an endpoint to see '
            'its recent deliveries.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<Webhook>>(
            value: webhooks,
            label: 'webhooks',
            onRetry: () => ref.invalidate(webhooksListProvider),
            builder: (list) {
              final live = list.where((w) => w.active).length;
              final unhealthy =
                  list.where((w) => w.health == WebhookHealth.unhealthy).length;
              return PanelCard(
                title: '${list.length} '
                    '${list.length == 1 ? 'endpoint' : 'endpoints'}',
                subtitle: unhealthy == 0
                    ? '$live receiving'
                    : '$live receiving · $unhealthy unhealthy',
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

/// "just now", "5m ago", "3h ago", "2d ago" — or "in 5m" for a future time.
String relativeTime(DateTime at, {DateTime? now}) {
  final diff = at.difference(now ?? DateTime.now());
  final future = diff.inSeconds > 0;
  final span = diff.abs();
  final String amount;
  if (span.inMinutes < 1) {
    return future ? 'in under a minute' : 'just now';
  } else if (span.inHours < 1) {
    amount = '${span.inMinutes}m';
  } else if (span.inDays < 1) {
    amount = '${span.inHours}h';
  } else {
    amount = '${span.inDays}d';
  }
  return future ? 'in $amount' : '$amount ago';
}

extension WebhookHealthStyle on WebhookHealth {
  LumenStatus get status => switch (this) {
    WebhookHealth.healthy => LumenStatus.good,
    WebhookHealth.failing => LumenStatus.warn,
    WebhookHealth.unhealthy => LumenStatus.crit,
  };

  String get word => switch (this) {
    WebhookHealth.healthy => 'Healthy',
    WebhookHealth.failing => 'Failing',
    WebhookHealth.unhealthy => 'Unhealthy',
  };
}

extension DeliveryStatusStyle on DeliveryStatus {
  LumenStatus get status => switch (this) {
    DeliveryStatus.pending => LumenStatus.none,
    DeliveryStatus.succeeded => LumenStatus.good,
    DeliveryStatus.failedRetrying => LumenStatus.warn,
    DeliveryStatus.gaveUp => LumenStatus.crit,
  };

  String get word => switch (this) {
    DeliveryStatus.pending => 'Queued',
    DeliveryStatus.succeeded => 'Delivered',
    DeliveryStatus.failedRetrying => 'Retrying',
    DeliveryStatus.gaveUp => 'Gave up',
  };
}

class _WebhookRow extends ConsumerStatefulWidget {
  const _WebhookRow({required this.webhook});

  final Webhook webhook;

  @override
  ConsumerState<_WebhookRow> createState() => _WebhookRowState();
}

class _WebhookRowState extends ConsumerState<_WebhookRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final webhook = widget.webhook;
    final colors = context.colors;

    Future<void> setActive(bool value) async {
      await ref.read(webhooksRepositoryProvider).setActive(webhook.id, value);
      ref.invalidate(webhooksListProvider);
    }

    Future<void> delete() async {
      await ref.read(webhooksRepositoryProvider).deleteWebhook(webhook.id);
      ref.invalidate(webhooksListProvider);
    }

    final lastDelivery = webhook.lastDeliveryAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        WorklistRow(
          key: ValueKey<String>('webhook-${webhook.id}'),
          title: webhook.event,
          onTap: () => setState(() => _expanded = !_expanded),
          meta: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // The URL is a thing the system calls, not prose — mono token.
              CodeToken(webhook.url),
              LumenStatusPill(
                key: ValueKey<String>('health-${webhook.id}'),
                status: webhook.health.status,
                label: webhook.health.word,
              ),
              Text(
                lastDelivery == null
                    ? 'No deliveries yet'
                    : 'Last delivery ${relativeTime(lastDelivery)}',
                style: TextStyle(fontSize: 11.5, color: colors.ink3),
              ),
            ],
          ),
          level: webhook.active ? StatusLevel.good : StatusLevel.neutral,
          statusLabel: webhook.active ? 'Active' : 'Paused',
          resolved: !webhook.active,
          actions: [
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: colors.ink3,
              semanticLabel: _expanded ? 'Hide deliveries' : 'Show deliveries',
            ),
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
        ),
        if (_expanded) _DeliveriesList(webhookId: webhook.id),
      ],
    );
  }
}

class _DeliveriesList extends ConsumerWidget {
  const _DeliveriesList({required this.webhookId});

  final String webhookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(webhookDeliveriesProvider(webhookId));
    return Padding(
      key: ValueKey<String>('deliveries-$webhookId'),
      padding: const EdgeInsets.fromLTRB(24, 2, 8, 8),
      child: AsyncSection<List<WebhookDelivery>>(
        value: deliveries,
        label: 'deliveries',
        onRetry: () => ref.invalidate(webhookDeliveriesProvider(webhookId)),
        builder: (list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No deliveries yet — one appears each time the event fires.',
                  style: TextStyle(fontSize: 11.5, color: context.colors.ink3),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 4),
                    child: Kicker('Recent deliveries'),
                  ),
                  for (final d in list)
                    _DeliveryTile(webhookId: webhookId, delivery: d),
                ],
              ),
      ),
    );
  }
}

class _DeliveryTile extends ConsumerWidget {
  const _DeliveryTile({required this.webhookId, required this.delivery});

  final String webhookId;
  final WebhookDelivery delivery;

  String get _when {
    final d = delivery;
    return switch (d.status) {
      DeliveryStatus.succeeded when d.deliveredAt != null =>
        'Delivered ${relativeTime(d.deliveredAt!)}',
      DeliveryStatus.failedRetrying when d.nextAttemptAt != null =>
        'Next retry ${relativeTime(d.nextAttemptAt!)}',
      DeliveryStatus.gaveUp => 'No more retries',
      _ => 'Created ${relativeTime(d.createdAt)}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final meta = TextStyle(fontSize: 11.5, color: colors.ink3);
    final figure = TextStyle(
      fontFamily: colors.glass ? LumenGlass.mono : 'monospace',
      fontSize: 11,
      color: colors.ink3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Future<void> redeliver() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(webhooksRepositoryProvider).redeliver(delivery.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Redelivery queued')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not redeliver. ${humanErrorMessage(e)}')),
        );
      } finally {
        ref.invalidate(webhookDeliveriesProvider(webhookId));
        ref.invalidate(webhooksListProvider);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassPane(
        key: ValueKey<String>('delivery-${delivery.id}'),
        kind: GlassKind.tile,
        // Repeated down a list: never blurred (see GlassPane.blur), and the
        // panel around it already owns the shadow.
        blur: false,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        delivery.event,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: colors.ink1,
                        ),
                      ),
                      LumenStatusPill(
                        status: delivery.status.status,
                        label: delivery.status.word,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      Text(
                        delivery.lastStatusCode != null
                            ? 'HTTP ${delivery.lastStatusCode}'
                            : delivery.attempts == 0
                            ? 'Not sent yet'
                            : 'No response',
                        style: figure,
                      ),
                      Text(
                        delivery.attempts == 1
                            ? '1 attempt'
                            : '${delivery.attempts} attempts',
                        style: figure,
                      ),
                      Text(_when, style: meta),
                    ],
                  ),
                  // The backend records a non-2xx as "HTTP <code>", which
                  // the code above already says; show only a real diagnostic
                  // (a refused connection, a timeout).
                  if (delivery.lastError != null &&
                      delivery.status != DeliveryStatus.succeeded &&
                      delivery.lastError != 'HTTP ${delivery.lastStatusCode}')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        delivery.lastError!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: meta,
                      ),
                    ),
                ],
              ),
            ),
            if (delivery.status.redeliverable)
              RowAction(
                key: ValueKey<String>('redeliver-${delivery.id}'),
                label: 'Redeliver',
                onPressed: redeliver,
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
            decoration: InputDecoration(
              labelText: 'Event',
              helperText: 'One of: ${webhookEvents.join(', ')}',
              helperMaxLines: 3,
            ),
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
