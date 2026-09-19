import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../../core/camera/photo_capture_service.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../core/widgets/torchlight/state.dart';
import '../../../../l10n/l10n.dart';
import '../../data/photos_repository.dart';
import '../../data/pricing_repository.dart';
import '../../data/skus_repository.dart';
import '../../data/visit_progress.dart';
import 'section_form.dart';
import 'section_photo.dart';

/// S5 — PRICING & PROMOTIONS. One group per client SKU: the price on the
/// shelf, whether a promotion is running, and how the comms read.
///
/// A SKU with no price typed is **not sent** — an untouched line is not a
/// price of zero, and the same distinction the stock section makes about
/// counts applies here.
///
/// **Amber:** one object, the inline Save, once something has changed.
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
    final l10n = context.l10n;
    final skus = ref.watch(skusListProvider(outletId));
    return skus.when(
      loading: () => SectionForm(
        title: l10n.visitSectionPricing,
        phase: 'pricing-loading',
        children: const <Widget>[SkeletonRows(count: 4, rowHeight: 120)],
      ),
      error: (err, _) => SectionForm(
        title: l10n.visitSectionPricing,
        phase: 'pricing-error',
        children: <Widget>[
          ErrorState(
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.unknown,
              headline: l10n.s5LoadError('$err'),
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
      data: (list) => _PricingForm(
        visitDraftId: visitDraftId,
        skus: list,
      ),
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
  bool _dirty = false;
  CapturedPhoto? _photo;

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
    for (final c in <TextEditingController>[..._price.values, ..._comms.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    // Untouched SKUs (no price entered) are skipped. The price is read in the
    // locale's notation — `24,99` from an Afrikaans keyboard is R 24,99, not
    // a shelf price of nothing.
    final numbers = TiqNumber.of(context);
    final entries = widget.skus
        .where((sku) => _price[sku.id]!.text.trim().isNotEmpty)
        .map(
          (sku) => PricingEntry(
            skuId: sku.id,
            priceActual: numbers.parse(_price[sku.id]!.text)?.toDouble() ?? 0.0,
            promoActive: _promo[sku.id] ?? false,
            // Manual promo-materials checklist is a follow-up; empty for now.
            promoMaterialsDetected: const <String, bool>{},
            commsRating: numbers.parse(_comms[sku.id]!.text)?.toInt() ?? 0,
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
    final photo = _photo;
    if (photo != null) {
      await ref
          .read(queuedPhotosRepositoryProvider)
          .queuePhoto(
            visitDraftId: widget.visitDraftId,
            section: 'pricing',
            dataUrl: photo.dataUrl,
            gpsTag: photo.gpsTag,
            capturedAt: photo.capturedAt,
          );
      _photo = null;
    }

    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (widget.skus.isEmpty) {
      return SectionForm(
        title: l10n.visitSectionPricing,
        phase: 'pricing-empty',
        skip: SectionSkipTarget(widget.visitDraftId, AuditSection.pricing),
        children: <Widget>[
          EmptyState(scope: EmptyScope.inPanel, headline: l10n.s5NoSkus),
        ],
      );
    }

    return SectionForm(
      title: l10n.visitSectionPricing,
      phase: 'pricing',
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.s5Saved,
      skip: SectionSkipTarget(widget.visitDraftId, AuditSection.pricing),
      photo: SectionPhotoField(
        label: l10n.s5PhotoLabel,
        framingLine: l10n.s5PhotoHelper,
        photo: _photo,
        onCaptured: (photo) => _touch(() => _photo = photo),
      ),
      children: <Widget>[
        for (final sku in widget.skus)
          SectionFieldGroup(
            title: sku.name,
            children: <Widget>[
              TorchNumericField(
                key: ValueKey<String>('price-${sku.id}'),
                label: l10n.s5ActualPriceLabel,
                controller: _price[sku.id]!,
                unit: TiqUnit.currency,
                decimals: 2,
                help: l10n.s2Rrp(
                  TiqNumber.of(
                    context,
                  ).format(sku.rrp, unit: TiqUnit.currency, decimals: 2),
                ),
                minimum: 0,
                onChanged: (_) => _touch(() {}),
              ),
              TorchToggle(
                key: ValueKey<String>('promo-${sku.id}'),
                label: l10n.s5PromoActiveLabel,
                value: _promo[sku.id] ?? false,
                onWord: l10n.wordYes,
                offWord: l10n.wordNo,
                onChanged: (v) => _touch(() => _promo[sku.id] = v),
              ),
              // Comms rating stays a numeric field, not a choice row: it is a
              // 1–5 scale, and a choice row is built for two to four big
              // choices, not five.
              TorchNumericField(
                key: ValueKey<String>('comms-${sku.id}'),
                label: l10n.s5CommsRatingLabel,
                controller: _comms[sku.id]!,
                minimum: 0,
                maximum: 5,
                onChanged: (_) => _touch(() {}),
              ),
            ],
          ),
      ],
    );
  }
}
