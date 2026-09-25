import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// What a plate does when the fold does not leave it room.
enum PlateForm {
  /// The full photographic band: image, strip light, scrim, hero cluster.
  photographic,

  /// Under 200dp of available height the plate does not render at all and a
  /// 96dp hero band takes its place — no image, no light, no scrim. The old
  /// "0.44 of the fold" left 22dp of list on a 360×640 A04, which is not a
  /// list.
  collapsed,

  /// Veld draws no plate. Not a smaller one, not a flat one: none. Outdoors a
  /// crushed photograph under glare is a grey rectangle, and the hero cluster
  /// on white says the same thing at 15:1.
  none,
}

/// Every number a plate paints, resolved once from the viewport and the skin.
///
/// Split from the widget for the reason [SoftRowSpec] is: the fold budget is
/// arithmetic, arithmetic deserves a unit test rather than a screenshot, and a
/// screen that needs to know how much list is left below the plate can ask.
@immutable
class PlateSpec {
  const PlateSpec({
    required this.form,
    required this.height,
    required this.stripLightY,
    required this.bloomHeight,
    required this.scrimFraction,
    required this.textZoneTop,
    required this.figureRole,
    required this.textInset,
    required this.captionGap,
    required this.radius,
  });

  /// The fold budget, as one expression.
  ///
  /// `min(clamp(0.40 × vh, 200, 312), vh − 440)`. The second term is the one
  /// that matters: 440dp is what the rest of the screen needs to keep its
  /// promise of the decision rows, and a plate that takes more of the fold
  /// than that has stopped arguing with the list and started replacing it.
  ///
  /// **The proportion moved from 0.44/360 to 0.40/312 on 25 September 2026.**
  /// The plate became an inset card on that date (the owner's reference), and
  /// a card also spends the shell's top inset and a gap beneath itself, so
  /// the same fraction bought a bigger object. On a 390×844 phone the old
  /// numbers left room for two decision rows above the nav; the owner's
  /// reference shows three. 312 is what is left once three decision cards,
  /// the lead card, the section marker, the block gaps and the nav pill have
  /// taken theirs on an 844dp phone — measured in Onest, not guessed, by
  /// `floor_proportion_test.dart`, which fails if it stops being true.
  ///
  /// [viewportHeight] is the height the plate may draw into — the full
  /// viewport on a phone, because the arithmetic below it is the whole
  /// screen's.
  static double heightFor(double viewportHeight) {
    final proportional = (viewportHeight * 0.40).clamp(200.0, 312.0);
    final afterTheList = viewportHeight - 440.0;
    return math.min(proportional, afterTheList);
  }

  /// Resolve. Pure and synchronous: callable from a test with a bare
  /// [TiqSkin] and a number.
  factory PlateSpec.resolve({
    required TiqSkin skin,
    required double viewportHeight,
    double textScale = 1.0,
  }) {
    if (skin.density == TiqDensity.veld) {
      return PlateSpec(
        form: PlateForm.none,
        height: 0,
        stripLightY: 0,
        bloomHeight: 0,
        scrimFraction: 0,
        textZoneTop: 0,
        figureRole: skin.text.heroFigure,
        textInset: skin.space.gutter,
        captionGap: TiqSpace.s2,
        radius: skin.radii.plate,
      );
    }

    final height = heightFor(viewportHeight);
    if (height < _floor) {
      return PlateSpec(
        form: PlateForm.collapsed,
        height: _collapsedHeight,
        stripLightY: 0,
        bloomHeight: 0,
        scrimFraction: 0,
        textZoneTop: 0,
        // A 96dp band has no room for 72px of figure whatever the fold says.
        figureRole: skin.text.heroFigureCompact,
        textInset: skin.space.gutter,
        captionGap: TiqSpace.s2,
        radius: skin.radii.rule,
      );
    }

    // y = 0.38h, clamped out of the lower 40%. The clamp is a guard rather
    // than a rule that bites at any sane height: a light low in the frame
    // would sit behind the hero figure, and a light behind a number is a
    // backlight, which is the one thing a strip light must not look like.
    final stripLightY = math.min(height * 0.38, height * 0.60);

    return PlateSpec(
      form: PlateForm.photographic,
      height: height,
      stripLightY: stripLightY,
      bloomHeight: math.min(_bloom, stripLightY),
      // The text-safe zone. 52% normally, 58% when the plate is short, because
      // the cluster's own height does not shrink with the plate and a scrim
      // that ends above the eyebrow is a scrim that has stopped working.
      scrimFraction: height < 240 ? 0.58 : 0.52,
      // The zone is the declared fraction, and it is a HARD box rather than a
      // floor. That is what keeps the provenance caption off the strip light:
      // when the cluster wants more room than the zone has — which it does at
      // the 200dp floor — the answer is the hero's own fitting ladder
      // (72 -> 56 -> scale down), not a scrim that quietly grows to swallow
      // more of the photograph.
      textZoneTop: height * (height < 240 ? 0.42 : 0.48),
      // `hero.figure` is 72/700 and caps at 1.6× — the one documented
      // exception to the app's 2.0 clamp. Under 260dp of plate it steps to the
      // 56 compact face before the fitting in `FigureSlot` ever runs.
      figureRole: height < 260
          ? skin.text.heroFigureCompact
          : skin.text.heroFigure,
      textInset: skin.space.gutter,
      captionGap: TiqSpace.s2,
      // THE PLATE IS A CARD (owner override, 25 September 2026). It used to
      // run full-bleed to the top edge at radius 0; the reference the owner
      // signed off insets it and rounds it hard, and the radius is the same
      // number the rest of the screen's cards are cut from, one step up.
      radius: skin.radii.plate,
    );
  }

  /// Under this the plate does not render.
  static const double _floor = 200;

  /// The band that replaces it.
  static const double _collapsedHeight = 96;

  /// The gradient above the strip light. A gradient is the blur of a line, at
  /// zero cost — `BackdropFilter` and `ImageFiltered` are both banned and
  /// neither would look better.
  static const double _bloom = 48;

  final PlateForm form;

  /// Zero for [PlateForm.none].
  final double height;

  /// From the top of the plate.
  final double stripLightY;

  final double bloomHeight;

  /// How much of the plate the bottom-up scrim covers, as a fraction of
  /// [height]. Kept as the declared value; [textZoneTop] is what is drawn.
  final double scrimFraction;

  /// Where the text-safe zone begins, measured from the top of the plate. The
  /// scrim starts here and the provenance caption sits on its first line.
  final double textZoneTop;

  /// The height of the text-safe zone.
  double get textZoneHeight => height - textZoneTop;

  /// Which hero face the figure is set in before [FigureSlot] measures it.
  final TiqTypeToken figureRole;

  /// Where the hero cluster's text starts. The screen's one gutter line.
  final double textInset;

  /// Between the provenance caption and the eyebrow below it.
  final double captionGap;

  final double radius;

  /// Whether an image is drawn at all.
  bool get drawsImage => form == PlateForm.photographic;

  /// Whether the strip light may be drawn — before [TorchScope] is asked
  /// whether it is *lit*, which is a different question with a different
  /// answer in Day.
  bool get drawsStripLight => form == PlateForm.photographic;

  /// How much vertical room is left under the plate, for the fold-budget test
  /// that has to fail rather than be argued about.
  double listRoom(double viewportHeight) =>
      viewportHeight - (form == PlateForm.none ? 0 : height);

  /// The golden's line. Declared values, so a diff names the number that
  /// moved.
  String describe() => <String>[
    'form=${form.name}',
    'height=${height.toStringAsFixed(1)}',
    'stripLightY=${stripLightY.toStringAsFixed(1)}',
    'bloom=${bloomHeight.toStringAsFixed(1)}',
    'scrim=${(scrimFraction * 100).toStringAsFixed(0)}%',
    'zoneTop=${textZoneTop.toStringAsFixed(1)}',
    'figure=${figureRole.name}',
    'inset=${textInset.toStringAsFixed(1)}',
  ].join('  ');
}
