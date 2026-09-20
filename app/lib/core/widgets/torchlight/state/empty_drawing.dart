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

/// THE PLACEHOLDER — and it is meant to look like one.
///
/// **The three drawings do not exist yet.** They are commissioned under
/// **#404** (unify open question 14: "commission half a day of one
/// illustrator before Phase 2; the enum refuses a stock import"). Until that
/// lands, this paints each silhouette as a crude single-stroke schematic
/// inside a **dashed frame**.
///
/// The dashed frame is not decoration and is not shyness about the schematic.
/// It is the signal, to anyone reviewing a screenshot of this app, that the
/// artwork is pending: no commissioned drawing in this system will ever sit
/// inside a dashed box, so a dashed box on a screen means one thing and only
/// one thing. A placeholder that looks finished is a placeholder that ships.
///
/// **#404 replaces this file and nothing else.** The API is the enum and
/// [EmptyStateDrawing]; the illustrator's three assets are dropped in behind
/// it, the dashed frame goes, and no call site changes. Nothing in
/// `lib/features` ever names this painter.
///
/// And under no circumstances is a stock illustration imported in the
/// meantime. That is the failure the closed enum exists to make impossible.
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

  /// 64 by default, 48 in Veld — a 64dp drawing in a 24dp gutter takes a
  /// quarter of the width that the headline needs.
  final double? extent;

  /// The declared extent for a skin.
  static double extentFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? 48 : 64;

  /// 2px, 3px in Veld.
  static double strokeFor(TiqSkin skin) =>
      skin.depth.borderWidth >= 2 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final size = extent ?? extentFor(skin);
    return ExcludeSemantics(
      // Decorative, always. The headline is the header and the body is the
      // instruction; a drawing that announced itself would be a screen reader
      // reading out a picture of a shelf.
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PlaceholderPainter(
            drawing: drawing,
            color: color ?? skin.palette.edgeControl,
            strokeWidth: strokeFor(skin),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter({
    required this.drawing,
    required this.color,
    required this.strokeWidth,
  });

  final EmptyDrawing drawing;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.shortestSide;

    _dashedFrame(canvas, size, paint);

    // Inset from the frame, so the schematic and the "pending" frame do not
    // read as one object.
    final inset = s * 0.22;
    final box = Rect.fromLTRB(inset, inset, s - inset, s - inset);

    switch (drawing) {
      case EmptyDrawing.shelf:
        // Three shelves and two uprights.
        for (var i = 0; i < 3; i++) {
          final y = box.top + box.height * (i / 2);
          canvas.drawLine(Offset(box.left, y), Offset(box.right, y), paint);
        }
        canvas.drawLine(box.topLeft, box.bottomLeft, paint);
        canvas.drawLine(box.topRight, box.bottomRight, paint);
      case EmptyDrawing.pin:
        // A teardrop: an arc over a point, with a hole in it.
        final head = Rect.fromCircle(
          center: Offset(box.center.dx, box.top + box.width * 0.36),
          radius: box.width * 0.36,
        );
        canvas.drawArc(head, 3.6651, 5.7596, false, paint);
        canvas.drawLine(
          Offset(box.center.dx - box.width * 0.29, box.top + box.width * 0.58),
          Offset(box.center.dx, box.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(box.center.dx + box.width * 0.29, box.top + box.width * 0.58),
          Offset(box.center.dx, box.bottom),
          paint,
        );
        canvas.drawCircle(head.center, box.width * 0.12, paint);
      case EmptyDrawing.envelope:
        final body = Rect.fromLTRB(
          box.left,
          box.top + box.height * 0.16,
          box.right,
          box.bottom - box.height * 0.16,
        );
        canvas.drawRect(body, paint);
        canvas.drawLine(body.topLeft, body.center, paint);
        canvas.drawLine(body.topRight, body.center, paint);
    }
  }

  /// The "artwork pending" signal. 4-on, 4-off, drawn as line segments — this
  /// painter runs inside scrolling regions and this system has a zero-
  /// `saveLayer`, zero-`PathEffect` budget.
  void _dashedFrame(Canvas canvas, Size size, Paint base) {
    final paint = Paint()
      ..color = base.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;
    const dash = 4.0;
    final w = size.width;
    final h = size.height;
    for (var x = 0.0; x < w; x += dash * 2) {
      final end = (x + dash).clamp(0.0, w);
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      canvas.drawLine(Offset(x, h), Offset(end, h), paint);
    }
    for (var y = 0.0; y < h; y += dash * 2) {
      final end = (y + dash).clamp(0.0, h);
      canvas.drawLine(Offset(0, y), Offset(0, end), paint);
      canvas.drawLine(Offset(w, y), Offset(w, end), paint);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) =>
      old.drawing != drawing ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
