import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/photo_capture_field.dart';
import '../../data/photos_repository.dart';
import '../../data/pricing_repository.dart';
import '../../data/skus_repository.dart';

/// S5 — Pricing & Promotions capture. One row per client SKU (actual price,
/// promo active, comms rating); on save the entries are queued for sync
/// (POST /pricing).
class S5PricingPromotionsScreen extends ConsumerWidget {
  const S5PricingPromotionsScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skus = ref.watch(skusListProvider);
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
        .map((sku) => PricingEntry(
              skuId: sku.id,
              priceActual: double.tryParse(_price[sku.id]!.text) ?? 0.0,
              promoActive: _promo[sku.id] ?? false,
              // Manual promo-materials checklist is a follow-up; empty for now.
              promoMaterialsDetected: const {},
              commsRating: int.tryParse(_comms[sku.id]!.text) ?? 0,
            ))
        .toList();

    await ref.read(pricingRepositoryProvider).savePricing(
          visitDraftId: widget.visitDraftId,
          entries: entries,
        );

    // The shelf-price photo is evidence, and the corpus a real price OCR (#2)
    // would be trained on. Prices themselves stay manually entered — the OCR
    // seam (`ocr.stub.ts`) is a passthrough that returns whatever it was given,
    // so nothing here is machine-read yet, and the UI does not pretend it is.
    if (_photoDataUrl != null) {
      await ref.read(queuedPhotosRepositoryProvider).queuePhoto(
            visitDraftId: widget.visitDraftId,
            section: 'pricing',
            dataUrl: _photoDataUrl!,
          );
    }

    if (mounted) setState(() => _saved = true);
  }

  Widget _numField(String label, Key key, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skus.isEmpty) {
      return const Center(child: Text('No SKUs configured for this client.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('S5 Pricing & Promotions'),
        const SizedBox(height: 8),
        for (final sku in widget.skus)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sku.name, style: Theme.of(context).textTheme.titleMedium),
                  _numField('Actual price', ValueKey('price-${sku.id}'), _price[sku.id]!),
                  SwitchListTile(
                    key: ValueKey('promo-${sku.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Promotion active'),
                    value: _promo[sku.id] ?? false,
                    onChanged: (v) => setState(() => _promo[sku.id] = v),
                  ),
                  _numField('Comms rating (1-5)', ValueKey('comms-${sku.id}'), _comms[sku.id]!),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        PhotoCaptureField(
          label: 'Shelf-price photo',
          helperText: 'Optional. Prices are still entered by hand — this is '
              'evidence, and the training data for automated price reading.',
          onCaptured: (dataUrl) => setState(() => _photoDataUrl = dataUrl),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _save, child: const Text('Save pricing')),
        if (_saved)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Pricing saved — queued for sync'),
          ),
      ],
    );
  }
}
