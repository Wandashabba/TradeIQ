import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
  Color get color => switch (this) {
        BannerLevel.good => AppColors.good,
        BannerLevel.warn => AppColors.warn,
        BannerLevel.bad => AppColors.crit,
        BannerLevel.info => AppColors.series1,
      };

  Color get wash => color.withValues(alpha: 0.12);
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
    final color = level.color;
    // The banner MORPHS between states — amber "held on this phone" easing into
    // green "everything is sent" is the moment the agent has been waiting for.
    // Cutting between them would throw it away.
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.base,
      curve: Motion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: level.wash,
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
                      color: color,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AnimatedSwitcher(
                      duration:
                          reduceMotion(context) ? Duration.zero : Motion.base,
                      child: Text(
                        subtitle!,
                        key: ValueKey(subtitle),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.ink3,
                        ),
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
              ? AppColors.surface2
              : secondary
                  ? AppColors.surface2
                  : AppColors.brand,
          border: Border.all(
            color: !enabled
                ? AppColors.lineStrong
                : secondary
                    ? AppColors.lineStrong
                    : AppColors.brand,
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
                        ? AppColors.ink3
                        : secondary
                            ? AppColors.ink1
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
                        ? AppColors.ink3
                        : secondary
                            ? AppColors.ink1
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
        style: const TextStyle(fontSize: 12, color: AppColors.ink3),
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
    final v = value;
    final isZero = v == 0;

    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.base,
      curve: Motion.enter,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        // The whole control takes on the finding's colour, so an out-of-stock is
        // unmissable from arm's length in a dark aisle.
        border: Border.all(
          color: isZero && zeroIsFinding
              ? AppColors.crit.withValues(alpha: 0.6)
              : AppColors.lineStrong,
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
                            ? AppColors.ink3
                            : (isZero && zeroIsFinding)
                                ? AppColors.crit
                                : AppColors.ink1,
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
  const _Step({required this.icon, required this.onTap, required this.semantic});

  final IconData icon;
  final VoidCallback? onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: AppColors.surface3,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 54,
            child: Icon(
              icon,
              size: 22,
              color: onTap == null ? AppColors.ink3 : AppColors.ink1,
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
    return SizedBox(
      height: kTapTarget,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.14)
              : AppColors.surface2,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.lineStrong,
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
                  color: selected ? AppColors.ink1 : AppColors.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 7),
          child,
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                help!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink3,
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
