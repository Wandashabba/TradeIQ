import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../theme/torchlight/tiq_skin.dart';

/// The four hatch patterns, and the two rules that bound them.
///
/// A hatch says something a fill cannot: *this area was not measured*, *this
/// number went the wrong way*, *this sample is too thin to trust*, *this
/// figure is not final yet*. It is the second channel for cases where there is
/// no room for a word, and it survives greyscale, deuteranopia and a
/// sun-washed panel — which a hue does not.
///
/// ## The two hard rules (unify §1.5, §4)
///
/// 1. **Never inside a glyph.** A 3dp stripe inside a 28dp section-state tile
///    aliases to a flat grey disc at 40% backlight on an entry LCD — which is
///    the half-disc it must not resemble. "Can't confirm" is a fourth
///    silhouette (a ring with a 2px diagonal bar), not a hatched one.
/// 2. **Never on a mark under 4dp.** Below that the stripe pitch and the mark
///    are the same size and the pattern reads as noise or as a solid.
///
/// Both are asserted by [HatchPaint.paint] in debug and by
/// `hatch_paint_test.dart`.
///
/// ## Where the lines are drawn from
///
/// In a list row a hatch is **painter lines**, not a gradient decoration: the
/// paint budget allows no gradient decoration inside a `ListView.builder` row,
/// because a gradient there is a new `Paint` and a new shader per row per
/// scroll frame. [HatchPaint.paint] draws `drawLine` into the canvas the row
/// already has. The gradient form does not exist; there is nothing to
/// accidentally reach for.
enum HatchPattern {
  /// **Not measured.** 45° falling stripes (top-left to bottom-right), full
  /// width of the track, over an em dash and a reason. A dimension nobody
  /// scored looks different from a dimension that scored zero.
  notMeasured,

  /// **Negative.** 45° rising stripes on a diverging bar's negative side.
  /// `bad` against `chartNeutral` is 1.16:1 true and 1.06:1 in protanopia —
  /// the stripe direction is what actually carries the sign. (It was 1.55 and
  /// 1.26 until Phase 1 moved the neutral off the AA floor against its own
  /// track; the hues converged and the stripe is now the whole of it.)
  negative,

  /// **Low sample.** No stripes: the fill is removed and only the outline
  /// stays. The figure itself keeps ink-2 and loses its delta. An outline is
  /// the honest shape for "there is a number here but not enough of it".
  lowSampleOutline,

  /// **Provisional.** Outline plus a dotted interior — a figure the server has
  /// stamped provisional, on the console only. The agent app never shows one.
  provisionalOutlineDots,
}

/// A resolved hatch: the colours and geometry for one pattern in one skin.
@immutable
class HatchSpec {
  const HatchSpec({
    required this.pattern,
    required this.line,
    required this.strokeWidth,
    required this.pitch,
    required this.degrees,
    required this.fill,
    required this.dots,
  });

  final HatchPattern pattern;

  /// The stripe / outline colour.
  final Color line;

  final double strokeWidth;

  /// Centre-to-centre distance between stripes, measured perpendicular to
  /// them. Fixed in logical pixels: a hatch is a decorative mark and
  /// decorative marks do not scale with text (unify §4).
  final double pitch;

  /// Stripe angle. 45 falls, −45 rises.
  final double degrees;

  /// A wash behind the stripes, or null for none. Veld has none — it has no
  /// fill step to spend.
  final Color? fill;

  /// Whether the interior carries dots instead of stripes.
  final bool dots;
}

/// The registry. One place that knows what each pattern looks like in each
/// skin, so a painter asks for a *meaning* and never for an angle.
class HatchPaint {
  HatchPaint._();

  /// The smallest mark a hatch may be applied to. Below this the pattern is
  /// noise (unify §1.5).
  static const double minimumMarkExtent = 4.0;

  /// Resolve [pattern] against a skin.
  static HatchSpec spec(TiqSkin skin, HatchPattern pattern) {
    final p = skin.palette;
    // Veld has no wash, no gradient and a 2px border floor; its hatch is
    // heavier line on white and nothing else.
    final veld = skin.depth.borderWidth >= 2;
    final stroke = veld ? 2.0 : 1.0;
    final pitch = veld ? 8.0 : 6.0;
    return switch (pattern) {
      HatchPattern.notMeasured => HatchSpec(
        pattern: pattern,
        line: p.ink3,
        strokeWidth: stroke,
        pitch: pitch,
        degrees: 45,
        fill: veld ? null : p.well,
        dots: false,
      ),
      HatchPattern.negative => HatchSpec(
        pattern: pattern,
        line: p.bad,
        strokeWidth: stroke,
        pitch: pitch,
        degrees: -45,
        fill: veld ? null : p.well,
        dots: false,
      ),
      HatchPattern.lowSampleOutline => HatchSpec(
        pattern: pattern,
        line: p.edgeControl,
        strokeWidth: stroke,
        pitch: pitch,
        degrees: 0,
        fill: null,
        dots: false,
      ),
      HatchPattern.provisionalOutlineDots => HatchSpec(
        pattern: pattern,
        line: p.ink3,
        strokeWidth: stroke,
        pitch: pitch,
        degrees: 0,
        fill: null,
        dots: true,
      ),
    };
  }

  /// Paint [pattern] into [rect].
  ///
  /// [insideGlyph] must be false. It exists as a named argument rather than as
  /// nothing at all because "never hatch inside a glyph" is a rule someone
  /// will otherwise discover by shipping it: a caller that believes it has a
  /// good reason has to write the word down, and then the assert tells it no.
  static void paint(
    Canvas canvas,
    Rect rect,
    HatchSpec spec, {
    bool insideGlyph = false,
  }) {
    assert(
      !insideGlyph,
      'HatchPaint: no pattern goes inside a glyph. A 3dp stripe inside a 28dp '
      'tile aliases to a flat grey disc at 40% backlight — the half-disc it '
      'must not resemble. "Can\'t confirm" is a fourth silhouette (a ring with '
      'a 2px diagonal bar), not a hatched third one.',
    );
    assert(
      rect.shortestSide >= minimumMarkExtent,
      'HatchPaint: ${spec.pattern.name} on a '
      '${rect.shortestSide.toStringAsFixed(1)}dp mark. Nothing under '
      '${minimumMarkExtent}dp may carry a pattern — the stripe pitch and the '
      'mark are the same size, so it reads as noise or as a solid. Use the '
      'outline form, or a word.',
    );
    if (rect.isEmpty) return;

    if (spec.fill != null) {
      canvas.drawRect(rect, Paint()..color = spec.fill!);
    }

    final line = Paint()
      ..color = spec.line
      ..strokeWidth = spec.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      // No anti-alias on a hard-stop stripe: the design bans blur everywhere,
      // and a feathered stripe at pitch 6 is a grey wash.
      ..isAntiAlias = false;

    if (spec.dots) {
      _paintDots(canvas, rect, spec, line);
      _paintOutline(canvas, rect, line);
      return;
    }
    if (spec.degrees == 0) {
      _paintOutline(canvas, rect, line);
      return;
    }
    _paintStripes(canvas, rect, spec, line);
    _paintOutline(canvas, rect, line);
  }

  static void _paintOutline(Canvas canvas, Rect rect, Paint line) {
    final inset = line.strokeWidth / 2;
    canvas.drawRect(rect.deflate(inset), line);
  }

  /// `drawLine` per stripe, clipped to the rect. Not a `LinearGradient` with
  /// hard stops: in a `ListView.builder` row that is a shader per row per
  /// frame, and the paint budget forbids it.
  static void _paintStripes(
    Canvas canvas,
    Rect rect,
    HatchSpec spec,
    Paint line,
  ) {
    canvas.save();
    canvas.clipRect(rect);
    final falling = spec.degrees > 0;
    // At ±45° a stripe's x-intercept advances by pitch * sqrt(2).
    final step = spec.pitch * math.sqrt2;
    final span = rect.width + rect.height;
    for (var offset = -rect.height; offset < span; offset += step) {
      final x = rect.left + offset;
      if (falling) {
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x + rect.height, rect.bottom),
          line,
        );
      } else {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rect.height, rect.top),
          line,
        );
      }
    }
    canvas.restore();
  }

  static void _paintDots(Canvas canvas, Rect rect, HatchSpec spec, Paint line) {
    canvas.save();
    canvas.clipRect(rect);
    final dot = Paint()
      ..color = spec.line
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    final r = spec.strokeWidth;
    for (var y = rect.top + spec.pitch / 2; y < rect.bottom; y += spec.pitch) {
      for (var x = rect.left + spec.pitch / 2; x < rect.right; x += spec.pitch) {
        canvas.drawRect(Rect.fromCircle(center: Offset(x, y), radius: r), dot);
      }
    }
    canvas.restore();
  }
}
