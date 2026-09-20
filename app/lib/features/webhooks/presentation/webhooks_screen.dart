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
import '../../../l10n/l10n.dart';
import '../data/webhooks_repository.dart';

/// "just now", "5m ago", "3h ago", "2d ago" — or "in 5m" for a future time.
String relativeTime(DateTime at, AppLocalizations l10n, {DateTime? now}) {
  final diff = at.difference(now ?? DateTime.now());
  final future = diff.inSeconds > 0;
  final span = diff.abs();
  if (span.inMinutes < 1) {
    return future ? l10n.relativeUnderAMinute : l10n.relativeJustNow;
  }
  if (span.inHours < 1) {
    return future
        ? l10n.relativeInMinutes(span.inMinutes)
        : l10n.relativeMinutesAgo(span.inMinutes);
  }
  if (span.inDays < 1) {
    return future
        ? l10n.relativeInHours(span.inHours)
        : l10n.relativeHoursAgo(span.inHours);
  }
  return future
      ? l10n.relativeInDays(span.inDays)
      : l10n.relativeDaysAgo(span.inDays);
}

extension WebhookHealthStyle on WebhookHealth {
  StatusLevel get level => switch (this) {
    WebhookHealth.healthy => StatusLevel.onTarget,
    WebhookHealth.failing => StatusLevel.watch,
    WebhookHealth.unhealthy => StatusLevel.critical,
  };

  String wordIn(AppLocalizations l10n) => switch (this) {
    WebhookHealth.healthy => l10n.webhookHealthHealthy,
    WebhookHealth.failing => l10n.webhookHealthFailing,
    WebhookHealth.unhealthy => l10n.webhookHealthUnhealthy,
  };
}

extension DeliveryStatusStyle on DeliveryStatus {
  StatusLevel get level => switch (this) {
    DeliveryStatus.pending => StatusLevel.held,
    DeliveryStatus.succeeded => StatusLevel.onTarget,
    DeliveryStatus.failedRetrying => StatusLevel.watch,
    DeliveryStatus.gaveUp => StatusLevel.critical,
  };

  String wordIn(AppLocalizations l10n) => switch (this) {
    DeliveryStatus.pending => l10n.webhookDeliveryQueued,
    DeliveryStatus.succeeded => l10n.webhookDeliveryDelivered,
    DeliveryStatus.failedRetrying => l10n.webhookDeliveryRetrying,
    DeliveryStatus.gaveUp => l10n.webhookDeliveryGaveUp,
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
    final l10n = context.l10n;
    final webhooks = ref.watch(webhooksListProvider);

    return webhooks.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.webhooksSkeleton,
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: l10n.webhooksSkeleton,
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('webhooks-retry'),
                label: l10n.torchTryAgain,
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
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.webhooksTitle,
        facts: <String>[l10n.webhooksFactPost, l10n.webhooksFactRetries],
        trailing: TorchIconButton(
          key: const ValueKey<String>('webhooks-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.webhooksRefresh,
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
    final l10n = context.l10n;
    final gutter = context.skin.space.gutter;
    final unhealthy = webhooks
        .where((w) => w.health == WebhookHealth.unhealthy)
        .length;

    return _frame(
      phase: webhooks.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        SectionRule(
          l10n.webhooksSection,
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
                  l10n.webhooksUnhealthyNote(unhealthy),
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
            headline: l10n.webhooksEmptyHeadline,
            body: l10n.webhooksEmptyBody,
            action: TorchSecondaryButton(
              key: const ValueKey<String>('webhook-create-empty'),
              label: l10n.webhookAdd,
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
              label: l10n.webhookAdd,
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
    final l10n = context.l10n;
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
        message: value
            ? l10n.webhookResumeFailed(TorchErrorMessage.sanitise(error).body)
            : l10n.webhookPauseFailed(TorchErrorMessage.sanitise(error).body),
        kind: ToastKind.failure,
      );
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final l10n = context.l10n;
    final confirmed = await showTorchSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(
        key: const ValueKey<String>('webhook-delete-sheet'),
        action: l10n.webhookDeleteAction,
        consequences: <String>[
          l10n.webhookDeleteConsequenceStops,
          l10n.webhookDeleteConsequenceHistory,
          l10n.webhookDeleteConsequenceDelivered,
        ],
        commitLabel: l10n.webhookDeleteCommit,
        cancelLabel: l10n.webhookDeleteCancel,
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
        message: l10n.webhookDeleteFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
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
              ? l10n.webhookNoDeliveriesYet
              : l10n.webhookLastDelivery(relativeTime(lastDelivery, l10n)),
          severity: unhealthy
              ? SoftRowSeverity.critical
              : webhook.health == WebhookHealth.failing
              ? SoftRowSeverity.watch
              : SoftRowSeverity.none,
          severityLabel: unhealthy
              ? l10n.webhookHealthUnhealthy
              : webhook.health == WebhookHealth.failing
              ? l10n.webhookHealthFailing
              : null,
          trailing: StatusChip(
            key: ValueKey<String>('health-${webhook.id}'),
            level: webhook.health.level,
            label: webhook.health.wordIn(l10n),
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
                    ? l10n.webhookSigned
                    : l10n.webhookNotSigned,
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
                  label: l10n.webhookReceivingEvents,
                  value: _active,
                  onWord: l10n.webhookOn,
                  offWord: l10n.webhookOff,
                  onChanged: _busy ? null : _setActive,
                  disabledReason: _busy
                      ? l10n.webhookWaitingForServer
                      : null,
                ),
              ),
              TorchTertiaryButton(
                key: ValueKey<String>('deliveries-toggle-${webhook.id}'),
                label: _expanded
                    ? l10n.webhookHideDeliveries
                    : l10n.webhookShowDeliveries,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              TorchTertiaryButton(
                key: ValueKey<String>('delete-${webhook.id}'),
                label: l10n.webhookDelete,
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
            webhook.health.wordIn(l10n),
            _active ? l10n.webhookReceiving : l10n.webhookPaused,
            webhook.hasSecret
                ? l10n.webhookSignedShort
                : l10n.webhookNotSignedShort,
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
    final l10n = context.l10n;
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
          SectionRule(l10n.webhookDeliveriesSection),
          const SizedBox(height: TiqSpace.s3),
          deliveries.when(
            loading: () => Skeleton(
              label: l10n.webhookDeliveriesSkeleton,
              child: const SkeletonRows(count: 2, rowHeight: 64),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                label: l10n.torchTryAgain,
                onPressed: () =>
                    ref.invalidate(webhookDeliveriesProvider(webhookId)),
              ),
            ),
            data: (list) => list.isEmpty
                ? EmptyState(
                    scope: EmptyScope.inPanel,
                    headline: l10n.webhookDeliveriesEmptyHeadline,
                    body: l10n.webhookDeliveriesEmptyBody,
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

  String _when(AppLocalizations l10n) {
    final d = widget.delivery;
    return switch (d.status) {
      DeliveryStatus.succeeded when d.deliveredAt != null =>
        l10n.webhookDeliveredWhen(relativeTime(d.deliveredAt!, l10n)),
      DeliveryStatus.failedRetrying when d.nextAttemptAt != null =>
        l10n.webhookNextRetryWhen(relativeTime(d.nextAttemptAt!, l10n)),
      DeliveryStatus.gaveUp => l10n.webhookNoMoreRetries,
      _ => l10n.webhookCreatedWhen(relativeTime(d.createdAt, l10n)),
    };
  }

  Future<void> _redeliver() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(webhooksRepositoryProvider)
          .redeliver(widget.delivery.id);
      if (!mounted) return;
      showTorchToast(
        context,
        message: l10n.webhookRedeliveryQueued,
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        message: l10n.webhookRedeliverFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
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
    final l10n = context.l10n;
    final delivery = widget.delivery;
    final when = _when(l10n);
    final facts = <String>[
      delivery.lastStatusCode != null
          ? l10n.webhookHttpStatus(delivery.lastStatusCode!)
          : delivery.attempts == 0
          ? l10n.webhookNotSentYet
          : l10n.webhookNoResponse,
      l10n.webhookAttempts(delivery.attempts),
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
      subtitle: when,
      trailing: StatusChip(
        level: delivery.status.level,
        label: delivery.status.wordIn(l10n),
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
              label: _busy ? l10n.webhookQueueing : l10n.webhookRedeliver,
              onPressed: _busy ? null : _redeliver,
            )
          : null,
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        delivery.event,
        delivery.status.wordIn(l10n),
        ...facts,
        when,
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
    final l10n = context.l10n;
    final text = _url.text.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return l10n.webhookCreateNotAUrl;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return l10n.webhookCreateWrongScheme;
    }
    return null;
  }

  String? get _blocked {
    final l10n = context.l10n;
    if (_url.text.trim().isEmpty) return l10n.webhookCreateBlockedUrl;
    final url = _urlError;
    if (url != null) return url;
    if (_event == null) return l10n.webhookCreateBlockedEvent;
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
    final l10n = context.l10n;
    final blocked = _blocked;
    final armed = blocked == null && !_saving;
    final failure = _failure;

    return TorchSheet(
      key: const ValueKey<String>('webhook-create-sheet'),
      title: l10n.webhookAdd,
      subtitle: l10n.webhookCreateSubtitle,
      claims: <TorchClaim>[
        if (armed) TorchPrimaryButton.claim('create-webhook'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('new-url'),
            label: l10n.webhookCreateAddress,
            controller: _url,
            identifier: true,
            // Not localised: an example URL is a shape, not prose.
            hint: 'https://example.com/hooks/tradeiq',
            help: l10n.webhookCreateAddressHelp,
            error: _urlError,
          ),
          const SizedBox(height: TiqSpace.s5),
          ChoiceRow<String>(
            key: const ValueKey<String>('new-event'),
            label: l10n.webhookCreateEvent,
            value: _event,
            notAnsweredLine: l10n.webhookCreateBlockedEvent,
            options: <ChoiceOption<String>>[
              for (final event in webhookEvents)
                ChoiceOption<String>(value: event, label: event),
            ],
            onChanged: (value) => setState(() => _event = value),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('new-secret'),
            label: l10n.webhookCreateSecret,
            controller: _secret,
            obscureText: true,
            help: l10n.webhookCreateSecretHelp,
          ),
          if (failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            ErrorState(
              key: const ValueKey<String>('webhook-create-error'),
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.rejected,
                headline: l10n.webhookCreateFailed,
                body: failure,
                offersRetry: false,
              ),
            ),
          ],
          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            key: const ValueKey<String>('create-webhook'),
            label: l10n.webhookCreateCommit,
            claimId: 'create-webhook',
            busy: _saving,
            blockedReason: blocked ?? (_saving ? l10n.webhookCreateAdding : null),
            onPressed: armed ? _create : null,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('cancel-webhook'),
            label: l10n.webhookCreateCancel,
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
