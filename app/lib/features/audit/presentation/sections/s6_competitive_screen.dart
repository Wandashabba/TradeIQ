import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/input.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../l10n/l10n.dart';
import '../../data/competitive_repository.dart';
import '../../data/visit_progress.dart';
import 'section_form.dart';

/// S6 — COMPETITIVE. A dynamic list of competitor observations: what the rival
/// is selling, at what price, on what POSM, over how much shelf.
///
/// The list is the repeating card set from the section grammar — never a
/// bespoke card — and an empty one is a real outcome, not a gap: an outlet
/// with no competitor on shelf is the finding, and the section is not required
/// to submit.
///
/// **Amber:** one object, the inline Save, once something has changed.
class S6CompetitiveScreen extends ConsumerStatefulWidget {
  const S6CompetitiveScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S6CompetitiveScreen> createState() => _S6State();
}

class _S6Entry {
  _S6Entry()
    : sku = TextEditingController(),
      price = TextEditingController(),
      posm = TextEditingController(),
      facings = TextEditingController(text: '1');

  final TextEditingController sku;
  final TextEditingController price;
  final TextEditingController posm;
  final TextEditingController facings;
  bool promoter = false;

  void dispose() {
    sku.dispose();
    price.dispose();
    posm.dispose();
    facings.dispose();
  }
}

class _S6State extends ConsumerState<S6CompetitiveScreen> {
  final _entries = <_S6Entry>[];
  bool _dirty = false;

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    // Rows without a competitor SKU name are skipped. Figures are read in the
    // locale's notation: `12,50` on an Afrikaans phone is twelve fifty, never
    // a price of nothing.
    final numbers = TiqNumber.of(context);
    final entries = <CompetitiveEntry>[
      for (final entry in _entries)
        if (entry.sku.text.trim().isNotEmpty)
          CompetitiveEntry(
            competitorSku: entry.sku.text.trim(),
            competitorPrice: numbers.parse(entry.price.text)?.toDouble() ?? 0.0,
            competitorPosmType: entry.posm.text.trim(),
            competitorPromoterPresent: entry.promoter,
            // Facings is what makes share-of-shelf a real ratio rather than a
            // count of how many rows the agent typed (#93). A blank box means
            // "at least one" — never zero, which would erase the competitor.
            facingsCount: numbers.parse(entry.facings.text)?.toInt() ?? 1,
          ),
    ];

    await ref
        .read(competitiveRepositoryProvider)
        .saveCompetitive(visitDraftId: widget.visitDraftId, entries: entries);
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SectionForm(
      title: l10n.visitSectionCompetitive,
      phase: 'competitive',
      dirty: _dirty,
      onSave: _save,
      savedLine: l10n.s6Saved,
      skip: SectionSkipTarget(widget.visitDraftId, AuditSection.competitive),
      children: <Widget>[
        SectionEntries(
          kind: 'competitor',
          summaries: <String?>[for (final entry in _entries) entry.sku.text],
          addLabel: l10n.s6AddButton,
          emptyLine: l10n.s6NoCompetitors,
          onAdd: () => _touch(() => _entries.add(_S6Entry())),
          onRemove: (i) => _touch(() => _entries.removeAt(i).dispose()),
          entries: <Widget>[
            for (final (i, entry) in _entries.indexed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TorchTextField(
                    key: ValueKey<String>('comp-sku-$i'),
                    label: l10n.s6SkuLabel,
                    controller: entry.sku,
                    hint: l10n.s6SkuHint,
                    onChanged: (_) => _touch(() {}),
                  ),
                  const SizedBox(height: TiqSpace.s4),
                  TorchNumericField(
                    key: ValueKey<String>('comp-price-$i'),
                    label: l10n.s6PriceLabel,
                    controller: entry.price,
                    unit: TiqUnit.currency,
                    decimals: 2,
                    minimum: 0,
                    onChanged: (_) => _touch(() {}),
                  ),
                  const SizedBox(height: TiqSpace.s4),
                  TorchTextField(
                    key: ValueKey<String>('comp-posm-$i'),
                    label: l10n.s6PosmLabel,
                    controller: entry.posm,
                    hint: l10n.s6PosmHint,
                    onChanged: (_) => _touch(() {}),
                  ),
                  const SizedBox(height: TiqSpace.s4),
                  TorchNumericField(
                    key: ValueKey<String>('comp-facings-$i'),
                    label: l10n.s6FacingsLabel,
                    controller: entry.facings,
                    help: l10n.s6FacingsHelp,
                    minimum: 1,
                    onChanged: (_) => _touch(() {}),
                  ),
                  const SizedBox(height: TiqSpace.s4),
                  TorchToggle(
                    key: ValueKey<String>('comp-promoter-$i'),
                    label: l10n.s6PromoterLabel,
                    value: entry.promoter,
                    onWord: l10n.wordYes,
                    offWord: l10n.wordNo,
                    onChanged: (v) => _touch(() => entry.promoter = v),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
