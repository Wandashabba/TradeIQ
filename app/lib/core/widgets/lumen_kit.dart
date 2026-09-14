import 'package:flutter/material.dart';

import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show PressFeedback, reduceMotion;
import 'glass.dart';

/// The small parts Lumen Glass screens are built from: micro-labels, status
/// pills and tiles, the benchmark bar, the perfect-store band, the primary
/// action and the back chip. Each renders its flat equivalent in dark.

/// An uppercase mono micro-label — the kicker above a title or a panel.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color, this.size = 10});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text.toUpperCase(),
      style: c.glass
          ? LumenGlass.kickerStyle(
              color: color ?? context.lumen.kicker,
              size: size,
            )
          : TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: color ?? c.ink3,
            ),
    );
  }
}

/// A status as a word on its own wash and rim — ON STANDARD, AT RISK, BREACH.
class LumenStatusPill extends StatelessWidget {
  const LumenStatusPill({super.key, required this.status, this.label});

  final LumenStatus status;

  /// Replaces the status word — `CRITICAL`, `WATCH` — never removes it.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sw = status.swatchOf(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: sw.tint,
        borderRadius: BorderRadius.circular(c.glass ? 6 : c.radiusControl),
        border: Border.all(color: sw.rim),
      ),
      child: Text(
        (label ?? status.word).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: c.glass ? LumenGlass.mono : null,
          fontSize: 8.5,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.85,
          color: sw.ink,
        ),
      ),
    );
  }
}

/// A status glyph (✓, a sequence number, !) in a tinted, rimmed square.
class StatusTile extends StatelessWidget {
  const StatusTile({
    super.key,
    required this.status,
    required this.glyph,
    this.size = 32,
    this.radius = LumenGlass.radiusIconTile,
    this.fontSize = 12,
    this.mono = false,
  });

  final LumenStatus status;
  final String glyph;
  final double size;
  final double radius;
  final double fontSize;

  /// Set the glyph in JetBrains Mono — for counts, not symbols.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sw = status.swatchOf(c);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: sw.tint,
        borderRadius: BorderRadius.circular(c.glass ? radius : c.radiusControl),
        border: Border.all(color: sw.rim),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          fontFamily: mono && c.glass ? LumenGlass.mono : null,
          fontSize: fontSize,
          fontWeight: mono ? FontWeight.w600 : FontWeight.w700,
          color: sw.ink,
        ),
      ),
    );
  }
}

/// A figure drawn against the standard it is judged by: a track, a status
/// fill to [value], and a 2px tick at [target].
///
/// The tick is the point of the widget. A number on its own is a fact; a
/// number next to its standard is a decision — so every benchmark in the
/// product is drawn this way.
class BenchmarkBar extends StatelessWidget {
  const BenchmarkBar({
    super.key,
    required this.value,
    required this.status,
    this.target,
    this.max = 100,
    this.height = 7,
    this.onDark = false,
  });

  final double value;
  final double? target;
  final double max;
  final LumenStatus status;
  final double height;

  /// Drawn on the dark pane: a white track and a white tick.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sw = status.swatchOf(c);
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final tickAt = target == null ? null : (target! / max).clamp(0.0, 1.0);
    final track = onDark
        ? Colors.white.withValues(alpha: 0.14)
        : (c.glass ? context.lumen.track : c.surface3);
    final tick = onDark ? Colors.white.withValues(alpha: 0.75) : c.ink1;
    final radius = BorderRadius.circular(height / 2);

    // The figure is always printed beside the bar, so the bar itself is
    // decoration to a screen reader.
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: radius,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: w * fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: sw.fill,
                      borderRadius: radius,
                    ),
                  ),
                ),
                if (tickAt != null)
                  Positioned(
                    left: (w * tickAt - 1).clamp(0.0, w < 2 ? 0.0 : w - 2),
                    top: -3,
                    bottom: -3,
                    width: 2,
                    child: ColoredBox(color: tick),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The published perfect-store banding — gap below 70, at risk to 79,
/// healthy from 80 — with a marker at [score]. Drawn on the dark pane.
class ScoreBandBar extends StatelessWidget {
  const ScoreBandBar({super.key, required this.score});

  final double score;

  static const _crit = Color(0x99B3261E);
  static const _warn = Color(0x99A86A00);
  static const _good = Color(0x991F7A4D);

  @override
  Widget build(BuildContext context) {
    final at = (score / 100).clamp(0.0, 1.0);
    final label = LumenGlass.kickerStyle(
      color: LumenGlass.onDarkMuted,
      size: 9.5,
    ).copyWith(fontWeight: FontWeight.w400, letterSpacing: 0.76);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, box) => SizedBox(
              height: 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: const Row(
                        children: [
                          Expanded(flex: 70, child: ColoredBox(color: _crit)),
                          Expanded(flex: 10, child: ColoredBox(color: _warn)),
                          Expanded(flex: 20, child: ColoredBox(color: _good)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (box.maxWidth * at - 1.5).clamp(
                      0.0,
                      box.maxWidth - 3,
                    ),
                    top: -4,
                    height: 16,
                    width: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.7),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GAP <70', style: label),
            Text('70–79', style: label),
            Text('HEALTHY 80–90', style: label),
          ],
        ),
      ],
    );
  }
}

/// The primary action: dark glass with a travelling shine. Disabled, it
/// dims but keeps its words readable — the note above it says why.
class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.height = 52,
    this.sweep = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final bool sweep;

  /// Swaps the words for a spinner and takes the tap away — the request is
  /// already on its way.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !busy;
    final ink = c.glass || enabled ? c.onAction : c.ink3;

    final Widget content = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: ink),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: ink),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 16, color: ink),
              ],
            ],
          );

    final radius = BorderRadius.circular(
      c.glass ? LumenGlass.radiusButton : c.radiusControl,
    );
    final Widget pane = c.glass
        ? GlassPane(
            kind: GlassKind.action,
            shadow: enabled,
            fillColor: enabled ? null : context.lumen.actionDisabled,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: sweep && enabled
                  ? GlassSweep(
                      borderRadius: radius,
                      child: Center(child: content),
                    )
                  : Center(child: content),
            ),
          )
        : AnimatedContainer(
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            height: height,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? c.action : c.surface2,
              border: Border.all(color: enabled ? c.action : c.lineStrong),
              borderRadius: radius,
            ),
            child: content,
          );

    return Semantics(
      button: true,
      enabled: enabled,
      child: PressFeedback(onTap: enabled ? onPressed : null, child: pane),
    );
  }
}

/// The 38px glass back chip, inside a 48px hit area.
class GlassBackChip extends StatelessWidget {
  const GlassBackChip({super.key, required this.onTap, this.tooltip = 'Back'});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!c.glass) {
      return IconButton(
        icon: const Icon(Icons.arrow_back, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      );
    }
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: GlassPane(
                kind: GlassKind.pill,
                radius: 13,
                shadow: false,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    Icons.chevron_left,
                    size: 22,
                    color: context.lumen.accentInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
