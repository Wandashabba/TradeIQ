import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../../core/camera/photo_capture_service.dart';
import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/card.dart';
import '../../../../core/widgets/torchlight/chrome/chrome.dart';
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
/// That is the single grant this screen spends, and it spends it on the only
/// control here a thumb commits with. A finding is **never** a light: zero is
/// a crimson wash on the product's card, a crimson count and the words "Out of
/// stock", and every one of those three is a label.
///
/// ## The shelf is a list of cards — 29 September 2026
///
/// The products were flush blocks divided by 1px rules, which is the table
/// form the card grammar replaced everywhere else in the product when the
/// owner overruled unify §1.3 on 25 September (*"it's still very boxy and I
/// don't need that"*, and then three times on the agent side, most recently
/// *"Match the manager side please"*). Each product is a `TorchCard` now, with
/// a gap of ground between them at `SoftRowSpec`'s own `gapAfter`. See
/// [_SkuBlock].
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

  /// How many products carried a count at the last successful save, so the
  /// saved line can say "Saved 7 of 12" instead of implying the shelf is done.
  int? _savedCounted;

  /// One key per SKU block, so "Jump to the first uncounted" can scroll to it.
  final _blockKeys = <String, GlobalKey>{};

  /// Past this many products the summary rule offers a jump to the first one
  /// still uncounted — a shorter list is one flick from end to end.
  static const int jumpThreshold = 12;

  @override
  void initState() {
    super.initState();
    for (final sku in widget.skus) {
      _units[sku.id] = null;
      _lastStockin[sku.id] = DateTime.now();
      _blockKeys[sku.id] = GlobalKey(debugLabel: 'sku-${sku.id}');
    }
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  int get _counted => _units.values.where((v) => v != null).length;
  int get _outOfStock => _units.values.where((v) => v == 0).length;
  int get _toGo => widget.skus.length - _counted;

  /// Scrolls the first product with no count into view, below the pinned
  /// summary rule rather than under it.
  void _jumpToFirstUncounted() {
    for (final sku in widget.skus) {
      if (_units[sku.id] != null) continue;
      final target = _blockKeys[sku.id]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.25,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
  }

  Future<void> _save() async {
    final counted = _counted;
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
            source: photo.source.name,
          );
      // Queued once. A second Save re-sends the counts, not a duplicate photo.
      _photo = null;
    }
    if (mounted) {
      setState(() {
        _dirty = false;
        _savedCounted = counted;
      });
    }
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
          EmptyState(scope: EmptyScope.inPanel, headline: l10n.s2NoSkus),
        ],
      );
    }

    final total = widget.skus.length;
    final savedCounted = _savedCounted;
    final onJump = total > jumpThreshold && _toGo > 0
        ? _jumpToFirstUncounted
        : null;
    return SectionForm(
      title: l10n.visitSectionStock,
      phase: 'stock',
      dirty: _dirty,
      onSave: _save,
      // "Saved 7 of 12" when the save was part-finished: the section's promise
      // is "saves as you go", and the line must not read as a finished shelf.
      savedLine: savedCounted != null && savedCounted < total
          ? l10n.s2StockSavedPartial(savedCounted, total)
          : l10n.s2StockSaved,
      // The summary is the only fixed chrome: on a 60-SKU shelf it is the one
      // place that says what a Save would record, so it never scrolls away.
      pinned: _SummaryRule(
        counted: _counted,
        outOfStock: _outOfStock,
        toGo: _toGo,
        total: total,
        onJump: onJump,
      ),
      skip: SectionSkipTarget(widget.visitDraftId, AuditSection.stock),
      photo: SectionPhotoField(
        label: l10n.s34PhotoLabel,
        photo: _photo,
        onCaptured: (photo) => _touch(() => _photo = photo),
      ),
      children: <Widget>[
        // What the band gives up when it collapses, first in the body: still
        // above the fold on arrival, and it scrolls like everything else.
        _SummaryDetail(toGo: _toGo, onJump: onJump),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (i, sku) in widget.skus.indexed)
              _SkuBlock(
                key: _blockKeys[sku.id],
                sku: sku,
                value: _units[sku.id],
                contextLine: _contextLine(l10n, TiqNumber.of(context), sku),
                last: i == widget.skus.length - 1,
                onChanged: (v) => _touch(() => _units[sku.id] = v),
              ),
          ],
        ),
      ],
    );
  }
}

/// Whether the pinned band keeps only its counted line, handing the
/// not-counted sentence and the jump ghost to the top of the body.
///
/// The band's three stacked things measured 187dp at 1.0× on a 360×640 phone,
/// 296dp at 1.4× — 46%, already past what unify §4 allows anything holding a
/// place at the top of a route — and 543dp at 2.0×, 85% of the screen given to
/// a summary of a shelf that was no longer on it. [TorchShell.pinnedBandFraction]
/// is the backstop; this is the band fitting inside it by construction, which
/// is how the header's own 40% is kept true.
///
/// Both halves read this: the band drops what it will not keep, and
/// [_SummaryDetail] picks up exactly what the band dropped. It is asked in the
/// widgets rather than in `_StockFormState.build`, because the skin is
/// re-rooted by `TorchlightRoute` *inside* `SectionForm` and is not knowable
/// above it.
bool _bandCollapsed(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_bandScaleProbe) >
        _bandScaleProbe * _bandCollapseAbove;

/// Above this text scale the band collapses.
const double _bandCollapseAbove = 1.3;

/// A font size to run the reader's scaler over: `TextScaler` scales sizes, not
/// factors, so the factor is read back rather than assumed.
const double _bandScaleProbe = 10;

/// "4 counted · 1 out of stock · 8 to go". A rule, not a card, and a live
/// region: it is the only place the agent can see what a Save would record.
/// Pinned beneath the header with a hairline under it; past twelve products
/// with any still uncounted it carries a ghost that jumps to the first.
///
/// When [_bandCollapsed] says so, the counted line travels alone and
/// [_SummaryDetail] carries the sentence and the ghost at the top of the body.
/// The spoken label does not change: a screen reader hears the count and what
/// is still to go as one sentence either way.
class _SummaryRule extends StatelessWidget {
  const _SummaryRule({
    required this.counted,
    required this.outOfStock,
    required this.toGo,
    required this.total,
    this.onJump,
  });

  final int counted;
  final int outOfStock;
  final int toGo;
  final int total;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    // Collapsed, the band keeps the counted line alone. The spoken label is
    // unchanged either way: a screen reader hears the count and what is still
    // to go as one sentence, wherever the words are drawn.
    final collapsed = _bandCollapsed(context);
    final jump = collapsed ? null : onJump;
    final sentence = !collapsed;
    return Column(
      key: const ValueKey<String>('stock-summary'),
      // The shell caps the band at 40% of the screen, which means the incoming
      // constraints are BOUNDED — without this the rule stretches to fill the
      // whole cap instead of being as tall as its words.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: TiqSpace.s2),
        Semantics(
          liveRegion: true,
          label: toGo > 0
              ? '${l10n.s2CountedOf(counted, total)}. ${l10n.s2PartCounted(toGo)}'
              : l10n.s2CountedOf(counted, total),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.s2Summary(counted, outOfStock, toGo),
                style: skin.text.bodyStrong.style(color: skin.palette.ink1),
              ),
              if (sentence && toGo > 0) ...<Widget>[
                const SizedBox(height: TiqSpace.s1),
                // What a Save would record, said before it is pressed. Null is
                // a first-class count now (#410), and the sentence is what
                // stops an agent believing a part-finished save accuses the
                // store.
                Text(
                  l10n.s2PartCounted(toGo),
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
              ],
            ],
          ),
        ),
        if (jump != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('stock-jump-uncounted'),
              label: l10n.s2JumpToUncounted,
              onPressed: jump,
            ),
          ),
        const SizedBox(height: TiqSpace.s2),
        // The hairline that makes the band a rule rather than a card, and
        // what the scrolled blocks disappear beneath.
        Container(
          height: skin.depth.borderWidth,
          color: skin.palette.edgeStructure,
        ),
      ],
    );
  }
}

/// What the band hands to the body at large type: the not-counted sentence and
/// the jump. The same words and the same key, drawn in the one place they
/// still fit — the band is already spoken as a live region, so this carries no
/// semantics of its own and the sentence is never announced twice.
class _SummaryDetail extends StatelessWidget {
  const _SummaryDetail({required this.toGo, this.onJump});

  final int toGo;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    // Exactly what the band dropped, and nothing when it dropped nothing.
    if (!_bandCollapsed(context)) return const SizedBox.shrink();
    final jump = onJump;
    if (toGo <= 0 && jump == null) return const SizedBox.shrink();
    return Column(
      key: const ValueKey<String>('stock-summary-detail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (toGo > 0)
          ExcludeSemantics(
            child: Text(
              l10n.s2PartCounted(toGo),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
        if (jump != null)
          TorchTertiaryButton(
            key: const ValueKey<String>('stock-jump-uncounted'),
            label: l10n.s2JumpToUncounted,
            onPressed: jump,
          ),
        SizedBox(height: skin.space.blockGap),
      ],
    );
  }
}

/// ONE SKU: the name and its recommended price, the server's context, and the
/// stepper.
///
/// ## A card, not a rule — amending this file's own comment, 29 September 2026
///
/// What stood here was: *"Separated by a real rule rather than wrapped in a
/// card — twelve rounded boxes down a phone is the uniform-cards failure, and
/// the rule is what the row grammar uses everywhere else."* Both halves of
/// that were overtaken.
///
/// The "uniform rounded cards" failure is unify §1.3's wording, and **the
/// owner overruled §1.3 on 25 September 2026** after looking at the running
/// screens twice — *"I hate this box style"*, *"it's still very boxy and I
/// don't need that"* — which is recorded in `SoftRowForm` and in
/// `docs/design/spec/unify.md`. And the rule is emphatically **not** what the
/// row grammar uses everywhere else any more: `SoftRowSpec` resolves a list
/// row to a radius-22 `surface` card with a gap of ground and **no rule at
/// all**, because "a line between two objects that already have edges is the
/// table look the card grammar exists to leave behind".
///
/// So this block stopped being the one place in the product that still drew
/// `Container(height: borderWidth, color: edgeStructure)` between repeated
/// things. The owner's note on the agent side, three times and most recently
/// on 29 September 2026 — *"Match the manager side please"* — is about exactly
/// this: the manager's lists are objects on a ground and this one was a table.
///
/// ## The finding is three channels and none of them is a bar
///
/// A product counted at zero used to carry **five**: a 3px crimson bar down
/// the leading edge, a 12dp indent to clear it, the stepper's crimson count,
/// the word "Out of stock" and the shoppers-switch sentence. The approved
/// mockup gives it three — the row washes, the count goes crimson, the chip
/// says "Out of stock" — and three is what it has:
///
/// * the **card washes** `torchChipWash(skin, bad)`, the same declared
///   composite the chips and the state tiles use;
/// * the **count** goes crimson, from `CountStepper`'s own `zeroIsFinding`;
/// * the **word** "Out of stock" says it.
///
/// The bar and its indent are gone. A 3px stripe inside a radius-22
/// silhouette is a scratch on the fill, which is the argument `SoftRowSpec`
/// made when the rows' severity bars became dots.
///
/// **The `IntrinsicHeight` hazard goes with it.** The bar had to be a `Stack`
/// overlay because `FigureSlot` measures itself with a `LayoutBuilder`, a
/// `LayoutBuilder` cannot answer an intrinsic query, and a stretch child of a
/// `Row` inside an `IntrinsicHeight` asks one — which took the whole too-far
/// screen down once already. A fill is painted by the card's own
/// `DecoratedBox` and asks nothing of its child's height. The shoppers-switch
/// sentence stays: it is information, not a fourth severity channel.
class _SkuBlock extends StatelessWidget {
  const _SkuBlock({
    super.key,
    required this.sku,
    required this.value,
    required this.contextLine,
    required this.last,
    required this.onChanged,
  });

  final Sku sku;
  final int? value;
  final String contextLine;

  /// The last product on the shelf takes no gap of ground beneath it — the
  /// body's own block gap follows.
  final bool last;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final finding = value == 0;

    final block = TorchCard(
      key: finding ? ValueKey<String>('finding-${sku.id}') : null,
      fill: finding ? torchChipWash(skin, skin.palette.bad) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // A Wrap, not a Row: the name and its price share a line while they
          // fit, and at 2.0× in Afrikaans — "R 1 284,99" beside a two-line
          // product name — the price drops beneath the name instead of
          // overflowing the block by 12dp.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: TiqSpace.s3,
            runSpacing: TiqSpace.s1,
            children: <Widget>[
              Text(
                sku.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: skin.text.titleM.style(color: skin.palette.ink1),
              ),
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
          SizedBox(height: skin.space.intraBlock),
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

    // A gap of ground between the cards, never a rule — `SoftRowSpec`'s
    // `gapAfter`, at the same s3, so a shelf of products and a list of rows
    // are spaced identically.
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : skin.space.intraBlock),
      child: block,
    );
  }
}
