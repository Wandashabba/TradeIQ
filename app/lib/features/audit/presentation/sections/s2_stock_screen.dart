import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
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
      error: (err, _) => Center(child: Text('Failed to load SKUs: $err')),
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
        // An uncounted SKU is recorded as 0 — the server reads that as out of
        // stock, which is why the hub will not let the visit be submitted until
        // every SKU has actually been counted.
        unitsAvailable: _units[sku.id] ?? 0,
        lastStockinDate: _lastStockin[sku.id]!,
      );
    }).toList();

    await ref
        .read(stockRepositoryProvider)
        .saveStock(visitDraftId: widget.visitDraftId, entries: entries);
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
  String _contextLine(Sku sku) {
    final velocity = sku.velocityAvg > 0
        ? 'Selling ~${sku.velocityAvg.toStringAsFixed(1)}/day'
        : 'No sales history yet';
    final oos = sku.daysOutOfStock > 0
        ? ' · out of stock ${sku.daysOutOfStock}d'
        : '';
    return '$velocity$oos';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (widget.skus.isEmpty) {
      return const Center(child: Text('No SKUs configured for this client.'));
    }
    // No section header here — the shared section wrapper already titles this
    // "Stock & availability".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sku in widget.skus)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: PanelCard(
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
                        'RRP ${sku.rrp.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: colors.ink3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contextLine(sku),
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
                      child: Row(
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
                              'Out of stock — this raises a task for the manager',
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
        const SizedBox(height: 12),
        // The inline save is the ONLY thing that persists this section — the
        // wrapper's "Done" button just pops back to the hub. It must stay.
        AgentButton(label: 'Save stock', onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Stock saved — queued for sync',
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
                labelText: 'Units on shelf',
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
                    label: 'Cancel',
                    secondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AgentButton(
                    key: ValueKey('units-confirm-${widget.sku.id}'),
                    label: 'Set',
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
