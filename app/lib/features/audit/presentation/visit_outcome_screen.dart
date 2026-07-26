import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/console.dart';
import '../data/scorecards_repository.dart';

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

    return AgentScaffold(
      title: 'Visit submitted',
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
            label: 'Next store',
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
        error: (_, _) =>
            const _HeldOnPhone(reason: 'Could not reach the server just now'),
        data: (outcome) {
          if (outcome.isHeldOnPhone) {
            return const _HeldOnPhone(reason: 'No signal right now');
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
            'Sending your visit…',
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
  const _HeldOnPhone({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const Center(child: TickMark(done: true, size: 44)),
        const SizedBox(height: 16),
        Text(
          'Your visit is safe on this phone',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.ink1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$reason — it will send itself the moment you have signal. '
          'You can close the app.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: colors.ink2),
        ),
        const SizedBox(height: 22),
        const StatusBanner(
          level: BannerLevel.warn,
          title: 'Scored when it sends',
          subtitle: 'Your score is worked out on the server, not on the phone',
        ),
        const SizedBox(height: 12),
        Text(
          // Not showing a number here is deliberate, and worth one sentence:
          // an agent who is shown 74 in the shop and finds 68 in the morning
          // will not trust the third one.
          'We are not guessing at a score here. You will see the real one — the '
          'same one your manager sees — as soon as this reaches the server.',
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
    final score = outcome.score!;
    final band = _band(colors, score.ratingBand);
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
                    // The dot is a graphical mark, so it keeps the raw status
                    // token; the word beside it carries the AA-safe tint.
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: band.dot,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      // The band is spelled out, never left to the dot's colour.
                      band.word,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: band.text,
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
        const _Heading('How it was scored'),
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
                    label: entry.value,
                    // Absent means the server could not measure it. It shows as
                    // "—", never as a zero that reads like the agent failed at
                    // something they were never given a chance to do (#93).
                    score: score.scoreOf(entry.key),
                    unmeasurableReason: kUnmeasurableReasons[entry.key],
                    isLast: i == kDimensionLabels.length - 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Band → (dot mark colour, AA-safe word colour, spelled word). The dot keeps
  /// the raw status token; the word takes the text-grade tint — red as `crit`
  /// text fails 4.5:1 on the hero wash, so the word uses `critText`.
  static ({Color dot, Color text, String word}) _band(
    TiqColors colors,
    String band,
  ) => switch (band) {
    'green' => (dot: colors.good, text: colors.good, word: 'Green'),
    'amber' => (dot: colors.warn, text: colors.warn, word: 'Amber'),
    _ => (dot: colors.crit, text: colors.critText, word: 'Red'),
  };
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
    final rounded = points.round();
    if (rounded == 0) {
      return Text(
        'Same as your last visit here (${previous.weightedTotal.round()}).',
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
          '${up ? 'Up' : 'Down'} ${rounded.abs()} '
          '${rounded.abs() == 1 ? 'point' : 'points'}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          ' from your last visit here (${previous.weightedTotal.round()}).',
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
  _HatchPainter({required this.track, required this.hatch});

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
