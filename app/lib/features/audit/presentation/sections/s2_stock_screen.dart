import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../../core/camera/photo_capture_service.dart';
import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../core/widgets/torchlight/state.dart';
import '../../../../l10n/l10n.dart';
import '../../data/photos_repository.dart';
import '../../data/skus_repository.dart';
import '../../data/stock_repository.dart';
import '../../data/visit_progress.dart';
import 'section_form.dart';
import 'section_photo.dart';

/// S2 — STOCK & AVAILABILITY. Counting a shelf one-handed, in a dark aisle,
/// where an out-of-stock is the most valuable thing the agent can record — and
/// where a product nobody looked at is never reported as empty.
///
/// ## The count that is not zero
///
/// An uncounted SKU travels as **null** (#389, and the server takes it since
/// #410). This used to be `?? 0`, and that expression is the bug: a shelf the
/// agent had not walked to yet was submitted as an empty one, raising a
/// stock-out task and dragging on-shelf availability down for a SKU nobody had
/// looked at. `CountStepper` carries the same distinction in the control —
/// *not counted* is an em dash and the word, never a zero — and the summary
/// rule states how many are still to go.
///
/// ## Amber
///
/// One object, and only when there is something to commit: the inline Save.
/// Zero is a finding and the finding is a bar, a silhouette and two sentences
/// — never a light.
class S2StockScreen extends ConsumerWidget {
  const S2StockScreen({
    super.key,
    required this.visitDraftId,
    required this.outletId,
  });

  final String visitDraftId;
  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skus = ref.watch(skusListProvider(outletId));
    return skus.when(
      loading: () => SectionForm(
        title: l10n.visitSectionStock,
        phase: 'stock-loading',
        children: const <Widget>[SkeletonRows(count: 4, rowHeight: 120)],
      ),
      // The product list is what this section is about, so a list that did not
      // load is not an empty section — it is a section the app cannot
      // establish, and the hub already renders it as can't-confirm (#389).
      error: (err, _) => SectionForm(
        title: l10n.visitSectionStock,
        phase: 'stock-error',
        children: <Widget>[
          ErrorState(
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.unknown,
              headline: l10n.s2LoadFailed('$err'),
              body: l10n.visitCantConfirmProducts,
              offersRetry: true,
            ),
            action: TorchSecondaryButton(
              label: l10n.visitRetry,
              onPressed: () => ref.invalidate(skusListProvider(outletId)),
            ),
          ),
        ],
      ),
      data: (list) => _StockForm(
        visitDraftId: visitDraftId,
        outletId: outletId,
        skus: list,
      ),
    );
  }
}

class _StockForm extends ConsumerStatefulWidget {
  const _StockForm({
    required this.visitDraftId,
    required this.outletId,
    required this.skus,
  });

  final String visitDraftId;
  final String outletId;
  final List<Sku> skus;

  @override
  ConsumerState<_StockForm> createState() => _StockFormState();
}

class _StockFormState extends ConsumerState<_StockForm> {
  /// The count on the shelf — the one thing here the agent can actually
  /// observe, and the one that raises a stockout task. Null means "not counted
  /// yet", which is a different thing from zero.
  final _units = <String, int?>{};
  final _lastStockin = <String, DateTime>{};
  bool _dirty = false;

  /// The optional shelf photo (#310). A count has no position of its own; a
  /// geotagged photo taken while counting is what places it for
  /// `stock_outside_outlet` (#248).
  CapturedPhoto? _photo;

  @override
  void initState() {
    super.initState();
    for (final sku in widget.skus) {
      _units[sku.id] = null;
      _lastStockin[sku.id] = DateTime.now();
    }
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  int get _counted => _units.values.where((v) => v != null).length;
  int get _outOfStock => _units.values.where((v) => v == 0).length;
  int get _toGo => widget.skus.length - _counted;

  Future<void> _save() async {
    final entries = widget.skus.map((sku) {
      return StockEntry(
        skuId: sku.id,
        // An uncounted SKU travels as null, not 0 (#389/#410). A part-finished
        // count must never accuse a store of being out of stock on products
        // the agent has not reached.
        unitsAvailable: _units[sku.id],
        lastStockinDate: _lastStockin[sku.id]!,
      );
    }).toList();

    await ref
        .read(stockRepositoryProvider)
        .saveStock(visitDraftId: widget.visitDraftId, entries: entries);

    final photo = _photo;
    if (photo != null) {
      await ref
          .read(queuedPhotosRepositoryProvider)
          .queuePhoto(
            visitDraftId: widget.visitDraftId,
            section: 'stock',
            dataUrl: photo.dataUrl,
            gpsTag: photo.gpsTag,
            capturedAt: photo.capturedAt,
          );
      // Queued once. A second Save re-sends the counts, not a duplicate photo.
      _photo = null;
    }
    if (mounted) setState(() => _dirty = false);
  }

  /// "selling ~4/day · 12 days cover" — read-only server context, not agent
  /// input (#112: an agent standing at a shelf cannot observe either number).
  String _contextLine(AppLocalizations l10n, TiqNumber numbers, Sku sku) {
    // Through the locale formatter: `4.2` in English is `4,2` in Afrikaans.
    final velocity = numbers.format(sku.velocityAvg, decimals: 1);
    final days = sku.daysOutOfStock;
    if (sku.velocityAvg > 0) {
      return days > 0
          ? l10n.s2ContextSellingOutOfStock(velocity, days)
          : l10n.s2ContextSelling(velocity);
    }
    return days > 0
        ? l10n.s2ContextNoHistoryOutOfStock(days)
        : l10n.s2ContextNoHistory;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (widget.skus.isEmpty) {
      return SectionForm(
        title: l10n.visitSectionStock,
        phase: 'stock-empty',
        skip: SectionSkipTarget(widget.visitDraftId, AuditSection.stock),
        children: <Widget>[
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.s2NoSkus,
          ),
        ],
      );
    }

    return SectionForm(
      title: l10n.visitSectionStock,
      phase: 'stock',
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.s2StockSaved,
      skip: SectionSkipTarget(widget.visitDraftId, AuditSection.stock),
      photo: SectionPhotoField(
        label: l10n.s34PhotoLabel,
        photo: _photo,
        onCaptured: (photo) => _touch(() => _photo = photo),
      ),
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SummaryRule(
              counted: _counted,
              outOfStock: _outOfStock,
              toGo: _toGo,
              total: widget.skus.length,
            ),
            for (final (i, sku) in widget.skus.indexed)
              _SkuBlock(
                sku: sku,
                value: _units[sku.id],
                contextLine: _contextLine(l10n, TiqNumber.of(context), sku),
                first: i == 0,
                onChanged: (v) => _touch(() => _units[sku.id] = v),
              ),
          ],
        ),
      ],
    );
  }
}

/// "4 counted · 1 out of stock · 8 to go". A rule, not a card, and a live
/// region: it is the only place the agent can see what a Save would record.
class _SummaryRule extends StatelessWidget {
  const _SummaryRule({
    required this.counted,
    required this.outOfStock,
    required this.toGo,
    required this.total,
  });

  final int counted;
  final int outOfStock;
  final int toGo;
  final int total;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      label: l10n.s2CountedOf(counted, total),
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey<String>('stock-summary'),
        padding: const EdgeInsets.only(bottom: TiqSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.s2Summary(counted, outOfStock, toGo),
              style: skin.text.bodyStrong.style(color: skin.palette.ink1),
            ),
            if (toGo > 0) ...<Widget>[
              const SizedBox(height: TiqSpace.s1),
              // What a Save would record, said before it is pressed. Null is a
              // first-class count now (#410), and the sentence is what stops
              // an agent believing a part-finished save accuses the store.
              Text(
                l10n.s2PartCounted(toGo),
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ONE SKU: the name and its recommended price, the server's context, and the
/// stepper. Separated by a real rule rather than wrapped in a card — twelve
/// rounded boxes down a phone is the uniform-cards failure, and the rule is
/// what the row grammar uses everywhere else.
class _SkuBlock extends StatelessWidget {
  const _SkuBlock({
    required this.sku,
    required this.value,
    required this.contextLine,
    required this.first,
    required this.onChanged,
  });

  final Sku sku;
  final int? value;
  final String contextLine;
  final bool first;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final finding = value == 0;
    final barWidth = skin.mode == SkinMode.veld ? 4.0 : 3.0;

    final block = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        finding ? barWidth + TiqSpace.s3 : 0,
        TiqSpace.s4,
        0,
        TiqSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  sku.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: skin.text.titleM.style(color: skin.palette.ink1),
                ),
              ),
              const SizedBox(width: TiqSpace.s3),
              // Through the locale formatter, never `toStringAsFixed`: R and
              // the decimal separator are the locale's business.
              FigureSlot(
                key: ValueKey<String>('rrp-${sku.id}'),
                value: sku.rrp,
                role: skin.text.figureS,
                decimals: 2,
                unit: TiqUnit.currency,
                color: skin.palette.ink3,
                semanticsLabel: l10n.s2Rrp(
                  TiqNumber.of(
                    context,
                  ).format(sku.rrp, unit: TiqUnit.currency, decimals: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            contextLine,
            key: ValueKey<String>('context-${sku.id}'),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s3),
          CountStepper(
            key: ValueKey<String>('units-${sku.id}'),
            label: l10n.s2UnitsOnShelf,
            value: value,
            onChanged: onChanged,
            zeroIsFinding: true,
            findingWord: l10n.s2OutOfStockWord,
            findingLine: l10n.s2OutOfStockRaisesTask,
            notCountedLine: l10n.s2NotCounted,
            help: finding ? l10n.s2ShoppersSwitch : null,
            decreaseLabel: l10n.s2OneFewer,
            increaseLabel: l10n.s2OneMore,
            typeLabel: l10n.s2TypeCount,
            sheetTitle: sku.name,
            setBlockedReason: l10n.s2TypeCountFirst,
            cancelLabel: l10n.s2Cancel,
            setLabel: l10n.s2Set,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!first)
          Container(
            height: skin.depth.borderWidth,
            color: skin.palette.edgeStructure,
          ),
        if (!finding)
          block
        else
          // The severity bar is an OVERLAY, never a stretch child of a Row
          // inside an `IntrinsicHeight`: `FigureSlot` measures itself with a
          // `LayoutBuilder`, and a `LayoutBuilder` cannot answer an intrinsic
          // query — which took the whole too-far screen down once already.
          Stack(
            key: ValueKey<String>('finding-${sku.id}'),
            children: <Widget>[
              block,
              PositionedDirectional(
                top: 0,
                bottom: 0,
                start: 0,
                width: barWidth,
                child: ColoredBox(color: skin.palette.bad),
              ),
            ],
          ),
      ],
    );
  }
}
