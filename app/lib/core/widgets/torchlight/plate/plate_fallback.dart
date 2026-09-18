import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// THE PLATE WITH NO PHOTOGRAPH.
///
/// Five horizontal rules receding in perspective, and a sentence saying why
/// they are there. Fixed spacing, not data-driven: manager's version drove the
/// gaps from the territory's availability trend so a shelf read tighter when
/// availability was worse, and unify §1.16 cut it because nobody decodes line
/// spacing. What survives is the part that was always doing the work — a shape
/// that is obviously a drawing, plus a sentence.
///
/// It is **never amber**, in any skin, in any state. The manager spec granted
/// the data-driven variant the screen's one light; with the data gone the
/// light has nothing to be about, and the spec's own sentence for the
/// first-run case — "amber withheld because there is nothing to light" — is
/// the right rule for every case. A lit decorative drawing is a gradient
/// pretending to be a photograph, which is the one thing this component exists
/// to avoid.
///
/// The five values are composited from tokens rather than painted with an
/// opacity, because opacity is banned as a state channel and a declared colour
/// is a colour somebody can look at.
class PlateFallback extends StatelessWidget {
  const PlateFallback({super.key, this.rules = 5});

  /// Five. The parameter exists so the painter's arithmetic is testable at
  /// another count, not so a caller can choose a different drawing.
  final int rules;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return CustomPaint(
      painter: _PerspectiveRules(
        ground: skin.palette.ground,
        ink: skin.palette.edgeControl,
        rules: rules,
      ),
      // The drawing is decoration; the sentence beside it carries the meaning
      // and lives on the plate, not here.
      isComplex: false,
      willChange: false,
      child: const SizedBox.expand(),
    );
  }
}

/// The receding rules. Perspective is faked the way it is faked on paper: each
/// gap is a fixed ratio of the one below it, so the lines crowd towards the
/// horizon without anybody computing a vanishing point.
class _PerspectiveRules extends CustomPainter {
  const _PerspectiveRules({
    required this.ground,
    required this.ink,
    required this.rules,
  });

  final Color ground;
  final Color ink;
  final int rules;

  /// Nearest rule at 0.30 of the way from the ground to the ink, furthest at
  /// 0.04 — the ramp the spec declares, resolved into five real colours.
  static const double _nearest = 0.30;
  static const double _furthest = 0.04;

  /// Each gap is this fraction of the gap below it.
  static const double _foreshortening = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    if (rules < 2 || size.isEmpty) return;

    // Lay the gaps out from the bottom up, then normalise so the top rule
    // lands at the top of the box whatever the box is.
    final gaps = <double>[];
    var gap = 1.0;
    for (var i = 0; i < rules - 1; i++) {
      gaps.add(gap);
      gap *= _foreshortening;
    }
    final total = gaps.fold<double>(0, (a, b) => a + b);
    final unit = total == 0 ? 0.0 : (size.height * 0.78) / total;

    // The horizon is inset from the top so the furthest rule is not flush with
    // the plate's edge — a rule on the edge reads as a border.
    var y = size.height * 0.94;
    final paint = Paint()..style = PaintingStyle.stroke;

    for (var i = 0; i < rules; i++) {
      final t = rules == 1 ? 0.0 : i / (rules - 1);
      // Nearest (i = 0) is the strongest.
      final mix = _nearest + (_furthest - _nearest) * t;
      paint
        ..color = Color.lerp(ground, ink, mix)!
        // The near rules are thicker. Never under 1px: a hairline that
        // disappears on a cheap panel is a rule that was not drawn.
        ..strokeWidth = 2.0 - t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      if (i < gaps.length) y -= gaps[i] * unit;
    }
  }

  @override
  bool shouldRepaint(_PerspectiveRules old) =>
      old.ground != ground || old.ink != ink || old.rules != rules;
}
