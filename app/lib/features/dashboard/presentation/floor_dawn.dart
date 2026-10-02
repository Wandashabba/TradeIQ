import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';

/// ── DAWN — THE PLATE'S OWN SKY, CONTINUED DOWN THE SCREEN ──────────────
///
/// A soft wash rising from the bottom edge of The Floor, behind everything,
/// in both skins — a **glow** on Night and a **shade** on Day, from the same
/// token and the same geometry. See `The Day half` below for why the one
/// substitution the skins make (`palette.comparison`) is the whole difference,
/// and for the numbers that bounded it.
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
/// decorations or a `Stack` of two boxes. It is **two decorations** on Night
/// and **one** on Day, which has no hot breath — see below. They are returned
/// in paint order and nested by [TorchShell]'s ground: a `RenderDecoratedBox`
/// paints its decoration into the call stream it is already in and then its
/// child, so the cost is two extra `drawRect`s with a gradient shader and
/// **no** new layer, no clip and no `saveLayer`. A `Stack` would have been two
/// more render objects and a second layout pass for nothing. Zero
/// `BackdropFilter`, `ShaderMask`, `ImageFiltered`, `ColorFiltered` or
/// `BoxShadow` — a gradient is the blur of a line, at zero cost, which is the
/// same sentence that licenses the plate's own bloom and the one this follows.
///
/// ## The Day half — *"Please also add that background shade on the white
/// theme as well"*
///
/// The owner's word was **shade**, and on paper that is not a figure of
/// speech: it is what the same wash becomes. Truffle is a skin-dependent
/// token — `#E08E71` on Night, `#A35139` on Day — and the Day value is
/// **darker** than Palladian, so washing the ground toward it at the same
/// alpha through the same ellipse *deepens* the bottom of the screen instead
/// of lifting it. One token, one geometry, and the direction inverts with the
/// skin. That inversion is not a workaround for the light theme; it is the
/// honest translation, because there is no headroom to glow into on a ground
/// whose value is already 0.933.
///
/// ### What Day could not keep: the hot breath
///
/// **The 9% `flame900` under-layer does not come to Day, and the reason is a
/// number.** On Night it is the hint of something behind the clay. On
/// Palladian it is worth +0.8 of a red level — invisible — and it is also
/// exactly what breaks the census: see `the census on paper` below. It is
/// dropped rather than reduced, so Day is **one** decoration and Night is two.
///
/// ### The census on paper, and why this is the tight one
///
/// Night's Dawn escapes the census twice over — hue 10.4°, ten degrees below
/// the box, and value 0.325, far under the 0.900 floor. **Neither rescue is
/// available on Day**, and the reason is the ground:
///
/// | | hue | saturation | value |
/// |---|---|---|---|
/// | Palladian `ground` `#EEE9DF` | **40.0°** | 0.063 | **0.933** |
/// | `vignette` `#E6E0D4` | **40.0°** | 0.078 | **0.902** |
/// | the census box | 20–48° | ≥ 0.12 | ≥ 0.90 |
///
/// The Day ground is **already inside the hue box and already over the value
/// floor**. The only thing keeping the whole screen out of the amber census is
/// its saturation, 0.063 against a floor of 0.12 — which is why nothing in
/// this system has ever bloomed on a light ground, and why a warm wash here is
/// a census question before it is a design one.
///
/// So the Day wash has exactly one escape: **be a shade.** Dropping the
/// ground's value under 0.900 needs the red channel down 9 levels from 238,
/// and the wash must get there *before* its own chroma lifts saturation to
/// 0.12. Clay does, and the margin is an interval rather than a distance:
///
/// * over the `ground`, the binding base: value ≥ 0.900 only while alpha
///   ≤ **0.1133**; saturation ≥ 0.120 only once alpha ≥ **0.1356**. The box
///   needs both, so the forbidden interval is **empty by 0.0223 of alpha**.
/// * over the `vignette`: ≤ 0.0075 and ≥ 0.1000 — empty by 0.0925.
/// * exhaustively, across all 29 distinct colours the Day falloff produces
///   and 4097 alpha steps: **zero** pixels inside the box. The closest
///   approach is `#E5D6CA` at alpha 0.1211 — hue 26.67°, saturation 0.1179,
///   value **0.8980**, under the floor by 0.0021.
///
///   That is **one eight-bit level**, and it is reported as one rather than
///   rounded off: the max channel there is 229 against a floor of 229.5. The
///   interval is the better guard and the reason is that the two conditions
///   move apart, not together — to count, a pixel needs max ≥ 230 (alpha
///   ≤ 0.1067) and saturation ≥ 0.12 (alpha ≥ 0.1356) at once. **A palette
///   move is what would eat this, not a dither**, which is exactly what
///   `floor_dawn_test.dart` holds.
///
/// **And that is why `flame900` had to go.** Adding it lifts the red channel,
/// which pushes the value escape later while the clay pushes saturation
/// earlier — the two bounds move toward each other and cross. Measured: at
/// Night's own 0.09 the forbidden interval opens to clay ∈ [0.1125, 0.1311],
/// a band 1.9% of alpha wide that a gradient running 0 → 0.22 crosses, and
/// the composite at `#E6D7CA` is hue 27.9°, saturation 0.122, value 0.902 —
/// **inside the census box**. The first flame900 alpha at which any rendered
/// pixel lands inside is **0.0378**. Day's budget is one lit object and the
/// send disc already owns it, so a second counted region is not something to
/// buy a 0.8-level highlight with.
///
/// ### The twenty-two percent, and the honest reason for it
///
/// Night washes at 0.30. **Day ships at 0.22, and no floor forced that** — it
/// is a judgement, so it is written down as one rather than dressed as a
/// constraint. Both were measured on the real frame:
///
/// | | trough outline, `edgeControl` | composer label, `ink2` (worst of four scales) |
/// |---|---|---|
/// | bare Day ground | 4.38:1 | 7.53:1 |
/// | clay at **0.22** | **3.77:1** (+0.77 over 3:1) | **6.37:1** (+1.87 over 4.5:1) |
/// | clay at 0.30 | 3.55:1 (+0.55) | 6.04:1 (+1.54) |
///
/// 0.30 clears every declared floor on this screen too. What decided it is the
/// render: at 0.30 the ground immediately around the send disc is a clay warm
/// enough to argue with it, and **Day's whole amber budget is one object and
/// the disc is it**. The wash is meant to be the room the disc is lit in, not
/// a second warm thing in the frame. At 0.22 the sunrise is plainly there and
/// the disc still wins. If that reads as too little on a real panel, 0.30 is
/// measured and available; the ceiling is elsewhere.
///
/// Where the ceiling actually is: `edgeControl` crosses WCAG 1.4.11's 3:1 at
/// clay alpha **0.287** against a flat ground, which is the bound rather than
/// the reading, because the trough's outline is not at the wash's peak.
///
/// Two Day pairings are tighter still and are **guarded rather than passed**:
/// `ink3` on the ground (4.74:1) crosses 4.5:1 at clay alpha 0.045, and
/// `edgeStructure` (3.14:1) crosses 3:1 at 0.038. Neither is painted on the
/// bare ground in the bottom third of this screen — every container here is a
/// `TorchCard`, which has no outline in any skin, and the one tertiary ink
/// down there is the trough's standing hint, which sits on `well`. **That is
/// the 0.02-margin pairing of this skin**: `ink3` on `well` is 4.52:1, the
/// tightest declared number in Day, and the measured table shows it
/// **unmoved**, because the wash is under an opaque fill.
/// `floor_dawn_test.dart` pins both absences in both skins with the number,
/// the same way the Night work pinned the hypothetical container edge.
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
/// The brightest pixel the Night wash can produce is its own centre
/// composited over the Night ground: `#53403C`, value **0.325**, which is
/// 0.575 under the floor. That was the prediction. **The measurement is better
/// than the prediction and for a different reason**: that pixel is at hue
/// **10.4°**, ten degrees *below* the box, and censused on its own the wash
/// has **zero** pixels inside the box at any value at all. Clay over
/// navy-black does not composite to a dark amber. It composites to something
/// that is not amber.
///
/// On Day neither of those rescues exists and the escape is the value floor
/// alone, by the interval arithmetic above: **zero** pixels inside the box,
/// clearing by 0.0021 of value at the closest approach and by 0.0223 of alpha
/// as an interval. The Day figure is the thin one and it is stated as a
/// forbidden interval rather than a distance because that is the form the
/// guard can actually hold: an alpha band either exists or it does not.
///
/// The wash can only ever be read against the ground, because it is strictly
/// *under* every object on the screen and the only thing beneath it is
/// `ground`/`vignette`. The counts per phase per skin are in
/// `floor_dawn_test.dart`, printed rather than asserted blind.
List<Decoration> floorDawnWash(TiqSkin skin) {
  // A WASH IS A GRADIENT AND A SKIN MAY REFUSE GRADIENTS. The honest flat
  // fallback for a wash is **no wash**: a bottom-rising falloff has no
  // single-colour form, and the shell's own ground is already the right
  // picture without it. Both skins allow gradients today, so this changes no
  // pixel; `floor_dawn_test.dart` pins that so the guard cannot go quiet.
  if (!skin.depth.allowsGradients) return const <Decoration>[];
  final p = skin.palette;
  // Truffle — `#E08E71` on Night, `#A35139` on Day. The token is the same and
  // the Day value is darker than Palladian, which is what turns the glow into
  // a shade without a second code path for the colour.
  final clay = p.comparison;
  // THE CLAY, and on Night it goes on top of the hot breath. Three stops, not
  // two: the tail has to leave at 76% of an ellipse whose centre is already
  // 4% below the bottom edge, which puts the wash's top boundary at 67.5% of
  // the screen and its only visible edge at zero alpha. A two-stop version
  // bands on a 6-bit panel for the same reason the shell's own falloff takes
  // four.
  final (double peak, double tail) = skin.amberIsInk
      ? _dayAlphas
      : _nightAlphas;
  final BoxDecoration clayLayer = BoxDecoration(
    gradient: RadialGradient(
      center: _clayCentre,
      radius: 1,
      transform: const _Ellipse(_clayCentre, width: 1.30, height: 0.48),
      colors: <Color>[
        clay.withValues(alpha: peak),
        clay.withValues(alpha: tail),
        clay.withValues(alpha: 0),
      ],
      stops: const <double>[0, 0.44, 0.76],
    ),
  );

  // AMBER IS INK HERE, SO THERE IS NO LIGHT TO EMIT — and therefore no hot
  // breath. Not `skin.mode == night`: a skin is a value set and this is the
  // token that already says what the gate means, exactly as
  // `primary_button.dart` and `nav_circle.dart` read it. The 9% `flame900`
  // under-layer is worth +0.8 of a red level on Palladian and it is what puts
  // the wash inside the census box from alpha 0.0378 up; see the Day half
  // above for the interval.
  if (skin.amberIsInk) return <Decoration>[clayLayer];

  // Truffle, and the one flame token this file names. See the note above for
  // why the marker is here and not an entry in the emitter allowlist.
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
    // 2. THE CLAY, on top.
    clayLayer,
  ];
}

/// The clay's `(centre, 44%)` alphas, per skin.
///
/// Night is the artifact's own `.30 → .08`, written as literals so this change
/// cannot move a Night pixel by a floating-point hair.
const (double, double) _nightAlphas = (0.30, 0.08);

/// **Day is 0.22 → 0.06, and it is a judgement, not a floor.** 0.30 was
/// rendered and measured too and it clears everything this screen declares;
/// the table and the reason are in the `twenty-two percent` section above.
///
/// What is a measurement is the direction of the cost. On a light ground the
/// wash darkens the backdrop its ink is read against instead of lifting it, so
/// every ratio over it *falls* — the exact inverse of Night, where the wash
/// lightens a dark ground under light ink and the ratios fall for the mirror
/// reason. `edgeControl` on the washed ground crosses WCAG 1.4.11's 3:1 at
/// alpha **0.287**, which is the ceiling. **No floor was lowered.** The table,
/// the worst point under each run, and the margins are in
/// `floor_dawn_test.dart`.
///
/// The tail is scaled with the peak rather than clipped, so there is no step
/// at the 44% stop: 0.06/0.22 is **0.273** of the peak against the artifact's
/// 0.08/0.30 = **0.267**, a difference of six thousandths of alpha at that one
/// stop, kept as a round number rather than carried as 0.0587.
const (double, double) _dayAlphas = (0.22, 0.06);

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
