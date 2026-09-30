import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../row/soft_row.dart' show SoftRowChevron;
import 'plate_fallback.dart';
import 'plate_spec.dart';

export 'plate_fallback.dart';
export 'plate_spec.dart';

/// THE PHOTOGRAPHIC PLATE.
///
/// The place the manager is about to act on, made cinematic by one strip of
/// light — and the hero figure sitting on the darkened half of it.
///
/// Four things are load-bearing and none of them are decoration:
///
/// 1. **The picture is attributed, not a mood.** What it is, and where it came
///    from, travels with it: a figure printed over a picture has to be visibly
///    a figure with a picture beside it rather than a figure the picture
///    proves. **The Floor's plate is a view of the TERRITORY in scope** and it
///    changes when the filter changes — a townscape is plainly context, which
///    is exactly why it replaced the outlet shelf photograph that used to sit
///    here: a shelf directly above a list of shelf decisions is a picture
///    somebody can act on. The attribution used to be a printed [caption] on
///    the first line of the text-safe zone. **Owner override, 25 September
///    2026:** the reference the owner signed off has no caption line, so The
///    Floor passes it as [semanticLabel] only — and that label says the
///    picture is an illustration, because the seeded ones are generated. The
///    [caption] parameter stays for the states that still print one.
/// 2. **One strip light, allocated.** The line and its bloom are one object,
///    and whether it is lit is [TorchScope]'s answer, not this widget's. In
///    Day the claim is denied on a light ground and the light becomes a 2px
///    `ink1` rule at the same y — amber on a light-ground photograph is
///    decoration, not emitted light.
/// 3. **The fold is arithmetic.** [PlateSpec] owns it, and it fails a test
///    rather than an argument.
/// 4. **No photograph is a state, not an error.** [PlateFallback] draws a
///    shape that is obviously a drawing and says so in a sentence. Never a
///    stock image, never a gradient pretending to be a photograph.
///
/// ## The bake this widget is still waiting for
///
/// The plate is specified as a server-baked asset: a chroma reduction, a
/// luminance range, an alpha edge dissolve, and a hard 60 kB WebP cap. That
/// bake does not exist yet — see the follow-up ticket referenced on [toneFor]
/// — so this widget applies the **tone** half of it client-side: the chroma
/// reduction *and* the luminance range, composed into one `ColorFilter.matrix`
/// that rides on the image's own draw call. The alpha dissolve and the byte
/// cap stay on the server, because a client cannot fix a 900 kB download by
/// dimming it.
///
/// **The tone is per skin, and that is not a convenience.** Night maps the
/// picture into `[0, #666666]` and Day into `[#999999, #E6E6E6]`. A light
/// ground cannot use a ceiling: its ink is dark, so a darkened photograph
/// converges on the text instead of receding behind it. See
/// `TiqPalette.plateLift`.
///
/// Only the luminance half used to be applied here, and what that leaves out
/// shows the moment a shelf photograph has any saturation in it: a multiply by
/// a neutral grey scales all three channels by the same factor, so it darkens
/// a colour without ever desaturating it. Against the seeded dev data, whose
/// shelf photos are blocks of primary colour, the plate rendered as a dim
/// rainbow — faithfully, and against the design. A plate is a photographic
/// *ground*, and whatever is in the frame it has to read as one.
///
/// ## Cost
///
/// One decoded image at `cacheWidth`, drawn through `paintImage` with a colour
/// filter on its own paint — a parameter on `drawImageRect`, not a layer. Two
/// gradient decorations (the bottom-up scrim and the bloom above the light).
/// Zero `BackdropFilter`, zero `ShaderMask`, zero `ImageFiltered`, zero
/// `ColorFiltered`, zero `saveLayer`, zero `BoxShadow`.
class TiqPlate extends StatelessWidget {
  const TiqPlate({
    super.key,
    required this.claimId,
    required this.viewportHeight,
    required this.hero,
    this.image,
    this.caption,
    this.fallbackSentence,
    this.semanticLabel,
    this.topSlot,
    this.devicePixelRatio,
    this.ground = PlateSpec.floorGround,
    this.tallest = PlateSpec.floorTallest,
    this.topScrim = false,
  });

  /// The [TorchClaim.plateStripLight] id this plate's light was declared under.
  /// The widget asks; it never decides.
  ///
  /// **A claim id is not a grant.** An id the route never declared is simply
  /// never lit, which is a supported way to use this widget and not a bug:
  /// `/login` renders the plate with the light in its unlit form in *both*
  /// skins, because the door's one amber object is the way through it. See
  /// `entry_plate.dart`.
  final String claimId;

  /// The height the plate may draw into — the viewport, because the plate runs
  /// full-bleed to the top edge and suppresses the shell's falloff there.
  final double viewportHeight;

  /// What the screen needs *under* the plate, and the tallest the plate may
  /// get. Both default to The Floor's, which is where they came from — see
  /// [PlateSpec.heightFor], which is where the two literals used to live.
  final double ground;
  final double tallest;

  /// Whether the band above the strip light gets a scrim too.
  ///
  /// Off by default, and The Floor leaves it off: its [topSlot] is a
  /// [PlateScopeChip], and a chip carries its own surface, so its label is
  /// never on the picture. A caller that puts **bare type** up there turns it
  /// on — `/login`'s wordmark — and the reason it is not optional for that
  /// caller is a measurement, printed by `entry_plate_test.dart` on every
  /// run. See the note where it is drawn.
  final bool topScrim;


  /// The hero cluster. Expected to be a [PlateHeroCluster]; typed as a widget
  /// so a screen can put its own eyebrow strings and figure in without this
  /// file learning about territories.
  final Widget hero;

  /// The shelf photograph. Null renders [PlateFallback] — and so does a decode
  /// failure, without a second code path in the caller.
  final ImageProvider<Object>? image;

  /// `Kasi Corner Spaza · 17 Sep 06:40`. Required in spirit whenever [image]
  /// is non-null: an uncaptioned photograph is an assertion.
  final String? caption;

  /// Why there is no photograph. Shown with the fallback drawing.
  final String? fallbackSentence;

  /// `Gauteng North. An illustration of the area…` — or the fallback's own
  /// label, which this widget supplies itself.
  final String? semanticLabel;

  /// ONE SMALL THING, AT THE TOP OF THE PICTURE.
  ///
  /// The plate is the screen's header, so the thing that says *where you are*
  /// belongs at the top of it. Two screens put something different here and
  /// both answers are that same sentence:
  ///
  /// * **The Floor** puts a [PlateScopeChip] — the territory and the window,
  ///   and a control that changes them. "Where you are", signed in.
  /// * **`/login`** puts the wordmark. Before sign-in there is no territory to
  ///   name and no scope to change, so what the top of the picture says is
  ///   *which product* — see `entry_plate.dart`. It is not a control and it
  ///   takes no taps, which is why this parameter is named for the slot and
  ///   not for the chip that was the first thing in it.
  ///
  /// It sits in the photographic band and **not** in the hero cluster, and
  /// that is arithmetic rather than taste. The cluster is laid out inside a
  /// `FittedBox(scaleDown)`: every dp added to it is taken off the hero
  /// figure, and at the 200dp plate floor a 48dp control up there would shrink
  /// a 66dp figure to something smaller than the metric that supports it — the
  /// exact defect `floor_proportion_test.dart` exists to catch. Out here it
  /// costs the hero nothing and the fold nothing, because the band above the
  /// strip light is picture that nothing else is using.
  ///
  /// It is the last thing in the stack, so it takes its own taps rather than
  /// losing them to the scrim. On the shortest plate it overlaps the top of
  /// the strip light's bloom; it never reaches the light itself, which is the
  /// object the amber budget is spent on.
  final Widget? topSlot;

  /// Overrides the ambient DPR when choosing `cacheWidth`. Tests pin it.
  final double? devicePixelRatio;

  /// How much of a photograph's chroma survives the bake.
  ///
  /// **55% since 29 September 2026, up from 12%.** Twelve percent was the
  /// spec's number and this file was forbidden from rounding it, because at
  /// the time the alternative on the table was *no* desaturation at all and a
  /// plate that rendered as a dim rainbow. The owner has since looked at the
  /// running screen and asked for the opposite correction — the territory
  /// photographs "are made dark, give them a bit of colour and luminous
  /// towards them" — and an owner asking for colour outranks a spec number
  /// written before anyone had seen the screen. `direction-torchlight.json`
  /// carries the override, the way the soft-rows one is carried.
  ///
  /// It is still a reduction and it still has to be one: a plate is a
  /// photographic *ground*, and at 100% a red end-cap is a red block behind a
  /// number. More than half the hue survives now; none of the picture's own
  /// exposure does — that is what [TiqPalette.plateCeiling] and
  /// [TiqPalette.plateLift] are for.
  static const double chroma = 0.55;

  /// THE INTERIM, CLIENT-SIDE HALF OF THE SERVER BAKE, AS ONE FILTER — in
  /// [palette]'s skin, because the tone is not the same in both.
  ///
  /// Two operations, composed into a single 4×5 colour matrix:
  ///
  /// 1. **Chroma to [chroma]** — a saturation matrix on Rec. 709 luma
  ///    weights, so a red end-cap becomes a warm dark grey rather than a red
  ///    block, without being drained to a photocopy.
  /// 2. **The range** — every channel mapped into
  ///    `[TiqPalette.plateLift, TiqPalette.plateCeiling]`. The ceiling is the
  ///    old multiply and the lift is new: white lands exactly on the ceiling,
  ///    black lands exactly on the lift, and nothing lands outside either.
  ///
  /// The lift is what makes this per skin. On Night it is zero, so the shape
  /// is exactly the old one and only the constants differ. On Day it is 0.60,
  /// which is the whole repair: `#1B2632` ink over a picture that used to be
  /// capped at `#474747` measured 2.63–2.99:1, and a ceiling cannot fix that
  /// because the ink and the picture were failing on the *same* side.
  ///
  /// It is applied as `DecorationImage.colorFilter`, which `paintImage` hands
  /// straight to `drawImageRect`'s `Paint` — one parameter on one draw call.
  /// `ColorFiltered` would say the same thing and push a `ColorFilterLayer`,
  /// which rasterises as a `saveLayer` on every frame the plate scrolls, and
  /// the paint budget forbids it.
  ///
  /// FOLLOW-UP: the real bake (the chroma, the per-skin range, an alpha edge
  /// dissolve, ≤60 kB WebP, served from the photo endpoint) is tracked as the
  /// plate-bake ticket filed with the Torchlight plate PR. A per-skin tone
  /// makes that bake **two** bakes or one untoned original plus this filter;
  /// until it is decided, the filter stays and a baked pixel must not be
  /// toned twice.
  static ColorFilter toneFor(TiqPalette palette) => plateTone(
    ceiling: palette.plateCeiling,
    lift: palette.plateLift,
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final spec = PlateSpec.resolve(
      skin: skin,
      viewportHeight: viewportHeight,
      textScale: scaler.scale(1.0),
      ground: ground,
      tallest: tallest,
    );

    switch (spec.form) {
      case PlateForm.none:
        // No plate. The hero cluster renders on the ground, with no band
        // around it — and the scope control comes with it, because a screen
        // that can be scoped with a plate and not without one is a screen
        // that loses a capability it never advertised losing.
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spec.textInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (topSlot != null) ...<Widget>[
                topSlot!,
                const SizedBox(height: TiqSpace.s3),
              ],
              hero,
            ],
          ),
        );
      case PlateForm.collapsed:
        return _CollapsedBand(
          spec: spec,
          hero: hero,
          topSlot: topSlot,
        );
      case PlateForm.photographic:
        return _PhotographicPlate(
          spec: spec,
          claimId: claimId,
          hero: hero,
          image: image,
          caption: caption,
          fallbackSentence: fallbackSentence,
          semanticLabel: semanticLabel,
          topSlot: topSlot,
          topScrim: topScrim,
          // The tone is the skin's, not the widget's: see [toneFor].
          tone: toneFor(skin.palette),
          devicePixelRatio:
              devicePixelRatio ??
              MediaQuery.maybeDevicePixelRatioOf(context) ??
              1.0,
        );
    }
  }
}

/// THE PLATE'S TONE, as one 4×5 colour matrix. See [TiqPlate.toneFor].
///
/// `chroma` is the share of the original saturation that survives; `ceiling`
/// and `lift` are the two ends of the range the result is mapped into.
/// Exposed as a function, and pure, so the numbers can be asserted in a unit
/// test instead of eyeballed in a screenshot — the last time this treatment
/// was half-applied, nothing failed.
///
/// `ceiling` and `lift` are **required**, with no default, and that is
/// deliberate: they are per-skin tokens now, and a default would be one skin's
/// numbers silently applied to the other, which is the exact defect this
/// change exists to close.
///
/// The luma weights are Rec. 709, the same ones every greyscale conversion in
/// the display pipeline uses. The matrix operates on sRGB-encoded values, like
/// the multiply it replaces.
ColorFilter plateTone({
  double chroma = TiqPlate.chroma,
  required Color ceiling,
  required double lift,
}) => ColorFilter.matrix(
  plateToneMatrix(chroma: chroma, ceiling: ceiling, lift: lift),
);

/// The tone's twenty numbers, before they become a [ColorFilter].
///
/// Split out because `ColorFilter` does not hand its matrix back, and a
/// treatment that was half-applied for a release is exactly the thing that
/// has to be assertable arithmetic rather than a screenshot somebody looks at.
///
/// ## The arithmetic
///
/// One operation per channel, written as it is meant to be read:
///
/// ```text
///   out_i = lift + (k_i − lift) × sat_i(in)
/// ```
///
/// `sat_i` is the saturation row — each channel interpolated towards Rec. 709
/// luma, keeping [chroma] of the distance — and `k_i` is the ceiling colour's
/// channel, normalised to 0..1. So a saturated input is first flattened
/// towards grey and then mapped out of `[0, 1]` and into `[lift, k_i]`. Two
/// operations, one matrix, one draw call.
///
/// `lift = 0` collapses it to `k_i × sat_i(in)` — exactly the shape this
/// matrix had when it was only a ceiling, with a different constant. The
/// generalisation is a strict superset and Night still takes that path.
///
/// ## Why the offset is × 255
///
/// `ColorFilter.matrix` runs on **0..255** values and the fifth column is a
/// constant added in that same unnormalised space. `lift` is a 0..1 scalar, so
/// the constant is `lift × 255`. Getting this wrong is silent: at `lift = 0`
/// the term vanishes and every test still passes.
///
/// ## What it bounds
///
/// For any input, `out.max − out.min = (k − lift) × chroma × (in.max − in.min)`
/// when the ceiling is neutral — so the plate's colour cast is capped, however
/// loud the photograph. And the range itself is closed at both ends: no pixel
/// above `ceiling`, and on Day no pixel below `lift`. `floor_plate_tone_test`
/// asserts both ends, per skin.
List<double> plateToneMatrix({
  double chroma = TiqPlate.chroma,
  required Color ceiling,
  required double lift,
}) {
  const double lumaR = 0.2126;
  const double lumaG = 0.7152;
  const double lumaB = 0.0722;
  final double keep = chroma;
  final double drop = 1 - chroma;
  // The span each channel is mapped across: from `lift` up to the ceiling's
  // own channel. Folded into the saturation rows exactly as the bare ceiling
  // used to be, so this stays one matrix.
  final double sr = ceiling.r - lift;
  final double sg = ceiling.g - lift;
  final double sb = ceiling.b - lift;
  // The fifth column is added in 0..255 space, not 0..1. See above.
  final double offset = lift * 255;
  return <double>[
    sr * (lumaR * drop + keep), sr * lumaG * drop, sr * lumaB * drop, 0, offset,
    sg * lumaR * drop, sg * (lumaG * drop + keep), sg * lumaB * drop, 0, offset,
    sb * lumaR * drop, sb * lumaG * drop, sb * (lumaB * drop + keep), 0, offset,
    0, 0, 0, 1, 0,
  ];
}

/// The 96dp band that replaces the plate when the fold cannot afford one.
///
/// No image, no light, no scrim — the same hero cluster on the ground. A
/// smaller photograph would be a photograph nobody can read *and* a list
/// nobody can use.
class _CollapsedBand extends StatelessWidget {
  const _CollapsedBand({
    required this.spec,
    required this.hero,
    this.topSlot,
  });

  final PlateSpec spec;
  final Widget hero;
  final Widget? topSlot;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: spec.height),
    padding: EdgeInsets.fromLTRB(
      spec.textInset,
      TiqSpace.s4,
      spec.textInset,
      TiqSpace.s4,
    ),
    alignment: Alignment.bottomLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The picture is what the fold could not afford. The control is 48dp
        // and it stays: losing the ability to change territory on the smallest
        // screen is losing it on the screen that needs it most.
        if (topSlot != null) ...<Widget>[
          topSlot!,
          const SizedBox(height: TiqSpace.s3),
        ],
        hero,
      ],
    ),
  );
}

class _PhotographicPlate extends StatefulWidget {
  const _PhotographicPlate({
    required this.spec,
    required this.claimId,
    required this.hero,
    required this.image,
    required this.caption,
    required this.fallbackSentence,
    required this.semanticLabel,
    required this.topSlot,
    required this.topScrim,
    required this.tone,
    required this.devicePixelRatio,
  });

  final PlateSpec spec;
  final String claimId;
  final Widget hero;
  final ImageProvider<Object>? image;
  final String? caption;
  final String? fallbackSentence;
  final String? semanticLabel;
  final Widget? topSlot;
  final bool topScrim;
  final ColorFilter tone;
  final double devicePixelRatio;

  @override
  State<_PhotographicPlate> createState() => _PhotographicPlateState();
}

class _PhotographicPlateState extends State<_PhotographicPlate> {
  /// A photograph that would not decode. Held as state rather than recomputed,
  /// because the strip light must go out when it happens: a lit drawing is a
  /// decoration wearing the screen's one light, and the fallback's whole job
  /// is to be visibly not a photograph.
  bool _imageFailed = false;

  @override
  void didUpdateWidget(_PhotographicPlate old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _imageFailed = false;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final skin = context.skin;
    final hasPhotograph = widget.image != null && !_imageFailed;
    // Asking the allocator is only half of it. A grant is permission, not an
    // instruction: with no photograph there is nothing for a strip light to be
    // a strip of light ON, so the claim goes unspent and the screen renders
    // one amber object instead of two. A budget is a ceiling.
    final lit = hasPhotograph && TorchScope.lit(context, widget.claimId);
    final still = MotionBudget.of(context).still;
    final large =
        (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling).scale(
          1.0,
        ) >=
        1.6;

    return SizedBox(
      height: spec.height,
      width: double.infinity,
      // THE CARD'S CORNERS. `Clip.antiAlias` and not `antiAliasWithSaveLayer`:
      // the paint budget forbids a `saveLayer`, and a rounded-rect clip is a
      // clip on the canvas, not a layer. Everything the plate paints — the
      // photograph, the strip light, the scrim — is inside it, so the card
      // has one silhouette rather than a rounded frame with square contents.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(spec.radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. The specimen, or the drawing that admits there is none.
            Semantics(
              // NOT "generated" for the fallback, whatever it used to say.
              // "Generated" now means one specific thing in this product — an
              // image a model made — and the fallback is the opposite of that:
              // a vector drawing that exists to admit there is no picture. Two
              // different absences must not share a word.
              label: hasPhotograph
                  ? (widget.semanticLabel ?? 'Photograph')
                  : 'A drawing, in place of a picture there is none of',
              image: true,
              child: _Frame(
                image: _imageFailed ? null : widget.image,
                sentence: widget.fallbackSentence,
                tone: widget.tone,
                still: still,
                width: MediaQuery.sizeOf(context).width,
                devicePixelRatio: widget.devicePixelRatio,
                onFailed: () {
                  if (!_imageFailed && mounted) {
                    // After the frame: a decode error can arrive during build.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _imageFailed = true);
                    });
                  }
                },
              ),
            ),

            // 1b. THE SAME SCRIM AT THE TOP, WHERE A CALLER PUTS TYPE THERE.
            //
            //     Opt-in, and off for The Floor, whose top slot is a chip
            //     with its own surface. `/login` puts a **wordmark** up here,
            //     which is the first bare type this component has carried on
            //     the unscrimmed band, and the answer is measured rather than
            //     argued — `entry_plate_test.dart` prints all four numbers:
            //
            //     |  | with | without |
            //     |---|---|---|
            //     | **Night** | 6.41:1 | **3.60:1** |
            //     | **Day**   | 7.32:1 | 6.88:1 |
            //
            //     **Night is the one that needs it**, which is the opposite
            //     of the way round it looks. Day's tone lifts the picture to
            //     a `#999999` floor and the mark sits over pale sky, so it
            //     clears on its own; Night's CEILING is `#666666` and the
            //     same sky is the *brightest* thing in the frame, so it sits
            //     at the ceiling — and `ink2` (`#C9C1B1`) against `#5C5F61`
            //     is 3.60:1. The half of the tone that saves the foot of the
            //     plate is the half that hurts the top of it.
            //
            //     **It runs to the strip light and is drawn UNDER it.** The
            //     band above the light is picture nothing else is using, so
            //     the falloff has all of it rather than a hard edge below the
            //     type — a scrim that stopped at the mark would be a smudge
            //     behind a wordmark. Under the light, because the light and
            //     its bloom are the brightest object on the plate and a scrim
            //     over them would dim the one thing amber was spent on.
            if (widget.topScrim && spec.stripLightY > 0)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: spec.stripLightY,
                child: const _Scrim(fromTop: true),
              ),

            // 2. The strip light: one object, line plus bloom, allocated.
            _StripLight(spec: spec, lit: lit, still: still),

            // 3. The text-safe zone. A bottom-up scrim is what makes the ink on
            //    a photograph a measured pairing rather than a gamble.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: spec.textZoneHeight,
              child: const _Scrim(),
            ),

            // 4. The caption, and the hero cluster under it — both at the foot.
            //
            //    The zone is a hard box that stops just under the strip light,
            //    so the caption can never climb over it — which it did, at the
            //    200dp floor, when the zone was the declared 58% and the cluster
            //    needed more. The light is the boundary between picture and
            //    text, and it is drawn as one.
            //
            //    ## The caption is a line above the figure, not a lid on the zone
            //
            //    This used to be `spaceBetween` with a `Flexible` on each child,
            //    which reads like "caption at the top, hero at the foot" and is
            //    not what a Column does: two flex-1 children with nothing
            //    inflexible between them take **half the zone each**. So a
            //    17dp caption was handed 44dp on a 360×640 phone and the hero
            //    cluster — which needs about 129 — was handed the other 44, and
            //    the FittedBox below crushed a 56pt figure to 19dp. The screen's
            //    hero rendered smaller than the supporting metric under it, and
            //    the caption floated in the middle of the plate with a hole
            //    beneath it. Both of those are exactly what the owner reported.
            //
            //    The caption is sized by its own content and sits [captionGap]
            //    above the cluster; everything left over is the hero's. One line
            //    at every scale now, because the zone does not grow with the
            //    type and provenance is meta where the figure is the screen.
            Positioned(
              left: spec.textInset,
              right: spec.textInset,
              bottom: TiqSpace.s4,
              top: spec.textZoneTop,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // The provenance caption, or the fallback's sentence in its
                  // place. Either way the reader is told what they are looking
                  // at — an uncaptioned band is the one state this component may
                  // not have.
                  if (hasPhotograph && widget.caption != null) ...<Widget>[
                    Text(
                      widget.caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: skin.text.meta.style(color: skin.palette.ink3),
                    ),
                    SizedBox(height: spec.captionGap),
                  ] else if (!hasPhotograph &&
                      widget.fallbackSentence != null) ...<Widget>[
                    // The fallback has no photograph to be a caption ON, so it
                    // is allowed the lines a sentence needs.
                    Flexible(
                      child: Text(
                        widget.fallbackSentence!,
                        maxLines: large ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: skin.text.meta.style(color: skin.palette.ink3),
                      ),
                    ),
                    SizedBox(height: spec.captionGap),
                  ],
                  // `hero.figure` caps at 1.6x, then steps to the 56 compact
                  // face, and then — only then — scales down. That ladder is the
                  // spec's own, and this is its last rung: the FittedBox is not
                  // a shortcut past the measured fitting in `FigureSlot`, it is
                  // that fitting's documented floor. It wraps the whole cluster
                  // so the eyebrow, the figure and the delta keep their sizes
                  // relative to one another instead of drifting apart.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: widget.hero,
                    ),
                  ),
                ],
              ),
            ),

            // 5. THE SCOPE CONTROL, LAST, so the taps are its own.
            //
            //    Top-left of the band, on the gutter the text zone hangs off,
            //    so the control, the hero and the decision cards below all
            //    line up on one left edge. `right` is bound as well as `left`
            //    — at 2.0x in Afrikaans the label wraps inside the plate
            //    instead of running off the card.
            if (widget.topSlot != null)
              Positioned(
                left: spec.textInset,
                right: spec.textInset,
                top: TiqSpace.s4,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: widget.topSlot!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The image, or the fallback drawing plus its sentence.
///
/// It resolves the provider itself rather than handing it to an `Image`, and
/// the reason is the tone. `Image` owns exactly one colour-filter slot and it
/// is a `ColorFilter.mode` built from `color` + `colorBlendMode` — enough for
/// the ceiling multiply, and structurally incapable of a saturation matrix.
/// `DecorationImage` takes an arbitrary `ColorFilter` and `paintImage` puts it
/// on the `Paint` of a single `drawImageRect`, which is the one way to get
/// [TiqPlate.toneFor] onto the plate without a `ColorFilteredLayer` and the
/// `saveLayer` it rasterises to.
///
/// What `Image` was giving us and this has to keep giving: the decode cap, the
/// fallback on a decode failure, and the reveal. The stream listener is what
/// replaces `frameBuilder`'s `frame == null` — it adds no second decode,
/// because a provider resolves through the image cache and both listeners land
/// on the same completer.
class _Frame extends StatefulWidget {
  const _Frame({
    required this.image,
    required this.sentence,
    required this.tone,
    required this.still,
    required this.width,
    required this.devicePixelRatio,
    required this.onFailed,
  });

  final ImageProvider<Object>? image;
  final String? sentence;
  final VoidCallback onFailed;
  final ColorFilter tone;
  final bool still;
  final double width;
  final double devicePixelRatio;

  @override
  State<_Frame> createState() => _FrameState();
}

class _FrameState extends State<_Frame> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// Whether the photograph is on screen yet, and whether it got there in the
  /// same frame it was asked for (a cache hit, or a test's synchronous
  /// provider). A picture that was already there does not "arrive".
  bool _arrived = false;
  bool _instant = false;

  /// The plate is never wider than the phone and never needs more than its own
  /// pixels. Decoding a 4000px capture to draw it at 360dp is how a 2 GB
  /// device runs out of memory on a dashboard.
  int get _cacheWidth =>
      (widget.width * widget.devicePixelRatio).round().clamp(1, 1440);

  ImageProvider<Object>? get _provider {
    final image = widget.image;
    if (image == null) return null;
    return ResizeImage(image, width: _cacheWidth, allowUpscaling: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_Frame old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image ||
        old.width != widget.width ||
        old.devicePixelRatio != widget.devicePixelRatio) {
      _arrived = false;
      _instant = false;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    final provider = _provider;
    if (provider == null) {
      _detach();
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (_stream != null && stream.key == _stream!.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener(_onImage, onError: _onError);
    stream.addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    // This listener only wants to know that a frame exists; the painting is
    // the decoration's. The handle it was given is its own and has to go back.
    info.dispose();
    if (_arrived) return;
    _arrived = true;
    _instant = synchronousCall;
    // A synchronous call happens inside `addListener`, which runs from
    // `didChangeDependencies` — the build that follows already sees the flag,
    // and calling setState from there is the one way to make this throw.
    if (!synchronousCall && mounted) setState(() {});
  }

  void _onError(Object error, StackTrace? stack) => widget.onFailed();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final provider = _provider;
    if (provider == null) return const _FallbackFrame();

    Widget drawn = DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: provider,
          fit: BoxFit.cover,
          // THE TONE: the chroma reduction and the skin's own luminance
          // range, as one filter on the image's own paint. See
          // [TiqPlate.toneFor].
          colorFilter: widget.tone,
          // A photograph that will not decode is the same state as no
          // photograph: the drawing and the sentence, never a broken-image
          // glyph and never an empty black band that reads as a fault.
          onError: (error, stack) => widget.onFailed(),
        ),
      ),
      child: const SizedBox.expand(),
    );

    if (!_instant && !widget.still) {
      // The reveal: opacity plus a 1.02 -> 1.00 scale, on the image only. The
      // figure does not count up and the light does not fade in from nowhere —
      // only the photograph arrives.
      drawn = AnimatedOpacity(
        opacity: _arrived ? 1 : 0,
        duration: TiqMotion.reveal,
        curve: TiqMotion.enterCurve,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.02, end: 1.0),
          duration: TiqMotion.reveal,
          curve: TiqMotion.enterCurve,
          builder: (context, scale, inner) =>
              Transform.scale(scale: scale, child: inner),
          child: drawn,
        ),
      );
    }

    return ColoredBox(color: skin.palette.well, child: drawn);
  }
}

class _FallbackFrame extends StatelessWidget {
  const _FallbackFrame();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.skin.palette.ground,
    child: const PlateFallback(),
  );
}

/// The one strip light: a 2px line and the 48dp gradient above it, counted as
/// a single object because that is what it looks like.
class _StripLight extends StatelessWidget {
  const _StripLight({
    required this.spec,
    required this.lit,
    required this.still,
  });

  final PlateSpec spec;
  final bool lit;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // Unlit is not "off": in Day the plate keeps its image and the light
    // becomes a 2px ink-1 rule at the same y. A band with nothing at 0.38h
    // would read as a different component.
    final line = lit
        ? skin
              .palette
              .flame600 // torchlight-ignore: the plate's strip light, granted by TorchScope
        : skin.palette.ink1;

    return Positioned(
      left: 0,
      right: 0,
      top: spec.stripLightY - spec.bloomHeight,
      height: spec.bloomHeight + 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        // Stretch, not the default centre: a `SizedBox(height: 2)` under loose
        // cross-axis constraints is two pixels tall and ZERO wide, which is a
        // strip light that paints nothing and a budget test that passes for
        // the wrong reason.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: lit && skin.depth.allowsGradients
                ? DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        // A gradient is the blur of a line, at zero cost.
                        colors: TiqPalette
                            .glowAmber, // torchlight-ignore: the bloom is the light, one object
                      ),
                    ),
                    child: const SizedBox.expand(),
                  )
                : const SizedBox.expand(),
          ),
          SizedBox(height: 2, child: ColoredBox(color: line)),
        ],
      ),
    );
  }
}

/// The scrim that makes a text zone safe.
///
/// `ground` at 0% rising to 80%. Over the worst pixel a baked plate may carry
/// this puts `ink1` at 7.68:1; over an unbaked one the client-side ceiling in
/// [TiqPlate] holds the same floor.
///
/// [fromTop] flips it for the band above the strip light — the same gradient
/// run the other way, so the strongest end is against the edge the type hangs
/// off in both cases. One gradient decoration either way; the cost note above
/// is unchanged. See [TiqPlate.topScrim] for when it is asked for and why.
class _Scrim extends StatelessWidget {
  const _Scrim({this.fromTop = false});

  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    final ground = context.skin.palette.ground;
    final clear = ground.withValues(alpha: 0);
    final solid = ground.withValues(alpha: 0.80);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fromTop ? <Color>[solid, clear] : <Color>[clear, solid],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// The cluster at the plate's bottom-left: what territory, what the number is,
/// which way it moved, and one tappable line into the decomposition.
///
/// It is a separate semantics node read *before* the image, because a manager
/// wants the figure, not a description of a photograph.
class PlateHeroCluster extends StatelessWidget {
  const PlateHeroCluster({
    super.key,
    required this.figure,
    this.eyebrow,
    this.delta,
    this.healthLine,
    this.onHealthTap,
    this.healthTrailing,
    this.semanticsLabel,
  });

  /// `GAUTENG NORTH · LAST 30 DAYS`, uppercased for display by the eyebrow
  /// role — or null, which is what The Floor passes.
  ///
  /// **THE EYEBROW WAS THE SCOPE CONTROL, AND IT IS NOT ANY MORE.** The line
  /// printed the territory and the window and opened the scope sheet, because
  /// the owner's reference has no filter chrome; the owner then met the
  /// running screen and said they would not have found it. The control is now
  /// [PlateScopeChip], at the top of the plate, and it prints the same two
  /// facts — so an eyebrow here would be the territory named twice on one
  /// card. It is dropped rather than kept as a label, and the hero has that
  /// line's height back, which is worth most on the 360x640 phone where the
  /// plate is already at its 200dp floor.
  final String? eyebrow;

  /// The hero figure — a `FigureSlot` at `hero.figure`, fitted by the caller.
  final Widget figure;

  /// The delta, on the figure's baseline. **Severity-coloured, never amber**:
  /// a delta is a verdict and a verdict leaves the amber band entirely.
  final Widget? delta;

  /// `Territory health` — the one tappable line, folding the lead indicator in
  /// rather than repeating it as a rail 84dp below.
  final Widget? healthLine;

  final VoidCallback? onHealthTap;

  /// One thing at the trailing end of the **health line** — The Floor's way
  /// back to all territories when one is chosen.
  ///
  /// It goes here and not beside the eyebrow because the health line is
  /// already a [space.tapTarget]-tall row with nothing in its trailing half,
  /// and the cluster above it is inside the plate's `FittedBox`: a second
  /// 48dp row up there would make the whole cluster overflow the text zone
  /// and the hero would render *smaller*, which is the defect
  /// `floor_proportion_test.dart` exists to catch.
  final Widget? healthTrailing;

  final String? semanticsLabel;

  /// Whether the delta drops under the figure instead of standing beside it.
  /// 1.6× is `hero.figure`'s own cap — above it the figure has stopped
  /// growing and everything beside it has not.
  static bool _stacks(BuildContext context) =>
      (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling).scale(
        1.0,
      ) >=
      1.6;

  @override
  Widget build(BuildContext context) {
    final cluster = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow != null) ...<Widget>[
          _Eyebrow(text: eyebrow!),
          const SizedBox(height: TiqSpace.s2),
        ],
        // THE FIGURE AND ITS DELTA SHARE A BASELINE — the pairing is the
        // point of a hero: a number, and whether it is moving.
        //
        // A `Row` with `CrossAxisAlignment.baseline` under 1.6×, so the
        // delta sits on the digits' own baseline rather than on the bottom of
        // the figure's line box, which is a descender lower and reads as a
        // second line. At 1.6× and above it is a `Wrap`, so the delta falls
        // *under* the figure rather than squeezing it — that was the whole
        // reason the Wrap was here, and it is still right at the top of the
        // scale.
        if (_stacks(context))
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: TiqSpace.s3,
            runSpacing: TiqSpace.s1,
            children: <Widget>[figure, ?delta],
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(child: figure),
              if (delta != null) ...<Widget>[
                const SizedBox(width: TiqSpace.s3),
                Flexible(child: delta!),
              ],
            ],
          ),
        if (healthLine != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Row(
            // MIN, AND NO `Flexible`. The cluster is laid out unbounded
            // inside the plate's `FittedBox`, and a flex child under an
            // unbounded main axis is a `RenderFlex` assertion, not a layout.
            // Both children size to their content and the `FittedBox` is what
            // brings the whole cluster back inside the plate.
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (onHealthTap == null)
                healthLine!
              else
                _HealthTarget(onTap: onHealthTap!, child: healthLine!),
              // A sibling and not a child: a button inside another button's
              // gesture region is the defect the section rule was repaired
              // for, in a third place.
              if (healthTrailing != null) ...<Widget>[
                const SizedBox(width: TiqSpace.s3),
                healthTrailing!,
              ],
            ],
          ),
        ],
      ],
    );

    if (semanticsLabel == null) return cluster;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: onHealthTap == null,
      child: cluster,
    );
  }
}

/// The eyebrow line — two lines of `eyebrow` ink-2, ellipsised at the end.
///
/// It was briefly a control wearing a label's clothes, with a transparent 48dp
/// target stacked over the cluster so the words cost the hero nothing. That
/// control is visible now and lives at the top of the plate
/// ([PlateScopeChip]), so this is a label again — which is what the reference
/// always showed it as.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      text.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: skin.text.eyebrow.style(color: skin.palette.ink2),
    );
  }
}

/// The tappable line. A 44dp box around a one-line target, because the line is
/// the affordance and the image deliberately is not.
class _HealthTarget extends StatelessWidget {
  const _HealthTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.skin.space.tapTarget),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    ),
  );
}

/// THE SCOPE CONTROL — where you are, and one tap to be somewhere else.
///
/// ```text
///   ╭──────────────────────────────────╮
///   │  Gauteng North · Last 30 days  ›  │
///   ╰──────────────────────────────────╯
/// ```
///
/// ## Why it is visible, after being deliberately invisible
///
/// The Floor's scope control shipped as the plate's eyebrow: the line reading
/// `GAUTENG NORTH · WEEK 38` was a button wearing a label's clothes, because
/// the owner's reference image has no filter chrome on it. That was the honest
/// reading of the reference and the wrong thing for a person meeting the app —
/// *"I wouldn't see it if I'm new on the app"* — so the words became a control
/// that looks like one. **Owner override, 28 September 2026**; unify §1.3 and
/// §1.17 carry the note.
///
/// It is still **one** control and not a toolbar. The window and the territory
/// are the two facts it sets and the two facts it prints, so nothing is said
/// twice: the eyebrow line the cluster used to carry is gone, and the hero has
/// its height back.
///
/// ## The grammar is the filter chip's
///
/// Radius `chip`, a 1px `edgeControl` edge, the `label` role, the press
/// treatment every control in this app uses, and **never amber** — a filter is
/// a control and a control is not a light (unify §1.6). Two deliberate
/// departures from `TorchFilterChip`, both because this chip stands on a
/// picture rather than on the ground:
///
/// * **It always has a `surface` fill.** An unselected rail chip is
///   transparent, which over a picture is a label nobody can read.
/// * **Filtered is an `ink1` edge and a heavier name, not a tick.** A tick
///   means "chosen from these options" in a rail of several. There is one chip
///   here, and what it has to say is whether the screen is narrowed.
///
/// The target is `space.tapTarget` tall in every density — the chip's own 44dp
/// Console height would be a control smaller in the console than the rule
/// requires.
class PlateScopeChip extends StatelessWidget {
  const PlateScopeChip({
    super.key,
    required this.scope,
    required this.window,
    required this.onTap,
    required this.semanticsLabel,
    this.filtered = false,
  });

  /// `All territories`, or the territory's name. Sentence case: this is a chip,
  /// and every other chip in the app is in sentence case. The uppercase came
  /// from the eyebrow role, which is not what this is any more.
  final String scope;

  /// `Last 30 days`. The window the figures under it were measured over.
  final String window;

  final VoidCallback onTap;

  /// Names the current scope AND says what pressing does. Required, not
  /// optional: the printed line is two facts joined by a separator, which a
  /// screen reader spells as a caption, and a control heard as a caption is a
  /// control that is not there.
  final String semanticsLabel;

  /// Whether a territory is chosen. Changes the edge and the weight, never the
  /// hue.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final radius = BorderRadius.circular(skin.radii.chip);

    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        borderRadius: radius,
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: skin.space.tapTarget),
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : p.surface,
            borderRadius: radius,
            border: Border.all(
              color: filtered ? p.ink1 : p.edgeControl,
              width: skin.depth.borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TiqSpace.s3,
            vertical: TiqSpace.s2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: scope,
                        style: skin.text.label
                            .copyWith(
                              weight: filtered
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            )
                            .style(color: p.ink1),
                      ),
                      TextSpan(
                        // The window is the quieter half: it is usually the
                        // default, and the territory is what a manager changes.
                        text: ' · $window',
                        style: skin.text.label.style(color: p.ink2),
                      ),
                    ],
                  ),
                  // Never ellipsised, like a filter chip's label: a scope you
                  // cannot read is a scope you cannot trust. At 2.0x it wraps
                  // and the chip grows.
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: TiqSpace.s2),
              SoftRowChevron(color: p.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
