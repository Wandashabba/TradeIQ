import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../design/hatch_paint.dart';
import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/tiq_mark.dart';

/// A milestone on a progress-to-reward bar.
@immutable
class ProgressMilestone {
  const ProgressMilestone({
    required this.at,
    this.label,
    this.reward = false,
  });

  /// Where it sits, in the same units as the bar's `value` and `total`.
  final num at;

  /// The words beneath the notch — "R500 at 20 visits". Always beneath, never
  /// inside the track.
  final String? label;

  /// The reward threshold gets a 3dp notch that **breaks the track's top
  /// edge**, so it has a silhouette and not only a hue.
  final bool reward;
}

/// Why a progress bar is not moving.
enum ProgressState {
  /// A known value against a known total.
  determinate,

  /// Working, with no denominator. It never invents one.
  indeterminate,

  /// The fill reached the end. The bar does not disappear — the fraction is
  /// replaced by the word.
  complete,

  /// No progress for ten seconds during an upload.
  stalled,

  /// The filled portion takes a 45° hatch and stops. **The hatch, not the
  /// hue, is the encoding.**
  failed,
}

/// PROGRESS WITH A KNOWN END — a route, an upload, a capture ladder, and the
/// gap list's progress-to-reward.
///
/// ```dart
/// TorchProgressBar(
///   label: 'Visits today',
///   value: 14,
///   total: 20,
///   milestones: [ProgressMilestone(at: 20, label: 'R500 at 20 visits', reward: true)],
/// )
/// ```
///
/// ## Never amber, in any skin, in any state
///
/// The reward bar is *"the most motivating thing an agent sees"* and it is
/// therefore the single most tempting object in the product to light. The
/// near-reward exception was written, argued and **deleted** (unify §1.18): the
/// leading segment goes solid ink-1 with a filled triangle at its head, which
/// survives greyscale and glare and costs nothing. If the moment deserves
/// more, it belongs in the row's sentence — "one visit to R500" — not in the
/// hue. Reaching the reward turns the fill `good` and fills the notch; nothing
/// pulses and nothing celebrates in colour.
///
/// ## The track carries an outline
///
/// `lifted` on `ground` measures 1.67:1, and a track you cannot see cannot
/// state a proportion. 8dp (12 at 2.0× — a track scales at half rate), radius
/// 4, `lifted` fill with a 1px `edgeStructure` outline, `chartNeutral` fill
/// inset 1px inside it with a hard leading edge.
///
/// ## The fraction is always text
///
/// The bar is never the only statement of progress. `6/9` renders beside it in
/// tabular mono, at every text scale, in every state.
class TorchProgressBar extends StatefulWidget {
  const TorchProgressBar({
    super.key,
    required this.label,
    this.value,
    this.total,
    this.state = ProgressState.determinate,
    this.milestones = const <ProgressMilestone>[],
    this.fractionText,
    this.doneWord = 'Done',
    this.workingWord = 'Working',
    this.note,
  });

  /// What is progressing. Never the control — "Visits today", not "Progress".
  final String label;

  final num? value;

  /// Null makes the bar indeterminate however [state] is set: it never
  /// invents a denominator.
  final num? total;

  final ProgressState state;

  /// Empty on a plain bar; one or more on the reward variant.
  final List<ProgressMilestone> milestones;

  /// Overrides the default "14 of 20" — a caller with a localised string.
  final String? fractionText;

  final String doneWord;
  final String workingWord;

  /// "Stuck at 40% · tap to retry".
  final String? note;

  /// 8dp, and **12 at 2.0×**: a track is a graphic, and a graphic scales at
  /// half rate (unify §4, §1.18).
  static double trackHeightFor(BuildContext context) =>
      math.min(8 * (1 + (MarkScale.factor(context) - 1) / 2), 12);

  @override
  State<TorchProgressBar> createState() => _TorchProgressBarState();
}

class _TorchProgressBarState extends State<TorchProgressBar>
    with SingleTickerProviderStateMixin {
  // In `initState`, not lazily in `build` — see the note in `skeleton.dart`.
  late final AnimationController _travel;

  @override
  void initState() {
    super.initState();
    _travel = AnimationController(vsync: this, duration: TiqMotion.skeleton);
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  bool get _indeterminate =>
      widget.state == ProgressState.indeterminate || widget.total == null;

  double get _fraction {
    final total = widget.total;
    final value = widget.value;
    if (total == null || value == null || total == 0) return 0;
    return (value / total).clamp(0.0, 1.0).toDouble();
  }

  bool get _rewardReached {
    final value = widget.value;
    if (value == null) return false;
    for (final m in widget.milestones) {
      if (m.reward && value >= m.at) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final still = MotionBudget.of(context).still;
    final height = TorchProgressBar.trackHeightFor(context);
    final complete =
        widget.state == ProgressState.complete ||
        (widget.total != null && _fraction >= 1);

    final runs =
        _indeterminate &&
        widget.state != ProgressState.stalled &&
        widget.state != ProgressState.failed &&
        !still &&
        skin.motion.enabled &&
        // Veld has no travelling rule at all: an indeterminate bar there is
        // the word "Working".
        skin.density != TiqDensity.veld;
    if (runs && !_travel.isAnimating) {
      _travel.repeat();
    } else if (!runs && _travel.isAnimating) {
      _travel.stop();
    }

    final fractionLine =
        widget.fractionText ??
        (widget.total == null
            ? null
            : '${widget.value ?? 0} of ${widget.total}');

    final veldWorking =
        _indeterminate && skin.density == TiqDensity.veld;

    return Semantics(
      label: widget.label,
      value: _indeterminate
          ? widget.workingWord
          : (fractionLine ?? '${(_fraction * 100).round()}%'),
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Heading(
            label: widget.label,
            labelStyle: skin.text.label.style(color: p.ink2),
            // THE FRACTION IS ALWAYS TEXT. Even at zero — "0/9" is
            // information, and a hidden bar is not.
            figure: complete
                ? widget.doneWord
                : _indeterminate
                ? widget.workingWord
                : (fractionLine ?? ''),
            figureStyle: complete
                ? skin.text.bodyStrong.style(color: p.good)
                : skin.text.figureS.style(color: p.ink2),
          ),
          const SizedBox(height: TiqSpace.s2),
          if (veldWorking)
            // No track that states nothing. Outdoors, the word is the whole
            // statement.
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.workingWord,
                style: skin.text.bodyStrong.style(color: p.ink1),
              ),
            )
          else
            SizedBox(
              height: height,
              child: AnimatedBuilder(
                animation: _travel,
                builder: (context, _) => CustomPaint(
                  painter: _TrackPainter(
                    skin: skin,
                    fraction: _indeterminate ? 0 : _fraction,
                    indeterminate: _indeterminate,
                    travel: runs ? _travel.value : null,
                    failed: widget.state == ProgressState.failed,
                    rewardReached: _rewardReached,
                    milestones: widget.milestones,
                    total: widget.total,
                  ),
                ),
              ),
            ),
          if (widget.milestones.any((m) => m.label != null)) ...<Widget>[
            const SizedBox(height: TiqSpace.s1),
            // THE WORDS ARE ALWAYS BENEATH. A label inside a 8dp track is a
            // label nobody can read.
            Text(
              widget.milestones
                  .where((m) => m.label != null)
                  .map((m) => m.label!)
                  .join(' · '),
              style: skin.text.meta.style(
                color: _rewardReached ? p.good : p.ink3,
              ),
            ),
          ],
          if (widget.note != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s1),
            Text(
              widget.note!,
              style: skin.text.meta.style(color: p.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bar's own heading: what is progressing, and how far.
///
/// **Measured, then stacked** — never a `Row` that assumes both fit. "Closest:
/// Thandi Mokoena" beside "14 of 20 visits" is about 360dp of type at 2.0x on
/// a 360dp phone, and the Row this replaced ran 160dp off the right edge at
/// exactly the setting whose reader needed it most. Neither side may shrink:
/// the fraction is the bar's only statement in words and the label names whose
/// progress it is, so when they will not sit side by side the figure drops
/// beneath and both stay whole.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.label,
    required this.labelStyle,
    required this.figure,
    required this.figureStyle,
  });

  final String label;
  final TextStyle labelStyle;
  final String figure;
  final TextStyle figureStyle;

  static double _widthOf(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            constraints.maxWidth.isFinite &&
            _widthOf(label, labelStyle, scaler, direction) +
                    TiqSpace.s2 +
                    _widthOf(figure, figureStyle, scaler, direction) <=
                constraints.maxWidth;

        if (fits) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Text(label, style: labelStyle)),
              const SizedBox(width: TiqSpace.s2),
              Text(figure, style: figureStyle),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: labelStyle),
            const SizedBox(height: TiqSpace.s1),
            Text(figure, style: figureStyle),
          ],
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.skin,
    required this.fraction,
    required this.indeterminate,
    required this.travel,
    required this.failed,
    required this.rewardReached,
    required this.milestones,
    required this.total,
  });

  final TiqSkin skin;
  final double fraction;
  final bool indeterminate;

  /// 0..1 while the Oatmeal rule is travelling; null when it is not.
  final double? travel;

  final bool failed;
  final bool rewardReached;
  final List<ProgressMilestone> milestones;
  final num? total;

  @override
  void paint(Canvas canvas, Size size) {
    final p = skin.palette;
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final border = skin.depth.borderWidth;

    canvas.drawRRect(track, Paint()..color = p.lifted);
    canvas.drawRRect(
      track.deflate(border / 2),
      Paint()
        ..color = p.edgeStructure
        ..style = PaintingStyle.stroke
        ..strokeWidth = border,
    );

    if (!indeterminate && fraction > 0) {
      final fillRect = Rect.fromLTWH(
        border,
        border,
        (size.width - border * 2) * fraction,
        size.height - border * 2,
      );
      if (fillRect.width > 0) {
        final rr = RRect.fromRectAndRadius(fillRect, radius);
        if (failed) {
          // THE HATCH IS THE ENCODING, not the hue. 45° stripes, hard-stop,
          // no blur — this painter runs inside scrolling lists.
          canvas.save();
          canvas.clipRRect(rr);
          HatchPaint.paint(
            canvas,
            fillRect,
            HatchPaint.spec(skin, HatchPattern.negative),
          );
          canvas.restore();
        } else {
          canvas.drawRRect(
            rr,
            Paint()..color = rewardReached ? p.good : p.chartNeutral,
          );
        }
      }
    }

    if (travel != null) {
      // The skeleton's own mechanism, reused, so the app has one "working"
      // motion rather than two. Oatmeal, never amber.
      final runWidth = size.width * 0.28;
      final x = (size.width + runWidth) * travel! - runWidth;
      canvas.save();
      canvas.clipRRect(track);
      canvas.drawRect(
        Rect.fromLTWH(x, 0, runWidth, 2),
        Paint()..color = p.ink2,
      );
      canvas.restore();
    }

    final denominator = total;
    if (denominator == null || denominator == 0) return;
    for (final m in milestones) {
      final t = (m.at / denominator).clamp(0.0, 1.0).toDouble();
      final x = size.width * t;
      final tickWidth = m.reward ? 3.0 : 2.0;
      // The reward notch BREAKS the track's top edge by 3dp, so it has a
      // silhouette rather than only a hue.
      final top = m.reward ? -3.0 : 0.0;
      canvas.drawRect(
        Rect.fromLTWH(
          (x - tickWidth / 2).clamp(0, size.width - tickWidth),
          top,
          tickWidth,
          size.height - top,
        ),
        Paint()..color = m.reward ? p.ink1 : p.ink3,
      );
      if (m.reward && rewardReached) {
        canvas.drawCircle(
          Offset(x.clamp(0, size.width), size.height / 2),
          size.height / 2 + 1,
          Paint()..color = p.good,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.fraction != fraction ||
      old.indeterminate != indeterminate ||
      old.travel != travel ||
      old.failed != failed ||
      old.rewardReached != rewardReached ||
      old.skin != skin;
}
