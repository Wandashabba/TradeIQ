import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/lumen_palette.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/console.dart';
import '../../../../core/widgets/lumen_kit.dart';
import '../../../../l10n/l10n.dart';
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
  static const _dimensionKeys = [
    'availability',
    'visibility',
    'display',
    'pricing',
    'competitive',
    'salesCapability',
  ];

  static String _dimensionLabel(AppLocalizations l10n, String key) =>
      switch (key) {
        'availability' => l10n.s10DimensionAvailability,
        'visibility' => l10n.s10DimensionVisibility,
        'display' => l10n.s10DimensionDisplay,
        'pricing' => l10n.s10DimensionPricing,
        'competitive' => l10n.s10DimensionCompetitive,
        _ => l10n.s10DimensionSalesCapability,
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
    final l10n = context.l10n;
    return FutureBuilder<LocalScorecard>(
      future: _scorecard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              l10n.s10ComputeFailed,
              style: TextStyle(fontSize: 13, color: colors.crit),
            ),
          );
        }
        final scorecard = snapshot.data;
        if (scorecard == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final total = Text(
          scorecard.weightedTotal.toStringAsFixed(1),
          key: const ValueKey('score-total'),
          style: colors.glass
              ? LumenGlass.figure(size: 34, color: context.lumen.ink)
              : TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: colors.ink1,
                ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No inline screen header: the shared section wrapper already
            // titles this "Score" (matches the other seven sections).
            PanelCard(
              title: l10n.s10DimensionScores,
              padded: false,
              child: Column(
                children: [
                  for (final (i, key) in _dimensionKeys.indexed)
                    _DimensionRow(
                      dimensionKey: key,
                      label: _dimensionLabel(l10n, key),
                      score: scorecard.dimensionScores[key],
                      // An absent dimension is UNKNOWN, not zero — e.g.
                      // competitive in an outlet where no competitor was on
                      // shelf to measure against. Printing 0 would read as
                      // "you scored nothing".
                      value: scorecard.dimensionScores.containsKey(key)
                          ? scorecard.dimensionScores[key]!
                                .toStringAsFixed(0)
                          : '—',
                      isLast: i == _dimensionKeys.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (colors.glass)
                              // Glass pairs the label with the band's
                              // compliance word — ON STANDARD, AT RISK, BREACH.
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SectionLabel(l10n.s10WeightedTotal),
                                  LumenStatusPill(
                                    status: _bandStatus(scorecard.ratingBand),
                                  ),
                                ],
                              )
                            else
                              SectionLabel(l10n.s10WeightedTotal),
                            const SizedBox(height: 6),
                            total,
                          ],
                        ),
                      ),
                      _BandReadout(
                        key: const ValueKey('score-band'),
                        band: scorecard.ratingBand,
                      ),
                    ],
                  ),
                  if (colors.glass) ...[
                    const SizedBox(height: 14),
                    // The total against the green line it is banded by.
                    BenchmarkBar(
                      value: scorecard.weightedTotal,
                      target: _greenFrom,
                      status: _bandStatus(scorecard.ratingBand),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AgentButton(label: l10n.s10Finalize, onPressed: _finalize),
            const SizedBox(height: 10),
            AgentButton(
              label: l10n.s10Refresh,
              icon: Icons.refresh,
              secondary: true,
              onPressed: _refresh,
            ),
            if (_finalized)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.s10Queued,
                  style: TextStyle(fontSize: 13, color: colors.ink2),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The on-device banding (scorecard_service.dart): green from 80, amber from
/// 60, red below. The glass bars tick at the green line and take their status
/// from the same cut-offs, so a bar never disagrees with the band word.
const double _greenFrom = 80;
const double _amberFrom = 60;

LumenStatus _bandStatus(String band) => switch (band) {
  'green' => LumenStatus.good,
  'amber' => LumenStatus.warn,
  _ => LumenStatus.crit,
};

LumenStatus _scoreStatus(double? score) => score == null
    ? LumenStatus.none
    : score >= _greenFrom
    ? LumenStatus.good
    : score >= _amberFrom
    ? LumenStatus.warn
    : LumenStatus.crit;

/// One dimension's score, as a tabular row on the console line — label on the
/// left, figure on the right. Glass adds the figure's benchmark bar beneath.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimensionKey,
    required this.label,
    required this.score,
    required this.value,
    required this.isLast,
  });

  final String dimensionKey;
  final String label;

  /// The raw score behind [value]; null when the dimension was not measured.
  final double? score;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (colors.glass) return _glass(context);
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

  /// The figure in mono, in its status ink, over a bar ticked at the green
  /// line. Unmeasured keeps an empty track with no tick and reads "—".
  Widget _glass(BuildContext context) {
    final colors = context.colors;
    final lumen = context.lumen;
    final score = this.score;
    final status = _scoreStatus(score);
    return Container(
      key: ValueKey('score-$dimensionKey'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: lumen.white(0xB3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: lumen.ink,
                  ),
                ),
              ),
              Text(
                value,
                style: LumenGlass.figure(
                  color: score == null
                      ? lumen.inkMuted
                      : status.swatchOf(colors).ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BenchmarkBar(
            value: score ?? 0,
            target: score == null ? null : _greenFrom,
            status: status,
            height: 6,
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
    // The band word is shared with the visit outcome screen's readout.
    final word = context.l10n.outcomeRatingBand(band);
    if (colors.glass) return _glass(colors, word);
    final (dot, text) = switch (band) {
      'green' => (colors.good, colors.good),
      'amber' => (colors.warn, colors.warn),
      _ => (colors.crit, colors.critText),
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

  /// Glass: the dot and word on an OPAQUE status wash, the word in the
  /// swatch's ink — which clears AA on that wash by itself.
  Widget _glass(TiqColors colors, String word) {
    final sw = _bandStatus(band).swatchOf(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(sw.tint, colors.surface1),
        borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
        border: Border.all(color: sw.rim),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: sw.fill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            word,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: sw.ink,
            ),
          ),
        ],
      ),
    );
  }
}
