import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// THE CLOSED ENUM OF THREE — unify §1.12.
///
/// Three drawings, reused by category, and a fourth requires an owner decision
/// and an illustrator rather than an import. That closure is the whole point.
/// The first draft said "a single object drawn from the domain", which across
/// at least eight named empty states means eight bespoke drawings nobody will
/// commission, which means a stock outline set, which means this product's
/// most carefully argued anti-slop surface ends up wearing the same icons as
/// every SaaS dashboard on earth.
enum EmptyDrawing {
  /// No content. An empty route, a filtered-to-nothing list, a search that
  /// found nothing, a finished day.
  shelf,

  /// No location. A missing permission, no fix, nothing near here.
  pin,

  /// Nothing sent, or nothing received. An empty outbox, an offline first run.
  envelope,
}

/// THE THREE DRAWINGS, DRAWN.
///
/// They were a placeholder for a long time: a crude single-stroke schematic
/// inside a **dashed frame**, on the argument that a placeholder which looks
/// finished is a placeholder that ships. It shipped anyway, and a dashed box
/// around a stick drawing does not read as "artwork pending" to a manager
/// looking at their own territory — it reads as an image that failed to load.
/// Every genuine empty state in the product wore it.
///
/// So they are drawn properly here, in the vocabulary that was already in the
/// building: [MarkShape]'s idiom, one step larger. All geometry is expressed
/// against the shortest side, so a drawing is the same shape at 48dp and at
/// 96dp; nothing calls `saveLayer`, nothing casts a shadow, and nothing is
/// hatched.
///
/// ## One family, one rule
///
/// Each drawing is **an outline at [strokeFor], with exactly one solid part**.
/// That is what separates these from a schematic: a line says "diagram", and a
/// solid says "object". The shelf's boards are filled because a plank is a
/// plank; the pin's eye is filled because a fix is a point; the envelope's
/// flap is filled because a flap catches the light. Three drawings that share
/// a rule read as one hand, which is the thing a stock icon set can never do.
///
/// ## Still no import, and still three
///
/// Drawn paths only. No asset, no font glyph, no stock outline set, no emoji —
/// the closed enum exists to make that impossible and it still does. Nothing
/// in `lib/features` names this painter; the API is the enum and
/// [EmptyStateDrawing], and **#404** — should the owner still want an
/// illustrator's hand on them — replaces the bodies of the three `case` arms
/// below and nothing else.
///
/// They are decorative in every state. The headline is the header and the body
/// is the instruction; a drawing that announced itself would be a screen
/// reader reading out a picture of a shelf.
class EmptyStateDrawing extends StatelessWidget {
  const EmptyStateDrawing({
    super.key,
    required this.drawing,
    this.color,
    this.extent,
  });

  final EmptyDrawing drawing;

  /// `edgeControl` for an empty state, `bad` for an error state.
  final Color? color;

  /// 64 by default.
  final double? extent;

  /// The declared extent for a skin.
  static double extentFor(TiqSkin skin) => 64;

  /// 2px.
  static double strokeFor(TiqSkin skin) => 2;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final size = extent ?? extentFor(skin);
    return ExcludeSemantics(
      // Decorative, always. See the class doc.
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _EmptyDrawingPainter(
            drawing: drawing,
            color: color ?? skin.palette.edgeControl,
            strokeWidth: strokeFor(skin),
          ),
        ),
      ),
    );
  }
}

class _EmptyDrawingPainter extends CustomPainter {
  const _EmptyDrawingPainter({
    required this.drawing,
    required this.color,
    required this.strokeWidth,
  });

  final EmptyDrawing drawing;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // The drawing sits in a square inset from the extent, so two of these
    // stacked in a review sheet have air between them and a stroke at the
    // edge is never clipped by a parent that rounds.
    final box = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: s,
      height: s,
    ).deflate(s * 0.08);

    switch (drawing) {
      case EmptyDrawing.shelf:
        _shelf(canvas, box, stroke, fill);
      case EmptyDrawing.pin:
        _pin(canvas, box, stroke, fill);
      case EmptyDrawing.envelope:
        _envelope(canvas, box, stroke, fill);
    }
  }

  /// NO CONTENT — a shelving unit, face on, with nothing on it.
  ///
  /// Two uprights and three solid boards. The boards **overhang** the uprights
  /// by design: rungs that stop inside their rails are a ladder, and a ladder
  /// is not what an empty list means. The emptiness is carried by the air
  /// between the boards, which is the whole drawing — there is deliberately
  /// nothing standing on them.
  void _shelf(Canvas canvas, Rect r, Paint stroke, Paint fill) {
    // Wider than tall. A square unit with three equal bands across it is a
    // window; a shelf is a piece of furniture and stands in a wider frame.
    final unit = Rect.fromCenter(
      center: r.center,
      width: r.width,
      height: r.height * 0.88,
    );
    final w = unit.width;
    final h = unit.height;
    final board = math.max(strokeWidth, h * 0.07);
    // Only just proud of the uprights. Rungs flush inside their rails are a
    // ladder; boards that overhang hard are a film strip. Four per cent is
    // the width of the difference.
    final left = unit.left + w * 0.04;
    final right = unit.right - w * 0.04;

    canvas
      ..drawLine(Offset(left, unit.top), Offset(left, unit.bottom), stroke)
      ..drawLine(Offset(right, unit.top), Offset(right, unit.bottom), stroke);

    // Three planks: top, middle, bottom, each a solid bar seen edge-on rather
    // than a rule. The air between them is the drawing — there is deliberately
    // nothing standing on them.
    for (var i = 0; i < 3; i++) {
      final cy = unit.top + board / 2 + (h - board) * (i / 2);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(unit.center.dx, cy),
          width: w,
          height: board,
        ),
        fill,
      );
    }
  }

  /// NO LOCATION — a map pin: a true teardrop, with a solid eye.
  ///
  /// The sides are the real tangents from the point to the head, computed
  /// rather than eyeballed, so the silhouette closes without a kink. The eye
  /// is filled: a pin is a claim about one point, and a hollow ring inside a
  /// hollow outline is two rings and no claim.
  void _pin(Canvas canvas, Rect r, Paint stroke, Paint fill) {
    final s = r.shortestSide;
    final radius = s * 0.30;
    final centre = Offset(r.center.dx, r.top + radius + strokeWidth / 2);
    final apex = Offset(r.center.dx, r.bottom - strokeWidth / 2);
    final d = apex.dy - centre.dy;
    // The head is always well clear of the point at these proportions, but a
    // caller may pass a very small extent: fall back to the head alone rather
    // than taking the acos of a number outside [-1, 1].
    if (d <= radius) {
      canvas
        ..drawCircle(centre, radius, stroke)
        ..drawCircle(centre, radius * 0.34, fill);
      return;
    }
    // The tangent touches the head where the angle off the centre→apex axis
    // is acos(r / d). The axis points straight down, which is +π/2 in canvas
    // angles, so the two touch points are at π/2 ± α.
    final alpha = math.acos(radius / d);
    final head = Rect.fromCircle(center: centre, radius: radius);
    final start = math.pi / 2 + alpha;
    final path = Path()
      // The long way round the head — everything except the arc between the
      // two tangent points on the apex's side.
      ..arcTo(head, start, 2 * math.pi - 2 * alpha, true)
      ..lineTo(apex.dx, apex.dy)
      ..close();

    canvas
      ..drawPath(path, stroke)
      ..drawCircle(centre, radius * 0.34, fill);
  }

  /// NOTHING SENT OR RECEIVED — an envelope, closed, with a solid flap.
  ///
  /// The body is a rounded rectangle because a real envelope has soft corners
  /// and a hard-cornered box at 64dp is a box. The flap is the one solid part,
  /// and it stops at 46% of the body rather than at its centre: a V that
  /// reaches the middle of the rectangle turns the whole drawing into an
  /// hourglass at a glance.
  void _envelope(Canvas canvas, Rect r, Paint stroke, Paint fill) {
    final w = r.width;
    // 3:2, centred in the square: an envelope is not square, and a square one
    // reads as a picture frame.
    final h = w * 0.68;
    final body = Rect.fromCenter(
      center: r.center,
      width: w,
      height: h,
    ).deflate(strokeWidth / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.06)),
      stroke,
    );

    final tip = Offset(body.center.dx, body.top + body.height * 0.46);
    canvas
      ..drawPath(
        Path()
          ..moveTo(body.left, body.top)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(body.right, body.top)
          ..close(),
        fill,
      )
      // The fold, stroked over the fill, so the flap has an edge where it
      // meets the body's top rather than bleeding into it.
      ..drawPath(
        Path()
          ..moveTo(body.left, body.top)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(body.right, body.top),
        stroke,
      );
  }

  @override
  bool shouldRepaint(_EmptyDrawingPainter old) =>
      old.drawing != drawing ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
