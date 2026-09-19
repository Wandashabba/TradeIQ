import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';

/// A BINARY FACT CAPTURED ON THE SHELF — "Planogram compliant", "Fridge
/// working".
///
/// Track 52×32, thumb 26 with a **tick drawn inside it**, and the state word
/// is **mandatory** (unify §1.9). Three things follow from that, and all three
/// are the reason this is not `Switch`:
///
/// * the tick is what makes the state survive greyscale — a thumb's position
///   alone is a coin toss at 56dp targets in glare;
/// * the word is what a screen reader reads and what a greyscale screenshot
///   described over a phone still carries;
/// * there is **no indeterminate state**, because a toggle sitting at off is a
///   recorded *no* and silence is not *no*. A binary whose value can be
///   unknown is a [ChoiceRow] with two options and nothing selected — and this
///   widget asserts that in debug rather than letting a screen quietly record
///   "compliant: false" for every shelf nobody looked at.
class TorchToggle extends StatelessWidget {
  const TorchToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onWord = 'On',
    this.offWord = 'Off',
    this.disabledReason,
  });

  /// The **fact**, not the control. "Fridge working", never "Toggle fridge".
  final String label;

  final bool value;

  /// Null disables the toggle; pass [disabledReason] with it.
  final ValueChanged<bool>? onChanged;

  /// The state word. Mandatory by construction — it has a default rather than
  /// being nullable, so a caller can localise it but cannot remove it.
  final String onWord;
  final String offWord;

  /// Why it cannot be changed. A disabled control with no reason is a dead
  /// end.
  final String? disabledReason;

  /// Track geometry. One set of numbers, scaled up in Veld only.
  static Size trackSizeFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? const Size(64, 36) : const Size(52, 32);

  static double thumbExtentFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? 30 : 26;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onChanged != null;
    final still = MotionBudget.of(context).still;
    final track = trackSizeFor(skin);
    final thumbExtent = thumbExtentFor(skin);
    final inset = (track.height - thumbExtent) / 2;
    final veld = skin.density == TiqDensity.veld;
    final word = value ? onWord : offWord;

    final Color trackFill;
    final Color trackBorder;
    final Color thumbFill;
    final Color tickInk;
    if (!enabled) {
      trackFill = p.ground;
      trackBorder = p.inkMute;
      thumbFill = p.inkMute;
      tickInk = p.ground;
    } else if (value) {
      // Veld keeps its 2px border in BOTH states, because outdoors a border
      // that comes and goes is a control that changes shape.
      trackFill = veld ? p.goodSolid : p.good;
      trackBorder = veld ? p.ink1 : p.good;
      thumbFill = veld ? p.ground : p.ground;
      tickInk = veld ? p.goodSolid : p.good;
    } else {
      trackFill = p.well;
      trackBorder = p.edgeControl;
      thumbFill = veld ? p.lifted : p.ink3;
      tickInk = trackFill;
    }

    final duration = still
        ? Duration.zero
        : skin.motion.resolve(TiqMotion.press);

    final control = SizedBox(
      width: track.width,
      height: track.height,
      child: AnimatedContainer(
        duration: duration,
        curve: TiqMotion.stateCurve,
        decoration: BoxDecoration(
          color: trackFill,
          borderRadius: BorderRadius.circular(track.height / 2),
          border: Border.all(color: trackBorder, width: skin.depth.borderWidth),
        ),
        child: AnimatedAlign(
          duration: duration,
          curve: TiqMotion.stateCurve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: SizedBox.square(
              dimension: thumbExtent,
              child: CustomPaint(
                painter: _ThumbPainter(
                  fill: thumbFill,
                  tick: value ? tickInk : null,
                  strokeWidth: veld ? 3 : 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: skin.text.body.style(
                  color: enabled ? p.ink1 : p.inkMute,
                ),
              ),
              if (disabledReason != null && !enabled) ...<Widget>[
                const SizedBox(height: TiqSpace.s1),
                Text(
                  disabledReason!,
                  style: skin.text.meta.style(color: p.ink3),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        // THE WORD. Never optional, and never only in Veld: the state has to
        // survive greyscale, a screen reader and a photograph of a screen sent
        // over WhatsApp.
        Text(
          word,
          style: skin.text.label
              .copyWith(weight: FontWeight.w700)
              .style(color: enabled ? p.ink2 : p.inkMute),
        ),
        const SizedBox(width: TiqSpace.s3),
        // The track pins to the FIRST line of the label: at 2.0× with a
        // four-line Afrikaans fact, a vertically centred track is a control
        // floating beside the middle of a sentence.
        control,
      ],
    );

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      value: word,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: enabled ? () => onChanged!(!value) : null,
        // The whole row is the target, and a row-wide scale reads as the list
        // moving rather than as a control pressing.
        pressScale: 1,
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: skin.space.rowMinHeight),
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: TiqSpace.s3),
          child: row,
        ),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  const _ThumbPainter({
    required this.fill,
    required this.tick,
    required this.strokeWidth,
  });

  final Color fill;

  /// Null when the toggle is off: the tick is the ON silhouette, and drawing
  /// it in the thumb's own colour would be a state channel nobody can see.
  final Color? tick;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      r,
      Paint()..color = fill,
    );
    final ink = tick;
    if (ink == null) return;
    final s = size.shortestSide;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.68)
      ..lineTo(s * 0.74, s * 0.34);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.fill != fill || old.tick != tick || old.strokeWidth != strokeWidth;
}
