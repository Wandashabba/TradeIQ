import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../../core/rating_band.dart';
import '../../../../core/theme/torchlight/tiq_skin.dart';
import '../../../../core/widgets/torchlight/button/buttons.dart';
import '../../../../core/widgets/torchlight/marks.dart';
import '../../../../core/widgets/torchlight/row/row.dart';
import '../../../../core/widgets/torchlight/state.dart';
import '../../../../l10n/l10n.dart';
import '../../data/scorecard_service.dart';
import 'section_form.dart';

/// S10 — THE SCORECARD. The offline score computed on-device from the queued
/// captures (ADR 0005), read before the agent leaves the outlet.
///
/// ## It is never shown as final
///
/// unify §1.20 is blunt about this: the agent app does not guess. The figure
/// here is what *this phone* worked out from what *this phone* has, and the
/// sentence under it says so in words rather than through a marker — the
/// `ProvisionalMarker` is a console component for server-stamped figures, and
/// borrowing it here would dress a local arithmetic up as a server verdict.
///
/// A dimension with nothing behind it renders an **em dash, a falling hatch
/// and a reason** — never a zero. "You scored nothing" and "nobody measured
/// this" are different sentences about a shop.
///
/// **Amber:** one object, `Finalize`, and only until it has been queued.
class S10ScorecardScreen extends ConsumerStatefulWidget {
  const S10ScorecardScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S10ScorecardScreen> createState() => _S10State();
}

class _S10State extends ConsumerState<S10ScorecardScreen> {
  static const _dimensionKeys = <String>[
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
      _finalized = false;
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
    final l10n = context.l10n;
    return FutureBuilder<LocalScorecard>(
      future: _scorecard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionForm(
            title: l10n.visitSectionScore,
            phase: 'score-error',
            children: <Widget>[
              ErrorState(
                scope: ErrorScope.inline,
                message: TorchErrorMessage(
                  kind: TorchErrorKind.unknown,
                  headline: l10n.s10ComputeFailed,
                  body: l10n.visitCheckInFailedNothingLost,
                  offersRetry: true,
                ),
                action: TorchSecondaryButton(
                  label: l10n.s10Refresh,
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              ),
            ],
          );
        }
        final scorecard = snapshot.data;
        if (scorecard == null) {
          return SectionForm(
            title: l10n.visitSectionScore,
            phase: 'score-loading',
            children: const <Widget>[SkeletonRows(count: 6)],
          );
        }
        final band = RatingBand.ofWire(scorecard.ratingBand);

        return SectionForm(
          title: l10n.visitSectionScore,
          phase: 'score',
          dirty: !_finalized,
          onSave: _finalize,
          saveLabel: l10n.s10Finalize,
          saveAndBackLabel: l10n.s10Finalize,
          savedLine: l10n.s10Queued,
          readOnlyActions: <Widget>[
            TorchSecondaryButton(
              key: const ValueKey<String>('score-refresh'),
              label: l10n.s10Refresh,
              icon: Icons.refresh,
              onPressed: _refresh,
            ),
          ],
          children: <Widget>[
            _ScoreHero(total: scorecard.weightedTotal, band: band),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (i, key) in _dimensionKeys.indexed)
                  _DimensionRow(
                    dimensionKey: key,
                    label: _dimensionLabel(l10n, key),
                    // An absent dimension is UNKNOWN, not zero — competitive
                    // in an outlet with no competitor on shelf to measure
                    // against. Printing 0 would read as "you scored nothing".
                    score: scorecard.dimensionScores[key],
                    last: i == _dimensionKeys.length - 1,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The weighted total, the band in words, and the sentence that keeps it from
/// reading as a verdict.
class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.total, required this.band});

  final double total;
  final RatingBand band;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    // The chip already draws a silhouette, so the word travels on its own
    // here — `markedWord` would put two marks beside one band.
    final word = band.word(l10n);
    final spoken = l10n.s10ScoreSemantics(
      TiqNumber.of(context).format(total, decimals: 1),
      word,
    );
    final level = switch (band) {
      RatingBand.healthy => StatusLevel.onTarget,
      RatingBand.watch => StatusLevel.watch,
      RatingBand.gap => StatusLevel.critical,
    };
    return Container(
      key: const ValueKey<String>('score-total'),
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
        // No shadow: this panel scrolls with the section body, and the paint
        // budget allows no shadow in a scrolling surface.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Eyebrow(l10n.s10WeightedTotal),
          const SizedBox(height: TiqSpace.s3),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: TiqSpace.s3,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              FigureSlot(
                value: total,
                role: skin.text.heroFigureCompact,
                fit: <TiqTypeToken>[
                  skin.text.heroFigureCompact,
                  skin.text.display,
                  skin.text.figureL,
                ],
                decimals: 1,
                semanticsLabel: spoken,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                child: StatusChip(
                  key: const ValueKey<String>('score-band'),
                  level: level,
                  label: word,
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s4),
          Meter(
            value: total,
            target: 80,
            semanticsValue: spoken,
          ),
          const SizedBox(height: TiqSpace.s4),
          // The whole reason this screen is not a verdict.
          Text(
            l10n.s10NotFinal,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ),
    );
  }
}

/// One dimension: the name, its figure, and a meter ticked at the Healthy
/// line. Unmeasured keeps its row and states its reason.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimensionKey,
    required this.label,
    required this.score,
    required this.last,
  });

  final String dimensionKey;
  final String label;

  /// Null when the dimension was not measured on this visit.
  final double? score;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final value = score;
    return SoftRow(
      key: ValueKey<String>('score-$dimensionKey'),
      title: label,
      // Through FigureSlot in both states: a null is its em dash, in ink-3, at
      // the figure's own role — the slot owns that, not this row.
      trailing: FigureSlot(
        value: value,
        role: skin.text.figureM,
        decimals: 0,
        semanticsLabel: value == null ? l10n.s10NotMeasured : null,
      ),
      meta: value == null
          ? NotMeasured(reason: l10n.s10NotMeasured)
          : Meter(value: value, target: 80),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: value == null
          ? '$label. ${l10n.s10NotMeasured}'
          : '$label. ${TiqNumber.of(context).format(value, decimals: 0)}',
    );
  }
}
