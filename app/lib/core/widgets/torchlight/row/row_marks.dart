import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/section_state_glyph.dart' show torchGlyphTileRadius;
import '../mark/tiq_chip.dart' show torchChipWash;

/// The silhouettes a row's leading tile can carry.
///
/// Every one of these is a **shape**, and the shape is the channel that has to
/// survive greyscale, deuteranopia, glare and a screen reader. Colour is a
/// second opinion on top of it, never the first: a queued row and a stuck row
/// differ by square-versus-triangle before they differ by neutral-versus-
/// crimson, and the state word says it a third time.
///
/// None of them is amber. A queue is a status list, and an amber queue chip
/// would make load-shedding look like a fault — the single most important
/// non-amber decision in the system.
enum RowMark {
  /// Held, queued, waiting. Oatmeal. The normal state of South African field
  /// connectivity and never an error.
  square,

  /// Paused. The same silhouette, unfilled.
  hollowSquare,

  /// Sending. Three dots travelling — Oatmeal, never an amber pulse: unify
  /// §1.1 rules that a pulse means presence and an upload is progress, and
  /// progress is a report.
  dots,

  /// Retrying. A circular arrow; the real next-attempt time carries the rest.
  circularArrow,

  /// Stuck. A half-filled triangle, the one place on a queue row where crimson
  /// appears, and it appears with a word.
  triangle,

  /// Sent. A filled disc inside a ring.
  disc,

  /// Waiting on another item's turn. A chain link — an ordering dependency,
  /// explicitly not a fault.
  link,

  /// Unknown. A barred ring — the fourth silhouette from unify §1.5, not a
  /// hatch: a 3dp stripe inside a 28dp tile aliases to a flat grey disc at 40%
  /// backlight.
  barredRing,
}

/// A drawn mark in a **filled** [torchGlyphTileRadius] tile, sized to the
/// row's leading slot.
///
/// A `CustomPaint` and nothing else: no gradient, no shadow, no blur, and the
/// only moving member ([RowMark.dots]) keeps its own `RepaintBoundary` and
/// stops dead when `MotionBudget.still`.
///
/// ## The outline goes and the eight silhouettes stay — amending §1.5
///
/// Owner override, 29 September 2026, looking at Me, My work and Today after
/// the chip round shipped: *"Literally you didnt change anything"*. They were
/// right about these three screens. Every row on every one of them opens with
/// this tile, and it was still a `well` box at `radii.chip` (6) inside a 1px
/// `edgeControl` border — the outlined square holding ◎ on every row of Me,
/// and the numbered squares on Today's rest-of-the-day list. It is the single
/// most repeated rectangle on the agent side.
///
/// This is **exactly** the treatment [SectionStateGlyph] took on the same
/// day, deliberately so: radius [torchGlyphTileRadius], no border, and a fill
/// tinted from the mark's own ink by the chip family's recipe
/// ([torchChipWash]) for the tones that have a colour, `raised` flat for the
/// tones whose ink is neutral. One arithmetic exercise, not two.
///
/// §1.5 declares this component as a tile carrying silhouettes, and the
/// silhouettes are untouched — a square, a hollow square, three dots, a
/// circular arrow, a half-filled triangle, a disc in a ring, a chain link and
/// a barred ring, at the same 16dp, in the same inks. **What §1.5 protects is
/// the silhouette set, not the border.** The mark is the greyscale channel and
/// it survives this change intact.
class RowMarkTile extends StatelessWidget {
  const RowMarkTile({
    super.key,
    required this.mark,
    this.tone = RowMarkTone.neutral,
    this.semanticLabel,
  });

  final RowMark mark;
  final RowMarkTone tone;

  /// Usually null: the row that owns this tile carries the whole sentence in
  /// its own `Semantics` node, and a second node saying "square" is noise.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = tone.inkOf(skin);
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: tone.fillOf(skin),
        borderRadius: BorderRadius.circular(torchGlyphTileRadius),
      ),
      child: Center(
        child: mark == RowMark.dots
            ? _TravellingDots(colour: ink)
            : CustomPaint(
                size: Size.square(_glyphExtent(context)),
                painter: _MarkPainter(
                  mark: mark,
                  colour: ink,
                  stroke: skin.depth.borderWidth * 2,
                ),
              ),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: tile)
        : Semantics(label: semanticLabel, child: ExcludeSemantics(child: tile));
  }

  /// A meaning-bearing glyph scales with the text — unify §1.5's 16 → 32 pair
  /// — and is clamped so it never outgrows the 48dp tile that holds it.
  static double _glyphExtent(BuildContext context) {
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    return math.min(16.0 * scaler.scale(1.0).clamp(1.0, 2.0), 32.0);
  }
}

/// Which ink a mark takes. Three tones, and none of them is amber.
enum RowMarkTone {
  /// Oatmeal — held, queued, sending, waiting.
  neutral,

  /// Crimson — stuck, and only ever beside a triangle and a word.
  severe,

  /// Mint — sent.
  settled,

  /// The comparison series — the console's held-work square. Truffle means
  /// "them, unlit" and nothing else; it is never a severity.
  comparison,

  /// Disabled / unknown.
  muted,
}

extension RowMarkToneInk on RowMarkTone {
  Color inkOf(TiqSkin skin) => switch (this) {
    RowMarkTone.neutral => skin.palette.ink2,
    RowMarkTone.severe => skin.palette.bad,
    RowMarkTone.settled => skin.palette.good,
    RowMarkTone.comparison => skin.palette.comparison,
    RowMarkTone.muted => skin.palette.inkMute,
  };

  /// The tile the mark is printed on, by [SectionStateGlyph]'s rule.
  ///
  /// A tone whose ink carries a **hue** takes that hue quietly, at the chip
  /// family's alpha, over `raised`. A tone whose ink is **neutral** takes
  /// `raised` flat: a neutral wash is ink-1 over the tier, and on Day that
  /// darkens the tile under an oatmeal silhouette — `raised` is the safer and
  /// the more visible answer, and it is the same call the neutral chip levels
  /// and the three neutral section states already make.
  ///
  /// [RowMarkTone.muted] is neutral for this purpose even though it is the
  /// disabled tone. Its ink is `inkMute`, which is deliberately sub-AA on
  /// every tier it has ever sat on (2.79:1 on the Night well before this
  /// change, 2.48:1 on `raised` after it; 2.26:1 → 2.74:1 on Day), because a
  /// disabled control is exempt under 1.4.3 and has to look disabled. Giving
  /// it a wash of its own would be inventing a fifth tier to carry an ink
  /// that is not trying to be read.
  Color fillOf(TiqSkin skin) => switch (this) {
    RowMarkTone.neutral || RowMarkTone.muted => skin.palette.raised,
    RowMarkTone.severe ||
    RowMarkTone.settled ||
    RowMarkTone.comparison => torchChipWash(skin, inkOf(skin)),
  };
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.mark,
    required this.colour,
    required this.stroke,
  });

  final RowMark mark;
  final Color colour;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = colour
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = Offset.zero & size;
    final centre = rect.center;
    final r = size.shortestSide / 2;

    switch (mark) {
      case RowMark.square:
        canvas.drawRect(Rect.fromCenter(center: centre, width: r * 1.6, height: r * 1.6), fill);
      case RowMark.hollowSquare:
        canvas.drawRect(
          Rect.fromCenter(center: centre, width: r * 1.6, height: r * 1.6).deflate(stroke / 2),
          line,
        );
      case RowMark.dots:
        // Painted by [_TravellingDots]; here only so the enum is total.
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(centre.translate(i * r * 0.7, 0), stroke, fill);
        }
      case RowMark.circularArrow:
        final arc = Rect.fromCircle(center: centre, radius: r * 0.7);
        canvas.drawArc(arc, -math.pi / 2, math.pi * 1.45, false, line);
        final head = Offset(centre.dx + r * 0.7, centre.dy);
        canvas.drawPath(
          Path()
            ..moveTo(head.dx - stroke * 1.4, head.dy - stroke * 1.4)
            ..lineTo(head.dx + stroke * 1.4, head.dy - stroke * 0.2)
            ..lineTo(head.dx - stroke * 0.6, head.dy + stroke * 1.6)
            ..close(),
          fill,
        );
      case RowMark.triangle:
        // Half-filled: the outline is the whole triangle, the fill is its
        // lower half. Two commitment levels in one silhouette, and neither of
        // them is an opacity step.
        final path = Path()
          ..moveTo(centre.dx, centre.dy - r * 0.85)
          ..lineTo(centre.dx + r * 0.9, centre.dy + r * 0.7)
          ..lineTo(centre.dx - r * 0.9, centre.dy + r * 0.7)
          ..close();
        canvas.drawPath(path, line);
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(rect.left, centre.dy, rect.right, rect.bottom),
        );
        canvas.drawPath(path, fill);
        canvas.restore();
      case RowMark.disc:
        canvas.drawCircle(centre, r * 0.85, line);
        canvas.drawCircle(centre, r * 0.42, fill);
      case RowMark.link:
        final w = r * 0.8;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: centre.translate(-w / 2, 0), width: w * 1.3, height: w),
            Radius.circular(w / 2),
          ),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: centre.translate(w / 2, 0), width: w * 1.3, height: w),
            Radius.circular(w / 2),
          ),
          line,
        );
      case RowMark.barredRing:
        canvas.drawCircle(centre, r * 0.8, line);
        canvas.drawLine(
          centre.translate(-r * 0.6, r * 0.6),
          centre.translate(r * 0.6, -r * 0.6),
          line,
        );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.colour != colour || old.stroke != stroke;
}

/// Three Oatmeal dots travelling. **Never an amber pulse.**
///
/// Unify §1.1: a pulse means presence — a human mid-visit, a tool executing, a
/// GPS fix being sought. An upload is progress, and progress is a report. The
/// dots are `ink2`, they live in their own `RepaintBoundary` so a scrolling
/// list does not repaint eleven rows to move three dots, and they do not exist
/// at all when `MotionBudget.still`: under reduce-motion and in battery saver
/// the state word and the byte figure are the whole signal.
///
/// The ticker is this widget's own. Unify §4 wants one application-wide
/// `Ticker` with three subscribers; that object is chrome and does not exist
/// yet, and at most one row in a queue is sending at a time — the row at the
/// head — so the debt here is one controller, not one per row.
// TODO(torchlight): subscribe to the app-wide Ticker when Phase 2 lands it.
class _TravellingDots extends StatefulWidget {
  const _TravellingDots({required this.colour});

  final Color colour;

  @override
  State<_TravellingDots> createState() => _TravellingDotsState();
}

class _TravellingDotsState extends State<_TravellingDots>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MotionBudget.of(context).still;
    if (still) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    _controller ??= AnimationController(
      vsync: this,
      duration: TiqMotion.skeleton,
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = RowMarkTile._glyphExtent(context);
    final controller = _controller;
    if (controller == null) {
      return CustomPaint(
        size: Size.square(extent),
        painter: _DotsPainter(colour: widget.colour, t: null),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(extent),
          painter: _DotsPainter(colour: widget.colour, t: controller.value),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.colour, required this.t});

  final Color colour;

  /// Null when nothing moves: three dots at rest, all the same size. The
  /// resting frame is a real frame, not a paused animation.
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.fill;
    final r = size.shortestSide / 8;
    final centre = (Offset.zero & size).center;
    for (var i = 0; i < 3; i++) {
      // Size, not opacity: an alpha ramp is a state channel the contrast walk
      // cannot see, and the opacity ban is absolute.
      final phase = t == null ? 0.0 : ((t! * 3 - i) % 3).clamp(0.0, 1.0);
      final grow = t == null ? 1.0 : 1.0 + 0.45 * math.sin(phase * math.pi);
      canvas.drawCircle(
        centre.translate((i - 1) * r * 2.6, 0),
        r * grow,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.t != t || old.colour != colour;
}
