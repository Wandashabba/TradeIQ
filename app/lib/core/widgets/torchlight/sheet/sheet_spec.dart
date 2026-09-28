import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// Every number and colour the modal container paints, resolved once.
///
/// Split out for the same three reasons [SoftRowSpec] is: it is what the text
/// golden snapshots, it is what a screen reads when it needs to align
/// something to a sheet's own insets, and it is a pure function so the
/// geometry can be argued about in a unit test rather than in a screenshot.
@immutable
class TorchSheetSpec {
  const TorchSheetSpec({
    required this.scrim,
    required this.fill,
    required this.outline,
    required this.outlineWidth,
    required this.radius,
    required this.maxHeightFraction,
    required this.horizontalPadding,
    required this.grabberColour,
    required this.grabberWidth,
    required this.grabberHeight,
    required this.grabberTopInset,
    required this.belowGrabber,
    required this.bottomPadding,
    required this.titleStyle,
    required this.titleInk,
    required this.bodyStyle,
    required this.bodyInk,
  });

  /// THE GRABBER, AS A DECLARED HEX.
  ///
  /// `#616465` — not "ink-1 at 38%". Opacity is banned as a state channel and
  /// as a colour channel with it (unify §4): a composited value is a value
  /// somebody should be able to look at, measure and argue with, and a grabber
  /// that is ink-1 at 38% over `surface` in Night is a *different* grey in Day
  /// and a *different one again* over a sheet that happens to sit on the
  /// ground. This is one grey, in all three skins, and it measures 3.09:1 on
  /// the Night sheet fill and 4.11:1 on the Day one.
  ///
  /// It is also not the affordance. The sheet is dismissed by the scrim, by
  /// the back gesture and — where it matters — by a real Close control. The
  /// grabber is the *sign* that those work.
  static const Color grabber = Color(0xFF616465);

  /// 88% of the viewport, and the one number that is a fraction rather than a
  /// height: a sheet taller than this stops reading as a sheet and starts
  /// reading as a route that forgot its header.
  static const double maxHeightFractionValue = 0.88;

  factory TorchSheetSpec.resolve({
    required TiqSkin skin,
    double bottomSafeArea = 0,
  }) {
    final p = skin.palette;
    return TorchSheetSpec(
      scrim: p.scrim,
      // THE SHEET IS THE GROUND ITS CONTENT STANDS ON — 26 September 2026.
      //
      // It was `surface`, and a list row's card fill is `surface` too, so
      // every card in every sheet in the product was **invisible**: the
      // manager's menu rendered as nine lines of text in a rectangle, which
      // is what the owner was looking at when they said "the menu still has
      // the rectangular shapes". A card is identified by its silhouette
      // (unify §1.3's own answer to the device-floor objection), and a
      // silhouette needs something behind it.
      //
      // `ground` is what The Floor's cards sit on, at the same 1.49:1 step, so
      // a list in a sheet now reads exactly as the same list on a screen —
      // which is the whole point of one grammar.
      //
      // The grabber's declared #616465 was measured at 3.09:1 on the Night
      // sheet fill and 4.11:1 on the Day one; against `ground` it is higher in
      // Night (a lighter grey on a darker block) and 4.5:1 in Day. The title
      // and body inks are ink-1 and ink-2, which are specified against the
      // ground to begin with.
      fill: p.ground,
      outline: p.edgeStructure,
      outlineWidth: skin.depth.borderWidth,
      // AND ITS CORNERS ARE THE PLATE'S. At `panel` (14) the sheet was squarer
      // than the radius-22 cards inside it — the container harder than its
      // contents, which is the wrong way round and the other half of what
      // reads as "rectangular". The plate's 28 is the product's softest
      // radius and the sheet is its largest object while it is up.
      radius: BorderRadius.vertical(top: Radius.circular(skin.radii.plate)),
      maxHeightFraction: maxHeightFractionValue,
      horizontalPadding: skin.space.gutter,
      grabberColour: grabber,
      grabberWidth: 40,
      grabberHeight: 4,
      grabberTopInset: TiqSpace.s3,
      belowGrabber: TiqSpace.s4,
      // 24 plus the safe area, because a sheet's last action must not sit
      // under a home indicator.
      bottomPadding: TiqSpace.s6 + bottomSafeArea,
      titleStyle: skin.text.titleL,
      titleInk: p.ink1,
      bodyStyle: skin.text.body,
      bodyInk: p.ink2,
    );
  }

  /// 72% of the skin's ground. Not 88%: #380 requires held work to stay
  /// **visible** behind the session-ended sheet, and the assistant's real
  /// finding — that a sheet should own the screen — is honoured by
  /// extinguishing every amber beneath it instead of by hiding the screen.
  final Color scrim;

  final Color fill;
  final Color outline;
  final double outlineWidth;

  /// Top corners only. A sheet's bottom corners are off-screen, and rounding
  /// them is a radius nobody sees paid for with a clip.
  final BorderRadius radius;

  final double maxHeightFraction;
  final double horizontalPadding;

  final Color grabberColour;
  final double grabberWidth;
  final double grabberHeight;
  final double grabberTopInset;

  /// 16 below the grabber, per the ruling.
  final double belowGrabber;

  final double bottomPadding;

  final TiqTypeToken titleStyle;
  final Color titleInk;
  final TiqTypeToken bodyStyle;
  final Color bodyInk;

  /// The sheet's ceiling for a viewport [height] logical pixels tall.
  double maxHeightFor(double height) => height * maxHeightFraction;

  /// The golden's line. Ordered and labelled, so a diff names the value that
  /// moved rather than showing two blobs of hex.
  String describe() {
    String hex(Color? c) => c == null
        ? '—'
        : '#${(c.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return <String>[
      'scrim=${hex(scrim)}',
      'fill=${hex(fill)}',
      'outline=${hex(outline)}@${outlineWidth.toStringAsFixed(1)}',
      'radiusTop=${radius.topLeft.x.toStringAsFixed(1)}',
      'maxHeight=${maxHeightFraction.toStringAsFixed(2)}',
      'padX=${horizontalPadding.toStringAsFixed(1)}',
      'grabber=${hex(grabberColour)}'
          '@${grabberWidth.toStringAsFixed(0)}x${grabberHeight.toStringAsFixed(0)}',
      'belowGrabber=${belowGrabber.toStringAsFixed(1)}',
      'padBottom=${bottomPadding.toStringAsFixed(1)}',
      'title=${titleStyle.name}',
      'body=${bodyStyle.name}',
    ].join('  ');
  }
}
