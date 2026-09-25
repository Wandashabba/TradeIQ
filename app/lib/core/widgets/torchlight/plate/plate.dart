import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'plate_fallback.dart';
import 'plate_spec.dart';

export 'plate_fallback.dart';
export 'plate_spec.dart';

/// THE PHOTOGRAPHIC PLATE.
///
/// A real shelf from the territory the manager is about to act on, made
/// cinematic by one strip of light — and the hero figure sitting on the
/// darkened half of it.
///
/// Four things are load-bearing and none of them are decoration:
///
/// 1. **The photograph is a specimen, not a mood.** It carries a provenance
///    caption at the top of the text-safe zone naming the outlet and the
///    capture time, so a figure printed over a picture of one named store is
///    visibly a figure about the territory with a specimen beside it. Without
///    the caption the plate is a lie told in the product's own voice.
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
/// The plate is specified as a server-baked asset: 12% chroma, no pixel above
/// `TiqPalette.plateCeiling` (#474747), an alpha edge dissolve, and a hard
/// 60 kB WebP cap. That bake does not exist yet — see the follow-up ticket
/// referenced on [tone] — so this widget applies the **tone** half of it
/// client-side: the chroma reduction *and* the luminance ceiling, composed
/// into one `ColorFilter.matrix` that rides on the image's own draw call. The
/// alpha dissolve and the byte cap stay on the server, because a client cannot
/// fix a 900 kB download by dimming it.
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
    this.devicePixelRatio,
  });

  /// The [TorchClaim.plateStripLight] id this plate's light was declared under.
  /// The widget asks; it never decides.
  final String claimId;

  /// The height the plate may draw into — the viewport, because the plate runs
  /// full-bleed to the top edge and suppresses the shell's falloff there.
  final double viewportHeight;

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

  /// `Kasi Corner Spaza, 17 September 06:40` — or "Generated shelf
  /// illustration" for the fallback, which this widget supplies itself.
  final String? semanticLabel;

  /// Overrides the ambient DPR when choosing `cacheWidth`. Tests pin it.
  final double? devicePixelRatio;

  /// How much of a photograph's chroma survives the bake. `direction-
  /// torchlight.json` says 12%, and 12% is a number this file may not round:
  /// it is what makes a plate a ground rather than a picture of a ground.
  static const double chroma = 0.12;

  /// The luminance ceiling: no pixel of the plate may exceed
  /// `TiqPalette.plateCeiling`, which is what makes `ink1` on the scrim a
  /// 7.68:1 pairing rather than a hope.
  static const Color ceiling = TiqPalette.plateCeiling;

  /// THE INTERIM, CLIENT-SIDE HALF OF THE SERVER BAKE, AS ONE FILTER.
  ///
  /// Two operations, composed into a single 4×5 colour matrix:
  ///
  /// 1. **Chroma to [chroma]** — a saturation matrix on Rec. 709 luma
  ///    weights, so a red end-cap becomes a dark warm grey instead of a dark
  ///    red block.
  /// 2. **The [ceiling]** — the multiply that used to be the whole treatment.
  ///    `#474747` is a neutral grey, so multiplying by it is a uniform scale
  ///    of every channel by `0x47/0xFF`; composing it with the saturation
  ///    matrix is therefore just that matrix scaled. White lands exactly on
  ///    the ceiling and everything else lands under it.
  ///
  /// It is applied as `DecorationImage.colorFilter`, which `paintImage` hands
  /// straight to `drawImageRect`'s `Paint` — one parameter on one draw call.
  /// `ColorFiltered` would say the same thing and push a `ColorFilterLayer`,
  /// which rasterises as a `saveLayer` on every frame the plate scrolls, and
  /// the paint budget forbids it.
  ///
  /// FOLLOW-UP: the real bake (12% chroma, #474747 luminance ceiling, alpha
  /// edge dissolve, ≤60 kB WebP, served from the photo endpoint) is tracked as
  /// the plate-bake ticket filed with the Torchlight plate PR. When it lands,
  /// delete this filter — a baked pixel is already toned, and toning it again
  /// would crush the plate twice.
  static ColorFilter get tone => plateTone();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final spec = PlateSpec.resolve(
      skin: skin,
      viewportHeight: viewportHeight,
      textScale: scaler.scale(1.0),
    );

    switch (spec.form) {
      case PlateForm.none:
        // Veld. The hero cluster renders on white, with no band around it.
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spec.textInset),
          child: hero,
        );
      case PlateForm.collapsed:
        return _CollapsedBand(spec: spec, hero: hero);
      case PlateForm.photographic:
        return _PhotographicPlate(
          spec: spec,
          claimId: claimId,
          hero: hero,
          image: image,
          caption: caption,
          fallbackSentence: fallbackSentence,
          semanticLabel: semanticLabel,
          tone: tone,
          devicePixelRatio:
              devicePixelRatio ??
              MediaQuery.maybeDevicePixelRatioOf(context) ??
              1.0,
        );
    }
  }
}

/// THE PLATE'S TONE, as one 4×5 colour matrix. See [TiqPlate.tone].
///
/// `chroma` is the share of the original saturation that survives; `ceiling`
/// is the grey every channel is multiplied by. Exposed as a function, and
/// pure, so the numbers can be asserted in a unit test instead of eyeballed in
/// a screenshot — the last time this treatment was half-applied, nothing
/// failed.
///
/// The luma weights are Rec. 709, the same ones every greyscale conversion in
/// the display pipeline uses. The matrix operates on sRGB-encoded values, like
/// the multiply it replaces.
ColorFilter plateTone({
  double chroma = TiqPlate.chroma,
  Color ceiling = TiqPlate.ceiling,
}) => ColorFilter.matrix(plateToneMatrix(chroma: chroma, ceiling: ceiling));

/// The tone's twenty numbers, before they become a [ColorFilter].
///
/// Split out because `ColorFilter` does not hand its matrix back, and a
/// treatment that was half-applied for a release is exactly the thing that
/// has to be assertable arithmetic rather than a screenshot somebody looks at.
///
/// Row `i` is `ceiling[i] × (saturation row i)`: the saturation rows
/// interpolate each channel towards Rec. 709 luma, keeping [chroma] of the
/// distance, and the ceiling is a neutral grey so multiplying by it is a
/// per-channel scale that folds straight into those rows. Two operations, one
/// matrix, one draw call.
///
/// A consequence worth naming, because it is what the pixel test asserts: for
/// any input, `out.max − out.min = ceiling × chroma × (in.max − in.min)`. At
/// `#474747` and 12% that is at most **8.5 of 255** — a plate cannot carry a
/// colour cast wider than that however loud the photograph is.
List<double> plateToneMatrix({
  double chroma = TiqPlate.chroma,
  Color ceiling = TiqPlate.ceiling,
}) {
  const double lumaR = 0.2126;
  const double lumaG = 0.7152;
  const double lumaB = 0.0722;
  final double keep = chroma;
  final double drop = 1 - chroma;
  final double kr = ceiling.r;
  final double kg = ceiling.g;
  final double kb = ceiling.b;
  return <double>[
    kr * (lumaR * drop + keep), kr * lumaG * drop, kr * lumaB * drop, 0, 0, //
    kg * lumaR * drop, kg * (lumaG * drop + keep), kg * lumaB * drop, 0, 0, //
    kb * lumaR * drop, kb * lumaG * drop, kb * (lumaB * drop + keep), 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// The 96dp band that replaces the plate when the fold cannot afford one.
///
/// No image, no light, no scrim — the same hero cluster on the ground. A
/// smaller photograph would be a photograph nobody can read *and* a list
/// nobody can use.
class _CollapsedBand extends StatelessWidget {
  const _CollapsedBand({required this.spec, required this.hero});

  final PlateSpec spec;
  final Widget hero;

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
    child: hero,
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
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. The specimen, or the drawing that admits there is none.
          Semantics(
            label: hasPhotograph
                ? (widget.semanticLabel ?? 'Shelf photograph')
                : 'Generated shelf illustration',
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

          // 4. Provenance on the zone's first line, hero cluster at its foot.
          //
          //    The zone is a hard box that stops just under the strip light,
          //    so the caption can never climb over it — which it did, at the
          //    200dp floor, when the zone was the declared 58% and the cluster
          //    needed more. The light is the boundary between picture and
          //    text, and now it is drawn as one.
          Positioned(
            left: spec.textInset,
            right: spec.textInset,
            bottom: TiqSpace.s5,
            top: spec.textZoneTop + TiqSpace.s2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // The provenance caption, or the fallback's sentence in its
                // place. Either way the top of the text-safe zone says what
                // the reader is looking at — an uncaptioned band is the one
                // state this component may not have.
                if (hasPhotograph && widget.caption != null)
                  Flexible(
                    child: Text(
                      widget.caption!,
                      // The zone does not grow with the type, so the caption
                      // gives up its second line before the hero gives up any
                      // of its size: provenance is meta and the figure is the
                      // screen.
                      maxLines: large ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: skin.text.meta.style(color: skin.palette.ink3),
                    ),
                  )
                else if (!hasPhotograph && widget.fallbackSentence != null)
                  Flexible(
                    child: Text(
                      widget.fallbackSentence!,
                      maxLines: large ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: skin.text.meta.style(color: skin.palette.ink3),
                    ),
                  )
                else
                  const SizedBox.shrink(),
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
        ],
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
/// [TiqPlate.tone] onto the plate without a `ColorFilteredLayer` and the
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
          // THE TONE: 12% chroma and the #474747 ceiling, as one filter on the
          // image's own paint. See [TiqPlate.tone].
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

/// The bottom-up scrim that makes the text-safe zone safe.
///
/// `ground` at 0% rising to 80%. Over the worst pixel a baked plate may carry
/// this puts `ink1` at 7.68:1; over an unbaked one the client-side ceiling in
/// [TiqPlate] holds the same floor.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    final ground = context.skin.palette.ground;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            ground.withValues(alpha: 0),
            ground.withValues(alpha: 0.80),
          ],
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
    required this.eyebrow,
    required this.figure,
    this.delta,
    this.healthLine,
    this.onHealthTap,
    this.semanticsLabel,
  });

  /// `GAUTENG NORTH · WEEK 38`. Uppercased for display by the eyebrow role.
  final String eyebrow;

  /// The hero figure — a `FigureSlot` at `hero.figure`, fitted by the caller.
  final Widget figure;

  /// The delta, on the figure's baseline. **Severity-coloured, never amber**:
  /// a delta is a verdict and a verdict leaves the amber band entirely.
  final Widget? delta;

  /// `Territory health` — the one tappable line, folding the lead indicator in
  /// rather than repeating it as a rail 84dp below.
  final Widget? healthLine;

  final VoidCallback? onHealthTap;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final cluster = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: skin.text.eyebrow.style(color: skin.palette.ink2),
        ),
        const SizedBox(height: TiqSpace.s2),
        // The figure and its delta share a baseline. A `Wrap` and not a `Row`
        // so the delta falls under the figure at 2.0x rather than squeezing it.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: TiqSpace.s3,
          runSpacing: TiqSpace.s1,
          children: <Widget>[figure, ?delta],
        ),
        if (healthLine != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          if (onHealthTap == null)
            healthLine!
          else
            _HealthTarget(onTap: onHealthTap!, child: healthLine!),
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
