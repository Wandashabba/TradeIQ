import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart';

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
  /// The level's status colour, drawn from the ambient (theme-aware) palette.
  /// Status slots are reserved — good/warn/crit — and info borrows series1,
  /// which is never a status colour elsewhere.
  Color color(TiqColors colors) => switch (this) {
    BannerLevel.good => colors.good,
    BannerLevel.warn => colors.warn,
    BannerLevel.bad => colors.crit,
    BannerLevel.info => colors.series1,
  };

  Color wash(TiqColors colors) => color(colors).withValues(alpha: 0.12);

  /// What the banner's words are set in — the dot and border keep the raw
  /// status token; only the words shift where the token would fail AA over its
  /// own 12% wash. Both washes composite over the theme plane.
  ///
  /// - `bad`: crit is a mark colour — as text over its wash it reads 3.74:1
  ///   (dark) — so the words take the theme-aware [TiqColors.critText] tint,
  ///   validated ≥4.5:1 in both themes.
  /// In **light** the status tokens are mid-dark hues over near-white washes,
  /// and every one lands just short of AA as 13px text over its own 12% wash
  /// on the plane (good 4.39:1, warn 4.34:1, info 4.28:1) — the same shortfall
  /// crit already carries. So in light the words deepen: good/warn to the
  /// console's status-text tints (the DeltaPill good/warn fg family), and info
  /// to [TiqColors.light.brandHover] (its darkened blue is the natural twin —
  /// DeltaPill has no blue tone). Each is validated ≥4.5:1 by the scaffold's
  /// contrast guard. The dot and border keep the raw token. In **dark** the
  /// tokens are bright over their dark washes and already clear AA, so the
  /// words stay on the token — bad excepted, which takes the theme-aware
  /// [TiqColors.critText] in both themes.
  Color textColor(TiqColors colors, Brightness brightness) {
    if (this == BannerLevel.bad) return colors.critText;
    if (brightness == Brightness.light) {
      return switch (this) {
        BannerLevel.good => const Color(0xFF0B6B0B),
        BannerLevel.warn => const Color(0xFF8A5A00),
        BannerLevel.info => TiqColors.light.brandHover, // == 0xFF0857C4
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
    // The banner MORPHS between states — amber "held on this phone" easing into
    // green "everything is sent" is the moment the agent has been waiting for.
    // Cutting between them would throw it away.
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.base,
      curve: Motion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: level.wash(colors),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      child: Row(
        children: [
          PulseDot(color: color, active: pulsing),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: reduceMotion(context) ? Duration.zero : Motion.base,
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: level.textColor(
                        colors,
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AnimatedSwitcher(
                      duration: reduceMotion(context)
                          ? Duration.zero
                          : Motion.base,
                      child: Text(
                        subtitle!,
                        key: ValueKey(subtitle),
                        style: TextStyle(fontSize: 11.5, color: colors.ink3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
            borderRadius: BorderRadius.circular(AppColors.radiusControl),
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

/// A count, entered with the thumb.
///
/// Counting stock is a two-handed job: one hand on the shelf, one on the phone.
/// A text field summons a keyboard that covers half the screen and needs the
/// hand that is holding the shelf — so the count is entered by tapping.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.zeroIsFinding = false,
    this.onEdit,
  });

  /// Tapping the number types it directly.
  ///
  /// A pure ±-stepper is right for small counts (facings, competitors) and wrong
  /// for a shelf holding 60 units — nobody taps + sixty times. So ± is for
  /// adjusting, and the number itself is for entering.
  final VoidCallback? onEdit;

  /// Null renders as "—": not yet counted, which is different from zero.
  final int? value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// When true, a zero is styled as the *finding* it is — an out-of-stock is
  /// the most valuable thing an agent can record, and it raises a task. It must
  /// not look like an empty field.
  final bool zeroIsFinding;

  /// The agent is looking at the shelf, not at the phone. A count they can
  /// *feel* land is worth more than one they have to look down to check — and
  /// hitting zero is heavier, because zero raises a task for a manager.
  void _change(int? from, int to) {
    if (to == 0 && zeroIsFinding) {
      Buzz.finding();
    } else {
      Buzz.tick();
    }
    onChanged(to);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = value;
    final isZero = v == 0;

    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.base,
      curve: Motion.enter,
      decoration: BoxDecoration(
        color: colors.surface2,
        // The whole control takes on the finding's colour, so an out-of-stock is
        // unmissable from arm's length in a dark aisle.
        border: Border.all(
          color: isZero && zeroIsFinding
              ? colors.crit.withValues(alpha: 0.6)
              : colors.lineStrong,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      child: Row(
        children: [
          _Step(
            icon: Icons.remove,
            // From "not counted", - means "there are none": an explicit zero,
            // which is exactly how an agent records an empty shelf.
            onTap: v == null || v > min ? () => _change(v, (v ?? 1) - 1) : null,
            semantic: 'One fewer',
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                child: SizedBox(
                  height: 54,
                  child: Center(
                    child: AnimatedCount(
                      value: v,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: v == null
                            ? colors.ink3
                            : (isZero && zeroIsFinding)
                            ? colors.crit
                            : colors.ink1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Step(
            icon: Icons.add,
            // From "not counted", the first + means "I counted one" — not zero.
            // Landing on 0 would silently record an out-of-stock, which is a
            // finding that raises a task.
            onTap: v == null || v < max ? () => _change(v, (v ?? 0) + 1) : null,
            semantic: 'One more',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.onTap,
    required this.semantic,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: colors.surface3,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 54,
            child: Icon(
              icon,
              size: 22,
              color: onTap == null ? colors.ink3 : colors.ink1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Two or three big choices instead of a 20px switch.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label})> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Choice(
              label: options[i].label,
              selected: options[i].value == selected,
              onTap: () => onChanged(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: kTapTarget,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colors.brand.withValues(alpha: 0.14)
              : colors.surface2,
          border: Border.all(
            color: selected ? colors.brand : colors.lineStrong,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusControl),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppColors.radiusControl),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.ink1 : colors.ink2,
                ),
              ),
            ),
          ),
        ),
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
    return Semantics(
      toggled: value,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(AppColors.radiusControl),
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
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.ink1,
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
        color: value ? colors.brand : colors.surface3,
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
            decoration: BoxDecoration(
              color: value ? Colors.white : colors.ink3,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A checkbox row — label-left, box-right, the whole row a target.
///
/// Checked fills [TiqColors.brand] and draws a tick: the state carries a glyph,
/// never colour alone, and `Semantics(checked:)` speaks it.
class AgentCheck extends StatelessWidget {
  const AgentCheck({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      checked: value,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(AppColors.radiusControl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.ink1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CheckBox(value: value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.value});

  final bool value;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.fast,
      curve: Motion.enter,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: value ? colors.brand : colors.surface2,
        border: Border.all(color: value ? colors.brand : colors.lineStrong),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      // White on brand clears AA (4.76:1); the tick is what carries "checked".
      child: value
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// A field with a label and, where it earns its place, a sentence of help.
class AgentField extends StatelessWidget {
  const AgentField({
    super.key,
    required this.label,
    required this.child,
    this.help,
  });

  final String label;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: 7),
          child,
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                help!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.ink3,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "2h ago" — a field agent does not want a timestamp, they want to know
/// whether it was recent.
String formatAgo(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
