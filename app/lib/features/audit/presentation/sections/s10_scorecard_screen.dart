import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../data/scorecard_service.dart';

/// S10 — Execution Scorecard: the offline scorecard computed on-device from
/// the queued captures (ADR 0005), shown before the agent leaves the outlet.
/// The score is computed and read-only — the agent cannot edit it here.
/// Finalizing queues a marker so the server recomputes authoritatively.
class S10ScorecardScreen extends ConsumerStatefulWidget {
  const S10ScorecardScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S10ScorecardScreen> createState() => _S10State();
}

class _S10State extends ConsumerState<S10ScorecardScreen> {
  static const _dimensionLabels = {
    'availability': 'Availability',
    'visibility': 'Visibility',
    'display': 'Display',
    'pricing': 'Pricing',
    'competitive': 'Competitive',
    'salesCapability': 'Sales Capability',
  };

  late Future<LocalScorecard> _scorecard;
  bool _finalized = false;

  @override
  void initState() {
    super.initState();
    _scorecard = ref
        .read(scorecardServiceProvider)
        .computeForVisit(widget.visitDraftId);
  }

  void _refresh() {
    setState(() {
      _scorecard = ref
          .read(scorecardServiceProvider)
          .computeForVisit(widget.visitDraftId);
    });
  }

  Future<void> _finalize() async {
    await ref
        .read(scorecardServiceProvider)
        .finalizeScorecard(widget.visitDraftId);
    if (mounted) setState(() => _finalized = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<LocalScorecard>(
      future: _scorecard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Could not compute the scorecard. Try refreshing.',
              style: TextStyle(fontSize: 13, color: colors.crit),
            ),
          );
        }
        final scorecard = snapshot.data;
        if (scorecard == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No inline screen header: the shared section wrapper already
            // titles this "Score" (matches the other seven sections).
            PanelCard(
              title: 'Dimension scores',
              padded: false,
              child: Column(
                children: [
                  for (final (i, entry) in _dimensionLabels.entries.indexed)
                    _DimensionRow(
                      dimensionKey: entry.key,
                      label: entry.value,
                      // An absent dimension is UNKNOWN, not zero — e.g.
                      // competitive in an outlet where no competitor was on
                      // shelf to measure against. Printing 0 would read as
                      // "you scored nothing".
                      value: scorecard.dimensionScores.containsKey(entry.key)
                          ? scorecard.dimensionScores[entry.key]!
                                .toStringAsFixed(0)
                          : '—',
                      isLast: i == _dimensionLabels.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PanelCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Weighted total'),
                        const SizedBox(height: 6),
                        Text(
                          scorecard.weightedTotal.toStringAsFixed(1),
                          key: const ValueKey('score-total'),
                          style: TextStyle(
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: colors.ink1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BandReadout(
                    key: const ValueKey('score-band'),
                    band: scorecard.ratingBand,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AgentButton(label: 'Finalize scorecard', onPressed: _finalize),
            const SizedBox(height: 10),
            AgentButton(
              label: 'Refresh',
              icon: Icons.refresh,
              secondary: true,
              onPressed: _refresh,
            ),
            if (_finalized)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Scorecard queued for sync',
                  style: TextStyle(fontSize: 13, color: colors.ink2),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One dimension's score, as a tabular row on the console line — label on the
/// left, figure on the right.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimensionKey,
    required this.label,
    required this.value,
    required this.isLast,
  });

  final String dimensionKey;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: ValueKey('score-$dimensionKey'),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colors.ink2)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.ink1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rating band as a coloured dot plus its spelled-out word — never colour
/// alone. The word's colour clears AA text contrast: `red` carries [critText]
/// (the mark [crit] fails 4.5:1 as text), matching the console's rule that
/// meaning surviving greyscale must also stay readable.
class _BandReadout extends StatelessWidget {
  const _BandReadout({super.key, required this.band});

  final String band;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (dot, text, word) = switch (band) {
      'green' => (colors.good, colors.good, 'Green'),
      'amber' => (colors.warn, colors.warn, 'Amber'),
      _ => (colors.crit, colors.critText, 'Red'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dot,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          word,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
      ],
    );
  }
}
