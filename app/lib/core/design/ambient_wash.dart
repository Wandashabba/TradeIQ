import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Matrix4;
import 'package:flutter/painting.dart';

/// ── THE SHAPE OF AN AMBIENT WASH, shared by the two that exist ─────────
///
/// `floor_dawn.dart` built an elliptical radial wash and proved it: the
/// geometry, the census arithmetic and the no-blur-no-mask-no-filter budget
/// are all measured in `floor_dawn_test.dart`. The console's desk wants two
/// more washes of exactly that kind, so this is Dawn's own machinery lifted
/// out rather than a second implementation of it.
///
/// **Dawn's rendered output is unchanged by the lift**, and that is held
/// rather than claimed: every golden in `test/features/dashboard/goldens/`
/// still matches, and `floor_dawn_test.dart`'s gradient-shape assertions —
/// which read the `RadialGradient`'s centre, radius, stops and `transform`
/// off the real decoration — pass against this class because `operator ==`
/// came with it.
///
/// Nothing here paints. It is one [GradientTransform] and one builder, so a
/// wash is still a `Decoration` the shell nests under its ground, with the
/// cost `floor_dawn.dart` already named: one `drawRect` with a gradient
/// shader, no layer, no clip, no `saveLayer`.

/// ONE ELLIPTICAL RADIAL WASH, as a decoration.
///
/// [centre] and [radii] are CSS's `radial-gradient(<w> <h> at <x> <y>, …)`:
/// the radii are a share of the box's **width and height**, which is the thing
/// Flutter's [RadialGradient] cannot say on its own — its `radius` is one
/// number against the box's shortest side. See [AmbientEllipse].
///
/// [stops] and [alphas] must be the same length, and the colour is one token
/// at falling alpha. A wash is a token at strengths, never a ramp between two
/// colours: that is what makes it arguable against a palette rather than
/// against a taste.
BoxDecoration ambientWash({
  required Color colour,
  required Alignment centre,
  required ({double width, double height}) radii,
  required List<double> stops,
  required List<double> alphas,
}) {
  assert(
    stops.length == alphas.length && stops.length >= 2,
    'A wash is a list of (stop, alpha) pairs and needs at least two of them. '
    'Two stops band on a 6-bit panel, which is why both shipping washes take '
    'three — see floor_dawn.dart.',
  );
  return BoxDecoration(
    gradient: RadialGradient(
      center: centre,
      radius: 1,
      transform: AmbientEllipse(
        centre,
        width: radii.width,
        height: radii.height,
      ),
      colors: <Color>[
        for (final alpha in alphas) colour.withValues(alpha: alpha),
      ],
      stops: stops,
    ),
  );
}

/// Flutter's [RadialGradient] is a circle: its `radius` is one number against
/// the paint box's **shortest side**. CSS states an ellipse — a share of the
/// width and a different share of the height — and `radial-gradient(130% 48%
/// …)` is 507×405 on a 390×844 phone, which no single radius expresses.
///
/// So the gradient is declared at `radius: 1` (a circle the width of the
/// shortest side) and this scales it about its own centre into the ellipse.
/// The matrix rides on the shader Flutter was going to build anyway: it is a
/// `localMatrix` on one `drawRect`, not a transform layer, and it costs
/// nothing beyond the gradient. [GradientTransform] is handed the box and not
/// the gradient, which is why the centre is repeated here.
///
/// Lifted out of `floor_dawn.dart` unchanged on 3 October 2026 so the console
/// desk's two washes use the geometry Dawn proved rather than a second copy of
/// it. The only edit was the name.
@immutable
class AmbientEllipse extends GradientTransform {
  const AmbientEllipse(
    this.centre, {
    required this.width,
    required this.height,
  });

  /// The same `center` the gradient was given. The scale is **about the
  /// centre**; about the box's origin it would slide the dome sideways and
  /// down, which on a 390×844 phone is a wash whose brightest point is off
  /// the bottom-right corner.
  final Alignment centre;

  /// The ellipse's radii, as a share of the box's width and of its height.
  final double width;
  final double height;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final side = bounds.shortestSide;
    if (side == 0) return null;
    final origin = centre.withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(
        width * bounds.width / side,
        height * bounds.height / side,
        1,
        1,
      )
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is AmbientEllipse &&
      other.centre == centre &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(centre, width, height);
}
