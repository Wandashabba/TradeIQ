import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;

/// The Lumen Glass material: the lit ground, the glass pane, and the four
/// ambient loops that make it read as light rather than paint.
///
/// Everything here renders flat in the dark theme ([TiqColors.glass] false),
/// so a screen can adopt these widgets without changing how dark looks.

/// The global switch for ambient loops.
///
/// Motion elsewhere in the app is feedback, never decoration — see
/// agent_motion.dart. The glass loops are the design's deliberate exception
/// (the handoff's motion table: pulse, bloom, sweep, spin), so they are held
/// to a stricter bar: off under reduce-motion, and off in tests, where a
/// forever-repeating animation would stop `pumpAndSettle` from settling.
/// `test/flutter_test_config.dart` clears [enabled] for the whole suite.
class AmbientMotion {
  AmbientMotion._();

  static bool enabled = true;

  static bool of(BuildContext context) => enabled && !reduceMotion(context);
}

/// A repeating animation that only runs when [AmbientMotion.of] allows it.
/// [builder] receives the curved progress, or null for the resting frame.
class AmbientLoop extends StatefulWidget {
  const AmbientLoop({
    super.key,
    required this.period,
    required this.builder,
    this.reverse = false,
    this.curve = Curves.easeInOut,
  });

  final Duration period;
  final bool reverse;
  final Curve curve;
  final Widget Function(BuildContext context, double? t) builder;

  @override
  State<AmbientLoop> createState() => _AmbientLoopState();
}

class _AmbientLoopState extends State<AmbientLoop>
    with SingleTickerProviderStateMixin {
  // Eager, not `late final`: a lazily-created controller would first be built
  // by dispose() on a loop that never ran, and a Ticker on a dead element
  // throws (the same trap PulseDot documents).
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AmbientLoop old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) _c.duration = widget.period;
    _sync();
  }

  void _sync() {
    final on = AmbientMotion.of(context);
    if (on && !_c.isAnimating) {
      _c.repeat(reverse: widget.reverse);
    } else if (!on && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AmbientMotion.of(context)) return widget.builder(context, null);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          widget.builder(context, widget.curve.transform(_c.value)),
    );
  }
}

/// One radial bloom of the lit ground, in the CSS terms the handoff uses:
/// an ellipse of [rx]×[ry] pixels centred at a fraction of the box, fading
/// to transparent at [stop] of its radius.
class GroundBloom {
  const GroundBloom(this.rx, this.ry, this.cx, this.cy, this.tone, this.stop);

  final double rx;
  final double ry;
  final double cx;
  final double cy;
  final BloomTone tone;
  final double stop;

  /// The bloom's colour in [palette] — lavender light by day, deep by night.
  Color colorIn(LumenPalette palette) => switch (tone) {
    BloomTone.violet => palette.bloomViolet,
    BloomTone.blue => palette.bloomBlue,
    BloomTone.rose => palette.bloomRose,
  };
}

enum BloomTone { violet, blue, rose }

enum GroundLayout {
  phone([
    GroundBloom(460, 340, 0.06, -0.08, BloomTone.violet, 0.68),
    GroundBloom(420, 320, 1.06, 0.10, BloomTone.blue, 0.70),
    GroundBloom(520, 420, 0.62, 1.12, BloomTone.rose, 0.72),
  ]),
  console([
    GroundBloom(720, 460, 0.88, -0.10, BloomTone.violet, 0.66),
    GroundBloom(620, 420, -0.04, 0.24, BloomTone.blue, 0.70),
    GroundBloom(700, 520, 0.54, 1.16, BloomTone.rose, 0.72),
  ]);

  const GroundLayout(this.blooms);

  final List<GroundBloom> blooms;
}

/// The lit ground every pane floats on — lavender by day, indigo by night.
/// Flat [TiqColors.plane] without a glass theme.
class LitGround extends StatelessWidget {
  const LitGround({
    super.key,
    this.child,
    this.layout = GroundLayout.phone,
    this.backdrop,
  });

  final Widget? child;
  final GroundLayout layout;

  /// A picture laid under the ground — the aisle footage on the splash and
  /// sign-in. The ground veils it (see [LumenPalette.footageVeil]) so it reads
  /// as texture and every pane keeps its contrast.
  final Widget? backdrop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = child ?? const SizedBox.expand();
    if (!colors.glass) return ColoredBox(color: colors.plane, child: content);

    final lumen = context.lumen;
    final veil = backdrop == null ? 1.0 : lumen.footageVeil;
    final ground = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lumen.groundTop.withValues(alpha: veil),
            lumen.groundBottom.withValues(alpha: veil),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GroundPainter(layout, lumen),
        isComplex: true,
        // The ground never animates — keep scrolling content above it from
        // repainting it every frame.
        child: RepaintBoundary(child: content),
      ),
    );
    if (backdrop == null) return ground;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: backdrop),
        ground,
      ],
    );
  }
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.layout, this.palette);

  final GroundLayout layout;
  final LumenPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in layout.blooms) {
      canvas.save();
      canvas.translate(size.width * b.cx, size.height * b.cy);
      // A circle of radius rx, squashed vertically into the rx×ry ellipse.
      canvas.scale(1, b.ry / b.rx);
      final rect = Rect.fromCircle(center: Offset.zero, radius: b.rx);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [b.colorIn(palette), b.colorIn(palette).withValues(alpha: 0)],
          stops: [0, b.stop],
        ).createShader(rect);
      canvas.drawCircle(Offset.zero, b.rx, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) =>
      old.layout != layout || old.palette != palette;
}

/// The six glass surfaces of the handoff's surface table.
enum GlassKind {
  /// Cards and panels. 50% fill, 22px blur.
  panel,

  /// List items and grid tiles. 48% fill, 18px blur.
  tile,

  /// The floating tab bar and the console rail. 28px blur.
  bar,

  /// The active tab pill, chips, the back chip. No blur.
  pill,

  /// The one heavy pane — the score. Near-black at 84%, 26px blur.
  dark,

  /// The primary action. Dark ink at 94%, no blur.
  action,
}

class _GlassSpec {
  const _GlassSpec({
    required this.fill,
    required this.rim,
    required this.sigma,
    required this.shadow,
    required this.radius,
    this.specular,
    this.specularStop = 0.46,
    this.highlight,
  });

  final Color fill;
  final Color rim;
  final double sigma;
  final BoxShadow shadow;
  final double radius;

  /// The top-left sheen, fading out at [specularStop] of the diagonal.
  final Color? specular;
  final double specularStop;

  /// The 1px lit edge along the top — the CSS `inset 0 1px 0` rim, which
  /// BoxShadow cannot express.
  final Color? highlight;
}

const _lightSpecs = <GlassKind, _GlassSpec>{
  GlassKind.panel: _GlassSpec(
    fill: LumenGlass.panelFill,
    rim: LumenGlass.panelRim,
    sigma: LumenGlass.blurPanel,
    shadow: LumenGlass.shadowPanel,
    radius: LumenGlass.radiusCard,
    specular: Color(0xB3FFFFFF),
    specularStop: 0.44,
    highlight: Color(0xF2FFFFFF),
  ),
  GlassKind.tile: _GlassSpec(
    fill: LumenGlass.tileFill,
    rim: LumenGlass.tileRim,
    sigma: LumenGlass.blurTile,
    shadow: LumenGlass.shadowTile,
    radius: LumenGlass.radiusCard,
    specular: Color(0xA8FFFFFF),
    highlight: Color(0xEBFFFFFF),
  ),
  GlassKind.bar: _GlassSpec(
    fill: LumenGlass.barFill,
    rim: LumenGlass.barRim,
    sigma: LumenGlass.blurBar,
    shadow: LumenGlass.shadowBar,
    radius: LumenGlass.radiusHero,
    specular: Color(0xB3FFFFFF),
    specularStop: 0.48,
    highlight: Color(0xFAFFFFFF),
  ),
  GlassKind.pill: _GlassSpec(
    fill: LumenGlass.pillFill,
    rim: LumenGlass.pillRim,
    sigma: 0,
    shadow: LumenGlass.shadowPill,
    radius: LumenGlass.radiusButton,
    highlight: Color(0xF2FFFFFF),
  ),
  GlassKind.dark: _GlassSpec(
    fill: LumenGlass.darkFill,
    rim: LumenGlass.darkRim,
    sigma: LumenGlass.blurDark,
    shadow: LumenGlass.shadowDark,
    radius: LumenGlass.radiusHero,
    specular: Color(0x4DFFFFFF),
    highlight: Color(0x52FFFFFF),
  ),
  GlassKind.action: _GlassSpec(
    fill: LumenGlass.buttonDark,
    rim: LumenGlass.actionRim,
    sigma: 0,
    shadow: LumenGlass.shadowAction,
    radius: LumenGlass.radiusButton,
    highlight: Color(0x57FFFFFF),
  ),
};

/// Lumen Glass at night: the same six surfaces as faint white panes over the
/// indigo ground — thin fills, cool rims, a low sheen and deeper shadows.
const _nightSpecs = <GlassKind, _GlassSpec>{
  GlassKind.panel: _GlassSpec(
    fill: Color(0x17FFFFFF),
    rim: Color(0x2EFFFFFF),
    sigma: LumenGlass.blurPanel,
    shadow: BoxShadow(
      color: Color(0x66000000),
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
    radius: LumenGlass.radiusCard,
    specular: Color(0x1FFFFFFF),
    specularStop: 0.44,
    highlight: Color(0x40FFFFFF),
  ),
  GlassKind.tile: _GlassSpec(
    fill: Color(0x14FFFFFF),
    rim: Color(0x26FFFFFF),
    sigma: LumenGlass.blurTile,
    shadow: BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
    radius: LumenGlass.radiusCard,
    specular: Color(0x1AFFFFFF),
    highlight: Color(0x38FFFFFF),
  ),
  GlassKind.bar: _GlassSpec(
    fill: Color(0x1FFFFFFF),
    rim: Color(0x33FFFFFF),
    sigma: LumenGlass.blurBar,
    shadow: BoxShadow(
      color: Color(0x73000000),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
    radius: LumenGlass.radiusHero,
    specular: Color(0x1FFFFFFF),
    specularStop: 0.48,
    highlight: Color(0x4DFFFFFF),
  ),
  GlassKind.pill: _GlassSpec(
    fill: Color(0x2EFFFFFF),
    rim: Color(0x3DFFFFFF),
    sigma: 0,
    shadow: BoxShadow(
      color: Color(0x40000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    radius: LumenGlass.radiusButton,
    highlight: Color(0x33FFFFFF),
  ),
  GlassKind.dark: _GlassSpec(
    fill: Color(0xE6070612),
    rim: Color(0x33FFFFFF),
    sigma: LumenGlass.blurDark,
    shadow: BoxShadow(
      color: Color(0x80000000),
      blurRadius: 34,
      offset: Offset(0, 14),
    ),
    radius: LumenGlass.radiusHero,
    specular: Color(0x26FFFFFF),
    highlight: Color(0x33FFFFFF),
  ),
  GlassKind.action: _GlassSpec(
    fill: Color(0xF5E9E6FF),
    rim: Color(0x80FFFFFF),
    sigma: 0,
    shadow: BoxShadow(
      color: Color(0x40000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    radius: LumenGlass.radiusButton,
    highlight: Color(0xCCFFFFFF),
  ),
};

/// A pane of glass: shadow, clip, backdrop blur, fill, rim, specular sheen
/// and a lit top edge, with [child] painted fully opaque on top.
///
/// Day and night take their own specs ([_lightSpecs], [_nightSpecs]). With no
/// glass theme at all it falls back to the flat instrument panel — surface1,
/// a hairline, and the flat radius.
class GlassPane extends StatelessWidget {
  const GlassPane({
    super.key,
    required this.child,
    this.kind = GlassKind.panel,
    this.radius,
    this.padding,
    this.blur = true,
    this.specular = true,
    this.shadow = true,
    this.fillColor,
    this.rimColor,
  });

  final Widget child;
  final GlassKind kind;

  /// Null takes the kind's own radius from the handoff's geometry table.
  final double? radius;
  final EdgeInsetsGeometry? padding;

  /// Set false for panes repeated in a scrolling list. [BackdropFilter] is
  /// the most expensive thing on the screen, the field app runs on cheap
  /// handsets, and a list of blurred rows is where that bill comes due — so
  /// a list item gets a more opaque fill instead of a blur.
  final bool blur;
  final bool specular;
  final bool shadow;

  /// Overrides for a status-washed pane (a crit SKU card, an alert card).
  final Color? fillColor;
  final Color? rimColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!colors.glass) return _flat(colors);

    final lumen = context.lumen;
    final spec = (identical(lumen, LumenPalette.light)
        ? _lightSpecs
        : _nightSpecs)[kind]!;
    final r = BorderRadius.circular(radius ?? spec.radius);
    final blurred = blur && spec.sigma > 0;
    final fill =
        fillColor ??
        (!blurred && (kind == GlassKind.panel || kind == GlassKind.tile)
            ? lumen.solidFill
            : spec.fill);

    final content = Stack(
      fit: StackFit.passthrough,
      children: [
        if (specular && spec.specular != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.8, -1),
                    end: const Alignment(0.4, 0.6),
                    colors: [
                      spec.specular!,
                      spec.specular!.withValues(alpha: 0),
                    ],
                    stops: [0, spec.specularStop],
                  ),
                ),
              ),
            ),
          ),
        if (spec.highlight != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: IgnorePointer(child: ColoredBox(color: spec.highlight!)),
          ),
        Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ],
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: r,
        border: Border.all(color: rimColor ?? spec.rim),
      ),
      child: content,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow ? [spec.shadow] : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: blurred
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: spec.sigma,
                  sigmaY: spec.sigma,
                ),
                child: decorated,
              )
            : decorated,
      ),
    );
  }

  Widget _flat(TiqColors c) {
    final radius = switch (kind) {
      GlassKind.pill || GlassKind.action => c.radiusControl,
      GlassKind.tile => c.radiusCard,
      _ => c.radiusPanel,
    };
    final (Color bg, Color border) = switch (kind) {
      GlassKind.action => (c.action, c.action),
      GlassKind.bar => (c.navBarBg, c.navBarLine),
      GlassKind.pill => (fillColor ?? c.surface3, rimColor ?? c.lineStrong),
      _ => (fillColor ?? c.surface1, rimColor ?? c.line),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

/// A shine band travelling across [child] — primary buttons and the hero
/// card. The band is painted over the child but never intercepts a tap.
class GlassSweep extends StatelessWidget {
  const GlassSweep({
    super.key,
    required this.child,
    this.period = LumenGlass.sweep,
    this.band = 64,
    this.strength = 0.26,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final Duration period;
  final double band;
  final double strength;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!context.colors.glass) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: AmbientLoop(
                period: period,
                builder: (context, t) {
                  if (t == null) return const SizedBox.shrink();
                  return LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        Positioned(
                          left: -band + (box.maxWidth + band * 2) * t,
                          top: 0,
                          bottom: 0,
                          width: band,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: strength),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The soft radial glow that breathes behind a dark pane or the check-in
/// disc. Decoration only — never hit-testable.
class GlassBloom extends StatelessWidget {
  const GlassBloom({
    super.key,
    required this.diameter,
    this.color = LumenGlass.accentLight,
    this.strength = 0.5,
    this.stop = 0.68,
    this.innerColor,
  });

  final double diameter;
  final Color color;
  final double strength;
  final double stop;

  /// An optional brighter core, for the check-in disc's two-stop glow.
  final Color? innerColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AmbientLoop(
        period: LumenGlass.bloomHalf,
        reverse: true,
        builder: (context, t) {
          final k = t ?? 0.5;
          final glow = SizedBox.square(
            dimension: diameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    innerColor ?? color.withValues(alpha: strength),
                    color.withValues(alpha: strength * 0.24),
                    color.withValues(alpha: 0),
                  ],
                  stops: [0, stop * 0.72, stop],
                ),
              ),
            ),
          );
          return Opacity(
            opacity: 0.42 + 0.43 * k,
            child: Transform.scale(scale: 1 + 0.08 * k, child: glow),
          );
        },
      ),
    );
  }
}

/// The unsent-sync dot: a status mark in a 3px halo, breathing gently.
class GlassPulseDot extends StatelessWidget {
  const GlassPulseDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), spreadRadius: 3),
        ],
      ),
    );
    return AmbientLoop(
      period: LumenGlass.pulseHalf,
      reverse: true,
      builder: (context, t) => t == null
          ? dot
          : Opacity(
              opacity: 0.55 + 0.45 * t,
              child: Transform.scale(scale: 1 + 0.14 * t, child: dot),
            ),
    );
  }
}

/// A glyph turning slowly — the retry mark on a held capture.
class AmbientSpin extends StatelessWidget {
  const AmbientSpin({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AmbientLoop(
    period: LumenGlass.spin,
    curve: Curves.linear,
    builder: (context, t) => t == null
        ? child
        : Transform.rotate(angle: t * 2 * math.pi, child: child),
  );
}

/// The one-shot entrance the score card makes: up 14px and in, once.
class GlassRise extends StatelessWidget {
  const GlassRise({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: LumenGlass.rise,
      curve: LumenGlass.riseCurve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
