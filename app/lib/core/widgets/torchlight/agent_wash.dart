import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/torchlight/tiq_skin.dart';
import '../../../features/dashboard/presentation/floor_dawn.dart'
    show floorDawnWash;

/// ── THE BACK SHADE ON THE AGENT'S TAB ROOTS: Dawn, TURNED OVER ─────────
///
/// > *"LETS DO A, MAKE IT PRODUCTON LEVEL AND HIGH QUALITY AND PLEASE ADD
/// > THAT BACK SHADE AS WELL"* — the owner, 4 October 2026.
///
/// ```text
///   ┌──────────────────────────────┐
///   │  ·  ·  ·  ·  ·  ·  ·  ·  ·   │  ← Dawn, from the top edge
///   │     Today · Thu 18 Sep       │
///   │                              │
///   │  [ the plan ]                │
///   │                              │     and nothing at all down here,
///   │  ░░░░░░░░░░░░░░░░░░░░░░░░░░  │  ← which is what lets the fade end
///   │   Today  My work  Map   Me   │     in a known colour
///   └──────────────────────────────┘
/// ```
///
/// ## IT IS NOT A THIRD WASH
///
/// [floorDawnWash] with a centre, exactly as `consoleDeskWash` is. Its clay
/// token, its three stops, its per-skin alphas (0.30 → 0.08 Night, 0.22 → 0.06
/// Day), its 130%×48% ellipse and its Night-only `flame900` hot breath all
/// travel across unchanged, so everything `floor_dawn.dart` measured — the
/// hue-10.4° escape on Night, the empty forbidden-alpha interval on Day, the
/// `edgeControl` ceiling at clay 0.287 — is already true here. The only
/// argument that does not travel is the one about *which* edge, so that is the
/// only thing passed in.
///
/// **It is a glow on Night and a shade on Day**, from the same token, because
/// `palette.comparison` is `#E08E71` on Night and `#A35139` on Day and the Day
/// value is darker than Palladian. The owner's word was "shade" and on paper
/// that is not a figure of speech.
///
/// ## TOP-ANCHORED, AND THE REASON IS THE FADE
///
/// The Floor's Dawn rises from the bottom edge. This one falls from the top,
/// and the choice is **not** a taste — it is what makes shape A's fade
/// possible at all.
///
/// [TorchShell.bandScrimExtent] has to end in the ground colour at one exact
/// pixel row, and `TorchShell.backdrop`'s own note says a wash makes that
/// colour unknowable: no linear gradient in a `BoxDecoration` reproduces a
/// radial one, and masking the composite is what a `ShaderMask` is for and the
/// paint budget does not have one. So a bottom-rising Dawn on these screens
/// means **no fade**, and the measurement says what that costs: the clay layer
/// spreads alpha 0.114 → 0.052 across the 24dp scrim band, which is about 5
/// eight-bit levels of red and 10 of green and blue between the fade's top and
/// its opaque end. That is the same seam class — a flat ground colour meeting a
/// washed one at a hard edge — that `fix/band-seam` took off The Floor after
/// the owner named it: *"The background colour is messed up here please fix
/// this to be seamless and not have this box blue there."*
///
/// Turned over, the wash is **provably absent** down there rather than
/// weak-and-hopefully-invisible. The clay ellipse's height radius is 0.48 of
/// the box and its outermost stop is at 0.76 of that, so with the centre 0.04
/// above the top edge the wash reaches zero alpha at
///
/// ```text
///   t = 0.76 × 0.48 − 0.04 = 0.3248
/// ```
///
/// of the screen's height, and the scrim band begins at t = 0.831 on a 360×640
/// phone and t = 0.874 on a 390×844 one. Half a screen of clearance, from the
/// geometry rather than from an alpha that happens to be small.
///
/// That is also why `TorchShell` takes a flag and not a guess:
/// [TorchShell.backdropClearsScrim] is the route's claim that this is true,
/// and `agent_wash_test.dart` measures it off the rendered frame at both sizes
/// in both skins. **The arithmetic above is the design; the test is the
/// proof.**
///
/// ## WHERE IT IS, AND WHERE IT IS NOT
///
/// The four tab roots — Today, My work, Map, Me — and nowhere else. That is
/// the same reach Dawn has on the manager side, where The Floor is the one
/// console route with a wash and the other 27 have none: an ambient light
/// belongs to the screen you land on, not to every screen in the product. The
/// agent's capture sections, the visit hub and the submit gate are work
/// surfaces and they keep the bare ground.
///
/// ## Paint budget
///
/// Two decorations on Night (the hot breath and the clay) and one on Day,
/// which has no hot breath. Each is one `drawRect` with a gradient shader
/// nested by `TorchShell`'s ground — no layer, no clip, no `saveLayer`, no
/// `BackdropFilter`, no `ShaderMask`, no `BoxShadow`. A skin that refuses
/// gradients gets **no wash**, which is [floorDawnWash]'s own flat fallback
/// and the honest one for a falloff with no single-colour form.
///
/// ## Amber: none
///
/// [floorDawnWash]'s census argument is the whole of this section and it
/// travels with the geometry: zero pixels inside the flame-hue box at any
/// value, in either skin. The move changes *where* the wash is and not what
/// colours it composites to — the ellipse, the stops and the alphas are
/// identical and the ground under it is a flat `palette.ground` on this
/// profile rather than the console's falloff, which is **fewer** distinct
/// bases than the 29 `floor_dawn_test.dart` walked exhaustively.
/// `agent_wash_test.dart` censuses the real frames anyway.
List<Decoration> agentDawnWash(TiqSkin skin) => floorDawnWash(
  skin,
  clayCentre: agentDawnClayCentre,
  hotCentre: agentDawnHotCentre,
);

/// `at 50% -4%` — four percent of the screen's height ABOVE the top edge, so
/// what is on screen is the bottom of the dome and never its brightest point.
/// The Floor's own centre, reflected: it uses `1.08`.
const Alignment agentDawnClayCentre = Alignment(0, -1.08);

/// `at 50% 0%` — exactly the top edge. The Floor's hot breath sits on the
/// bottom edge at `1`; this is the same alignment reflected, and it is Night
/// only.
const Alignment agentDawnHotCentre = Alignment(0, -1);

/// ── THE COMPARISON THE OWNER ASKED TO SEE, AND THE SEAM THAT MAKES IT ──
///
/// > *"ALSO produce a comparison render of Today with a bottom-rising wash,
/// > both skins — the owner will choose."*
///
/// [AgentWashDirection.rising] is the same wash coming up from the bottom
/// edge, which is The Floor's own default and therefore literally
/// [floorDawnWash] with no arguments.
///
/// **This enum and its provider exist for a comparison render, and that is a
/// cost worth naming rather than hiding.** It is one `Provider` with a
/// constant value and four one-line reads, and the app never overrides it, so
/// no shipping frame depends on it. What it buys is that the comparison is a
/// photograph of **Today** — its real plan, its real header, its real nav bar
/// — rather than of a `TorchShell` a test assembled to look like Today. The
/// honest alternative was to hand-build the frame in the test and label the
/// result a comparison of something it was not.
///
/// It also keeps the comparison **truthful about the trade**, which an
/// inline-wash mock could not: the fade is tied to the direction here, not
/// declared beside it, so the rising render comes out with **no fade at the
/// bar** — because that is what choosing it would mean. See the top-anchored
/// note above for the 5-and-10-level seam that is the price.
enum AgentWashDirection {
  /// Dawn from the top edge, which is what ships. The fade comes with it.
  falling,

  /// Dawn from the bottom edge, as The Floor has it. No fade: the wash makes
  /// the colour at the body's bottom edge unknowable, so the scrim is declined
  /// by `TorchShell`'s own rule.
  rising,
}

/// Which way the back shade falls. [AgentWashDirection.falling] everywhere in
/// the app; a test overrides it for the comparison pair.
final agentWashDirectionProvider = Provider<AgentWashDirection>(
  (ref) => AgentWashDirection.falling,
);

/// The decorations for a direction.
List<Decoration> agentWashFor(TiqSkin skin, AgentWashDirection direction) =>
    switch (direction) {
      AgentWashDirection.falling => agentDawnWash(skin),
      AgentWashDirection.rising => floorDawnWash(skin),
    };

/// Whether a direction's wash leaves the scrim band bare — the argument for
/// `TorchShell.backdropClearsScrim`, kept next to the geometry it is about so
/// the two cannot be set independently and disagree.
bool agentWashClearsScrim(AgentWashDirection direction) =>
    direction == AgentWashDirection.falling;
