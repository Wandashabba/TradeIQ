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
/// Three skins, not two: NIGHT (the cinematic dark — managers by default, and
/// agents doing back-of-store or pre-dawn forecourt work), DAY (Palladian
/// paper — the agent default) and VELD (outdoor high-contrast, a genuine third
/// theme with its own token set, not a contrast tweak on Day).
enum SkinMode {
  night,
  day,
  veld,

  /// Follow the platform brightness, plus — once the solar/memory logic lands
  /// — the outdoor triggers. Always overridable by the thumb-zone skin cycle.
  auto,
}

/// **The** token source. One `ThemeExtension`, three value sets.
///
/// This replaces `TiqColors`, `LumenPalette`, `LumenGlass`, `AppColors` and
/// `status_pill_colors.dart`. Those five still exist as `@Deprecated` shims so
/// the existing screens compile; new code reads `context.skin`.
///
/// A mode is a value set, not a code path: every difference between Night, Day
/// and Veld is a different [TiqPalette]/[TiqType]/[TiqDepth] instance handed to
/// the same constructor. There is no `if (isNight)` anywhere in this file, and
/// there should be none in a widget either.
///
/// Veld is single-density by construction — [TiqSkin.veld] takes no density
/// argument, so `Veld × Console` cannot be built.
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
    this.textFloor = 0,
    this.borderFloor = 0,
  });

  /// Which of the three skins this is. Never [SkinMode.auto] — auto is a
  /// preference, and it resolves to one of the three before a skin is built.
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

  /// THIS SKIN's own contrast floor for anything carrying a word, over and
  /// above whatever WCAG asks of the role.
  ///
  /// Zero on Night and Day: there the role's own floor (4.5 for body, 3.0 for
  /// large text) is the whole requirement. Nine on Veld, because an entry LCD
  /// at 40% backlight in highveld sun loses the bottom two stops and outdoors
  /// there is no such thing as a decoration — not even a disabled control.
  ///
  /// It is a token and not an `if (mode == veld)` in the contrast generator
  /// for the reason the system doc gives: a skin is a value set, not a code
  /// path, and a branch on the mode is a token that does not exist yet.
  final double textFloor;

  /// The same, for a border or a meaningful graphic. Fifteen on Veld.
  final double borderFloor;

  /// The floor a pairing actually has to clear on this skin: the stricter of
  /// the role's requirement and the skin's own.
  double floorFor(double roleFloor, {required bool isText}) {
    final skinFloor = isText ? textFloor : borderFloor;
    return roleFloor > skinFloor ? roleFloor : skinFloor;
  }

  TiqDensity get density => space.density;

  /// NIGHT. Console by default — it is the manager's skin.
  factory TiqSkin.night({TiqDensity density = TiqDensity.console}) {
    assert(
      density != TiqDensity.veld,
      'TiqDensity.veld belongs to TiqSkin.veld() only.',
    );
    return TiqSkin(
      mode: SkinMode.night,
      brightness: Brightness.dark,
      palette: TiqPalette.night,
      text: TiqType.forDensity(density),
      space: density == TiqDensity.field ? TiqSpace.field : TiqSpace.console,
      radii: TiqRadii.lit,
      depth: TiqDepth.night,
      motion: TiqMotion.on,
      amberIsInk: false,
    );
  }

  /// DAY. Field by default — it is the agent's skin.
  factory TiqSkin.day({TiqDensity density = TiqDensity.field}) {
    assert(
      density != TiqDensity.veld,
      'TiqDensity.veld belongs to TiqSkin.veld() only.',
    );
    return TiqSkin(
      mode: SkinMode.day,
      brightness: Brightness.light,
      palette: TiqPalette.day,
      text: TiqType.forDensity(density),
      space: density == TiqDensity.console ? TiqSpace.console : TiqSpace.field,
      radii: TiqRadii.lit,
      depth: TiqDepth.day,
      motion: TiqMotion.on,
      amberIsInk: true,
    );
  }

  /// VELD. No density argument, by design.
  factory TiqSkin.veld() => const TiqSkin(
    mode: SkinMode.veld,
    brightness: Brightness.light,
    palette: TiqPalette.veld,
    text: TiqType.veld,
    space: TiqSpace.veld,
    radii: TiqRadii.flat,
    depth: TiqDepth.veld,
    motion: TiqMotion.off,
    amberIsInk: true,
    textFloor: 9,
    borderFloor: 15,
  );

  /// Build the skin a [SkinMode] asks for. [platformBrightness] only matters
  /// for [SkinMode.auto].
  static TiqSkin of(
    SkinMode mode, {
    Brightness platformBrightness = Brightness.dark,
    TiqDensity? density,
  }) => switch (mode) {
    SkinMode.night => TiqSkin.night(density: density ?? TiqDensity.console),
    SkinMode.day => TiqSkin.day(density: density ?? TiqDensity.field),
    SkinMode.veld => TiqSkin.veld(),
    SkinMode.auto =>
      platformBrightness == Brightness.dark
          ? TiqSkin.night(density: density ?? TiqDensity.console)
          : TiqSkin.day(density: density ?? TiqDensity.field),
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
    double? textFloor,
    double? borderFloor,
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
    textFloor: textFloor ?? this.textFloor,
    borderFloor: borderFloor ?? this.borderFloor,
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
      // A contrast floor does not interpolate: half of Veld's 9:1 is a floor
      // nobody declared and nothing was designed against.
      textFloor: past ? textFloor : other.textFloor,
      borderFloor: past ? borderFloor : other.borderFloor,
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
