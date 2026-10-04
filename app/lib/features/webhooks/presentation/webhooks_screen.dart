import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
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
/// so the content grant goes unspent. Day paints zero.
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

  Widget _frame({
    required String phase,
    required List<Widget> children,
    ConsoleDeskRecords? desk,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      // Non-null on `loaded` only: a skeleton, an error and "no endpoints yet"
      // are not records.
      desk: desk,
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
    final unhealthy = webhooks
        .where((w) => w.health == WebhookHealth.unhealthy)
        .length;

    // THE TWO BLOCKS ABOVE THE LIST, BUILT ONCE and handed to both arms: the
    // named, counted section marker and — only when there is one — the note
    // that says how many endpoints have stopped receiving.
    final section = SectionRule(
      l10n.webhooksSection,
      count: webhooks.isEmpty ? null : webhooks.length,
      listAction: true,
    );
    final unhealthyNote = unhealthy == 0
        ? null
        : Row(
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
          );

    return _frame(
      phase: webhooks.isEmpty ? 'empty' : 'loaded',
      // ── WHAT THE DESK GETS, AND WHY THIS SCREEN CHANGED THE MOST ──────
      //
      // This route was the product's example of a screen that is **not** a
      // list of records: its rows expand in place, so the argument went, and
      // there was nowhere for a third pane to point. That was backwards. The
      // thing the row expands to show — the delivery log — is exactly what a
      // detail pane is for, and on a phone it costs the manager the list they
      // were reading to see it.
      //
      // So on the desk the expansion is **suppressed** (`_WebhookRow.onDesk`)
      // and `_DeliveriesList` is the pane, with the row's own verbs — the
      // receiving toggle and `Delete` — lifted beside it, and each delivery's
      // `Redeliver` arriving with the log it belongs to. The phone keeps the
      // fold exactly as it was: `Show deliveries` still opens underneath the
      // row it belongs to, because there is no second pane to open it in.
      //
      // `Add an endpoint` moves to the footer, under the records, where the
      // phone puts it — the desk does not draw `children`, and dropping it
      // would have left a manager on a desktop with no way to add one.
      desk: webhooks.isEmpty
          ? null
          : ConsoleDeskRecords(
              toolbar: ConsoleDeskToolbar.marker,
              lead: <Widget>[
                section,
                const SizedBox(height: TiqSpace.s5),
                if (unhealthyNote != null) ...<Widget>[
                  unhealthyNote,
                  const SizedBox(height: TiqSpace.s6),
                ],
              ],
              footer: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TorchSecondaryButton(
                  key: const ValueKey<String>('webhook-create-desk'),
                  label: l10n.webhookAdd,
                  onPressed: _create,
                ),
              ),
              records: <ConsoleDeskRecord>[
                for (var i = 0; i < webhooks.length; i++)
                  ConsoleDeskRecord(
                    id: webhooks[i].id,
                    row: (context, selected) => _WebhookRow(
                      key: ValueKey<String>('webhook-${webhooks[i].id}'),
                      webhook: webhooks[i],
                      last: i == webhooks.length - 1,
                      onChanged: _refresh,
                      onDesk: true,
                    ),
                    detail: (context) => _WebhookDetail(
                      key: ValueKey<String>('webhook-detail-${webhooks[i].id}'),
                      webhook: webhooks[i],
                      onChanged: _refresh,
                    ),
                  ),
              ],
            ),
      children: <Widget>[
        section,
        const SizedBox(height: TiqSpace.s5),

        if (unhealthyNote != null) ...<Widget>[
          unhealthyNote,
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

/// ── AN ENDPOINT'S TWO VERBS, HELD ONCE ─────────────────────────────────
///
/// Pausing an endpoint and deleting one are the same two flows at two
/// addresses — the row on a phone, the detail pane on a desk — and the only
/// difference is which element the optimistic value belongs to. So they live
/// here rather than in two copies, one of which would eventually stop asking
/// the confirmation or stop standing the switch back up on a failure.
///
/// [active] is the optimistic read every caller uses: the switch moves on the
/// tap and goes back if the PATCH fails, because a switch that waits for a
/// round trip in a shop reads as a switch that does not work.
mixin _WebhookVerbs<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  bool? optimisticActive;

  /// The endpoint this state is acting on.
  Webhook get endpoint;

  /// What to tell the screen when the list it is showing has changed.
  VoidCallback get onEndpointChanged;

  bool get active => optimisticActive ?? endpoint.active;

  Future<void> setActive(bool value) async {
    final l10n = context.l10n;
    setState(() {
      optimisticActive = value;
      busy = true;
    });
    try {
      await ref.read(webhooksRepositoryProvider).setActive(endpoint.id, value);
      if (!mounted) return;
      setState(() => busy = false);
      onEndpointChanged();
    } catch (error) {
      if (!mounted) return;
      // Honesty: the change did not happen, so the switch goes back.
      setState(() {
        optimisticActive = null;
        busy = false;
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

  Future<void> delete() async {
    if (busy) return;
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
        record: endpoint.url,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(webhooksRepositoryProvider).deleteWebhook(endpoint.id);
      if (!mounted) return;
      onEndpointChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      showTorchToast(
        context,
        message: l10n.webhookDeleteFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
    }
  }
}

class _WebhookRow extends ConsumerStatefulWidget {
  const _WebhookRow({
    super.key,
    required this.webhook,
    required this.last,
    required this.onChanged,
    this.onDesk = false,
  });

  final Webhook webhook;
  final bool last;
  final VoidCallback onChanged;

  /// True in the desk's list pane, where **the deliveries are the detail
  /// pane**.
  ///
  /// It takes two things off the row and puts neither of them nowhere: the
  /// fold (`Show deliveries`, and the `_DeliveriesList` it reveals) is the
  /// pane itself, and the two verbs are lifted into that pane beside it. What
  /// is left is the row a manager scans — the event in words, when it last
  /// delivered, the health chip, the URL and whether it is signed.
  ///
  /// The phone arm passes nothing and keeps the fold: below the threshold
  /// there is no second pane to open a log in, which is the whole reason the
  /// row expanded in the first place.
  final bool onDesk;

  @override
  ConsumerState<_WebhookRow> createState() => _WebhookRowState();
}

class _WebhookRowState extends ConsumerState<_WebhookRow>
    with _WebhookVerbs<_WebhookRow> {
  bool _expanded = false;

  @override
  Webhook get endpoint => widget.webhook;

  @override
  VoidCallback get onEndpointChanged => widget.onChanged;

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
          title: webhookEventWords(l10n, webhook.event),
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
              // THE EVENT'S OWN TOKEN, AND THE URL — both things the system
              // uses rather than things a person reads, so both wear the
              // identifier face. The token was the row's *headline* until
              // 26 September 2026 (`visit.submitted` as the name of the
              // webhook); it is a thing you paste into a config file, not a
              // name, and it belongs here where the URL already is.
              Text(
                '${webhook.event} · ${webhook.url}',
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
          // ON THE DESK THESE THREE ARE THE PANE. See [_WebhookRow.onDesk]:
          // the fold is the pane itself and the two verbs are lifted into it,
          // so a desk row carries no action slot at all rather than offering
          // the same toggle twice, 40dp apart.
          actions: widget.onDesk
              ? null
              : Wrap(
                  spacing: TiqSpace.s4,
                  runSpacing: TiqSpace.s2,
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: TorchToggle(
                        key: ValueKey<String>('toggle-${webhook.id}'),
                        label: l10n.webhookReceivingEvents,
                        value: active,
                        onWord: l10n.webhookOn,
                        offWord: l10n.webhookOff,
                        onChanged: busy ? null : setActive,
                        disabledReason: busy
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
                      onPressed: busy ? null : delete,
                    ),
                  ],
                ),
          separator: widget.last && !_expanded
              ? SoftRowSeparator.none
              : SoftRowSeparator.auto,
          semanticsLabel: <String>[
            webhookEventWords(l10n, webhook.event),
            webhook.url,
            webhook.health.wordIn(l10n),
            active ? l10n.webhookReceiving : l10n.webhookPaused,
            webhook.hasSecret
                ? l10n.webhookSignedShort
                : l10n.webhookNotSignedShort,
          ].join('. '),
        ),
        // Unreachable on the desk — the control that sets this is not drawn
        // there — and the guard says so rather than relying on it.
        if (_expanded && !widget.onDesk)
          _DeliveriesList(webhookId: webhook.id),
      ],
    );
  }
}

/// ── ONE ENDPOINT, IN THE DETAIL PANE ───────────────────────────────────
///
/// The record the row identifies, and then **the log the row used to expand to
/// show**: the same [_DeliveriesList], at the measure, with the list it was
/// chosen from still on screen beside it. That is the whole argument for this
/// screen having a third pane at all.
///
/// The facts are the two things a manager pastes into a config file — the
/// address and the event token — in the identifier face, and the signing
/// sentence is the row's own, printed in full rather than shortened: **the
/// secret itself is not here, obscured or behind a reveal, it is absent**, as
/// it is everywhere else on this screen.
///
/// The verbs are the row's, lifted: the receiving toggle and `Delete`. Each
/// delivery's `Redeliver` comes with the log, where it belongs.
///
/// **Amber: none.** A toggle is an Abyssal block with its state word, `Delete`
/// is the row's own tertiary, and the commit is inside the confirm sheet,
/// which puts out every amber beneath it.
class _WebhookDetail extends ConsumerStatefulWidget {
  const _WebhookDetail({
    super.key,
    required this.webhook,
    required this.onChanged,
  });

  final Webhook webhook;
  final VoidCallback onChanged;

  @override
  ConsumerState<_WebhookDetail> createState() => _WebhookDetailState();
}

class _WebhookDetailState extends ConsumerState<_WebhookDetail>
    with _WebhookVerbs<_WebhookDetail> {
  @override
  Webhook get endpoint => widget.webhook;

  @override
  VoidCallback get onEndpointChanged => widget.onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final webhook = widget.webhook;
    final lastDelivery = webhook.lastDeliveryAt;

    return ConsoleRecordDetail(
      // The row's own chip, in the row's own words.
      kicker: StatusChip(
        key: ValueKey<String>('health-${webhook.id}-pane'),
        level: webhook.health.level,
        label: webhook.health.wordIn(l10n),
      ),
      title: webhookEventWords(l10n, webhook.event),
      lede: lastDelivery == null
          ? l10n.webhookNoDeliveriesYet
          : l10n.webhookLastDelivery(relativeTime(lastDelivery, l10n)),
      facts: <RecordFact>[
        RecordFact(l10n.webhookCreateAddress, webhook.url, mono: true),
        RecordFact(l10n.webhookCreateEvent, webhook.event, mono: true),
      ],
      blocks: <Widget>[
        Text(
          // The word, never the value — the screen's own rule.
          webhook.hasSecret ? l10n.webhookSigned : l10n.webhookNotSigned,
          key: ValueKey<String>('signing-${webhook.id}-pane'),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        _DeliveriesList(webhookId: webhook.id, inCard: true),
      ],
      actions: <Widget>[
        TorchToggle(
          key: ValueKey<String>('toggle-${webhook.id}-pane'),
          label: l10n.webhookReceivingEvents,
          value: active,
          onWord: l10n.webhookOn,
          offWord: l10n.webhookOff,
          onChanged: busy ? null : setActive,
          disabledReason: busy ? l10n.webhookWaitingForServer : null,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: ValueKey<String>('delete-${webhook.id}-pane'),
            label: l10n.webhookDelete,
            onPressed: busy ? null : delete,
          ),
        ),
      ],
    );
  }
}

/// ── THE DELIVERY LOG ────────────────────────────────────────────────────
///
/// Under the row it belongs to on a phone; **the detail pane** on a desk. One
/// widget either way: the log is the same log, and the only thing that differs
/// is who pays the gutter — see [inCard].
class _DeliveriesList extends ConsumerWidget {
  const _DeliveriesList({required this.webhookId, this.inCard = false});

  final String webhookId;

  /// True in the detail pane, where this list is inside a [TorchCard] that has
  /// already spent its own padding. On the phone the list hangs off a
  /// full-bleed row list and pays the gutter back itself; paying it twice
  /// would indent the log from the record it is about.
  final bool inCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final l10n = context.l10n;
    final deliveries = ref.watch(webhookDeliveriesProvider(webhookId));
    return Padding(
      key: ValueKey<String>('deliveries-$webhookId'),
      padding: inCard
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(
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
            data: (page) {
              final list = page.data;
              if (list.isEmpty) {
                return EmptyState(
                  scope: EmptyScope.inPanel,
                  headline: l10n.webhookDeliveriesEmptyHeadline,
                  body: l10n.webhookDeliveriesEmptyBody,
                );
              }
              return Column(
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
                  // THE LOG SAYS WHERE IT STOPS. `listDeliveries` defaulted
                  // to ten that nobody asked for, so a manager debugging a
                  // failing endpoint saw ten deliveries and no sign there
                  // were more — and a log that silently stops is a log you
                  // draw the wrong conclusion from. Never a total: the server
                  // sends a cursor, not a count.
                  if (page.nextCursor != null) ...<Widget>[
                    const SizedBox(height: TiqSpace.s3),
                    PaginationFooter(
                      summary: l10n.webhookDeliveriesShowing(list.length),
                    ),
                  ],
                ],
              );
            },
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
      title: webhookEventWords(l10n, delivery.event),
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
        webhookEventWords(l10n, delivery.event),
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
                ChoiceOption<String>(
                  value: event,
                  label: webhookEventWords(l10n, event),
                ),
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
