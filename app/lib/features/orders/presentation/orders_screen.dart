import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/network/human_error.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/orders_repository.dart';
import 'order_form_screen.dart';

/// ORDERS — what agents captured, and what is still waiting on a decision.
///
/// ```text
///   Orders                                        [ ⟳ ]
///   Captured in the field. A submitted order is
///   waiting on a decision.
///   ┌──────────────────┐ ┌──────────────────┐
///   │ AWAITING A…   2  │ │ VALUE OF…  R 191 │
///   │ 1 confirmed · 1… │ │ Summed over the… │
///   └──────────────────┘ └──────────────────┘
///   ── Orders  4 ─────────────── New order ──
///   ▌ Kasi Corner Spaza              R 149,50
///   ▌ Submitted · 3 lines
///   Showing the 20 newest of 74 orders.
/// ```
///
/// ## A page is not a history, and a sum over one is not a total
///
/// `GET /orders` returns one page. The old screen summed that page, put the
/// number under the words "Total value", and said nothing — so a manager
/// reading R 191,50 on an account with four hundred orders read a number that
/// was true of nothing. The figure now names its own scope in its eyebrow,
/// carries the sentence beneath it when the page was cut, and the footer says
/// what was shown. unify §4: a rank or a total is never invented.
///
/// ## A row names a shop
///
/// The old row's title was `Order 4f3a90c1` and its meta carried the outlet's
/// uuid. Neither is a thing anybody says out loud. The row is titled with the
/// store's name, resolved from the store list; the order's own id stays in the
/// identifier face where a support ticket can quote it, and an outlet that is
/// not on the loaded list says so in words rather than falling back to its id.
///
/// ## The amber, counted
///
/// A console route under Menu, so Night paints the nav's active tab and
/// nothing else; Day and Veld paint zero. Nothing on a worklist is armed — the
/// status words are words, the lead figure is crimson when it is anything at
/// all, and "New order" is a section rule's ghost action.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _Orders());
  }
}

/// Consequence order: anything still awaiting a decision first, closed rows
/// last. Nothing is filtered out — every order stays on the page.
List<OrderItem> sortedOrders(List<OrderItem> all) {
  int rank(OrderItem o) => switch (o.status) {
    'submitted' => 0,
    'confirmed' => 2,
    'cancelled' => 3,
    _ => 1,
  };
  final sorted = <OrderItem>[...all];
  sorted.sort((a, b) => rank(a).compareTo(rank(b)));
  return sorted;
}

String orderStatusWord(AppLocalizations l10n, String status) =>
    switch (status) {
      'submitted' => l10n.ordersStatusSubmitted,
      'confirmed' => l10n.ordersStatusConfirmed,
      'cancelled' => l10n.ordersStatusCancelled,
      _ => l10n.ordersStatusOther(status),
    };

/// A cancelled order is a closed fact, not a failure of anybody's; a submitted
/// one is the only row a manager still owes something to.
SoftRowSeverity orderSeverity(String status) => switch (status) {
  'submitted' => SoftRowSeverity.watch,
  _ => SoftRowSeverity.none,
};

class _Orders extends ConsumerWidget {
  const _Orders();

  void _refresh(WidgetRef ref) => ref.invalidate(ordersPageProvider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final page = ref.watch(ordersPageProvider);

    return page.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.ordersTitle,
            child: const SkeletonRows(count: 5, rowHeight: 72),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'orders',
            child: ErrorState(
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.ordersLoadErrorHeadline,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              drawing: EmptyDrawing.envelope,
              action: TorchSecondaryButton(
                key: const ValueKey<String>('orders-retry'),
                label: l10n.ordersRetry,
                onPressed: () => _refresh(ref),
              ),
            ),
          ),
        ],
      ),
      data: (data) => _loaded(context, ref, data),
    );
  }

  Widget _loaded(
    BuildContext context,
    WidgetRef ref,
    PaginatedResponse<OrderItem> page,
  ) {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    final gutter = context.skin.space.gutterFor(
      MediaQuery.sizeOf(context).width,
    );
    final orders = sortedOrders(page.data);
    final cut = page.nextCursor != null;
    final shown = numbers.format(page.data.length);

    // Order capture is a field-agent/manager action (it matches POST /orders).
    final role = ref.watch(sessionControllerProvider).value?.role;
    final canCreate = role == 'field_agent' || role == 'manager';

    int countOf(String status) =>
        page.data.where((o) => o.status == status).length;
    final submitted = countOf('submitted');

    return _frame(
      context,
      ref,
      phase: page.data.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        if (page.data.isNotEmpty) ...<Widget>[
          StatCluster(
            tiles: <StatTile>[
              StatTile(
                key: const ValueKey<String>('orders-awaiting'),
                eyebrow: l10n.ordersAwaitingEyebrow,
                // A measured zero renders 0: nought orders waiting is a fact
                // worth reading. Over a cut page it is "at least this many",
                // said in the state line rather than silently.
                value: submitted,
                severity: submitted > 0 ? SeverityMarkKind.watch : null,
                stateLine: cut ? l10n.ordersCountPartial(shown) : null,
                subordinates: l10n.ordersAwaitingSubordinates(
                  numbers.format(countOf('confirmed')),
                  numbers.format(countOf('cancelled')),
                ),
              ),
              StatTile(
                key: const ValueKey<String>('orders-value'),
                // The eyebrow names the scope — THESE orders — and the state
                // line says so again when the page was cut. A sum over one
                // page called "total value" is a number true of nothing.
                eyebrow: l10n.ordersValueEyebrow,
                value: page.data.fold<double>(0, (sum, o) => sum + o.total),
                unit: TiqUnit.currency,
                decimals: 2,
                stateLine: cut ? l10n.ordersValuePartial(shown) : null,
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s7),
        ],
        SectionRule(
          l10n.ordersSectionHeading,
          count: orders.isEmpty ? null : orders.length,
          action: canCreate
              ? SectionRuleAction(
                  l10n.ordersNewOrder,
                  onTap: () => _openForm(context, ref),
                )
              : null,
        ),
        const SizedBox(height: TiqSpace.s5),
        if (orders.isEmpty)
          EmptyState(
            headline: l10n.ordersEmptyHeadline,
            drawing: EmptyDrawing.envelope,
            body: l10n.ordersEmptyBody,
            action: canCreate
                ? TorchSecondaryButton(
                    key: const ValueKey<String>('order-create'),
                    label: l10n.ordersNewOrder,
                    icon: Icons.add,
                    onPressed: () => _openForm(context, ref),
                  )
                : null,
          )
        else
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < orders.length; i++)
                  _OrderRow(order: orders[i], last: i == orders.length - 1),
              ],
            ),
          ),
        if (cut) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter.left * 2,
            child: PaginationFooter(
              key: const ValueKey<String>('orders-footer'),
              summary: page.total == null || page.total! <= page.data.length
                  ? l10n.ordersFooterMore(shown)
                  : l10n.ordersFooterOf(shown, numbers.format(page.total!)),
              narrowLine: l10n.ordersFooterScope(shown),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => const OrderFormScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    ref.invalidate(ordersPageProvider);
  }

  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.ordersTitle,
        facts: <String>[l10n.ordersSubtitle],
        trailing: TorchIconButton(
          key: const ValueKey<String>('orders-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.ordersRefresh,
          onPressed: () => _refresh(ref),
        ),
      ),
      children: children,
    );
  }
}

/// One order, as a row named after the shop it was captured in.
class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order, required this.last});

  final OrderItem order;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;

    // The store list is reference data the app already holds; a name is what
    // a manager reads and an id is what a ticket quotes.
    final outlets = ref.watch(outletsListProvider).value;
    final name = outlets
        ?.where((o) => o.id == order.outletId)
        .map((o) => o.name)
        .firstOrNull;

    final status = orderStatusWord(l10n, order.status);
    final lines = l10n.ordersLineCount(order.lineCount);

    return SoftRow(
      key: ValueKey<String>('order-${order.id}'),
      density: SoftRowDensity.tall,
      title: name ?? l10n.ordersUnknownStore,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: l10n.ordersRowSubtitle(status, lines),
      severity: orderSeverity(order.status),
      severityLabel: orderSeverity(order.status) == SoftRowSeverity.none
          ? null
          : status,
      // The order's own id, and the store's when the store is not on the
      // list. Machine-facing, so the identifier face.
      meta: Text(
        name == null ? '${order.id} · ${order.outletId}' : order.id,
        style: skin.text.monoIdent.style(color: skin.palette.ink3),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Money is a figure and goes through the one formatter: mono, tabular,
      // the locale's grouping, the locale's currency prefix.
      trailing: FigureSlot(
        value: order.total,
        role: skin.text.figureS,
        unit: TiqUnit.currency,
        decimals: 2,
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        name ?? l10n.ordersUnknownStore,
        status,
        lines,
        TiqNumber.of(
          context,
        ).format(order.total, unit: TiqUnit.currency, decimals: 2),
      ].join('. '),
    );
  }
}
