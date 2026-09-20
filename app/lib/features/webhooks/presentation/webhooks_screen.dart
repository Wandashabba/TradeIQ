import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/webhooks_repository.dart';

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
  StatusLevel get level => switch (this) {
    WebhookHealth.healthy => StatusLevel.onTarget,
    WebhookHealth.failing => StatusLevel.watch,
    WebhookHealth.unhealthy => StatusLevel.critical,
  };

  String get word => switch (this) {
    WebhookHealth.healthy => 'Healthy',
    WebhookHealth.failing => 'Failing',
    WebhookHealth.unhealthy => 'Unhealthy',
  };
}

extension DeliveryStatusStyle on DeliveryStatus {
  StatusLevel get level => switch (this) {
    DeliveryStatus.pending => StatusLevel.held,
    DeliveryStatus.succeeded => StatusLevel.onTarget,
    DeliveryStatus.failedRetrying => StatusLevel.watch,
    DeliveryStatus.gaveUp => StatusLevel.critical,
  };

  String get word => switch (this) {
    DeliveryStatus.pending => 'Queued',
    DeliveryStatus.succeeded => 'Delivered',
    DeliveryStatus.failedRetrying => 'Retrying',
    DeliveryStatus.gaveUp => 'Gave up',
  };
}

/// WEBHOOKS — the outbound endpoints, whether each is receiving, and what it
/// received.
///
/// ## A secret is never on this screen
///
/// Not obscured, not behind a reveal, not in a copy action: **absent**. The
/// row says `Signed` or `Not signed` and the secret itself stays on the
/// server. The create sheet takes one and never shows it again — the field is
/// write-only by construction, because a secret that can be read back is a
/// secret that can be read by whatever is standing behind the manager.
///
/// This turned out to matter more than a rendering rule. `GET /webhooks` was
/// returning the raw row, secret column included, so the value was arriving in
/// the browser whether or not a widget drew it. That is fixed on the server in
/// the same change; the screen's own rule is the second lock.
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 and nothing here is armed,
/// so the content grant goes unspent. Day and Veld paint zero.
class WebhooksScreen extends ConsumerStatefulWidget {
  const WebhooksScreen({super.key});

  @override
  ConsumerState<WebhooksScreen> createState() => _WebhooksScreenState();
}

class _WebhooksScreenState extends ConsumerState<WebhooksScreen> {
  void _refresh() => ref.invalidate(webhooksListProvider);

  @override
  Widget build(BuildContext context) {
    final webhooks = ref.watch(webhooksListProvider);

    return webhooks.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'webhooks',
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'webhooks',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('webhooks-retry'),
                label: 'Try again',
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: _loaded,
    );
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Webhooks',
        facts: const <String>[
          'Each endpoint receives a POST when its event fires.',
          'Failed deliveries retry for about eight hours.',
        ],
        trailing: TorchIconButton(
          key: const ValueKey<String>('webhooks-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the endpoints',
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  Future<void> _create() async {
    final created = await showTorchSheet<bool>(
      context,
      builder: (_) => const _CreateWebhookSheet(),
    );
    if (created == true && mounted) _refresh();
  }

  Widget _loaded(List<Webhook> webhooks) {
    final gutter = context.skin.space.gutter;
    final unhealthy = webhooks
        .where((w) => w.health == WebhookHealth.unhealthy)
        .length;

    return _frame(
      phase: webhooks.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        SectionRule(
          'Endpoints',
          count: webhooks.isEmpty ? null : webhooks.length,
        ),
        const SizedBox(height: TiqSpace.s5),

        if (unhealthy > 0) ...<Widget>[
          Row(
            key: const ValueKey<String>('webhooks-unhealthy'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SeverityMark(kind: SeverityMarkKind.critical),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Text(
                  '$unhealthy ${unhealthy == 1 ? 'endpoint is' : 'endpoints are'} '
                  'not receiving. A delivery to '
                  '${unhealthy == 1 ? 'it' : 'them'} has given up after every '
                  'retry.',
                  style: context.skin.text.body.style(
                    color: context.skin.palette.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s6),
        ],

        if (webhooks.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: 'No endpoints registered.',
            body: 'Add one to forward events to an external system.',
            action: TorchSecondaryButton(
              key: const ValueKey<String>('webhook-create-empty'),
              label: 'Add an endpoint',
              onPressed: _create,
            ),
          )
        else ...<Widget>[
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < webhooks.length; i++)
                  _WebhookRow(
                    key: ValueKey<String>('webhook-${webhooks[i].id}'),
                    webhook: webhooks[i],
                    last: i == webhooks.length - 1,
                    onChanged: _refresh,
                  ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('webhook-create'),
              label: 'Add an endpoint',
              onPressed: _create,
            ),
          ),
        ],
      ],
    );
  }
}

class _WebhookRow extends ConsumerStatefulWidget {
  const _WebhookRow({
    super.key,
    required this.webhook,
    required this.last,
    required this.onChanged,
  });

  final Webhook webhook;
  final bool last;
  final VoidCallback onChanged;

  @override
  ConsumerState<_WebhookRow> createState() => _WebhookRowState();
}

class _WebhookRowState extends ConsumerState<_WebhookRow> {
  bool _expanded = false;
  bool _busy = false;
  bool? _optimisticActive;

  bool get _active => _optimisticActive ?? widget.webhook.active;

  Future<void> _setActive(bool value) async {
    setState(() {
      _optimisticActive = value;
      _busy = true;
    });
    try {
      await ref
          .read(webhooksRepositoryProvider)
          .setActive(widget.webhook.id, value);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      // Honesty: the change did not happen, so the switch goes back.
      setState(() {
        _optimisticActive = null;
        _busy = false;
      });
      showTorchToast(
        context,
        message:
            'That endpoint was not ${value ? 'resumed' : 'paused'}. '
            '${TorchErrorMessage.sanitise(error).body}',
        kind: ToastKind.failure,
      );
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showTorchSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(
        key: const ValueKey<String>('webhook-delete-sheet'),
        action: 'Delete this endpoint?',
        consequences: const <String>[
          'It stops receiving events immediately.',
          'Its delivery history is removed with it.',
          'Nothing already delivered is withdrawn.',
        ],
        commitLabel: 'Delete this endpoint',
        cancelLabel: 'Keep it',
        record: widget.webhook.url,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(webhooksRepositoryProvider)
          .deleteWebhook(widget.webhook.id);
      if (!mounted) return;
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTorchToast(
        context,
        message:
            'That endpoint was not deleted. '
            '${TorchErrorMessage.sanitise(error).body}',
        kind: ToastKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final webhook = widget.webhook;
    final lastDelivery = webhook.lastDeliveryAt;
    final unhealthy = webhook.health == WebhookHealth.unhealthy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SoftRow(
          key: ValueKey<String>('webhook-row-${webhook.id}'),
          density: SoftRowDensity.tall,
          title: webhook.event,
          subtitle: lastDelivery == null
              ? 'No deliveries yet'
              : 'Last delivery ${relativeTime(lastDelivery)}',
          severity: unhealthy
              ? SoftRowSeverity.critical
              : webhook.health == WebhookHealth.failing
              ? SoftRowSeverity.watch
              : SoftRowSeverity.none,
          severityLabel: unhealthy
              ? 'Unhealthy'
              : webhook.health == WebhookHealth.failing
              ? 'Failing'
              : null,
          trailing: StatusChip(
            key: ValueKey<String>('health-${webhook.id}'),
            level: webhook.health.level,
            label: webhook.health.word,
          ),
          meta: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // A URL is a thing the system calls, not prose.
              Text(
                webhook.url,
                style: skin.text.monoIdent.style(color: skin.palette.ink3),
              ),
              const SizedBox(height: TiqSpace.s1),
              Text(
                // The word, never the value. See the class comment.
                webhook.hasSecret
                    ? 'Signed — deliveries carry an HMAC signature.'
                    : 'Not signed — deliveries carry no signature.',
                key: ValueKey<String>('signing-${webhook.id}'),
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
            ],
          ),
          actions: Wrap(
            spacing: TiqSpace.s4,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: TorchToggle(
                  key: ValueKey<String>('toggle-${webhook.id}'),
                  label: 'Receiving events',
                  value: _active,
                  onWord: 'On',
                  offWord: 'Off',
                  onChanged: _busy ? null : _setActive,
                  disabledReason: _busy ? 'Waiting for the server.' : null,
                ),
              ),
              TorchTertiaryButton(
                key: ValueKey<String>('deliveries-toggle-${webhook.id}'),
                label: _expanded ? 'Hide deliveries' : 'Show deliveries',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              TorchTertiaryButton(
                key: ValueKey<String>('delete-${webhook.id}'),
                label: 'Delete',
                onPressed: _busy ? null : _delete,
              ),
            ],
          ),
          separator: widget.last && !_expanded
              ? SoftRowSeparator.none
              : SoftRowSeparator.auto,
          semanticsLabel: <String>[
            webhook.event,
            webhook.url,
            webhook.health.word,
            _active ? 'Receiving' : 'Paused',
            webhook.hasSecret ? 'Signed' : 'Not signed',
          ].join('. '),
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
    final skin = context.skin;
    final deliveries = ref.watch(webhookDeliveriesProvider(webhookId));
    return Padding(
      key: ValueKey<String>('deliveries-$webhookId'),
      padding: EdgeInsets.fromLTRB(
        skin.space.gutter,
        TiqSpace.s3,
        skin.space.gutter,
        TiqSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SectionRule('Recent deliveries'),
          const SizedBox(height: TiqSpace.s3),
          deliveries.when(
            loading: () => Skeleton(
              label: 'deliveries',
              child: const SkeletonRows(count: 2, rowHeight: 64),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                label: 'Try again',
                onPressed: () =>
                    ref.invalidate(webhookDeliveriesProvider(webhookId)),
              ),
            ),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    scope: EmptyScope.inPanel,
                    headline: 'No deliveries yet.',
                    body: 'One appears each time the event fires.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < list.length; i++)
                        _DeliveryRow(
                          key: ValueKey<String>('delivery-${list[i].id}'),
                          webhookId: webhookId,
                          delivery: list[i],
                          last: i == list.length - 1,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends ConsumerStatefulWidget {
  const _DeliveryRow({
    super.key,
    required this.webhookId,
    required this.delivery,
    required this.last,
  });

  final String webhookId;
  final WebhookDelivery delivery;
  final bool last;

  @override
  ConsumerState<_DeliveryRow> createState() => _DeliveryRowState();
}

class _DeliveryRowState extends ConsumerState<_DeliveryRow> {
  bool _busy = false;

  String get _when {
    final d = widget.delivery;
    return switch (d.status) {
      DeliveryStatus.succeeded when d.deliveredAt != null =>
        'Delivered ${relativeTime(d.deliveredAt!)}',
      DeliveryStatus.failedRetrying when d.nextAttemptAt != null =>
        'Next retry ${relativeTime(d.nextAttemptAt!)}',
      DeliveryStatus.gaveUp => 'No more retries',
      _ => 'Created ${relativeTime(d.createdAt)}',
    };
  }

  Future<void> _redeliver() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(webhooksRepositoryProvider).redeliver(widget.delivery.id);
      if (!mounted) return;
      showTorchToast(
        context,
        message: 'Redelivery queued.',
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        message:
            'That delivery was not re-queued. '
            '${TorchErrorMessage.sanitise(error).body}',
        kind: ToastKind.failure,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(webhookDeliveriesProvider(widget.webhookId));
        ref.invalidate(webhooksListProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final delivery = widget.delivery;
    final facts = <String>[
      delivery.lastStatusCode != null
          ? 'HTTP ${delivery.lastStatusCode}'
          : delivery.attempts == 0
          ? 'Not sent yet'
          : 'No response',
      delivery.attempts == 1 ? '1 attempt' : '${delivery.attempts} attempts',
    ];
    // The backend records a non-2xx as "HTTP <code>", which the facts already
    // say; only a real diagnostic (a refused connection, a timeout) is shown.
    final diagnostic =
        delivery.lastError != null &&
            delivery.status != DeliveryStatus.succeeded &&
            delivery.lastError != 'HTTP ${delivery.lastStatusCode}'
        ? delivery.lastError
        : null;

    return SoftRow(
      density: SoftRowDensity.tall,
      title: delivery.event,
      subtitle: _when,
      trailing: StatusChip(
        level: delivery.status.level,
        label: delivery.status.word,
      ),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            facts.join(' · '),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          if (diagnostic != null)
            Padding(
              padding: const EdgeInsets.only(top: TiqSpace.s1),
              child: Text(
                diagnostic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: skin.text.meta.style(color: skin.palette.ink2),
              ),
            ),
        ],
      ),
      actions: delivery.status.redeliverable
          ? TorchTertiaryButton(
              key: ValueKey<String>('redeliver-${delivery.id}'),
              label: _busy ? 'Queueing…' : 'Redeliver',
              onPressed: _busy ? null : _redeliver,
            )
          : null,
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        delivery.event,
        delivery.status.word,
        ...facts,
        _when,
        ?diagnostic,
      ].join('. '),
    );
  }
}

/// ADD AN ENDPOINT — a URL, an event, and optionally a signing secret.
///
/// The secret box is write-only: it is sent once and the server never returns
/// it, so there is no state in which this app holds a secret it could show.
class _CreateWebhookSheet extends ConsumerStatefulWidget {
  const _CreateWebhookSheet();

  @override
  ConsumerState<_CreateWebhookSheet> createState() =>
      _CreateWebhookSheetState();
}

class _CreateWebhookSheetState extends ConsumerState<_CreateWebhookSheet> {
  final _url = TextEditingController();
  final _secret = TextEditingController();
  String? _event = webhookEvents.first;
  bool _saving = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[_url, _secret]) {
      c.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() => _failure = null);
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_url, _secret]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Mirrors the server's own guard: a public http(s) URL. Saying so here
  /// means the 400 is unreachable from the form rather than arriving as a
  /// sentence about "private and link-local addresses".
  String? get _urlError {
    final text = _url.text.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'That is not a web address.';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'The address has to start with http:// or https://.';
    }
    return null;
  }

  String? get _blocked {
    if (_url.text.trim().isEmpty) return 'Give the endpoint a web address.';
    final url = _urlError;
    if (url != null) return url;
    if (_event == null) return 'Pick the event it listens for.';
    return null;
  }

  Future<void> _create() async {
    final event = _event;
    if (event == null) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(webhooksRepositoryProvider)
          .createWebhook(
            url: _url.text.trim(),
            event: event,
            secret: _secret.text.trim().isEmpty ? null : _secret.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage.sanitise(error).body;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final blocked = _blocked;
    final armed = blocked == null && !_saving;
    final failure = _failure;

    return TorchSheet(
      key: const ValueKey<String>('webhook-create-sheet'),
      title: 'Add an endpoint',
      subtitle: 'It receives a POST every time its event fires.',
      claims: <TorchClaim>[
        if (armed) TorchPrimaryButton.claim('create-webhook'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('new-url'),
            label: 'Address',
            controller: _url,
            identifier: true,
            hint: 'https://example.com/hooks/tradeiq',
            help: 'A public http or https address the server can reach.',
            error: _urlError,
          ),
          const SizedBox(height: TiqSpace.s5),
          ChoiceRow<String>(
            key: const ValueKey<String>('new-event'),
            label: 'Event',
            value: _event,
            notAnsweredLine: 'Pick the event it listens for.',
            options: <ChoiceOption<String>>[
              for (final event in webhookEvents)
                ChoiceOption<String>(value: event, label: event),
            ],
            onChanged: (value) => setState(() => _event = value),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('new-secret'),
            label: 'Signing secret (optional)',
            controller: _secret,
            obscureText: true,
            help:
                'Deliveries are signed with it. It is stored on the server and '
                'never shown again — keep your own copy.',
          ),
          if (failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            ErrorState(
              key: const ValueKey<String>('webhook-create-error'),
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.rejected,
                headline: 'The endpoint was not added.',
                body: failure,
                offersRetry: false,
              ),
            ),
          ],
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            key: const ValueKey<String>('create-webhook'),
            label: 'Add this endpoint',
            claimId: 'create-webhook',
            busy: _saving,
            blockedReason: blocked ?? (_saving ? 'Adding…' : null),
            onPressed: armed ? _create : null,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('cancel-webhook'),
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
