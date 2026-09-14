import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/lumen_palette.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/photo_capture_field.dart';
import '../../data/photos_repository.dart';
import '../../data/pricing_repository.dart';
import '../../data/skus_repository.dart';

/// S5 — Pricing & Promotions capture. One row per client SKU (actual price,
/// promo active, comms rating); on save the entries are queued for sync
/// (POST /pricing).
class S5PricingPromotionsScreen extends ConsumerWidget {
  const S5PricingPromotionsScreen({
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
      data: (list) => _PricingForm(visitDraftId: visitDraftId, skus: list),
    );
  }
}

class _PricingForm extends ConsumerStatefulWidget {
  const _PricingForm({required this.visitDraftId, required this.skus});

  final String visitDraftId;
  final List<Sku> skus;

  @override
  ConsumerState<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends ConsumerState<_PricingForm> {
  final _price = <String, TextEditingController>{};
  final _comms = <String, TextEditingController>{};
  final _promo = <String, bool>{};
  bool _saved = false;
  String? _photoDataUrl;

  @override
  void initState() {
    super.initState();
    for (final sku in widget.skus) {
      _price[sku.id] = TextEditingController();
      _comms[sku.id] = TextEditingController();
      _promo[sku.id] = false;
    }
  }

  @override
  void dispose() {
    for (final c in [..._price.values, ..._comms.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Untouched SKUs (no price entered) are skipped.
    final entries = widget.skus
        .where((sku) => _price[sku.id]!.text.trim().isNotEmpty)
        .map(
          (sku) => PricingEntry(
            skuId: sku.id,
            priceActual: double.tryParse(_price[sku.id]!.text) ?? 0.0,
            promoActive: _promo[sku.id] ?? false,
            // Manual promo-materials checklist is a follow-up; empty for now.
            promoMaterialsDetected: const {},
            commsRating: int.tryParse(_comms[sku.id]!.text) ?? 0,
          ),
        )
        .toList();

    await ref
        .read(pricingRepositoryProvider)
        .savePricing(visitDraftId: widget.visitDraftId, entries: entries);

    // The shelf-price photo is evidence, and the corpus a real price OCR (#2)
    // would be trained on. Prices themselves stay manually entered — the OCR
    // seam (`ocr.stub.ts`) is a passthrough that returns whatever it was given,
    // so nothing here is machine-read yet, and the UI does not pretend it is.
    if (_photoDataUrl != null) {
      await ref
          .read(queuedPhotosRepositoryProvider)
          .queuePhoto(
            visitDraftId: widget.visitDraftId,
            section: 'pricing',
            dataUrl: _photoDataUrl!,
          );
    }

    if (mounted) setState(() => _saved = true);
  }

  // Comms rating stays a numeric field, not a ChoiceRow: it is a 1–5 scale, and
  // the kit's ChoiceRow is built for two or three big choices, not five.
  Widget _numField(String label, Key key, TextEditingController controller) {
    return AgentField(
      label: label,
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: '0'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (widget.skus.isEmpty) {
      return const Center(child: Text('No SKUs configured for this client.'));
    }
    // No section header here — the shared section wrapper already titles this
    // "Pricing & promotions".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sku in widget.skus)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _SkuCard(
              title: sku.name,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _numField(
                    'Actual price',
                    ValueKey('price-${sku.id}'),
                    _price[sku.id]!,
                  ),
                  AgentToggle(
                    key: ValueKey('promo-${sku.id}'),
                    label: 'Promotion active',
                    value: _promo[sku.id] ?? false,
                    onChanged: (v) => setState(() => _promo[sku.id] = v),
                  ),
                  const SizedBox(height: 12),
                  _numField(
                    'Comms rating (1-5)',
                    ValueKey('comms-${sku.id}'),
                    _comms[sku.id]!,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        PhotoCaptureField(
          label: 'Shelf-price photo',
          helperText:
              'Optional. Prices are still entered by hand — this is '
              'evidence, and the training data for automated price reading.',
          onCaptured: (dataUrl) => setState(() => _photoDataUrl = dataUrl),
        ),
        const SizedBox(height: 12),
        AgentButton(label: 'Save pricing', onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Pricing saved — queued for sync',
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

/// One SKU's pricing. Glass: a no-blur tile (it repeats down the list) headed
/// by the SKU name, like the stock section's cards.
class _SkuCard extends StatelessWidget {
  const _SkuCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!colors.glass) return PanelCard(title: title, child: child);
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      // AgentField pads its own bottom, so the tile's bottom is trimmed.
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.lumen.ink,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
