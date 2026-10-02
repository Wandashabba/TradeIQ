import 'package:flutter/material.dart';

import 'tiq_palette.dart';
import 'tiq_space.dart';
import 'tiq_type.dart';

export 'tiq_palette.dart';
export 'tiq_space.dart';
export 'tiq_text_scale.dart';
export 'tiq_type.dart';

/// Which skin the app is wearing.
///
/// Two skins: NIGHT (the cinematic dark — managers by default, and agents
/// doing back-of-store or pre-dawn forecourt work) and DAY (Palladian paper —
/// the agent default).
///
/// There was a third, VELD — an outdoor high-contrast skin with its own token
/// set. The owner removed it on 28 September 2026; see
/// `docs/design/spec/unify.md` §4.
enum SkinMode {
  night,
  day,

  /// Follow the platform brightness. Always overridable by the thumb-zone
  /// skin cycle.
  auto,
}

/// **The** token source. One `ThemeExtension`, two value sets.
///
/// This replaces `TiqColors`, `LumenPalette`, `LumenGlass`, `AppColors` and
/// `status_pill_colors.dart`. Those five still exist as `@Deprecated` shims so
/// the existing screens compile; new code reads `context.skin`.
///
/// A mode is a value set, not a code path: every difference between Night and
/// Day is a different [TiqPalette]/[TiqType]/[TiqDepth] instance handed to the
/// same constructor. There is no `if (isNight)` anywhere in this file, and
/// there should be none in a widget either.
@immutable
class TiqSkin extends ThemeExtension<TiqSkin> {
  const TiqSkin({
    required this.mode,
    required this.brightness,
    required this.palette,
    required this.text,
    required this.space,
    required this.radii,
    required this.depth,
    required this.motion,
    required this.amberIsInk,
    required this.standingColoursFigures,
  });

  /// Which of the two skins this is. Never [SkinMode.auto] — auto is a
  /// preference, and it resolves to one of the two before a skin is built.
  final SkinMode mode;

  final Brightness brightness;
  final TiqPalette palette;
  /// The type scale for this skin's density. Named `text` and not `type`
  /// because `ThemeExtension` already uses `type` as its lookup key.
  final TiqType text;
  final TiqSpace space;
  final TiqRadii radii;
  final TiqDepth depth;
  final TiqMotion motion;

  /// THE AMBER LAW, as a value.
  ///
  /// False on dark grounds: amber is emitted light — a rim, an underbar, a
  /// focus ring, a gradient stop, a stroke, one focus bar per chart. It is
  /// never a chip background, never a repeated series fill, never a status
  /// word's colour, never a badge and never the caret on a severity-coded
  /// delta.
  ///
  /// True on light grounds: amber inverts from light to ink-carrier, and there
  /// is EXACTLY ONE amber block per screen — the primary commit action.
  /// Everything else that used to be amber (torch-on, "you are here", the
  /// ranked-bar focus channel, the live pulse) is something else there.
  final bool amberIsInk;

  /// WHETHER A FIGURE IS ALLOWED TO CARRY ITS OWN VERDICT IN INK, as a value.
  ///
  /// True on paper, false on the console, and the asymmetry is the ground's
  /// rather than a preference:
  ///
  /// * On **Day** the ground is Palladian and [TiqPalette.ink1] is a navy so
  ///   dark that a page of figures is one colour. Severity ink is the cheapest
  ///   way to tell a good number from a bad one there, and the owner asked for
  ///   it in as many words on 28 September 2026. It stays.
  /// * On **Night** the ground is near-black and [TiqPalette.ink1] is a warm
  ///   bone that *emits*. A figure set in [TiqPalette.bad] on that ground is
  ///   darker than the ink around it, so the screen's brightest objects become
  ///   its least important ones and a list of rows reads as damage. The
  ///   verdict is carried by the mark and the word instead, which is what
  ///   §16.2 already ruled for the visit-outcome hero and what the approved
  ///   artifact does on every row it draws.
  ///
  /// It is a value and not an `if (isNight)` for the reason this whole class
  /// is: a skin is a value set, and the one place that reads this is
  /// `standingInk` / `severityInk` in
  /// `core/widgets/torchlight/figure/standing.dart`. No widget asks.
  ///
  /// It does **not** mute severity generally. Marks, dots, bars, severity
  /// words, phrases, chips, sparkline strokes and deltas keep their hue in
  /// both skins — only the figure gives its colour up, and only where
  /// something else beside it still says the same thing.
  final bool standingColoursFigures;

  TiqDensity get density => space.density;

  /// THE STOPS OF AN AMBER FILL'S GRADIENT — hot core first, [TiqPalette
  /// .flame600] last — 1 October 2026.
  ///
  /// The owner's note was *"the send button ... and everywhere else for orange
  /// is very dull, it need to be lumunous and bright and inviting"*, and
  /// `flame600` was already at value 1.00. Half the answer was chroma, and that
  /// lives in `tiq_palette.dart`. This is the other half, and it is the bigger
  /// one: **a flat swatch of one colour cannot glow.** Real emitted light has a
  /// hot core and falls off, which is exactly what the plate's strip light
  /// already does — and the strip light is the one object in the product that
  /// genuinely reads as lit, while the send disc was a flat fill.
  ///
  /// ## Why it stops at `flame600` and not past it
  ///
  /// Because that is what makes the gradient **free in the contrast table**.
  /// Dark ink on amber is a declared pairing, and over a gradient the ink sits
  /// on a *range* of colours rather than one — so the number that matters is
  /// the worst point under the text, not the average. Every stop here is
  /// lighter than `flame600` except the last, which IS `flame600`, so the worst
  /// pixel any ink on an amber fill can land on is `flame600` — the same pixel
  /// the flat fill painted. Every declared `onAmber` ratio is preserved to the
  /// digit: 9.68:1 on Night, 7.78:1 on Day.
  ///
  /// The falloff *to nothing* that a real light has cannot happen inside a
  /// fill — past the object's own edge there is only the ground. That is what
  /// [TiqPalette.glowAmber] is for, and on a dark ground only; see its note.
  ///
  /// ## Why the hot end is per skin
  ///
  /// Night ramps to `flame900`, the white-hot core, because a dark ground has
  /// the headroom — the same argument [TiqPalette.plateCeiling] makes for the
  /// photograph.
  ///
  /// **Day stops at `flame700`.** On paper `flame900` measures **1.04:1**
  /// against Palladian, so a near-white core inside an amber block does not
  /// read as a hot centre, it reads as a hole in the block — the ground
  /// showing through. `flame700` is 1.32:1 against the ground and 9.63:1 under
  /// dark ink, so the Day ramp is shallower, stays unmistakably amber, and
  /// still has a lit end.
  ///
  /// ## The census does not move
  ///
  /// Every colour interpolated between these two stops is inside the census's
  /// flame box (hue 20–48°, value ≥ 0.90, saturation ≥ 0.12) — checked at a
  /// hundred points across the ramp in both skins. So a gradient-filled object
  /// is one connected flame-hued region, exactly as the flat fill was, and the
  /// count is unchanged on every screen. The lit *fraction* of the frame is
  /// unchanged too, because the same pixels are inside the box; only their
  /// colour varies.
  ///
  /// Geometry is **not** decided here, deliberately: a 36dp disc and a 56dp
  /// full-width block do not want the same gradient. Each object picks its own
  /// and says why, the way [TiqPalette.glowAmber]'s call sites do.
  List<Color> get amberFillRamp => <Color>[
    amberIsInk ? palette.flame700 : palette.flame900,
    palette.flame600,
  ];

  /// NIGHT. Console by default — it is the manager's skin.
  factory TiqSkin.night({TiqDensity density = TiqDensity.console}) => TiqSkin(
    mode: SkinMode.night,
    brightness: Brightness.dark,
    palette: TiqPalette.night,
    text: TiqType.forDensity(density),
    space: density == TiqDensity.field ? TiqSpace.field : TiqSpace.console,
    radii: TiqRadii.lit,
    depth: TiqDepth.night,
    motion: TiqMotion.on,
    amberIsInk: false,
    // A bone figure on a near-black ground is the luminous object the console
    // is built around. The verdict goes on the mark beside it.
    standingColoursFigures: false,
  );

  /// DAY. **Console by default, since 29 September 2026** — symmetrical with
  /// [TiqSkin.night] above.
  ///
  /// IT USED TO DEFAULT TO FIELD, on the true observation that the agent is
  /// the one who starts in Day. That default was a measurement trap and it
  /// caught things for weeks. `TiqSkin.night()` means console and
  /// `TiqSkin.day()` meant field, so **every test that paired the two to hold
  /// the density still and vary the skin was varying both** — and there are
  /// 118 bare `TiqSkin.day()` calls under `test/`, including three manager
  /// look harnesses (`floor_look_test.dart`, `overview_look_test.dart`,
  /// `manager_chip_look_test.dart` via [of]) that were photographing manager
  /// screens at the agent's density and calling the result a manager screen.
  /// `tiq_contrast.dart` built the whole declared Day contrast contract off a
  /// bare call, so the Day walk ran at one type scale and the Night walk at
  /// another.
  ///
  /// A default cannot carry that meaning. Nothing in production relied on it:
  /// `agent_skin.dart`, `entry_skin.dart`, `console_skin.dart` and
  /// `app_theme.dart` all name the density at every call site, which is why
  /// this changes no shipping pixel — proved by sha256 over the 26 manager
  /// look renders, not assumed. A surface with a density opinion states it;
  /// a bare call now means "the Day token set, no density opinion", and the
  /// two factories answer the same way.
  factory TiqSkin.day({TiqDensity density = TiqDensity.console}) => TiqSkin(
    mode: SkinMode.day,
    brightness: Brightness.light,
    palette: TiqPalette.day,
    text: TiqType.forDensity(density),
    space: density == TiqDensity.console ? TiqSpace.console : TiqSpace.field,
    radii: TiqRadii.lit,
    depth: TiqDepth.day,
    motion: TiqMotion.on,
    amberIsInk: true,
    // Dark ink on paper: without the severity hue a page of figures is one
    // colour. The owner asked for it on 28 September 2026 and has not
    // withdrawn it.
    standingColoursFigures: true,
  );

  /// Build the skin a [SkinMode] asks for. [platformBrightness] only matters
  /// for [SkinMode.auto].
  ///
  /// [density] defaults to console on **both** arms, since 29 September 2026
  /// and for the reason on [TiqSkin.day]: a caller that hands this a mode and
  /// no density is asking for a skin, not for a surface, and it should not
  /// silently get the agent's geometry on the Day arm and the manager's on
  /// the Night one. `manager_chip_look_test.dart` was doing exactly that.
  static TiqSkin of(
    SkinMode mode, {
    Brightness platformBrightness = Brightness.dark,
    TiqDensity? density,
  }) => switch (mode) {
    SkinMode.night => TiqSkin.night(
      density: density ?? TiqDensity.console,
    ),
    SkinMode.day => TiqSkin.day(density: density ?? TiqDensity.console),
    SkinMode.auto =>
      platformBrightness == Brightness.dark
          ? TiqSkin.night(density: density ?? TiqDensity.console)
          : TiqSkin.day(density: density ?? TiqDensity.console),
  };

  /// The default ink for a body of text on this skin's ground.
  TextStyle get bodyStyle => text.body.style(color: palette.ink1);

  /// The ink that belongs on a fill — the only place a caller should ask a
  /// question about a background, and it is answered here once.
  Color onFill(Color fill) => switch (fill) {
    _ when fill == palette.amberPressed => palette.onAmberPressed,
    _ when fill == palette.flame600 || fill == palette.flame500 =>
      palette.onAmber,
    _ when fill == palette.badSolid => palette.onBadSolid,
    _ when fill == palette.goodSolid => palette.onGoodSolid,
    _ => palette.ink1,
  };

  @override
  TiqSkin copyWith({
    SkinMode? mode,
    Brightness? brightness,
    TiqPalette? palette,
    TiqType? text,
    TiqSpace? space,
    TiqRadii? radii,
    TiqDepth? depth,
    TiqMotion? motion,
    bool? amberIsInk,
    bool? standingColoursFigures,
  }) => TiqSkin(
    mode: mode ?? this.mode,
    brightness: brightness ?? this.brightness,
    palette: palette ?? this.palette,
    text: text ?? this.text,
    space: space ?? this.space,
    radii: radii ?? this.radii,
    depth: depth ?? this.depth,
    motion: motion ?? this.motion,
    amberIsInk: amberIsInk ?? this.amberIsInk,
    standingColoursFigures:
        standingColoursFigures ?? this.standingColoursFigures,
  );

  /// Colours and radii interpolate; a type scale, a density and a depth budget
  /// do not — those snap at the midpoint, because half a tap target is not a
  /// tap target.
  @override
  TiqSkin lerp(ThemeExtension<TiqSkin>? other, double t) {
    if (other is! TiqSkin) return this;
    final past = t < 0.5;
    return TiqSkin(
      mode: past ? mode : other.mode,
      brightness: past ? brightness : other.brightness,
      palette: palette.lerp(other.palette, t),
      text: past ? text : other.text,
      space: past ? space : other.space,
      radii: radii.lerp(other.radii, t),
      depth: past ? depth : other.depth,
      motion: past ? motion : other.motion,
      amberIsInk: past ? amberIsInk : other.amberIsInk,
      // A law, not a colour: it snaps at the midpoint with the rest of them.
      standingColoursFigures: past
          ? standingColoursFigures
          : other.standingColoursFigures,
    );
  }
}

/// `context.skin` — how feature code reads the ambient tokens.
///
/// Falls back to Night when no theme registers the extension, which only
/// happens in a test that pumps a bare `MaterialApp`.
extension TiqSkinContext on BuildContext {
  TiqSkin get skin => Theme.of(this).extension<TiqSkin>() ?? _fallbackNight;
}

final TiqSkin _fallbackNight = TiqSkin.night();
