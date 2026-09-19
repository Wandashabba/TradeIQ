import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/status_pill_colors.dart';
import '../theme/tiq_colors.dart';
import '../theme/lumen_glass.dart';
import 'agent_motion.dart';
import 'glass.dart';
import 'lumen_kit.dart';
import '../theme/lumen_palette.dart';

/// The field agent's widget kit.
///
/// The manager's console optimises for density: many things, read at a glance,
/// with a mouse. This optimises for the opposite conditions — one hand, bad
/// light, a shelf in the other hand, and no signal. Every control here is at
/// least 48px, and counts are entered by tapping rather than by summoning a
/// keyboard that covers half the screen.

/// The minimum size of anything an agent has to hit.
const double kTapTarget = 48;

enum BannerLevel { good, warn, bad, info }

extension BannerLevelStyle on BannerLevel {
  /// The level as a Lumen Glass status role — how the glass theme draws it.
  LumenStatus get status => switch (this) {
    BannerLevel.good => LumenStatus.good,
    BannerLevel.warn => LumenStatus.warn,
    BannerLevel.bad => LumenStatus.crit,
    BannerLevel.info => LumenStatus.current,
  };

  /// The level's status colour, drawn from the ambient (theme-aware) palette.
  /// Status slots are reserved — good/warn/crit — and info borrows series1,
  /// which is never a status colour elsewhere. Glass takes the handoff's
  /// status fill.
  Color color(TiqColors colors) {
    if (colors.glass) return status.swatchOf(colors).fill;
    return switch (this) {
      BannerLevel.good => colors.good,
      BannerLevel.warn => colors.warn,
      BannerLevel.bad => colors.crit,
      BannerLevel.info => colors.series1,
    };
  }

  Color wash(TiqColors colors) => colors.glass
      ? status.swatchOf(colors).tint
      : color(colors).withValues(alpha: 0.12);

  /// What the banner's words are set in — the dot and border keep the raw
  /// status token; only the words shift where the token would fail AA over its
  /// own wash.
  ///
  /// - **Glass:** the handoff's status ink, which clears 4.5:1 over its own
  ///   tint on every part of the lit ground (glass_test.dart holds it).
  /// - **Dark:** the tokens are bright over their dark washes and already clear
  ///   AA, so the words stay on the token — bad excepted, which takes
  ///   [TiqColors.critText] (crit is a mark colour, 3.74:1 as text).
  /// - **Flat light** (a TiqColors that is light but not glass, e.g. a test
  ///   palette): the status-text tints — see status_pill_colors.dart.
  Color textColor(TiqColors colors, Brightness brightness) {
    if (colors.glass) return status.swatchOf(colors).ink;
    if (this == BannerLevel.bad) return colors.critText;
    if (brightness == Brightness.light) {
      return switch (this) {
        BannerLevel.good => statusPillGood.fg,
        BannerLevel.warn => statusPillWarn.fg,
        BannerLevel.info => TiqColors.light.brandHover,
        BannerLevel.bad => colors.critText, // unreachable — bad handled above
      };
    }
    return color(colors);
  }
}

/// A status line the agent reads before anything else on the screen.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.level,
    required this.title,
    this.subtitle,
    this.trailing,
    this.pulsing = false,
  });

  final BannerLevel level;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Breathe the dot — reserved for "sending, right now".
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = level.color(colors);
    final motion = reduceMotion(context) ? Duration.zero : Motion.base;
    final titleColor = level.textColor(colors, Theme.of(context).brightness);
    // In glass a problem carries its ink into the sub-line too; a calm state
    // keeps the sub-line muted so the title is what reads.
    final loudSub =
        colors.glass && (level == BannerLevel.warn || level == BannerLevel.bad);

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: motion,
          child: Text(
            title,
            key: ValueKey(title),
            style: TextStyle(
              fontSize: colors.glass ? 12.5 : 13,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AnimatedSwitcher(
              duration: motion,
              child: Text(
                subtitle!,
                key: ValueKey(subtitle),
                style: TextStyle(
                  fontSize: colors.glass ? 11 : 11.5,
                  color: loudSub ? titleColor : colors.ink3,
                ),
              ),
            ),
          ),
      ],
    );

    if (colors.glass) {
      // A glass strip like every other pane. Held-on-phone breathes — the
      // handoff's one hard requirement is that unsent work is never quiet — and
      // a problem that will not fix itself is washed in its tint as well.
      final sw = level.status.swatchOf(colors);
      final loud = level == BannerLevel.bad;
      final Widget dot = pulsing || level == BannerLevel.warn
          ? GlassPulseDot(color: color)
          : Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    spreadRadius: 3,
                  ),
                ],
              ),
            );
      return GlassPane(
        radius: LumenGlass.radiusControl,
        fillColor: loud ? sw.tint : null,
        rimColor: loud ? sw.rim : null,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            dot,
            const SizedBox(width: 11),
            Expanded(child: words),
            ?trailing,
          ],
        ),
      );
    }

    // The banner MORPHS between states — amber "held on this phone" easing into
    // green "everything is sent" is the moment the agent has been waiting for.
    // Cutting between them would throw it away.
    return AnimatedContainer(
      duration: motion,
      curve: Motion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: level.wash(colors),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(colors.radiusControl),
      ),
      child: Row(
        children: [
          PulseDot(color: color, active: pulsing),
          const SizedBox(width: 9),
          Expanded(child: words),
          ?trailing,
        ],
      ),
    );
  }
}

/// The one primary action, sized for a thumb.
class AgentButton extends StatelessWidget {
  const AgentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;

    if (colors.glass) {
      if (!secondary) {
        return GlassPrimaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          height: kTapTarget + 4,
        );
      }
      final ink = enabled ? context.lumen.ink : context.lumen.inkMuted;
      return Semantics(
        button: true,
        enabled: enabled,
        child: PressFeedback(
          onTap: onPressed,
          child: GlassPane(
            kind: GlassKind.pill,
            radius: LumenGlass.radiusControl,
            child: SizedBox(
              width: double.infinity,
              height: kTapTarget,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: ink),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // The moment the last required section lands, this button comes alive — the
    // colour eases in rather than snapping. It is the agent's "you can go now".
    return PressFeedback(
      onTap: onPressed,
      child: SizedBox(
        width: double.infinity,
        height: kTapTarget,
        child: AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : Motion.base,
          curve: Motion.enter,
          decoration: BoxDecoration(
            color: !enabled
                ? colors.surface2
                : secondary
                ? colors.surface2
                : colors.brand,
            border: Border.all(
              color: !enabled
                  ? colors.lineStrong
                  : secondary
                  ? colors.lineStrong
                  : colors.brand,
            ),
            borderRadius: BorderRadius.circular(colors.radiusControl),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: !enabled
                        ? colors.ink3
                        : secondary
                        ? colors.ink1
                        : Colors.white,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: !enabled
                        ? colors.ink3
                        : secondary
                        ? colors.ink1
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Why a disabled button is disabled. A dead end in a shop is a phone call to
/// the manager, so a blocked action always explains itself.
class BarNote extends StatelessWidget {
  const BarNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: context.colors.ink3),
      ),
    );
  }
}

/// An on/off setting — a thumb-sized row, not a 20px `SwitchListTile`.
///
/// The whole row is the target (label-left, track-right), so an agent flips it
/// without hunting for a tiny switch. State never rides on colour alone: the
/// thumb slides and `Semantics(toggled:)` speaks it to a screen reader.
class AgentToggle extends StatelessWidget {
  const AgentToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.help,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // MergeSemantics folds the InkWell's tap into the labelled+toggled node, so
    // a screen reader hears ONE control: label, on/off state, and "activate".
    // The visible label Text is excluded so it isn't announced a second time.
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(colors.radiusControl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kTapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.ink1,
                              ),
                            ),
                          ),
                          if (help != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                help!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.ink3,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ToggleTrack(value: value),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTrack extends StatelessWidget {
  const _ToggleTrack({required this.value});

  final bool value;

  static const double _w = 44;
  static const double _h = 26;
  static const double _thumb = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.fast,
      curve: Motion.enter,
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: value
            ? colors.brand
            : (colors.glass ? context.lumen.track : colors.surface3),
        border: Border.all(color: value ? colors.brand : colors.lineStrong),
        borderRadius: BorderRadius.circular(_h / 2),
      ),
      child: AnimatedAlign(
        duration: reduceMotion(context) ? Duration.zero : Motion.fast,
        curve: Motion.enter,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: _thumb,
            height: _thumb,
            // Off the thumb is a muted knob (ink3) on the surface3 track; on it
            // is white on brand — the knob itself carries the state, not colour.
            // Glass: a lit white knob by day; at night the on-knob takes the
            // action's dark ink so it stands off the lavender track.
            decoration: BoxDecoration(
              color: switch ((colors.glass, colors.isNight, value)) {
                (true, true, true) => colors.onAction,
                (true, false, _) => Colors.white,
                (_, _, true) => Colors.white,
                _ => colors.ink3,
              },
              shape: BoxShape.circle,
              boxShadow: colors.glass && !colors.isNight
                  ? const [
                      BoxShadow(
                        color: Color(0x33241F47),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// "2h ago" — a field agent does not want a timestamp, they want to know
/// whether it was recent.
///
/// Pass the active [l10n] (`context.l10n`) on agent screens; without it the
/// English copy is used (the manager console is not localised yet).
String formatAgo(DateTime when, [AppLocalizations? l10n]) {
  final l = l10n ?? englishLocalizations;
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 60) return l.agoJustNow;
  if (d.inMinutes < 60) return l.agoMinutes(d.inMinutes);
  if (d.inHours < 24) return l.agoHours(d.inHours);
  return l.agoDays(d.inDays);
}
