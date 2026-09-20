import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../audit/data/skus_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/orders_repository.dart';

/// IN-STORE ORDER CAPTURE — pick a store, set quantities, submit.
///
/// ```text
///   ← Orders
///   New order
///   ── Which store ────────────────────────────
///   Store
///   ┌──────────────────────────────────┐
///   │ Kasi Corner Spaza              › │
///   └──────────────────────────────────┘
///   ── Line items  12 ─────────────────────────
///   ▏ Coca-Cola 2L                    R 24,99
///   ▏ [   3   ] [ − ][ + ]
///   Order total                       R 149,50
///   [ ☾ ]  [       Create the order        ]
/// ```
///
/// ## A quantity is a count, so it is the count stepper
///
/// The old line was a 30dp text label between two 18dp icon buttons — under
/// the tap-target floor, unreadable at 2.0×, and with no way to type 48
/// without pressing plus forty-eight times. Unify §1.8's stepper is a value
/// trough with an adjacent ± pair and a number sheet behind a tap on the
/// trough.
///
/// **Nought is not nothing.** A SKU with no quantity is *not on this order*; a
/// SKU explicitly set to nought is a line the agent decided about, and it is
/// still not sent — the stepper says both in words, and the submit builds its
/// lines from quantities above nought exactly as it always did.
///
/// ## The amber, counted
///
/// Not a tab root: the thumb zone carries the one commit. Night's two content
/// grants go to **one** object, "Create the order", and only when there is a
/// store and at least one line — a primary that is lit and refuses is a
/// primary nobody trusts. Day and Veld light the same block.
class OrderFormScreen extends ConsumerWidget {
  const OrderFormScreen({super.key});

  /// "Create the order". Rung 1, and the only claim this route makes.
  static const String submitClaimId = 'order-form-submit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _OrderForm());
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm();

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  String? _outletId;

  /// Quantities by SKU id. **A SKU absent from this map is not on the order**;
  /// a SKU mapped to 0 is one somebody looked at and set to nought. Both are
  /// left out of the request, and the two are different states on screen.
  final Map<String, int> _quantity = <String, int>{};

  bool _submitting = false;

  void _setQuantity(String skuId, int? value) {
    setState(() {
      if (value == null) {
        _quantity.remove(skuId);
      } else {
        _quantity[skuId] = value;
      }
    });
  }

  double _total(List<Sku> skus) {
    var total = 0.0;
    for (final sku in skus) {
      total += (_quantity[sku.id] ?? 0) * sku.effectivePrice;
    }
    return total;
  }

  List<OrderLine> _lines(List<Sku> skus) => <OrderLine>[
    for (final sku in skus)
      if ((_quantity[sku.id] ?? 0) > 0)
        OrderLine(
          skuId: sku.id,
          quantity: _quantity[sku.id]!,
          unitPrice: sku.effectivePrice,
        ),
  ];

  Future<void> _submit(List<Sku> skus) async {
    final l10n = context.l10n;
    final lines = _lines(skus);
    if (_outletId == null || lines.isEmpty) return;

    setState(() => _submitting = true);
    final bool created;
    try {
      await ref
          .read(ordersRepositoryProvider)
          .createOrder(outletId: _outletId!, lines: lines);
      ref.invalidate(ordersPageProvider);
      created = true;
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showTorchToast(
        context,
        message: l10n.orderFormFailed,
        kind: ToastKind.failure,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    // Leaving is not inside the try: a router with nothing to pop must not be
    // reported as a failed order.
    if (created && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final outlets = ref.watch(outletsListProvider);
    final outletId = _outletId;
    // SKUs are store-scoped (#112) — there is nothing meaningful to show until
    // a store is picked, so the list is only watched once one is.
    final skus = outletId == null
        ? null
        : ref.watch(skusListProvider(outletId));

    final loaded = switch (skus) {
      AsyncData<List<Sku>>(:final value) => value,
      _ => null,
    };
    final ready =
        _outletId != null && loaded != null && _lines(loaded).isNotEmpty;

    return TorchScope(
      skin: skin,
      phase: _submitting ? 'submitting' : (ready ? 'ready' : 'form'),
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        TorchPrimaryButton.claim(OrderFormScreen.submitClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: l10n.orderFormTitle,
          back: TorchIconButton(
            icon: Icons.arrow_back,
            semanticLabel: l10n.orderFormBack,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        primary: TorchPrimaryButton(
          key: const ValueKey<String>('order-save-button'),
          label: l10n.orderFormSubmit,
          claimId: OrderFormScreen.submitClaimId,
          busy: _submitting,
          blockedReason: ready ? null : l10n.orderFormBlocked,
          onPressed: ready && !_submitting ? () => _submit(loaded) : null,
        ),
        children: <Widget>[
          SectionRule(l10n.orderFormStoreHeading),
          const SizedBox(height: TiqSpace.s4),
          outlets.when(
            loading: () => Skeleton(
              label: l10n.orderFormStore,
              child: const SkeletonShell(height: 72, outlined: true),
            ),
            error: (error, stack) => ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.orderFormStoresFailed,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('order-outlets-retry'),
                label: l10n.ordersRetry,
                onPressed: () => ref.invalidate(outletsListProvider),
              ),
            ),
            data: (list) => TorchPickerField<String>(
              key: const ValueKey<String>('order-outlet-field'),
              label: l10n.orderFormStore,
              value: _outletId,
              options: <PickerOption<String>>[
                for (final outlet in list)
                  PickerOption<String>(
                    value: outlet.id,
                    label: outlet.name,
                    identifier: outlet.code,
                  ),
              ],
              notChosenLine: l10n.orderFormStoreNotChosen,
              onChanged: (id) => setState(() {
                _outletId = id;
                // A quantity belongs to a shelf in one shop. Carrying it into
                // another store would order twelve of something that store
                // does not stock.
                _quantity.clear();
              }),
            ),
          ),
          const SizedBox(height: TiqSpace.s7),

          SectionRule(
            l10n.orderFormLinesHeading,
            count: loaded == null || loaded.isEmpty ? null : loaded.length,
          ),
          const SizedBox(height: TiqSpace.s4),
          if (skus == null)
            EmptyState(
              scope: EmptyScope.inPanel,
              headline: l10n.orderFormPickStoreFirst,
            )
          else
            skus.when(
              loading: () => Skeleton(
                label: l10n.orderFormLinesHeading,
                child: const SkeletonRows(count: 4, rowHeight: 96),
              ),
              error: (error, stack) => ErrorState(
                scope: ErrorScope.inline,
                message: TorchErrorMessage(
                  kind: TorchErrorKind.unknown,
                  headline: l10n.orderFormSkusFailed,
                  body: humanErrorMessage(error, l10n),
                  offersRetry: true,
                ),
                action: TorchSecondaryButton(
                  key: const ValueKey<String>('order-skus-retry'),
                  label: l10n.ordersRetry,
                  onPressed: () => ref.invalidate(skusListProvider(outletId!)),
                ),
              ),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      scope: EmptyScope.inPanel,
                      headline: l10n.orderFormNoSkusHeadline,
                      body: l10n.orderFormNoSkusBody,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final sku in list) ...<Widget>[
                          _SkuLine(
                            key: ValueKey<String>('sku-row-${sku.id}'),
                            sku: sku,
                            quantity: _quantity[sku.id],
                            onChanged: (value) => _setQuantity(sku.id, value),
                          ),
                          const SizedBox(height: TiqSpace.s6),
                        ],
                        const SizedBox(height: TiqSpace.s2),
                        _OrderTotal(value: _total(list)),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// One SKU: its name, its unit price, and the count stepper that puts it on
/// the order.
class _SkuLine extends StatelessWidget {
  const _SkuLine({
    super.key,
    required this.sku,
    required this.quantity,
    required this.onChanged,
  });

  final Sku sku;
  final int? quantity;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final gutter = skin.space.gutterFor(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TorchBleed(
          extra: gutter.left * 2,
          child: SoftRow(
            density: SoftRowDensity.compact,
            title: sku.name,
            trailing: FigureSlot(
              value: sku.effectivePrice,
              role: skin.text.figureS,
              unit: TiqUnit.currency,
              decimals: 2,
            ),
            separator: SoftRowSeparator.none,
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        CountStepper(
          key: ValueKey<String>('sku-qty-${sku.id}'),
          label: l10n.orderFormQuantity,
          value: quantity,
          onChanged: onChanged,
          // Nought on an order is a decision, not a finding: nobody raises a
          // task because an agent ordered none of something.
          zeroIsFinding: false,
          findingWord: l10n.orderFormNoneOrdered,
          findingLine: l10n.orderFormNoneOrderedLine,
          notCountedLine: l10n.orderFormNotOrdered,
          decreaseLabel: l10n.orderFormOneFewer,
          increaseLabel: l10n.orderFormOneMore,
          typeLabel: l10n.orderFormTypeQuantity,
          sheetTitle: sku.name,
          setBlockedReason: l10n.orderFormTypeQuantityFirst,
          cancelLabel: l10n.orderFormCancel,
          setLabel: l10n.orderFormSet,
        ),
      ],
    );
  }
}

/// The number the agent reads back to the shop owner.
class _OrderTotal extends StatelessWidget {
  const _OrderTotal({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;

    return Row(
      key: const ValueKey<String>('order-total'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Text(
            l10n.orderFormTotal,
            style: skin.text.label.style(color: skin.palette.ink2),
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        FigureSlot(
          value: value,
          role: skin.text.figureM,
          unit: TiqUnit.currency,
          decimals: 2,
          semanticsLabel:
              '${l10n.orderFormTotal}. '
              '${TiqNumber.of(context).format(value, unit: TiqUnit.currency, decimals: 2)}',
        ),
      ],
    );
  }
}
