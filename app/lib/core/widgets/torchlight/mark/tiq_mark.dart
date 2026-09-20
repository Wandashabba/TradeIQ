import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// THE SILHOUETTE VOCABULARY.
///
/// Every mark in the system is one of these shapes, drawn. Not a font glyph,
/// not an icon pack, not a character.
///
/// The reason is a bug this product already shipped: `TileDelta.text` built
/// `▲`/`▼` as characters, and the `pyftsubset` step that keeps Onest under a
/// megabyte does not carry U+25B2/U+25BC. On a device that fell back to the
/// subset the delta rendered as tofu, and in the PDF exporter (#401) it
/// rendered as nothing at all — a number with no direction beside it, which is
/// worse than no delta. A drawn path has no codepoint to lose.
///
/// ## The law these shapes exist to satisfy
///
/// Colour is never the only signal (unify §4). Every hue-coded distinction
/// carries a second channel, and the second channel is the one that has to
/// survive greyscale, deuteranopia, glare and a screen reader. That is what a
/// silhouette is for: [criticalTriangle] and [watchTriangle] are the same hue
/// at two commitment levels and two different shapes, and [sectionRing] and
/// [sectionBarredRing] differ by a bar that is still there when the colour is
/// gone.
///
/// ## No pattern inside a glyph
///
/// None of these shapes is hatched, and none may be. A 3dp stripe inside a
/// 28dp tile aliases to a flat grey disc at 40% backlight on an entry LCD,
/// which is exactly what [sectionHalfDisc] — "in progress" — looks like. The
/// hatch registry asserts it; this enum simply does not offer the option.
enum MarkShape {
  // ── Severity: one hue, two commitment levels ───────────────────────────
  /// Critical. A solid triangle, apex up.
  criticalTriangle,

  /// Watch. The same triangle outlined, with its lower half filled — one
  /// commitment level down, and a different silhouette rather than a paler
  /// version of the same one.
  watchTriangle,

  /// On target. A filled circle.
  onTargetCircle,

  /// Held / queued. A filled square in Oatmeal (unify §1.13). Truffle is the
  /// comparison series and nothing else.
  heldSquare,

  /// Not measured, as a MARK (a dimension's row marker, not its track): a
  /// hollow square with a 2dp diagonal bar. Manager's hatched square became
  /// this one under unify §1.5 — a pattern this small is noise.
  notMeasuredBarredSquare,

  // ── Section state (unify §1.5) ─────────────────────────────────────────
  /// Not started. An empty ring.
  sectionRing,

  /// In progress. A half disc: the ring, with its lower half filled solid.
  sectionHalfDisc,

  /// Done. A filled disc with the tick knocked out of it in the ground
  /// colour.
  sectionTickDisc,

  /// Can't confirm. The ring at the empty ring's stroke weight, with a 2px
  /// diagonal bar across it. **Its own silhouette, not a hatch** — this is the
  /// whole of unify §1.5.
  sectionBarredRing,

  // ── Delta (unify §1.5, §4) ─────────────────────────────────────────────
  /// A rise. Flat-bottomed, pointing up.
  deltaUp,

  /// A fall. Flat-topped, pointing down.
  deltaDown,

  /// No change. A rectangle, not a triangle and not a dash: a dash is a
  /// character and an em dash already means "we do not know".
  deltaFlat,

  /// A reconciliation's direction. The same triangle, hollow at a 1.5dp
  /// stroke, and never good or bad — the arithmetic changed, the performance
  /// did not.
  deltaHollowUp,
  deltaHollowDown,

  // ── Flag family: six neutral silhouettes, plus the one severity ────────
  /// Out of fence. A ring with a gap in it.
  flagBrokenRing,

  /// Flagged for review. An eye with a bar through it.
  flagEyeBarred,

  /// Unfinished visit. A three-quarter arc, left open.
  flagThreeQuarterArc,

  /// Skipped. A ring with a rising strike through it.
  flagStruckRing,

  /// No GPS. A pin outline with a gap in its lower arc.
  flagPinWithGap,

  /// Sent back. An arrow returning to a wall — the only flag that carries
  /// severity, because a human rejected the work.
  flagReturnArrow,

  // ── Small parts ───────────────────────────────────────────────────────
  /// The Live chip's dot, and the reconciliation line's neutral square is
  /// [heldSquare].
  dot,

  /// Low sample. A hollow square at a 1.5dp stroke, beside the sample line.
  hollowSquare,

  /// Provisional. A hollow circle, beside the word.
  hollowCircle,

  /// Confirmed. A filled circle at the same size as [hollowCircle], so
  /// "confirmed" and "provisional" are the same mark filled and not filled.
  filledCircle,
}

/// One drawn mark.
///
/// Carries no semantics of its own. Every mark in this system renders beside
/// its word — the word is what a screen reader reads and what survives a
/// greyscale screenshot being described over a phone — so a `Semantics` node
/// here would double-read every row in the product.
class TiqMark extends StatelessWidget {
  const TiqMark({
    super.key,
    required this.shape,
    required this.color,
    this.size = 12,
    this.strokeWidth,
    this.ground,
  });

  final MarkShape shape;

  /// The ink. Bound in the same token as the word by every component that uses
  /// this, so a level cannot be given a hue without a silhouette and a label.
  final Color color;

  /// The mark's extent, already scaled by the caller. Meaning-bearing glyphs
  /// scale with text (unify §4) and decorative ones do not, and only the
  /// caller knows which it is holding — see [MarkScale].
  final double size;

  /// Defaults to 2, or 3 in Veld, where a 2px line at arm's length in glare is
  /// a smudge. 1.5 for the low-sample and reconciliation marks, which say
  /// "less committed" with a lighter stroke rather than a paler colour.
  final double? strokeWidth;

  /// The colour knocked out of a filled mark — the tick inside
  /// [MarkShape.sectionTickDisc]. Defaults to the skin's ground.
  final Color? ground;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: MarkPainter(
          shape: shape,
          color: color,
          strokeWidth: strokeWidth ?? defaultStrokeFor(skin),
          ground: ground ?? skin.palette.ground,
        ),
      ),
    );
  }

  /// 2dp on Night and Day, 3dp in Veld.
  static double defaultStrokeFor(TiqSkin skin) =>
      skin.depth.borderWidth >= 2 ? 3 : 2;
}

/// How a mark's size follows the text scale.
///
/// Unify §4: *meaning-bearing glyphs scale with text (tile 28→48, glyph 16→32,
/// delta triangle 8→16, chips' glyphs 16→32); decorative marks stay fixed;
/// tracks scale at half rate.* Those four numbers are the whole rule, and they
/// are here rather than in each component so that a new mark cannot pick its
/// own curve.
class MarkScale {
  MarkScale._();

  /// The app-wide text-scale ceiling. 2.0, as declared everywhere else; the
  /// one documented exception (`hero.figure` at 1.6) lives on its token.
  static const double ceiling = 2.0;

  /// The live scaler, clamped. Applied through `TextScaler.scale()`, never as
  /// a factor multiplied into a size — a factor stops being right the moment
  /// the platform stops being linear.
  static double factor(BuildContext context) {
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    return scaler.clamp(maxScaleFactor: ceiling).scale(100) / 100;
  }

  /// A glyph that carries meaning: `base` at 1.0×, `base × 2` at 2.0×.
  static double glyph(BuildContext context, double base) =>
      base * factor(context);

  /// The section-state tile: 28 at 1.0×, **48** at 2.0× — not 56. The tile is
  /// a container for a glyph, and a container that doubled would push a
  /// nine-rung ladder off the fold at the exact setting that needed it most.
  static double tile(BuildContext context, {double base = 28, double max = 48}) {
    final t = (factor(context) - 1).clamp(0.0, 1.0);
    return base + (max - base) * t;
  }

  /// A track, a rule, a hatch: half rate.
  static double track(BuildContext context, double base) =>
      base * (1 + (factor(context) - 1) / 2);
}

/// Draws one [MarkShape].
///
/// All geometry is expressed against the shortest side, so a mark is the same
/// shape at 8dp and at 32dp. Nothing here calls `saveLayer`, and nothing casts
/// a shadow: this painter is used inside `ListView.builder` rows.
class MarkPainter extends CustomPainter {
  const MarkPainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
    required this.ground,
  });

  final MarkShape shape;
  final Color color;
  final double strokeWidth;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: s,
      height: s,
    );
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    switch (shape) {
      case MarkShape.criticalTriangle:
        canvas.drawPath(_triangle(rect, up: true), fill);
      case MarkShape.watchTriangle:
        _halfTriangle(canvas, rect, stroke, fill);
      case MarkShape.onTargetCircle:
      case MarkShape.filledCircle:
        canvas.drawCircle(rect.center, s / 2 - strokeWidth / 2, fill);
      case MarkShape.heldSquare:
        canvas.drawRect(rect.deflate(s * 0.08), fill);
      case MarkShape.notMeasuredBarredSquare:
        canvas.drawRect(rect.deflate(strokeWidth / 2), stroke);
        _bar(canvas, rect, stroke, falling: true, inset: 0.18);
      case MarkShape.sectionRing:
        canvas.drawCircle(rect.center, s / 2 - strokeWidth / 2, stroke);
      case MarkShape.sectionHalfDisc:
        _halfDisc(canvas, rect, stroke, fill);
      case MarkShape.sectionTickDisc:
        canvas.drawCircle(rect.center, s / 2, fill);
        _tick(canvas, rect);
      case MarkShape.sectionBarredRing:
        canvas.drawCircle(rect.center, s / 2 - strokeWidth / 2, stroke);
        _bar(canvas, rect, stroke, falling: true, inset: 0.14);
      case MarkShape.deltaUp:
        canvas.drawPath(_triangle(rect, up: true), fill);
      case MarkShape.deltaDown:
        canvas.drawPath(_triangle(rect, up: false), fill);
      case MarkShape.deltaFlat:
        // An 8 × 2 bar at the mark's own width. Not a dash: an em dash is the
        // one mark that means "we do not know", and a movement of zero is a
        // measurement.
        canvas.drawRect(
          Rect.fromCenter(center: rect.center, width: s, height: s / 4),
          fill,
        );
      case MarkShape.deltaHollowUp:
        canvas.drawPath(_triangle(rect.deflate(strokeWidth / 2), up: true), stroke);
      case MarkShape.deltaHollowDown:
        canvas.drawPath(_triangle(rect.deflate(strokeWidth / 2), up: false), stroke);
      case MarkShape.flagBrokenRing:
        // A ring with a bite out of its right side: the fence is not closed.
        canvas.drawArc(
          rect.deflate(strokeWidth / 2),
          -math.pi / 4,
          math.pi * 1.5,
          false,
          stroke,
        );
      case MarkShape.flagEyeBarred:
        _eye(canvas, rect, stroke);
        _bar(canvas, rect, stroke, falling: true, inset: 0.02);
      case MarkShape.flagThreeQuarterArc:
        // Three quarters of the ring, open at the top right — the visit that
        // was not closed.
        canvas.drawArc(
          rect.deflate(strokeWidth / 2),
          math.pi / 2,
          math.pi * 1.5,
          false,
          stroke,
        );
      case MarkShape.flagStruckRing:
        canvas.drawCircle(rect.center, s / 2 - strokeWidth / 2, stroke);
        // The strike RISES, where the section glyph's bar and the not-measured
        // square's bar fall. Two bars in one screen must not be one material.
        _bar(canvas, rect, stroke, falling: false, inset: 0.14);
      case MarkShape.flagPinWithGap:
        _pin(canvas, rect, stroke);
      case MarkShape.flagReturnArrow:
        _returnArrow(canvas, rect, stroke);
      case MarkShape.dot:
        canvas.drawCircle(rect.center, s / 2, fill);
      case MarkShape.hollowSquare:
        canvas.drawRect(rect.deflate(strokeWidth / 2), stroke);
      case MarkShape.hollowCircle:
        canvas.drawCircle(rect.center, s / 2 - strokeWidth / 2, stroke);
    }
  }

  Path _triangle(Rect r, {required bool up}) {
    final path = Path();
    if (up) {
      path
        ..moveTo(r.center.dx, r.top)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom);
    } else {
      path
        ..moveTo(r.center.dx, r.bottom)
        ..lineTo(r.right, r.top)
        ..lineTo(r.left, r.top);
    }
    return path..close();
  }

  /// Watch: the triangle outlined, its lower half solid. One hue, two
  /// commitment levels — and two silhouettes, so the level survives greyscale.
  void _halfTriangle(Canvas canvas, Rect r, Paint stroke, Paint fill) {
    final outline = _triangle(r.deflate(stroke.strokeWidth / 2), up: true);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom));
    canvas.drawPath(outline, fill);
    canvas.restore();
    canvas.drawPath(outline, stroke);
  }

  /// In progress: a hard horizontal stop at the disc's centre. A hard stop and
  /// not a gradient, because a gradient is a fill step and a fill step is not
  /// a cue a 6-bit panel at 40% backlight can resolve.
  void _halfDisc(Canvas canvas, Rect r, Paint stroke, Paint fill) {
    final radius = r.shortestSide / 2 - stroke.strokeWidth / 2;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(r.left, r.center.dy, r.right, r.bottom));
    canvas.drawCircle(r.center, radius, fill);
    canvas.restore();
    canvas.drawCircle(r.center, radius, stroke);
  }

  /// The tick knocked out of a filled disc, in the ground colour.
  void _tick(Canvas canvas, Rect r) {
    final s = r.shortestSide;
    final paint = Paint()
      ..color = ground
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, s * 0.14)
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(
      Path()
        ..moveTo(r.left + s * 0.24, r.top + s * 0.52)
        ..lineTo(r.left + s * 0.43, r.top + s * 0.70)
        ..lineTo(r.left + s * 0.76, r.top + s * 0.30),
      paint,
    );
  }

  /// The 2px bar that makes "can't confirm" its own silhouette.
  void _bar(
    Canvas canvas,
    Rect r,
    Paint stroke, {
    required bool falling,
    required double inset,
  }) {
    final s = r.shortestSide;
    final d = s * inset;
    canvas.drawLine(
      falling
          ? Offset(r.left + d, r.top + d)
          : Offset(r.left + d, r.bottom - d),
      falling
          ? Offset(r.right - d, r.bottom - d)
          : Offset(r.right - d, r.top + d),
      stroke,
    );
  }

  /// Flagged for review: an eye — two arcs meeting at the corners — with the
  /// bar that says somebody is looking at it.
  void _eye(Canvas canvas, Rect r, Paint stroke) {
    final s = r.shortestSide;
    final left = Offset(r.left, r.center.dy);
    final right = Offset(r.right, r.center.dy);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(r.center.dx, r.top - s * 0.06, right.dx, right.dy)
        ..quadraticBezierTo(r.center.dx, r.bottom + s * 0.06, left.dx, left.dy),
      stroke,
    );
    canvas.drawCircle(r.center, s * 0.15, stroke);
  }

  /// No GPS: a pin whose lower arc is open. A closed pin means a fix.
  void _pin(Canvas canvas, Rect r, Paint stroke) {
    final s = r.shortestSide;
    final headCentre = Offset(r.center.dx, r.top + s * 0.36);
    final headRadius = s * 0.30;
    // Three quarters of the head, open at the bottom left, then the point.
    canvas.drawArc(
      Rect.fromCircle(center: headCentre, radius: headRadius),
      -math.pi * 0.85,
      math.pi * 1.55,
      false,
      stroke,
    );
    canvas.drawLine(
      Offset(r.center.dx + headRadius * 0.72, headCentre.dy + headRadius * 0.72),
      Offset(r.center.dx, r.bottom),
      stroke,
    );
  }

  /// Sent back: an arrow returning to a wall.
  void _returnArrow(Canvas canvas, Rect r, Paint stroke) {
    final s = r.shortestSide;
    final y = r.center.dy;
    final wallX = r.right - s * 0.06;
    canvas
      ..drawLine(Offset(wallX, r.top + s * 0.14), Offset(wallX, r.bottom - s * 0.14), stroke)
      ..drawLine(Offset(r.left + s * 0.10, y), Offset(wallX - s * 0.12, y), stroke)
      ..drawPath(
        Path()
          ..moveTo(r.left + s * 0.10, y)
          ..lineTo(r.left + s * 0.42, y - s * 0.24)
          ..moveTo(r.left + s * 0.10, y)
          ..lineTo(r.left + s * 0.42, y + s * 0.24),
        stroke,
      );
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.ground != ground;
}
