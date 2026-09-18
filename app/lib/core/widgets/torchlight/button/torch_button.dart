/// The anatomy every Torchlight button shares: heights, label roles, the busy
/// dots, the blocker note and the drawn triangle.
///
/// Nothing here paints a fill. The five buttons differ by fill and edge, which
/// is the whole of their vocabulary; they must not also differ by height, by
/// type role or by how they say "working".
library;

import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';

/// The height of a block button — primary, secondary, destructive.
///
/// Field 56, Console 44, Veld 64 — which is exactly [TiqSpace.primaryActionHeight],
/// read rather than restated so a density change lands here for free. It is a
/// **minimum**: at 2.0× the label wraps to two lines and the button grows to
/// intrinsic height. A button pinned to 56 with an ellipsised label is a button
/// whose verb the reader cannot read.
double torchBlockHeight(TiqSkin skin) => skin.space.primaryActionHeight;

/// The tap target floor for a text or glyph action: 48 everywhere, 56 in Veld,
/// where a thumb in the sun is imprecise.
double torchTapTarget(TiqSkin skin) =>
    skin.space.tapTarget < 48 ? 48 : skin.space.tapTarget;

/// The block-button label role.
///
/// unify §1.7: **16/600 Field, 14/600 Console, 18/700 Veld** — the agent's
/// argument that the commit action was carrying the smallest type on the
/// screen. Those three land exactly on three existing roles, so this is a
/// lookup and not a new token: Console `body.strong` is 14/600, Field `title.m`
/// is 16/600 and Veld `title.m` is 18/700.
TiqTypeToken torchBlockLabelToken(TiqSkin skin) =>
    skin.density == TiqDensity.console
    ? skin.text.bodyStrong
    : skin.text.titleM;

/// The text-action label role: `label` 13/500, Veld 16/600.
TiqTypeToken torchTextLabelToken(TiqSkin skin) => skin.text.label;

/// Horizontal padding inside a block button.
double torchBlockPadding(TiqSkin skin) => skin.space.intraBlock;

/// Vertical padding once the label has wrapped past the button's fixed height.
const double torchBlockGrowthPadding = TiqSpace.s4;

/// THE BLOCKER NOTE.
///
/// A disabled primary or destructive button **must** carry one, naming exactly
/// what is missing: "Stock, Pricing and the client's questions still need
/// finishing." A dead grey button with no explanation is, in a shop, a phone
/// call to the office.
///
/// It sits **above** the button rather than beneath it. Kit drew it beneath;
/// the agent surface drew it above, and the agent surface is right for the
/// reason its own shell gives — the primary lives in a 96dp thumb zone at the
/// bottom edge of the screen, and there is nothing beneath it to put a
/// sentence in.
///
/// meta 12/400 ink-3, wraps, never truncated, and a `liveRegion` so a screen
/// reader user hears why the button will not fire without hunting for it.
class TorchBarNote extends StatelessWidget {
  const TorchBarNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: skin.text.meta.style(color: skin.palette.ink3),
        // No maxLines, no overflow: a reason that is cut off is not a reason.
      ),
    );
  }
}

/// Three dots on the 600ms loop — never a spinner.
///
/// A spinner says "something is happening somewhere"; three dots inside the
/// button say "this button is doing the thing you pressed it for", and the
/// button keeps its exact width while they run so the layout does not twitch
/// at the moment of commitment.
///
/// When the frame is [MotionBudget.still] the dots are drawn at rest, evenly
/// inked. They are still three dots, and the semantic label still says
/// "sending" — the state is carried by the label and the swallowed taps, not by
/// the motion.
class TorchBusyDots extends StatefulWidget {
  const TorchBusyDots({
    super.key,
    required this.color,
    this.size = 6,
    this.gap = TiqSpace.s2,
  });

  final Color color;
  final double size;
  final double gap;

  @override
  State<TorchBusyDots> createState() => _TorchBusyDotsState();
}

class _TorchBusyDotsState extends State<TorchBusyDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TiqMotion.countUp,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MotionBudget.of(context).still;
    if (still && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    } else if (!still && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dots = <Widget>[];
    for (var i = 0; i < 3; i++) {
      dots.add(
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // A travelling emphasis, not a fade: opacity is banned as a state
            // channel, so the dot that is "up" is drawn larger rather than
            // more opaque.
            final phase = (_controller.value * 3).floor() % 3;
            final up = _controller.isAnimating && phase == i;
            final d = up ? widget.size : widget.size * 0.66;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: SizedBox(
                  width: d,
                  height: d,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      if (i < 2) dots.add(SizedBox(width: widget.gap));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: dots);
  }
}

/// The destructive mark: a triangle, **drawn**, never the character U+25B2.
///
/// Onest has no geometric shapes at any weight, the PDF subset cannot be given
/// them, and `package:pdf` draws a missing glyph as nothing at all — which is
/// how a delta arrow vanished from every exported report and was found by a
/// customer rather than by CI. A painter cannot go missing.
///
/// Filled means the action is live; outlined means it is disabled. The shape is
/// the channel, so the distinction survives greyscale.
class TorchTriangle extends StatelessWidget {
  const TorchTriangle({
    super.key,
    required this.color,
    required this.size,
    this.filled = true,
  });

  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _TrianglePainter(color: color, filled: filled),
    ),
  );
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.color != color || old.filled != filled;
}

/// The label row inside a block button: an optional leading glyph, an 8dp gap,
/// and the label — which wraps rather than ellipsising, at every text scale.
class TorchButtonLabel extends StatelessWidget {
  const TorchButtonLabel({
    super.key,
    required this.label,
    required this.style,
    this.icon,
    this.leading,
    this.iconSize = 18,
  });

  final String label;
  final TextStyle style;
  final IconData? icon;

  /// A drawn mark — the destructive triangle — in place of an icon font glyph.
  final Widget? leading;

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final mark = leading ?? (icon == null ? null : _glyph(context));
    final text = Flexible(
      child: Text(
        label,
        style: style,
        textAlign: TextAlign.center,
        // Two channels of insurance against a long Afrikaans verb phrase: the
        // label wraps, and the button grows. Neither is an ellipsis.
        softWrap: true,
      ),
    );
    if (mark == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[text],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The mark aligns to the first line, not to the centre of a wrapped
        // block.
        Padding(
          padding: EdgeInsets.only(top: (style.fontSize ?? 16) * 0.15),
          child: mark,
        ),
        const SizedBox(width: TiqSpace.s2),
        text,
      ],
    );
  }

  Widget _glyph(BuildContext context) =>
      TorchGlyph(icon, size: iconSize, color: style.color);
}

/// An icon-font glyph, without Material's `Icon`.
///
/// The Torchlight widgets are built on `flutter/widgets` so that nothing in the
/// system can inherit a Material colour, a Material ripple or a Material tap
/// target by accident; the one Material thing they use is the icon font, which
/// is a typeface and not a theme.
///
/// The glyph is painted at `size` with `TextScaler.noScaling`. That is not an
/// accessibility failure — it is how the glyph-scale rule is implemented. A
/// component that carries **meaning** in its glyph (a nav slot gone icon-only,
/// a section-state tile, a chip's mark) grows it by asking for a bigger `size`;
/// a decorative chevron does not. Letting the ambient scaler do it would scale
/// both.
class TorchGlyph extends StatelessWidget {
  const TorchGlyph(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
  });

  final IconData? icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final data = icon;
    if (data == null) return SizedBox(width: size, height: size);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            String.fromCharCode(data.codePoint),
            textAlign: TextAlign.center,
            // A glyph is not text: it must not grow with the text scaler here,
            // because the components that DO scale their glyphs (the nav, the
            // chips, the tile) scale them by asking for a bigger `size`.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              inherit: false,
              fontSize: size,
              fontFamily: data.fontFamily,
              package: data.fontPackage,
              color: color,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
