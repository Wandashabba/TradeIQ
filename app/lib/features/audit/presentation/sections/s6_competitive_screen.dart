import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/lumen_palette.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/lumen_kit.dart';
import '../../../../l10n/l10n.dart';
import '../../data/competitive_repository.dart';

/// S6 — Competitive Intelligence capture: a dynamic list of competitor
/// observations (SKU, price, POSM type, promoter presence). On save the
/// entries are queued for sync (POST /competitive).
class S6CompetitiveScreen extends ConsumerStatefulWidget {
  const S6CompetitiveScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S6CompetitiveScreen> createState() => _S6State();
}

class _S6State extends ConsumerState<S6CompetitiveScreen> {
  final _skus = <TextEditingController>[];
  final _prices = <TextEditingController>[];
  final _posmTypes = <TextEditingController>[];
  final _facings = <TextEditingController>[];
  final _promoters = <bool>[];
  bool _saved = false;

  @override
  void dispose() {
    for (final c in [..._skus, ..._prices, ..._posmTypes, ..._facings]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCompetitor() {
    setState(() {
      _skus.add(TextEditingController());
      _prices.add(TextEditingController());
      _posmTypes.add(TextEditingController());
      _facings.add(TextEditingController(text: '1'));
      _promoters.add(false);
    });
  }

  Future<void> _save() async {
    // Rows without a competitor SKU name are skipped.
    final entries = <CompetitiveEntry>[
      for (var i = 0; i < _skus.length; i++)
        if (_skus[i].text.trim().isNotEmpty)
          CompetitiveEntry(
            competitorSku: _skus[i].text.trim(),
            competitorPrice: double.tryParse(_prices[i].text) ?? 0.0,
            competitorPosmType: _posmTypes[i].text.trim(),
            competitorPromoterPresent: _promoters[i],
            // Facings is what makes share-of-shelf a real ratio rather than a
            // count of how many rows the agent typed (#93). A blank box means
            // "at least one" — never zero, which would erase the competitor.
            facingsCount: int.tryParse(_facings[i].text.trim()) ?? 1,
          ),
    ];

    await ref
        .read(competitiveRepositoryProvider)
        .saveCompetitive(visitDraftId: widget.visitDraftId, entries: entries);
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _skus.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CompetitorCard(
              index: i,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AgentField(
                    label: l10n.s6SkuLabel,
                    child: TextField(
                      key: ValueKey('comp-sku-$i'),
                      controller: _skus[i],
                      decoration: InputDecoration(hintText: l10n.s6SkuHint),
                    ),
                  ),
                  AgentField(
                    label: l10n.s6PriceLabel,
                    child: TextField(
                      key: ValueKey('comp-price-$i'),
                      controller: _prices[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(hintText: '0.00'),
                    ),
                  ),
                  AgentField(
                    label: l10n.s6PosmLabel,
                    child: TextField(
                      key: ValueKey('comp-posm-$i'),
                      controller: _posmTypes[i],
                      decoration: InputDecoration(hintText: l10n.s6PosmHint),
                    ),
                  ),
                  AgentField(
                    label: l10n.s6FacingsLabel,
                    help: l10n.s6FacingsHelp,
                    child: TextField(
                      key: ValueKey('comp-facings-$i'),
                      controller: _facings[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '1'),
                    ),
                  ),
                  AgentToggle(
                    label: l10n.s6PromoterLabel,
                    value: _promoters[i],
                    onChanged: (v) => setState(() => _promoters[i] = v),
                  ),
                ],
              ),
            ),
          ),
        AgentButton(
          key: const ValueKey('add-competitor'),
          label: l10n.s6AddButton,
          icon: Icons.add,
          secondary: true,
          onPressed: _addCompetitor,
        ),
        const SizedBox(height: 12),
        AgentButton(label: l10n.s6SaveButton, onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.s6Saved,
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

/// One competitor observation. Glass: a no-blur tile (they repeat) headed by
/// its sequence number in a status tile — a count, so it is set in mono.
class _CompetitorCard extends StatelessWidget {
  const _CompetitorCard({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = context.l10n.s6CompetitorTitle(index + 1);
    if (!colors.glass) return PanelCard(title: title, child: child);
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusTile(
                status: LumenStatus.none,
                glyph: '${index + 1}',
                size: 26,
                radius: 8,
                mono: true,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.lumen.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
