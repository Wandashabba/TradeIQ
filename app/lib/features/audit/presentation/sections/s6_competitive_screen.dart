import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _skus.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PanelCard(
              title: 'Competitor ${i + 1}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AgentField(
                    label: 'Competitor SKU',
                    child: TextField(
                      key: ValueKey('comp-sku-$i'),
                      controller: _skus[i],
                      decoration: const InputDecoration(
                        hintText: 'What the rival is selling',
                      ),
                    ),
                  ),
                  AgentField(
                    label: 'Competitor price',
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
                    label: 'POSM type',
                    child: TextField(
                      key: ValueKey('comp-posm-$i'),
                      controller: _posmTypes[i],
                      decoration: const InputDecoration(
                        hintText: 'Poster, wobbler, gondola…',
                      ),
                    ),
                  ),
                  AgentField(
                    label: 'Facings on shelf',
                    help: 'How much shelf this competitor holds',
                    child: TextField(
                      key: ValueKey('comp-facings-$i'),
                      controller: _facings[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '1'),
                    ),
                  ),
                  AgentToggle(
                    label: 'Promoter present',
                    value: _promoters[i],
                    onChanged: (v) => setState(() => _promoters[i] = v),
                  ),
                ],
              ),
            ),
          ),
        AgentButton(
          key: const ValueKey('add-competitor'),
          label: 'Add competitor',
          icon: Icons.add,
          secondary: true,
          onPressed: _addCompetitor,
        ),
        const SizedBox(height: 12),
        AgentButton(label: 'Save competitive', onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Competitive intel saved — queued for sync',
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}
