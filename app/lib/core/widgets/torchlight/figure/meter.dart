import 'package:flutter/widgets.dart';

import '../../../design/hatch_paint.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/tiq_mark.dart';

/// What a meter is drawing.
enum MeterState {
  /// A real value, including a real zero.
  filled,

  /// Nobody sent a value. Outlined track, no fill, **no tick** — a target
  /// annotated against nothing is a target you cannot read.
  missing,

  /// A real value from too thin a sample. The fill draws as a 1.5dp outline
  /// rather than a solid: outline-versus-fill is a shape distinction that
  /// survives greyscale, sun and deuteranopia, which an alpha reduction does
  /// not.
  lowSample,

  /// The dimension could not be measured. A full-width falling hatch — see
  /// `NotMeasured`, which is the component that pairs it with an em dash and a
  /// reason.
  notMeasured,

  /// Waiting. Outlined track, no fill, no tick.
  loading,
}

/// The in-tile bar: where a figure sits against its own range or its target.
///
/// ## The target tick is ink-1, everywhere, and that is deliberate
///
/// The written direction specifies an amber tick. Unify §1.1 deletes it and
/// `TorchClaim.meterTick` does not exist on the ladder. Two reasons, and the
/// second is the load-bearing one:
///
/// 1. A target is an annotation, an annotation is a label, and amber is never
///    a label.
/// 2. The amber budget is counted per **route**, not per viewport — a grant
///    that released on scroll would make amber blink in and out under a thumb.
///    A phone dashboard route carries up to four metered tiles and a dimension
///    breakdown carries six, on the same route, whose two slots are already
///    spent on the plate's strip light and the nav's active tab. So the tick
///    is ink-1 not because four are on screen but because up to ten are on the
///    route and the route's budget is zero.
///
/// The tick's **silhouette** does the work the amber was there to do: it is
/// 2dp wide, runs the full track height and breaks the track's top edge by
/// 2dp, so it has a shape above the bar. A tick that is only a hue change
/// disappears in greyscale.
///
/// ## The empty track gets an edge
///
/// A filled track needs no edge; an empty one is 1.3:1 from the panel behind
/// it and is simply invisible. So in the zero, missing, loading and hatched
/// states — and only then — the track draws a 1px `edge-structure` outline.
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.value,
    this.minimum = 0,
    this.maximum = 100,
    this.target,
    this.state = MeterState.filled,
    this.reasonForHatch,
    this.semanticsValue,
  });

  /// The value, in the same units as [minimum] and [maximum]. Null forces
  /// [MeterState.missing] whatever the caller declared — a meter cannot draw
  /// what it was not given.
  final double? value;

  final double minimum;
  final double maximum;

  /// Where the tick goes. Null renders **no tick** — never a tick at 100, and
  /// never one at the midpoint. An invented target is a target somebody will
  /// be measured against.
  final double? target;

  final MeterState state;

  /// Only used for the assert message on a hatched meter, so a hatch that
  /// shipped without its sentence is caught here rather than in review.
  final String? reasonForHatch;

  /// "61 out of 100, target 80" — the target is in the value string, so the
  /// tick's silhouette is reinforced rather than relied on.
  final String? semanticsValue;

  /// Track height by density (unify §1.19). 4dp Console, 6dp Field, 8dp Veld.
  static double trackHeight(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console => 4,
    TiqDensity.field => 6,
    TiqDensity.veld => 8,
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resolved = value == null && state == MeterState.filled
        ? MeterState.missing
        : state;
    assert(
      resolved != MeterState.notMeasured || reasonForHatch != null,
      'Meter: a hatched track without a sentence is a puzzle. Pass the '
      'reason the server gave, or "Not measured in this visit" — never blank.',
    );
    // A track scales at half rate: it is a graphic, and a graphic that doubled
    // would be a bar chart.
    final height = MarkScale.track(context, trackHeight(skin));
    final fraction = _fraction(value);
    final targetFraction = _fraction(target);

    return Semantics(
      value: semanticsValue,
      excludeSemantics: semanticsValue != null,
      child: SizedBox(
        // The tick breaks the top edge by 2dp, so the widget is taller than
        // its track by exactly that much and nothing clips.
        height: height + 2,
        width: double.infinity,
        child: CustomPaint(
          painter: MeterPainter(
            skin: skin,
            state: resolved,
            fraction: fraction,
            targetFraction: targetFraction,
            trackHeight: height,
          ),
        ),
      ),
    );
  }

  double? _fraction(double? v) {
    if (v == null) return null;
    final span = maximum - minimum;
    if (span <= 0) return null;
    return ((v - minimum) / span).clamp(0.0, 1.0);
  }
}

/// The one track painter. The progress-to-reward bar is this object at a
/// different height with milestone ticks, so there is one piece of arithmetic
/// for where a fill ends.
class MeterPainter extends CustomPainter {
  const MeterPainter({
    required this.skin,
    required this.state,
    required this.fraction,
    required this.targetFraction,
    required this.trackHeight,
  });

  final TiqSkin skin;
  final MeterState state;
  final double? fraction;
  final double? targetFraction;
  final double trackHeight;

  /// A non-zero value is never invisible. A **true zero** renders no fill at
  /// all and the figure above carries it — which is the difference between
  /// "nearly none" and "none".
  static const double minimumFill = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || trackHeight <= 0) return;
    final p = skin.palette;
    final top = size.height - trackHeight;
    final track = Rect.fromLTWH(0, top, size.width, trackHeight);
    final radius = Radius.circular(skin.radii.chip == 0 ? 0 : trackHeight / 2);
    final rounded = RRect.fromRectAndRadius(track, radius);

    canvas.drawRRect(
      rounded,
      Paint()..color = _trackFill(p),
    );

    // A filled track needs no edge. An empty one is 1.3:1 from the panel
    // behind it and is simply invisible — and in Veld a white track on a white
    // ground is invisible in every state, which is why the border width is the
    // second half of this condition rather than a mode check.
    final outlined = skin.depth.borderWidth >= 2 ||
        state != MeterState.filled ||
        fraction == null ||
        fraction == 0;
    if (outlined) {
      canvas.drawRRect(
        rounded.deflate(skin.depth.borderWidth / 2),
        Paint()
          ..color = p.edgeStructure
          ..style = PaintingStyle.stroke
          ..strokeWidth = skin.depth.borderWidth,
      );
    }

    if (state == MeterState.notMeasured) {
      // Full width, always. A partial hatched bar reads as a hatched VALUE;
      // full-width hatch plus the em dash above it says "there is no
      // measurement here", and nothing else can.
      HatchPaint.paint(
        canvas,
        track,
        HatchPaint.spec(skin, HatchPattern.notMeasured),
      );
      return;
    }

    if (state == MeterState.missing || state == MeterState.loading) return;

    final f = fraction;
    if (f != null && f > 0) {
      final width = (size.width * f).clamp(minimumFill, size.width);
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, width, trackHeight),
        radius,
      );
      if (state == MeterState.lowSample) {
        // Outline, not a solid. A shape distinction, because a thin sample is
        // a thing the reader has to see in sunlight.
        canvas.drawRRect(
          fill.deflate(0.75),
          Paint()
            ..color = p.chartNeutral
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        canvas.drawRRect(fill, Paint()..color = p.chartNeutral);
      }
    }

    final t = targetFraction;
    if (t != null) {
      // 2dp wide, the full track height, breaking the top edge by 2dp.
      final x = (size.width * t).clamp(1.0, size.width - 1);
      canvas.drawRect(
        Rect.fromLTWH(x - 1, top - 2, 2, trackHeight + 2),
        Paint()..color = p.ink1,
      );
    }
  }

  /// A dark ground recesses by *lifting* a surface out of it; a light ground
  /// recesses by *welling* into it. Night's track is `lifted` #2C3B4D, Day's
  /// is `well` #E2DBCC, and Veld's is white with the 2px border above.
  Color _trackFill(TiqPalette p) =>
      skin.brightness == Brightness.dark ? p.lifted : p.well;

  @override
  bool shouldRepaint(MeterPainter old) =>
      old.skin != skin ||
      old.state != state ||
      old.fraction != fraction ||
      old.targetFraction != targetFraction ||
      old.trackHeight != trackHeight;
}
