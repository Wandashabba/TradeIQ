import 'package:flutter/material.dart';

import 'lumen_glass.dart';

/// The colours of Lumen Glass, per theme. [LumenGlass] keeps the geometry,
/// motion and type (which never change with the theme) plus the light values
/// as constants; anything that paints reads its colour from here instead, so
/// the same glass branch renders the lit lavender day or the indigo night.
///
/// Read it with `context.lumen`.
@immutable
class LumenPalette {
  const LumenPalette({
    required this.groundTop,
    required this.groundBottom,
    required this.bloomViolet,
    required this.bloomBlue,
    required this.bloomRose,
    required this.ink,
    required this.inkMuted,
    required this.kicker,
    required this.accent,
    required this.accentSolid,
    required this.accentInk,
    required this.accentLight,
    required this.track,
    required this.critical,
    required this.panelFill,
    required this.panelRim,
    required this.tileFill,
    required this.tileRim,
    required this.solidFill,
    required this.barFill,
    required this.barRim,
    required this.pillFill,
    required this.pillRim,
    required this.darkFill,
    required this.darkRim,
    required this.actionFill,
    required this.actionRim,
    required this.actionDisabled,
    required this.actionInk,
    required this.specular,
    required this.highlight,
    required this.shadow,
    required this.footageVeil,
  });

  final Color groundTop;
  final Color groundBottom;
  final Color bloomViolet;
  final Color bloomBlue;
  final Color bloomRose;

  /// Headline and body ink on the ground and on panes.
  final Color ink;

  /// Secondary words — still 4.5:1 on every pane.
  final Color inkMuted;
  final Color kicker;
  final Color accent;
  final Color accentSolid;

  /// Accent used as text or an icon on a pane.
  final Color accentInk;
  final Color accentLight;
  final Color track;

  /// The critical status as ink and mark — a fall, a breach, a negative bar.
  /// Derived from the rose bloom rather than the flat palette's fire-engine
  /// red, so a bad number reads as part of the same lavender material:
  /// `#A3294A` by day (6.5:1 on surface1), `#F29BB0` at night (8:1).
  final Color critical;

  final Color panelFill;
  final Color panelRim;
  final Color tileFill;
  final Color tileRim;
  final Color solidFill;
  final Color barFill;
  final Color barRim;
  final Color pillFill;
  final Color pillRim;
  final Color darkFill;
  final Color darkRim;

  /// The primary action: dark ink by day, a bright lavender pane by night.
  final Color actionFill;
  final Color actionRim;
  final Color actionDisabled;
  final Color actionInk;

  /// The top-left sheen and the 1px lit top edge on panes.
  final Color specular;
  final Color highlight;

  /// The colour every pane's drop shadow is cast in.
  final Color shadow;

  /// How much of the ground covers footage laid under it (0–1): enough that
  /// the picture reads as texture and the panes' words keep their contrast.
  final double footageVeil;

  /// A white edge or wash given at its light-theme [alpha] (0–255). Night
  /// keeps the role at about a quarter of the strength: white at 80% is a lit
  /// rim on lavender and a glare on indigo.
  Color white(int alpha) => Color.fromARGB(
    identical(this, dark) ? (alpha * 0.28).round() : alpha,
    255,
    255,
    255,
  );

  static const light = LumenPalette(
    groundTop: LumenGlass.groundTop,
    groundBottom: LumenGlass.groundBottom,
    bloomViolet: LumenGlass.bloomViolet,
    bloomBlue: LumenGlass.bloomBlue,
    bloomRose: LumenGlass.bloomRose,
    ink: LumenGlass.ink,
    inkMuted: LumenGlass.inkMuted,
    kicker: LumenGlass.kicker,
    accent: LumenGlass.accent,
    accentSolid: LumenGlass.accentSolid,
    accentInk: LumenGlass.accentInk,
    accentLight: LumenGlass.accentLight,
    track: LumenGlass.track,
    critical: LumenGlass.critical,
    panelFill: LumenGlass.panelFill,
    panelRim: LumenGlass.panelRim,
    tileFill: LumenGlass.tileFill,
    tileRim: LumenGlass.tileRim,
    solidFill: LumenGlass.solidFill,
    barFill: LumenGlass.barFill,
    barRim: LumenGlass.barRim,
    pillFill: LumenGlass.pillFill,
    pillRim: LumenGlass.pillRim,
    darkFill: LumenGlass.darkFill,
    darkRim: LumenGlass.darkRim,
    actionFill: LumenGlass.buttonDark,
    actionRim: LumenGlass.actionRim,
    actionDisabled: LumenGlass.actionDisabled,
    actionInk: Colors.white,
    specular: Color(0xB3FFFFFF),
    highlight: Color(0xF2FFFFFF),
    shadow: Color(0x33241F47),
    footageVeil: 0.84,
  );

  static const dark = LumenPalette(
    groundTop: Color(0xFF15132B),
    groundBottom: Color(0xFF0B0A17),
    bloomViolet: Color(0x8C3A2F78),
    bloomBlue: Color(0x732A3F74),
    bloomRose: Color(0x66523063),
    ink: Color(0xFFEEECFB),
    inkMuted: Color(0xFFAEACC8),
    kicker: Color(0xFFB5ABFC),
    accent: Color(0xEBB5ABFC),
    accentSolid: Color(0xFFB5ABFC),
    accentInk: Color(0xFFD4CDFF),
    accentLight: Color(0xFFB5ABFC),
    track: Color(0x29FFFFFF),
    critical: Color(0xFFF29BB0),
    panelFill: Color(0x17FFFFFF),
    panelRim: Color(0x2EFFFFFF),
    tileFill: Color(0x14FFFFFF),
    tileRim: Color(0x26FFFFFF),
    solidFill: Color(0xF21B192E),
    barFill: Color(0x1FFFFFFF),
    barRim: Color(0x33FFFFFF),
    pillFill: Color(0x2EFFFFFF),
    pillRim: Color(0x3DFFFFFF),
    darkFill: Color(0xE6070612),
    darkRim: Color(0x33FFFFFF),
    actionFill: Color(0xF5E9E6FF),
    actionRim: Color(0x80FFFFFF),
    actionDisabled: Color(0xA6E9E6FF),
    actionInk: Color(0xFF241F47),
    specular: Color(0x1FFFFFFF),
    highlight: Color(0x40FFFFFF),
    shadow: Color(0x66000000),
    footageVeil: 0.80,
  );
}

extension LumenContext on BuildContext {
  LumenPalette get lumen => Theme.of(this).brightness == Brightness.dark
      ? LumenPalette.dark
      : LumenPalette.light;
}
