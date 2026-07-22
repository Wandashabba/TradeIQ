import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/agents/data/agents_repository.dart';
import 'agent_motion.dart' show reduceMotion;

/// The one glyph both the "Where are my agents" list rows and the map pins
/// draw from (`dashboard_shell_screen.dart`'s `_agentStateVisual`/
/// `_pinGlyphColor` doc comments) — so the two halves of the panel can never
/// quietly disagree about what a state looks like.
///
/// Hand-drawn with [CustomPainter] rather than a stock Material icon,
/// because #144's rule is that state must differ in SILHOUETTE, not just
/// colour — a reader in greyscale, or with red-green colour-blindness, must
/// still tell the three apart:
///
///  * **at store** — a storefront (scalloped awning over a shopfront box)
///    with a FILLED presence dot. The only glyph with a solid fill.
///  * **in transit** — three chevrons pointing the direction of travel,
///    fading toward the tail. Angular, directional — nothing like the other
///    two.
///  * **idle** — a HOLLOW, dashed ring. Open where the other two are solid;
///    "nothing to report" reads as literally empty.
class AgentStateGlyph extends StatefulWidget {
  const AgentStateGlyph({
    super.key,
    required this.state,
    required this.color,
    this.size = 16,
    this.pulse = false,
  });

  final AgentState state;
  final Color color;
  final double size;

  /// Whether this glyph may show the "in a store right now" halo. Only ever
  /// acts when [state] is [AgentState.atStore] — passing it for the other
  /// two states is a no-op, so callers do not need to gate it themselves.
  ///
  /// The panel's map pins opt in; the compact list rows do not, so the
  /// motion stays a map-only signal rather than decorating every row with
  /// it. Plays ONCE per mount, as an expand-and-fade, rather than looping —
  /// an agent can stay checked in for hours, and a ring that pulsed for the
  /// whole time would be exactly the kind of animation `agent_motion.dart`
  /// warns against: one that never finishes never lets `pumpAndSettle`
  /// settle, and would just be noise on a screen a manager watches for
  /// minutes at a time. Internally gated on [reduceMotion] — reduced motion
  /// skips it entirely and renders the still glyph.
  final bool pulse;

  @override
  State<AgentStateGlyph> createState() => _AgentStateGlyphState();
}

class _AgentStateGlyphState extends State<AgentStateGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _played = false;

  bool get _eligible => widget.pulse && widget.state == AgentState.atStore;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(AgentStateGlyph old) {
    super.didUpdateWidget(old);
    if (!_eligible) {
      // No longer eligible (state changed away from at-store, or pulse was
      // turned off) — stop and rewind so a later eligible transition plays
      // fresh, and nothing keeps a Ticker alive for a state that no longer
      // wants one.
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
      _played = false;
      return;
    }
    _maybeStart();
  }

  void _maybeStart() {
    if (_played || !_eligible || reduceMotion(context)) return;
    _played = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: _painterFor(widget.state, widget.color)),
    );

    if (!_eligible || reduceMotion(context)) return glyph;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (t > 0 && t < 1)
                Transform.scale(
                  scale: 1 + t * 1.6,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: glyph,
    );
  }
}

CustomPainter _painterFor(AgentState state, Color color) => switch (state) {
  AgentState.atStore => _StorefrontPainter(color),
  AgentState.inTransit => _ChevronTrailPainter(color),
  AgentState.idle => _DashedRingPainter(color),
};

/// Shared base so every concrete glyph painter agrees on when to repaint —
/// on a colour change, or (defensively) if the concrete type itself changed,
/// which happens whenever [AgentStateGlyph.state] switches to a different
/// state on the same Element.
abstract class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.color);
  final Color color;

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.runtimeType != runtimeType || oldDelegate.color != color;
}

/// At store: a scalloped awning over a shopfront box, with a filled dot —
/// the only glyph with a solid fill, so "someone is here right now" reads
/// even with colour stripped out.
class _StorefrontPainter extends _GlyphPainter {
  const _StorefrontPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, w * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Scalloped awning across the top third.
    const scallops = 3;
    final awningTop = h * 0.10;
    final awningBottom = h * 0.40;
    final left = w * 0.08;
    final span = w * 0.84;
    final scallopWidth = span / scallops;
    final path = Path()..moveTo(left, awningTop);
    for (var i = 0; i < scallops; i++) {
      final x0 = left + i * scallopWidth;
      final xMid = x0 + scallopWidth / 2;
      final x1 = x0 + scallopWidth;
      path.lineTo(x0, awningTop);
      path.quadraticBezierTo(xMid, awningBottom, x1, awningTop);
    }
    canvas.drawPath(path, stroke);

    // Shopfront box below the awning.
    final box = Rect.fromLTWH(w * 0.14, awningBottom, w * 0.72, h * 0.42);
    canvas.drawRect(box, stroke);

    // A single off-centre door stroke.
    canvas.drawLine(
      Offset(w * 0.58, box.top + h * 0.04),
      Offset(w * 0.58, box.bottom),
      stroke,
    );

    // Presence dot: filled, bottom-right — the mark that says "occupied".
    canvas.drawCircle(Offset(w * 0.80, h * 0.88), w * 0.13, fill);
  }
}

/// In transit: three chevrons pointing right, fading toward the tail — an
/// angular, directional shape unlike either sibling.
class _ChevronTrailPainter extends _GlyphPainter {
  const _ChevronTrailPainter(super.color);

  static const _positions = [0.30, 0.56, 0.82];
  static const _opacities = [1.0, 0.62, 0.32];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = math.max(1.2, w * 0.15);

    for (var i = 0; i < _positions.length; i++) {
      final cx = w * _positions[i];
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * _opacities[i])
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(cx - w * 0.16, h * 0.26)
        ..lineTo(cx + w * 0.12, h * 0.5)
        ..lineTo(cx - w * 0.16, h * 0.74);
      canvas.drawPath(path, paint);
    }
  }
}

/// Idle: a HOLLOW, dashed ring — open where the other two states are solid
/// (a filled dot, stroked chevrons).
class _DashedRingPainter extends _GlyphPainter {
  const _DashedRingPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2 * 0.7;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.12)
      ..strokeCap = StrokeCap.round;

    const dashCount = 8;
    const gapFraction = 0.5;
    final anglePerDash = (2 * math.pi) / dashCount;
    final dashAngle = anglePerDash * (1 - gapFraction);

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * anglePerDash - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }
}

/// Exposed for tests that want to assert glyphs differ by SHAPE, not colour
/// — comparing [CustomPaint.painter]'s `runtimeType` across two
/// [AgentStateGlyph]s only proves that if the concrete painter types differ,
/// which requires this to be reachable without reaching into a private
/// library. Returns the same `Type` [_painterFor] would build a painter of,
/// for a given [state].
Type glyphPainterTypeFor(AgentState state) => _painterFor(state, const Color(0xFF000000)).runtimeType;
