import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rating_band.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../l10n/l10n.dart';
import '../data/scorecards_repository.dart';
import '../../../core/theme/lumen_palette.dart';

/// How the visit ended.
///
/// The score is the point of the visit, so it is the *outcome* — not a form
/// section the agent has to go and open after the fact. It is the first thing
/// they see when they walk out of the shop.
///
/// It shows the score the manager will see, or no score at all. There is a
/// scorecard the app can compute offline, but it is a proxy — it would show a
/// number that quietly changes once the visit reaches the server, and an agent
/// whose score moves after the fact has no reason to believe the next one.
class VisitOutcomeScreen extends ConsumerWidget {
  const VisitOutcomeScreen({
    super.key,
    required this.visitDraftId,
    required this.outletId,
    required this.outletName,
  });

  final String visitDraftId;
  final String outletId;
  final String outletName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomeAsync = ref.watch(
      visitOutcomeProvider((visitDraftId: visitDraftId, outletId: outletId)),
    );

    final l10n = context.l10n;
    return AgentScaffold(
      title: l10n.outcomeTitle,
      subtitle: outletName,
      showSyncChip: false,
      // There is no way back into a submitted visit. Back means "on to the next
      // store", which is what the agent is actually doing.
      onBack: () => context.go('/today'),
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AgentButton(
            key: const ValueKey('next-store'),
            label: l10n.outcomeNextStore,
            icon: Icons.arrow_forward,
            onPressed: () => context.go('/today'),
          ),
        ],
      ),
      body: outcomeAsync.when(
        loading: () => const _Scoring(),
        // Failing to *read* the score is not failing to submit. The captures are
        // in the outbox either way, and saying so is the only thing that matters
        // to someone walking out of a shop.
        error: (_, _) => const _HeldOnPhone(unreachable: true),
        data: (outcome) {
          if (outcome.isHeldOnPhone) {
            return const _HeldOnPhone(unreachable: false);
          }
          return _Scored(outcome: outcome);
        },
      ),
    );
  }
}

class _Scoring extends StatelessWidget {
  const _Scoring();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.outcomeSending,
            style: TextStyle(fontSize: 13.5, color: colors.ink2),
          ),
        ],
      ),
    );
  }
}

/// Submitted, but still on the phone. This is the ordinary case in a shop with
/// no signal, so it is not an error — it is a receipt.
class _HeldOnPhone extends StatelessWidget {
  const _HeldOnPhone({required this.unreachable});

  /// True when the server could not be read; false when there is no signal.
  final bool unreachable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const Center(child: TickMark(done: true, size: 44)),
        const SizedBox(height: 16),
        Text(
          l10n.outcomeHeldTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.ink1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          unreachable
              ? l10n.outcomeHeldBodyUnreachable
              : l10n.outcomeHeldBodyNoSignal,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: colors.ink2),
        ),
        const SizedBox(height: 22),
        StatusBanner(
          level: BannerLevel.warn,
          title: l10n.outcomeScoredWhenSends,
          subtitle: l10n.outcomeScoredOnServer,
        ),
        const SizedBox(height: 12),
        Text(
          // Not showing a number here is deliberate, and worth one sentence:
          // an agent who is shown 74 in the shop and finds 68 in the morning
          // will not trust the third one.
          l10n.outcomeNoGuess,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: colors.ink3),
        ),
      ],
    );
  }
}

class _Scored extends StatelessWidget {
  const _Scored({required this.outcome});

  final VisitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (colors.glass) return _GlassScored(outcome: outcome);
    final l10n = context.l10n;
    final score = outcome.score!;
    final band = RatingBand.ofWire(score.ratingBand);
    final ink = band.inkOn(colors);
    final delta = outcome.delta;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        // The score-reveal moment, on the console's glass-hero treatment: the
        // washed panel every other console hero wears (heroWash → surface1).
        PanelCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.heroWash, colors.surface1],
          ),
          borderColor: colors.heroBorder,
          child: Column(
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // The number counts up to itself. It is the one moment in
                    // the visit worth landing — everything before it was work.
                    AnimatedCount(
                      value: score.weightedTotal.round(),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.ink1,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A mark and the word, never a coloured dot: '✓ / ! / ✕'
                    // says which band this is without colour, so Watch and Gap
                    // — which share a hue, because severity never borrows the
                    // brand's amber — are still told apart in greyscale. The
                    // label carries the AA-safe tint.
                    Text(
                      band.markedWord(l10n),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: _Delta(points: delta, previous: outcome.previous!),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _Heading(l10n.outcomeHowScored),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface1,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(AppColors.radiusPanel),
          ),
          child: Column(
            children: [
              for (final (i, entry) in kDimensionLabels.entries.indexed)
                Reveal(
                  index: i,
                  child: _Dimension(
                    label: _dimensionLabel(l10n, entry.key, entry.value),
                    // Absent means the server could not measure it. It shows as
                    // "—", never as a zero that reads like the agent failed at
                    // something they were never given a chance to do (#93).
                    score: score.scoreOf(entry.key),
                    unmeasurableReason: _unmeasurableReason(l10n, entry.key),
                    isLast: i == kDimensionLabels.length - 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

}

/// Up or down since this agent's last visit to this store — the only comparison
/// that is theirs to own.
class _Delta extends StatelessWidget {
  const _Delta({required this.points, required this.previous});

  final double points;
  final ServerScorecard previous;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final rounded = points.round();
    if (rounded == 0) {
      return Text(
        l10n.outcomeDeltaSame(previous.weightedTotal.round()),
        style: TextStyle(fontSize: 12.5, color: colors.ink3),
      );
    }

    final up = rounded > 0;
    // A move down uses critText, not crit — as coloured text on the hero wash,
    // crit fails 4.5:1 (the recurring crit→critText lesson).
    final color = up ? colors.good : colors.critText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          up
              ? l10n.outcomeDeltaUp(rounded.abs())
              : l10n.outcomeDeltaDown(rounded.abs()),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        // Styled apart from the movement, so it is its own message; the
        // leading space is layout, not copy.
        Text(
          ' ${l10n.outcomeDeltaFromLast(previous.weightedTotal.round())}',
          style: TextStyle(fontSize: 12.5, color: colors.ink3),
        ),
      ],
    );
  }
}

class _Dimension extends StatelessWidget {
  const _Dimension({
    required this.label,
    required this.score,
    required this.unmeasurableReason,
    required this.isLast,
  });

  final String label;
  final double? score;
  final String? unmeasurableReason;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = score;
    final measured = value != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, color: colors.ink1),
                ),
              ),
              Text(
                measured ? value.round().toString() : '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: measured ? FontWeight.w600 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: measured ? colors.ink1 : colors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Bar(value: value),
          if (!measured && unmeasurableReason != null) ...[
            const SizedBox(height: 6),
            Text(
              unmeasurableReason!,
              style: TextStyle(fontSize: 11.5, color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // An unmeasured dimension is hatched, not empty — an empty bar looks like a
    // zero, which is the exact misreading this whole thing exists to prevent.
    if (value == null) {
      return SizedBox(
        height: 5,
        child: CustomPaint(
          painter: _HatchPainter(
            track: colors.surface3,
            hatch: colors.lineStrong,
          ),
          size: Size.infinite,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: 5, color: colors.surface3),
          LayoutBuilder(
            builder: (context, constraints) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value! / 100).clamp(0.0, 1.0)),
              duration: reduceMotion(context) ? Duration.zero : Motion.slow,
              curve: Motion.enter,
              builder: (context, t, _) => Container(
                height: 5,
                width: constraints.maxWidth * t,
                color: colors.series1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.track, required this.hatch});

  final Color track;
  final Color hatch;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = track;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, trackPaint);

    canvas.save();
    canvas.clipRRect(rect);
    final hatchPaint = Paint()
      ..color = hatch
      ..strokeWidth = 1.2;
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatchPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.hatch != hatch;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.88,
          color: colors.ink3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Lumen Glass — the score on the one dark pane
// ═══════════════════════════════════════════════════════════════════════

/// The score reveal in glass. The score is the one surface in the product that
/// should feel heavier than everything around it, so it is the dark pane: the
/// figure, the band in words, the published perfect-store banding under it,
/// and every dimension drawn against the 80-point standard.
class _GlassScored extends StatelessWidget {
  const _GlassScored({required this.outcome});

  final VisitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final score = outcome.score!;
    final delta = outcome.delta;
    final band = RatingBand.ofWire(score.ratingBand);
    final ink = band.glassInk();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        GlassRise(
          child: GlassPane(
            key: const ValueKey('score-hero'),
            kind: GlassKind.dark,
            radius: LumenGlass.radiusScore,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  top: -94,
                  right: -74,
                  child: GlassBloom(diameter: 190),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(
                      l10n.outcomePerfectStoreScore,
                      color: LumenGlass.onDarkMuted,
                      size: 9.5,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // The one moment in the visit worth landing.
                            AnimatedCount(
                              value: score.weightedTotal.round(),
                              style: LumenGlass.hero(
                                size: 74,
                                color: Colors.white,
                              ).copyWith(
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99B5ABFC),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              '/100',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: LumenGlass.onDarkMuted,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The mark carries the band without colour, and
                              // the word spells it out; Watch and Gap share
                              // this ink on purpose.
                              Text(
                                band.markedWord(l10n),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ScoreBandBar(score: score.weightedTotal),
                    if (delta != null) ...[
                      const SizedBox(height: 14),
                      _GlassDelta(points: delta, previous: outcome.previous!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Kicker(l10n.outcomeHowScored),
        const SizedBox(height: 10),
        GlassPane(
          child: Column(
            children: [
              for (final (i, entry) in kDimensionLabels.entries.indexed)
                Reveal(
                  index: i,
                  child: _GlassDimension(
                    label: _dimensionLabel(l10n, entry.key, entry.value),
                    // Absent means the server could not measure it: "—", never
                    // a zero that reads like a failure (#93).
                    score: score.scoreOf(entry.key),
                    unmeasurableReason: _unmeasurableReason(l10n, entry.key),
                    isLast: i == kDimensionLabels.length - 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Up or down since this agent's last visit here, in light inks on the pane.
class _GlassDelta extends StatelessWidget {
  const _GlassDelta({required this.points, required this.previous});

  final double points;
  final ServerScorecard previous;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rounded = points.round();
    final was = previous.weightedTotal.round();
    if (rounded == 0) {
      return Text(
        l10n.outcomeDeltaSame(was),
        style: const TextStyle(fontSize: 12.5, color: LumenGlass.onDarkMuted),
      );
    }
    final up = rounded > 0;
    final color = up ? LumenGlass.onDarkGood : LumenGlass.onDarkCrit;
    return Row(
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          up
              ? l10n.outcomeDeltaUp(rounded.abs())
              : l10n.outcomeDeltaDown(rounded.abs()),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Flexible(
          child: Text(
            ' ${l10n.outcomeDeltaFromLast(was)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: LumenGlass.onDarkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// One dimension against the 80-point standard: its figure in status ink and
/// a bar with the tick at 80. Unmeasured is hatched and reads "—".
class _GlassDimension extends StatelessWidget {
  const _GlassDimension({
    required this.label,
    required this.score,
    required this.unmeasurableReason,
    required this.isLast,
  });

  final String label;
  final double? score;
  final String? unmeasurableReason;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = score;
    final status = value == null
        ? LumenStatus.none
        : value >= 80
        ? LumenStatus.good
        : value >= 70
        ? LumenStatus.warn
        : LumenStatus.crit;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.lumen.white(0xB3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: context.lumen.ink,
                  ),
                ),
              ),
              Text(
                value == null ? '—' : value.round().toString(),
                style: LumenGlass.figure(
                  size: 14,
                  color: value == null
                      ? context.lumen.inkMuted
                      : status.swatchOf(colors).ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (value == null)
            SizedBox(
              height: 6,
              child: CustomPaint(
                painter: _HatchPainter(
                  track: context.lumen.track,
                  hatch: Color(0x665B5F75),
                ),
                size: Size.infinite,
              ),
            )
          else
            BenchmarkBar(value: value, target: 80, status: status, height: 6),
          if (value == null && unmeasurableReason != null) ...[
            const SizedBox(height: 6),
            Text(
              unmeasurableReason!,
              style: TextStyle(
                fontSize: 11.5,
                color: context.lumen.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dimension's name in the active language. The keys are the API's
/// ([kDimensionLabels]); an unknown key keeps the repository's English label.
String _dimensionLabel(AppLocalizations l10n, String key, String fallback) =>
    switch (key) {
      'availability' => l10n.outcomeDimensionAvailability,
      'visibility' => l10n.outcomeDimensionVisibility,
      'display' => l10n.outcomeDimensionDisplay,
      'pricing' => l10n.outcomeDimensionPricing,
      'competitive' => l10n.outcomeDimensionCompetitive,
      'salesCapability' => l10n.outcomeDimensionSalesCapability,
      _ => fallback,
    };

/// Why a dimension could not be scored ([kUnmeasurableReasons]), localised.
String? _unmeasurableReason(AppLocalizations l10n, String key) =>
    switch (key) {
      'competitive' => l10n.outcomeUnmeasurableCompetitive,
      'salesCapability' => l10n.outcomeUnmeasurableSalesCapability,
      _ => kUnmeasurableReasons[key],
    };
