import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Which density a skin is laid out at.
///
/// Veld is declared single-density in the type system — `TiqSkin.veld()` takes
/// no density argument — so `Veld × Console` cannot be constructed. A manager
/// who opens the app outdoors gets Veld, and that is correct: outdoors nobody
/// is doing analysis.
enum TiqDensity {
  /// The manager console: tight rows, 24px block gaps, a 44dp row floor.
  console,

  /// The field agent's phone: 64dp rows, 48dp tap targets, 56dp primary
  /// actions.
  field,

  /// Outdoors. Fewer things, further apart, because a thumb in the sun is
  /// imprecise. Only ever paired with the Veld palette.
  veld,
}

/// The spacing scale. Base 4, eleven steps, and **no other value exists** —
/// this replaces the raw-numeric `EdgeInsets` the audit found in 96 files.
///
/// The steps are named `s1…s11` rather than by intent, because a name like
/// `cardPadding` invites a twelfth step the first time a card is not a card.
@immutable
class TiqSpace {
  const TiqSpace({
    required this.density,
    required this.gutter,
    required this.gutterWide,
    required this.rowMinHeight,
    required this.blockGap,
    required this.intraBlock,
    required this.tapTarget,
    required this.primaryActionHeight,
    required this.chipHeight,
  });

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;
  static const double s9 = 56;
  static const double s10 = 72;
  static const double s11 = 96;

  /// Every legal spacing value, in order. Anything not in this list is a
  /// magic number — `torchlight_lint_test.dart` treats it as one.
  static const List<double> scale = <double>[
    s1,
    s2,
    s3,
    s4,
    s5,
    s6,
    s7,
    s8,
    s9,
    s10,
    s11,
  ];

  final TiqDensity density;

  /// Side gutter on a phone. Everything on a screen hangs off this one line.
  final double gutter;

  /// Side gutter at ≥1080 logical pixels (Console only; the other densities
  /// hold their phone gutter because they are phone-only).
  final double gutterWide;

  /// Minimum height of a list row.
  final double rowMinHeight;

  /// Between two sections.
  final double blockGap;

  /// Between two things inside one section.
  final double intraBlock;

  /// Minimum interactive box.
  final double tapTarget;

  /// Height of the one primary commit action.
  final double primaryActionHeight;

  /// Chip height.
  final double chipHeight;

  static const TiqSpace console = TiqSpace(
    density: TiqDensity.console,
    gutter: s5,
    gutterWide: s8,
    rowMinHeight: 44,
    blockGap: s6,
    intraBlock: s3,
    tapTarget: 44,
    primaryActionHeight: 44,
    chipHeight: 44,
  );

  static const TiqSpace field = TiqSpace(
    density: TiqDensity.field,
    gutter: s5,
    gutterWide: s5,
    rowMinHeight: 64,
    blockGap: s7,
    intraBlock: s4,
    tapTarget: 48,
    primaryActionHeight: s9,
    chipHeight: 48,
  );

  static const TiqSpace veld = TiqSpace(
    density: TiqDensity.veld,
    gutter: s6,
    gutterWide: s6,
    rowMinHeight: 64,
    blockGap: s8,
    intraBlock: s5,
    tapTarget: s9,
    primaryActionHeight: 64,
    chipHeight: s9,
  );

  /// The horizontal gutter for a viewport [width] logical pixels wide.
  EdgeInsets gutterFor(double width) =>
      EdgeInsets.symmetric(horizontal: width >= 1080 ? gutterWide : gutter);
}

/// Four materials, four radii. If a designer cannot name which of the four a
/// surface is, it does not get a radius.
///
/// The 999 pill radius is gone entirely: it existed only for the active-tab
/// pill, which no longer exists.
@immutable
class TiqRadii {
  const TiqRadii({
    required this.rule,
    required this.chip,
    required this.control,
    required this.panel,
    required this.plate,
  });

  /// Rules and dividers.
  final double rule;

  /// Chips, outlined pills, ladder glyph tiles.
  final double chip;

  /// Buttons and thumbnails.
  final double control;

  /// The instrument panel, forms, sheets.
  final double panel;

  /// Photographic plates.
  final double plate;

  /// Night and Day share one radius set.
  static const TiqRadii lit = TiqRadii(
    rule: 0,
    chip: 6,
    control: 10,
    panel: 14,
    plate: 20,
  );

  /// Veld squares everything off: a radius is a soft cue, and Veld has none.
  static const TiqRadii flat = TiqRadii(
    rule: 0,
    chip: 0,
    control: 0,
    panel: 0,
    plate: 0,
  );

  /// An input is a trough — it holds at the BOTTOM.
  BorderRadius get input =>
      BorderRadius.vertical(top: Radius.zero, bottom: Radius.circular(control));

  TiqRadii lerp(TiqRadii other, double t) => TiqRadii(
    rule: lerpDouble(rule, other.rule, t)!,
    chip: lerpDouble(chip, other.chip, t)!,
    control: lerpDouble(control, other.control, t)!,
    panel: lerpDouble(panel, other.panel, t)!,
    plate: lerpDouble(plate, other.plate, t)!,
  );
}

/// Five depth levels. The rule that governs them is the DEVICE FLOOR: no
/// surface may rely on a fill step alone to be perceived, because a
/// 1.12–1.24:1 fill step is one or two quantisation levels on a 6-bit budget
/// LCD at 40% backlight.
enum TiqDepthLevel {
  /// Ground. No edge.
  l0Ground,

  /// Well — inset, no edge. It is allowed to recede; that is its job.
  l1Well,

  /// Surface + a 1px `edgeStructure` outline (3.00:1), plus a decorative lit
  /// top rim over it.
  l2Surface,

  /// Raised. Used only INSIDE an L2 that already has an edge, divided by
  /// hairlines.
  l3Raised,

  /// Emitted: any fill plus an amber gradient bloom. Reserved for the plate's
  /// strip light, the active-tab underbar and the one focus bar in a chart —
  /// never more than two L4 objects on screen.
  l4Emitted,
}

/// What each skin is allowed to cast.
@immutable
class TiqDepth {
  const TiqDepth({
    required this.shadows,
    required this.litRim,
    required this.allowsGradients,
    required this.borderWidth,
  });

  /// `sh1`, `sh2`, `sh3` — Day only. Night has none (black on black is
  /// invisible, and the audit's 34 ad-hoc BoxShadows all go). Veld has none.
  final List<BoxShadow> shadows;

  /// The decorative 1px top rim over an L2 edge. Transparent where a skin has
  /// no rim.
  final Color litRim;

  /// Whether gradient decorations (the only legal bloom) are permitted.
  /// False in Veld.
  final bool allowsGradients;

  /// Structural border width. Veld's hairlines are 2px solid.
  final double borderWidth;

  static const TiqDepth night = TiqDepth(
    shadows: <BoxShadow>[],
    litRim: Color(0x1AEEE9DF), // Palladian @ 10%
    allowsGradients: true,
    borderWidth: 1,
  );

  static const TiqDepth day = TiqDepth(
    shadows: <BoxShadow>[
      BoxShadow(
        color: Color(0x0F1B2632),
        offset: Offset(0, 1),
        blurRadius: 2,
      ), // sh1 .06
      BoxShadow(
        color: Color(0x141B2632),
        offset: Offset(0, 4),
        blurRadius: 12,
      ), // sh2 .08
      BoxShadow(
        color: Color(0x1F1B2632),
        offset: Offset(0, 12),
        blurRadius: 32,
      ), // sh3 .12
    ],
    litRim: Color(0x00000000),
    allowsGradients: true,
    borderWidth: 1,
  );

  static const TiqDepth veld = TiqDepth(
    shadows: <BoxShadow>[],
    litRim: Color(0x00000000),
    allowsGradients: false,
    borderWidth: 2,
  );

  /// sh1 — the only shadow a Day panel takes.
  BoxShadow? get sh1 => shadows.isEmpty ? null : shadows[0];
  BoxShadow? get sh2 => shadows.length < 2 ? null : shadows[1];
  BoxShadow? get sh3 => shadows.length < 3 ? null : shadows[2];
}

/// Durations and curves. One application-wide `Ticker` drives the three loops;
/// all three are disabled under `MediaQuery.disableAnimations`, battery-saver
/// and Veld.
@immutable
class TiqMotion {
  const TiqMotion({required this.enabled});

  /// False in Veld, and wherever the platform asks for reduced motion.
  final bool enabled;

  /// Press, toggle, chip select.
  static const Duration press = Duration(milliseconds: 120);

  /// Element enter (40ms stagger).
  static const Duration enter = Duration(milliseconds: 200);

  /// Plate reveal, sheet, route.
  static const Duration reveal = Duration(milliseconds: 320);

  /// Figure count-up, and the button busy loop.
  static const Duration countUp = Duration(milliseconds: 600);

  /// The skeleton's travelling rule — Oatmeal, never amber: a skeleton is
  /// loading, not live.
  static const Duration skeleton = Duration(milliseconds: 1400);

  /// The ambient live pulse. Night-only, and the one semantic amber in the
  /// system: a *breathing* amber means "happening right now".
  static const Duration livePulse = Duration(milliseconds: 3200);

  static const Curve enterCurve = Cubic(0.05, 0.70, 0.10, 1.00);
  static const Curve exitCurve = Cubic(0.30, 0.00, 0.80, 0.15);
  static const Curve stateCurve = Cubic(0.20, 0.00, 0.00, 1.00);
  static const Curve countUpCurve = Curves.easeOutQuart;

  static const TiqMotion on = TiqMotion(enabled: true);
  static const TiqMotion off = TiqMotion(enabled: false);

  /// The duration to actually use — zero when motion is off, so a caller never
  /// has to branch.
  Duration resolve(Duration d) => enabled ? d : Duration.zero;
}
