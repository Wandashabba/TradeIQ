import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';

/// ── DAWN — THE PLATE'S OWN SKY, CONTINUED DOWN THE SCREEN ──────────────
///
/// A soft wash rising from the bottom edge of The Floor, behind everything,
/// on the dark skin only.
///
/// > *"Lets ship in C. Dawn — the plate's own sky"* — the owner, from an
/// > artifact of four ambient washes for the manager's landing screen.
///
/// **IT IS CLAY, NOT FLAME — the colour of the sky in the territory
/// photographs the plate already carries.** That one sentence is the whole
/// design and it is also the whole safety argument. The ask was for the app's
/// orange; a full-screen amber wash is a **third amber object** against a
/// budget of two, and it makes the send button — the one thing on this screen
/// saying *press here* — vanish into a background of its own hue. Truffle is
/// the palette's comparison ink, 15.7° away from Burning Flame and nothing
/// the amber law has a claim on, so the wash reads as warm light without
/// *being* the light: the screen glows and Send still wins. It ties the
/// bottom of the screen to the top — the plate's sunrise, continued.
///
/// ## Two gradients, two decorations, and what that costs
///
/// The artifact drew it as two stacked CSS radial gradients and this is a
/// faithful port of them:
///
/// ```css
/// radial-gradient(130% 48% at 50% 104%,
///   rgba(224,142,113,.30), rgba(224,142,113,.08) 44%, rgba(224,142,113,0) 76%)
/// radial-gradient(90% 30% at 50% 100%,
///   rgba(255,241,222,.09), rgba(255,241,222,0) 70%)
/// ```
///
/// `#E08E71` is `palette.comparison` (Truffle) and `#FFF1DE` is
/// `palette.flame900`; both are read off the skin rather than typed, which is
/// also what keeps this file off the style ledger.
///
/// A `BoxDecoration` carries **one** gradient, so two gradients is either two
/// decorations or a `Stack` of two boxes. It is **two decorations**, returned
/// in paint order and nested by [TorchShell]'s ground: a `RenderDecoratedBox`
/// paints its decoration into the call stream it is already in and then its
/// child, so the cost is two extra `drawRect`s with a gradient shader and
/// **no** new layer, no clip and no `saveLayer`. A `Stack` would have been two
/// more render objects and a second layout pass for nothing. Zero
/// `BackdropFilter`, `ShaderMask`, `ImageFiltered`, `ColorFiltered` or
/// `BoxShadow` — a gradient is the blur of a line, at zero cost, which is the
/// same sentence that licenses the plate's own bloom and the one this follows.
///
/// ## Dark skin only
///
/// A glow is **emitted light** and there is none on a page lit by the sun —
/// the same reason the plate's strip light goes out on Day. The gate is
/// `skin.amberIsInk`, the token that already carries "on this skin amber is a
/// carrier of ink, not a light", exactly as `primary_button.dart` and
/// `nav_circle.dart` read it. On Day this returns the empty list and the
/// shell's ground is untouched: nothing paints, rather than something painting
/// a Day-coloured version of itself. `floor_dawn_test.dart` pins every pixel
/// of a bare column of the Day render against the shell's own falloff, and the
/// eight committed Day sign-off renders are byte-identical across this
/// change — the twelve Night ones are not.
///
/// ## It names an amber token, and the lint was right to stop it
///
/// `torchlight_amber_lint_test.dart` failed this file on its `flame900`
/// stops, and the failure is the correct behaviour of a guard that exists
/// because *"a widget that reaches for flame600 directly is lit on every
/// route"*. The resolution is **one `torchlight-ignore` marker, on the one
/// line that names the token, plus this paragraph** — and deliberately
/// **not** an entry in `TorchlightScanner.amberAllowlist`:
///
/// * That list is the **emitter** allowlist — the thirteen files allowed to
///   light something, each one of which asks `TorchScope` first and is
///   counted by the census. This file lights nothing. It declares no claim, it
///   asks the allocator for nothing, and the census over every phase of this
///   route in both skins reads the same counts with it as without it. Putting
///   it on that list would make the one place a reader goes to find out what
///   emits light say something untrue.
/// * The `flame900` here is the **under** layer, at nine percent, beneath a
///   clay layer at thirty. Its whole contribution at the brightest pixel on
///   the screen is three levels of red and five of green and blue. Measured:
///   the composite is `#53403C`, hue **10.4°** — ten degrees *below* the
///   census's 20° boundary, so it is not a dark amber, it is not an amber at
///   all. `floor_dawn_test.dart` censuses the wash on its own and finds
///   **zero** pixels inside the flame-hue box at any value.
/// * And dropping the stop was considered first, because that would need no
///   argument. It is the owner's approved artifact, stop for stop, and
///   `#FFF1DE` is what the artifact draws: taking it out would be shipping a
///   different wash than the one that was chosen.
///
/// ## Why it is not amber, measured
///
/// The amber census counts connected regions of emitted light inside a
/// flame-hue box — hue **20–48°**, saturation ≥ 0.12 — at **value ≥ 0.90**.
///
/// The brightest pixel this wash can produce is its own centre composited over
/// the Night ground: `#53403C`, value **0.325**, which is 0.575 under the
/// floor. That was the prediction. **The measurement is better than the
/// prediction and for a different reason**: that pixel is at hue **10.4°**,
/// ten degrees *below* the box, and censused on its own the wash has **zero**
/// pixels inside the box at any value at all. Clay over navy-black does not
/// composite to a dark amber. It composites to something that is not amber.
///
/// The wash can only ever be read against the ground, because it is strictly
/// *under* every object on the screen and the only thing beneath it is
/// `ground`/`vignette`. The counts per phase per skin are in
/// `floor_dawn_test.dart`, printed rather than asserted blind.
List<Decoration> floorDawnWash(TiqSkin skin) {
  // AMBER IS INK HERE, SO THERE IS NO LIGHT TO EMIT. Not `skin.mode ==
  // night`: a skin is a value set and this is the token that already says
  // what the gate means.
  if (skin.amberIsInk) return const <Decoration>[];
  final p = skin.palette;
  // Truffle, and the one flame token this file names. See the note above for
  // why the marker is here and not an entry in the emitter allowlist.
  final clay = p.comparison;
  final hot = p.flame900; // torchlight-ignore: the 9% under-layer; see above
  return <Decoration>[
    // 1. THE HOT BREATH, painted first and therefore underneath — the CSS
    //    lists it second and a CSS background list paints back to front.
    //    `flame900` is the white-hot core of a glow gradient everywhere else
    //    in the system; at 9% over a navy-black ground it is the hint of
    //    something behind the clay rather than a light of its own.
    BoxDecoration(
      gradient: RadialGradient(
        center: _hotCentre,
        radius: 1,
        transform: const _Ellipse(_hotCentre, width: 0.90, height: 0.30),
        colors: <Color>[hot.withValues(alpha: 0.09), hot.withValues(alpha: 0)],
        stops: const <double>[0, 0.70],
      ),
    ),
    // 2. THE CLAY, on top. Three stops, not two: the tail has to leave at
    //    76% of an ellipse whose centre is already 4% below the bottom edge,
    //    which puts the wash's top boundary at 67.5% of the screen and its
    //    only visible edge at zero alpha. A two-stop version bands on a 6-bit
    //    panel for the same reason the shell's own falloff takes four.
    BoxDecoration(
      gradient: RadialGradient(
        center: _clayCentre,
        radius: 1,
        transform: const _Ellipse(_clayCentre, width: 1.30, height: 0.48),
        colors: <Color>[
          clay.withValues(alpha: 0.30),
          clay.withValues(alpha: 0.08),
          clay.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.44, 0.76],
      ),
    ),
  ];
}

/// `at 50% 104%` — four percent of the screen's height BELOW the bottom edge,
/// so what is on screen is the top of the dome and never its brightest point.
const Alignment _clayCentre = Alignment(0, 1.08);

/// `at 50% 100%` — exactly the bottom edge.
const Alignment _hotCentre = Alignment(0, 1);

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
@immutable
class _Ellipse extends GradientTransform {
  const _Ellipse(this.centre, {required this.width, required this.height});

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
      other is _Ellipse &&
      other.centre == centre &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(centre, width, height);
}
