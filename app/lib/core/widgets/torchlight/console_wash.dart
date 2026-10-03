import 'package:flutter/widgets.dart';

import '../../design/ambient_wash.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../../../features/dashboard/presentation/floor_dawn.dart'
    show floorDawnWash;

/// ── THE TWO LIGHTS ON THE CONSOLE'S DESK ───────────────────────────────
///
/// A **cool** wash high and left, behind the rail; and the app's own **warm**
/// Dawn low and right, under the detail pane. Painted into
/// `TorchShell.backdrop` — the one layer continuous across all three panes —
/// and under every object on the screen.
///
/// Only at desk width. Below [ConsoleDesk.isDesk] this returns nothing, so the
/// phone renders the pixels it rendered before this file existed.
///
/// ```text
///   ·  ·  ·                                      cool, from the top-left
///   ┌────────────┬──────────────┬─────────────┐
///   │  rail      │  list        │  detail     │
///   │            │              │             │
///   └────────────┴──────────────┴─────────────┘
///                                   ·  ·  ·    Dawn, from the bottom-right
/// ```
///
/// ## DAWN IS NOT A SECOND IMPLEMENTATION, IT IS DAWN
///
/// [floorDawnWash] with a centre. Its clay token, its three stops, its
/// per-skin alphas (0.30 → 0.08 Night, 0.22 → 0.06 Day), its 130%×48%
/// ellipse and its Night-only `flame900` hot breath all travel across
/// unchanged; the only argument that does not is the one about *which*
/// bottom edge, so that is the only thing passed in. Everything
/// `floor_dawn.dart` measured — the hue-10.4° escape on Night, the
/// forbidden-alpha interval on Day, the `edgeControl` ceiling at clay 0.287 —
/// is therefore already true here.
///
/// It moves to **x = 0.52**, which is the detail pane's own horizontal centre
/// and is stable across the approved widths rather than a number per width:
/// the list and detail panes split what is left after the rail in a fixed
/// 8 : 11, so the detail centre lands at 0.759 of the viewport at 1440 and
/// 0.763 at 1280 — a quarter of a percent apart, which is why one constant
/// does for both.
///
/// ## THE COOL ONE IS NEW, AND IT HAD A SPECIFIC HAZARD TO CLEAR
///
/// Blue-grey is already this product's outline colour — Night's
/// `edgeStructure` is `#5B718A` and `edgeControl` is `#7C93AC`, both at
/// hue 211° — so a cool ambient light sits *underneath every outlined control
/// in the rail and the list* and could quietly take the separation that makes
/// a control look like a control. The declared floor for a structural edge is
/// **3.0**. `console_wash_contrast_test.dart` measures it on the real frame,
/// at the worst point, in both skins, before and after.
///
/// What the arithmetic says, and the two skins do not say the same thing:
///
/// ### Day is free, and the reason is luminance
///
/// [TiqPalette.ambientCool] on Day is `#D5E2F1`, whose relative luminance is
/// **0.748897** against `vignette`'s **0.748878**. The console's ground is a
/// falloff that runs `ground → vignette → vignette → ground`, so every pixel
/// of it already lies between those two luminances; compositing any of them
/// toward a colour at the vignette's own luminance keeps the result inside
/// that interval. **Contrast is a function of luminance alone**, so the wash
/// cannot take any pairing on the console ground below what it already has at
/// the darkest row of the falloff — at any alpha, which is why Day has no
/// ceiling at all.
///
/// It is not a rhetorical zero. 8-bit rounding moves the composite by up to
/// 0.004 of luminance, worth about 0.02 of a ratio point, and measured at the
/// shipping alpha the rounding lands the right way:
///
/// | Day pairing | bare vignette | under the wash | floor |
/// |---|---|---|---|
/// | `edgeStructure` | 3.137:1 | **3.149:1** | 3.0 |
/// | `ink3` | 4.739:1 | **4.756:1** | 4.5 |
///
/// Those two are the tightest numbers in the skin — `edgeStructure` has 0.137
/// of margin and `ink3` has 0.239 — and they are the pair that forced Dawn to
/// be *guarded rather than passed* on Day. A warm wash moves them the wrong
/// way; this one does not move them.
///
/// The light is still visible, because what it drains is **warmth**, not
/// value: Palladian is hue 40° at 6% saturation, and at [_dayAlphas]'s peak
/// the top-left corner reads `#E2E1DC` against a bare `#E6E0D4` — blue up
/// nine levels, red down four. On paper a cool light is the warmth leaving.
///
/// ### Night is not free, and here is the ceiling
///
/// On a near-black ground there is no iso-luminant move available: `ground`
/// and `vignette` are 1.09:1 apart and a wash between them is invisible. So
/// the Night wash lightens, and lightening the ground under light ink and
/// light edges costs contrast. Measured against the **vignette** (the binding
/// base), with `#7196C4`:
///
/// | Night pairing | floor | bare | at alpha 0.10 | crosses its floor at |
/// |---|---|---|---|---|
/// | `edgeStructure` | 3.0 | 3.61:1 | **3.15:1** | **α 0.1315** |
/// | `edgeControl` | 3.0 | 5.73:1 | 5.00:1 | α 0.3790 |
/// | `ink3` | 4.5 | 6.85:1 | 5.97:1 | α 0.2620 |
/// | `navInkInactive` | 4.5 | 6.75:1 | 5.89:1 | α 0.2540 |
/// | `ink2` | 4.5 | 10.16:1 | 8.87:1 | α 0.4650 |
/// | `ink1` | 4.5 | 15.02:1 | 13.10:1 | α 0.6680 |
///
/// **`edgeStructure` is the binding term and 0.1315 is the ceiling.** It ships
/// at **0.10**, which is 76% of the way to it and leaves 0.15 of ratio. That
/// is a thin margin and it is stated as one rather than dressed up: the
/// pairing has only 0.61 of margin on the bare ground to begin with, and a
/// wash that is visible on near-black spends some of it. The alternative was a
/// Night wash nobody can see, and the owner asked for two lights.
///
/// The margin is real rather than nominal because of **where the wash
/// actually is**. 0.10 is the peak, at the top-left corner behind the rail,
/// and the rail paints no `edgeStructure` and no `edgeControl` at all — its
/// rows are flat on the ground and its markers are kickers. The outlined
/// controls on a console screen are the filter chips and the ask bar's two
/// keys, which are in the list and detail panes where the cool falloff has
/// already dropped. The test measures the real frame rather than this
/// paragraph.
///
/// ## WHAT WOULD HAVE HAPPENED IF IT HAD FAILED
///
/// Dawn ships alone and the cool light does not ship. It was close enough to
/// that to be worth writing down: a cool wash in the **direction Dawn takes on
/// Day** — darkening a light ground — puts `edgeStructure` under 3.0 at alpha
/// **0.034** and `ink3` under 4.5 at **0.042**, which is a wash nobody can
/// see. The thing that rescued it is not a smaller alpha, it is picking the
/// one cool colour in the band that has the vignette's luminance.
///
/// ## Amber: none, in either skin
///
/// The cool wash is hue 212–215°, which is **163° from the nearest edge** of
/// the census's 20–48° box; walked exhaustively over both bases and 4,097
/// alpha steps, zero pixels land inside it at any value. Dawn's own zero is
/// `floor_dawn.dart`'s and is unchanged by the move.
///
/// ## Paint budget
///
/// Three decorations on Night (cool, Dawn's hot breath, Dawn's clay) and two
/// on Day (Dawn has no hot breath there). Each is one `drawRect` with a
/// gradient shader nested by `TorchShell`'s ground — no layer, no clip, no
/// `saveLayer`, no `BackdropFilter`, no `ShaderMask`, no `BoxShadow`. A skin
/// that refuses gradients gets **no wash**, which is the honest flat fallback
/// for a falloff that has no single-colour form; both shipping skins allow
/// them, so that branch changes no pixel today and
/// `console_wash_test.dart` pins it so the guard cannot go quiet.
List<Decoration> consoleDeskWash(TiqSkin skin) {
  if (!skin.depth.allowsGradients) return const <Decoration>[];
  final (double peak, double tail) = skin.amberIsInk
      ? _dayAlphas
      : _nightAlphas;
  return <Decoration>[
    // 1. THE COOL ONE, FIRST AND THEREFORE UNDERNEATH. Where the two overlap
    //    — the bottom-left of the list pane — Dawn is the one on top, which is
    //    the same order The Floor paints its own two layers in and the order
    //    the warm light should win: Dawn is the app's light and this is the
    //    room it is in.
    ambientWash(
      colour: skin.palette.ambientCool,
      centre: _coolCentre,
      radii: (width: 0.70, height: 0.90),
      // Three stops, not two, for `floor_dawn.dart`'s reason: two band on a
      // 6-bit panel. The stop positions are Dawn's own, so the two washes
      // have the same falloff shape and differ only in where they are and
      // what colour they are.
      stops: const <double>[0, 0.44, 0.76],
      alphas: <double>[peak, tail, 0],
    ),
    // 2. AND DAWN, MOVED UNDER THE DETAIL PANE. See the class comment: this is
    //    `floorDawnWash` itself, not a copy of it.
    ...floorDawnWash(
      skin,
      clayCentre: _dawnCentre,
      hotCentre: const Alignment(_dawnX, 1),
    ),
  ];
}

/// The cool wash's Night alphas.
///
/// **0.10 is a ceiling question, not a taste.** `edgeStructure` crosses WCAG
/// 1.4.11's 3:1 against the washed vignette at alpha **0.1315**; 0.10 is 76%
/// of the way there and measures 3.15:1. The tail is 0.027 — Dawn's own
/// 0.08/0.30 ratio of 0.267, applied to this peak, so the two washes fall off
/// at the same rate and the stop at 44% is not a step in one and a shelf in
/// the other.
const (double, double) _nightAlphas = (0.10, 0.027);

/// The cool wash's Day alphas.
///
/// **0.26, and no floor forced it**, which is the opposite of the Night half
/// and is worth being plain about: the token is iso-luminant with `vignette`,
/// so there is no alpha at which this wash takes a Day pairing under its
/// floor. 0.26 is where the warmth visibly leaves the top-left corner —
/// `#E2E1DC` against a bare `#E6E0D4` — without the corner reading as a
/// different material. The tail keeps Dawn's 0.273 ratio.
const (double, double) _dayAlphas = (0.26, 0.071);

/// `at 4% -4%` — just inside the left edge and four percent above the top, so
/// what is on screen is the shoulder of the dome and never its brightest
/// point. The same trick Dawn plays with its own centre 4% below the bottom.
const Alignment _coolCentre = Alignment(-0.92, -1.08);

/// The detail pane's own horizontal centre, as an [Alignment]. See the class
/// comment for why one constant does for both approved widths.
const double _dawnX = 0.52;

/// Dawn's centre on the desk: the detail pane's midline, four percent below
/// the bottom edge — which is the y `floor_dawn.dart` already argued for.
const Alignment _dawnCentre = Alignment(_dawnX, 1.08);
