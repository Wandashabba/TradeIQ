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
/// referenced on [_luminanceCeiling] — so this widget applies the *luminance*
/// half of it client-side, as one blend parameter inside the image's existing
/// draw call. The chroma reduction, the dissolve and the byte cap stay on the
/// server, because a client cannot fix a 900 kB download by dimming it.
///
/// ## Cost
///
/// One `Image`, decoded at `cacheWidth`. Two gradient decorations (the bottom-up
/// scrim and the bloom above the light). Zero `BackdropFilter`, zero
/// `ShaderMask`, zero `ImageFiltered`, zero `saveLayer`, zero `BoxShadow`.
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

  /// The interim, client-side half of the server bake: no pixel of the plate
  /// may exceed `TiqPalette.plateCeiling`, which is what makes `ink1` on the
  /// scrim a 7.68:1 pairing rather than a hope.
  ///
  /// A `multiply` blend against the ceiling grey is exactly that clamp, and it
  /// is a parameter on the image's own paint — not a `ColorFiltered`, which
  /// would push a `saveLayer` the budget forbids.
  ///
  /// FOLLOW-UP: the real bake (12% chroma, #474747 luminance ceiling, alpha
  /// edge dissolve, ≤60 kB WebP, served from the photo endpoint) is tracked as
  /// the plate-bake ticket filed with this PR. When it lands, delete this
  /// blend — a baked pixel is already under the ceiling and multiplying it
  /// again would darken the plate twice.
  static const Color _luminanceCeiling = TiqPalette.plateCeiling;

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
          ceiling: _luminanceCeiling,
          devicePixelRatio:
              devicePixelRatio ??
              MediaQuery.maybeDevicePixelRatioOf(context) ??
              1.0,
        );
    }
  }
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
    required this.ceiling,
    required this.devicePixelRatio,
  });

  final PlateSpec spec;
  final String claimId;
  final Widget hero;
  final ImageProvider<Object>? image;
  final String? caption;
  final String? fallbackSentence;
  final String? semanticLabel;
  final Color ceiling;
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
              ceiling: widget.ceiling,
              still: still,
              width: MediaQuery.sizeOf(context).width,
              devicePixelRatio: widget.devicePixelRatio,
              onFailed: () {
                if (!_imageFailed && mounted) {
                  // After the frame: an errorBuilder runs during build.
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
class _Frame extends StatelessWidget {
  const _Frame({
    required this.image,
    required this.sentence,
    required this.ceiling,
    required this.still,
    required this.width,
    required this.devicePixelRatio,
    required this.onFailed,
  });

  final ImageProvider<Object>? image;
  final String? sentence;
  final VoidCallback onFailed;
  final Color ceiling;
  final bool still;
  final double width;
  final double devicePixelRatio;

  /// The plate is never wider than the phone and never needs more than its own
  /// pixels. Decoding a 4000px capture to draw it at 360dp is how a 2 GB
  /// device runs out of memory on a dashboard.
  int get _cacheWidth => (width * devicePixelRatio).round().clamp(1, 1440);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    if (image == null) return const _FallbackFrame();

    final drawn = Image(
      image: ResizeImage(image!, width: _cacheWidth, allowUpscaling: false),
      fit: BoxFit.cover,
      // Never flash back to nothing while a rebuild re-decodes.
      gaplessPlayback: true,
      // The interim luminance ceiling. One paint parameter, no layer.
      color: ceiling,
      colorBlendMode: BlendMode.multiply,
      // A photograph that will not decode is the same state as no photograph:
      // the drawing and the sentence, never a broken-image glyph and never an
      // empty black band that reads as a rendering fault.
      errorBuilder: (context, error, stack) {
        onFailed();
        return const _FallbackFrame();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || still) return child;
        // The reveal: opacity plus a 1.02 -> 1.00 scale, on the image only.
        // The figure does not count up and the light does not fade in from
        // nowhere — only the photograph arrives.
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: TiqMotion.reveal,
          curve: TiqMotion.enterCurve,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.02, end: 1.0),
            duration: TiqMotion.reveal,
            curve: TiqMotion.enterCurve,
            builder: (context, scale, inner) =>
                Transform.scale(scale: scale, child: inner),
            child: child,
          ),
        );
      },
    );

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
