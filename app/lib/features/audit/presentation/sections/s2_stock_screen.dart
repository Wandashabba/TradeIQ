import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/camera/photo_capture_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/photo_capture_field.dart';
import '../../../../l10n/l10n.dart';
import '../../data/photos_repository.dart';
import '../../data/skus_repository.dart';
import '../../data/stock_repository.dart';

/// S2 — Stock & Availability capture. One row per client SKU; on save the
/// entries are persisted locally and queued for sync (POST /stock).
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
    final skus = ref.watch(skusListProvider(outletId));
    return skus.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text(context.l10n.s2LoadFailed('$err'))),
      data: (list) => _StockForm(visitDraftId: visitDraftId, skus: list),
    );
  }
}

class _StockForm extends ConsumerStatefulWidget {
  const _StockForm({required this.visitDraftId, required this.skus});

  final String visitDraftId;
  final List<Sku> skus;

  @override
  ConsumerState<_StockForm> createState() => _StockFormState();
}

class _StockFormState extends ConsumerState<_StockForm> {
  /// The count on the shelf — the one thing here the agent can actually observe,
  /// and the one that raises a stockout task. Null means "not counted yet",
  /// which is a different thing from zero.
  final _units = <String, int?>{};
  final _lastStockin = <String, DateTime>{};
  bool _saved = false;

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

  Future<void> _save() async {
    final entries = widget.skus.map((sku) {
      return StockEntry(
        skuId: sku.id,
        // An uncounted SKU travels as null, not 0 (#389).
        //
        // This used to be `?? 0`, and that expression is the bug: a shelf the
        // agent had not walked to yet was submitted as an empty one, raising a
        // stock-out task and dragging on-shelf availability down for a SKU
        // nobody had looked at. The hub still refuses to submit a visit with
        // uncounted SKUs — but a half-finished save must not accuse the store
        // in the meantime.
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
    if (mounted) setState(() => _saved = true);
  }

  /// Tap the number to type it. A shelf can hold sixty units, and nobody taps
  /// "+" sixty times — the +/- is for adjusting, this is for entering.
  Future<void> _typeCount(Sku sku) async {
    final entered = await showDialog<int>(
      context: context,
      builder: (_) => _CountInputDialog(sku: sku, initial: _units[sku.id]),
    );
    if (entered != null && mounted) {
      setState(() => _units[sku.id] = entered);
    }
  }

  /// "selling ~4/day · 12 days cover" — read-only server context, not agent
  /// input (#112: an agent standing at a shelf cannot observe either number).
  String _contextLine(AppLocalizations l10n, Sku sku) {
    final velocity = sku.velocityAvg.toStringAsFixed(1);
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
    final colors = context.colors;
    final l10n = context.l10n;
    if (widget.skus.isEmpty) {
      return Center(child: Text(l10n.s2NoSkus));
    }
    // No section header here — the shared section wrapper already titles this
    // "Stock & availability".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sku in widget.skus)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _SkuCard(
              zero: _units[sku.id] == 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          sku.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.ink1,
                          ),
                        ),
                      ),
                      Text(
                        l10n.s2Rrp(sku.rrp.toStringAsFixed(2)),
                        style: TextStyle(fontSize: 12, color: colors.ink3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contextLine(l10n, sku),
                    key: ValueKey('context-${sku.id}'),
                    style: TextStyle(fontSize: 12, color: colors.ink3),
                  ),
                  const SizedBox(height: 10),
                  CountStepper(
                    key: ValueKey('units-${sku.id}'),
                    value: _units[sku.id],
                    zeroIsFinding: true,
                    onChanged: (v) => setState(() => _units[sku.id] = v),
                    onEdit: () => _typeCount(sku),
                  ),
                  if (_units[sku.id] == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: colors.glass
                          ? const _OutOfStockNote()
                          : Row(
                        children: [
                          // The icon keeps raw crit (a glyph paired with the
                          // word); the WORDS take the AA-safe critText, which
                          // clears 4.5:1 on the card's surface1 in both themes —
                          // raw crit as text fails AA in dark.
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 15,
                            color: colors.crit,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              l10n.s2OutOfStockRaisesTask,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colors.critText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        PhotoCaptureField(
          label: l10n.s34PhotoLabel,
          geotag: true,
          onPhotoCaptured: (photo) => setState(() => _photo = photo),
        ),
        const SizedBox(height: 12),
        // The inline save is the ONLY thing that persists this section — the
        // wrapper's "Done" button just pops back to the hub. It must stay.
        AgentButton(label: l10n.s2SaveStock, onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.s2StockSaved,
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

/// Owns its own controller, so the field is never disposed while the dialog is
/// still animating away.
class _CountInputDialog extends StatefulWidget {
  const _CountInputDialog({required this.sku, required this.initial});

  final Sku sku;
  final int? initial;

  @override
  State<_CountInputDialog> createState() => _CountInputDialogState();
}

class _CountInputDialogState extends State<_CountInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sku.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: ValueKey('units-input-${widget.sku.id}'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 16, color: colors.ink1),
              decoration: InputDecoration(
                labelText: context.l10n.s2UnitsOnShelf,
                labelStyle: TextStyle(color: colors.ink3),
                isDense: true,
                filled: true,
                fillColor: colors.surface2,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusControl),
                  borderSide: BorderSide(color: colors.lineStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusControl),
                  borderSide: BorderSide(color: colors.brand),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AgentButton(
                    label: context.l10n.s2Cancel,
                    secondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AgentButton(
                    key: ValueKey('units-confirm-${widget.sku.id}'),
                    label: context.l10n.s2Set,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(int.tryParse(_controller.text.trim())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One SKU's card. Glass: a no-blur tile (it repeats down the list) whose rim
/// turns crit on an out-of-stock, so the finding reads from arm's length.
class _SkuCard extends StatelessWidget {
  const _SkuCard({required this.zero, required this.child});

  final bool zero;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!colors.glass) return PanelCard(child: child);
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      rimColor: zero ? LumenStatus.crit.swatchOf(colors).rim : null,
      padding: const EdgeInsets.all(15),
      child: child,
    );
  }
}

/// Zero is the finding, not an empty box: it raises a task, and the note says
/// why that matters. An opaque crit wash so the words clear AA on their own.
class _OutOfStockNote extends StatelessWidget {
  const _OutOfStockNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final crit = LumenStatus.crit.swatchOf(colors);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(crit.tint, colors.surface1),
        borderRadius: BorderRadius.circular(LumenGlass.radiusIconTile),
        border: Border.all(color: crit.rim),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_outlined,
              size: 15,
              color: colors.crit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.s2OutOfStockRaisesTask,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: crit.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.s2ShoppersSwitch,
                  style: TextStyle(fontSize: 11, height: 1.45, color: crit.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

