import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../mark/tiq_mark.dart';

/// MULTI-SELECT INSIDE A SECTION — visibility elements present, materials
/// deployed.
///
/// 28dp at 1.0× and **48 at 2.0×** (unify §1.9): a checkbox is a
/// meaning-bearing glyph and meaning-bearing glyphs scale with the text. 48 is
/// also the tap-target floor, so nothing useful happens above it.
///
/// **There is no mixed state.** It was fully specified once — a token, a
/// painter branch, a golden, a semantics case and a line in the contrast test
/// — for a parent-over-children pattern that exists on none of the sixty
/// screens, because group select-all is a tertiary button above the group. It
/// comes back with the screen that needs it, not before.
///
/// **Read-only is not opacity.** Reviewing a submitted visit renders the box
/// with no border and no press surface and drops the label to ink-2. The
/// previous draft used 0.8, which is a state the contrast walk cannot see.
class TorchCheckbox extends StatelessWidget {
  const TorchCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
    this.disabledReason,
  });

  final String label;
  final bool value;

  /// Null disables it.
  final ValueChanged<bool>? onChanged;

  /// Reviewing a submitted visit.
  final bool readOnly;

  final String? disabledReason;

  /// 28 at 1.0×, 48 at 2.0×, and 32 in Veld before scaling.
  static double extentFor(BuildContext context, TiqSkin skin) {
    final base = skin.density == TiqDensity.veld ? 32.0 : 28.0;
    return math.min(base * MarkScale.factor(context), 48.0);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = onChanged != null && !readOnly;
    final extent = extentFor(context, skin);
    final veld = skin.density == TiqDensity.veld;

    final Color? fill;
    final Color? border;
    final Color tickInk;
    if (readOnly) {
      fill = value ? p.ink3 : null;
      border = null;
      tickInk = p.ground;
    } else if (!enabled) {
      fill = value ? p.inkMute : null;
      border = p.inkMute;
      tickInk = p.ground;
    } else if (value) {
      // Veld fills with INK, not green: outdoors filled-versus-empty is the
      // signal and the success colour is reserved for success blocks.
      fill = veld ? p.lifted : p.good;
      border = veld ? p.ink1 : p.good;
      tickInk = veld ? p.ground : p.ground;
    } else {
      fill = null;
      border = p.edgeControl;
      tickInk = p.ground;
    }

    final box = SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(skin.radii.chip),
          border: border == null
              ? null
              : Border.all(color: border, width: skin.depth.borderWidth * 2),
        ),
        child: value
            ? CustomPaint(
                painter: _TickPainter(
                  color: tickInk,
                  strokeWidth: veld ? 3 : 2.5,
                ),
              )
            : null,
      ),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Top-aligned, never centred: at 2.0× with a four-line label, a
        // vertically centred box sits beside the middle of a paragraph.
        box,
        const SizedBox(width: TiqSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: skin.text.body.style(
                  color: readOnly
                      ? p.ink2
                      : enabled
                      ? p.ink1
                      : p.inkMute,
                ),
              ),
              if (disabledReason != null && !enabled && !readOnly) ...<Widget>[
                const SizedBox(height: TiqSpace.s1),
                Text(
                  disabledReason!,
                  style: skin.text.meta.style(color: p.ink3),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final semantics = Semantics(
      checked: value,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: row,
    );

    if (!enabled) {
      return Container(
        constraints: BoxConstraints(minHeight: skin.space.rowMinHeight),
        padding: const EdgeInsets.symmetric(vertical: TiqSpace.s3),
        child: semantics,
      );
    }

    return TorchPressable(
      onPressed: () => onChanged!(!value),
      pressScale: 1,
      builder: (context, pressed) => Container(
        constraints: BoxConstraints(minHeight: skin.space.rowMinHeight),
        decoration: BoxDecoration(
          color: pressed ? torchPressSurface(skin).fill : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: TiqSpace.s3),
        child: semantics,
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final path = Path()
      ..moveTo(s * 0.24, s * 0.52)
      ..lineTo(s * 0.42, s * 0.70)
      ..lineTo(s * 0.76, s * 0.30);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// A required group of checkboxes that was submitted with nothing checked.
///
/// The **group** takes the error, not the boxes: no single box is wrong, and
/// turning eight of them crimson tells a reader that eight things are broken.
class TorchCheckboxGroup extends StatelessWidget {
  const TorchCheckboxGroup({
    super.key,
    required this.label,
    required this.children,
    this.error,
    this.selectAll,
  });

  /// Names the question. Read by a screen reader before the options.
  final String label;

  final List<Widget> children;

  /// A sentence beneath, behind a filled triangle, with a 2px `bad` bar down
  /// the group's leading edge.
  final String? error;

  /// Select-all is a tertiary button **above** the group — never a fourth
  /// checkbox state.
  final Widget? selectAll;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final bad = error != null;
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selectAll != null) ...<Widget>[
            Align(alignment: Alignment.centerLeft, child: selectAll!),
            const SizedBox(height: TiqSpace.s2),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              border: bad
                  ? Border(
                      left: BorderSide(
                        color: p.bad,
                        width: skin.depth.borderWidth * 2,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.only(left: bad ? TiqSpace.s3 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
          if (bad) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: TiqMark(
                      shape: MarkShape.criticalTriangle,
                      color: p.bad,
                      size: MarkScale.glyph(context, 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: skin.text.meta
                          .copyWith(weight: FontWeight.w500)
                          .style(color: p.bad),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
