import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Motion for the field agent.
///
/// The palette, the type and the geometry are unchanged — this layer only adds
/// *response*. A static app cannot tell you the difference between "I heard you"
/// and "I'm broken", and an agent tapping a count on a cheap phone in a dark
/// aisle needs to know which.
///
/// Two rules run through everything here:
///
/// 1. **Motion is feedback, never decoration.** Every animation is triggered by
///    something the agent did or something the system learned. Nothing moves to
///    look busy.
/// 2. **Nothing repeats forever.** An infinitely-repeating animation means
///    `pumpAndSettle` never settles, which quietly makes the widget under it
///    untestable. The only looping animation in the app is [PulseDot], and it
///    loops only while a sync is *actually in flight* — a transient state.

/// Durations. Short enough to feel instant, long enough to be seen.
class Motion {
  Motion._();

  /// A control acknowledging a tap.
  static const fast = Duration(milliseconds: 120);

  /// A value changing, a row settling.
  static const base = Duration(milliseconds: 260);

  /// Something completing — the one place a little length is earned.
  static const slow = Duration(milliseconds: 420);

  /// Stagger between rows entering. Small: nine rows × 40ms is still under
  /// half a second, and an agent should not wait for the UI to finish arriving.
  static const stagger = Duration(milliseconds: 40);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// For a value landing — a touch of overshoot reads as physical.
  static const settle = Curves.easeOutBack;
}

/// Whether the agent has asked the OS to reduce motion, or we are in a context
/// where animation would be noise.
///
/// This is not a nicety: vestibular disorders are common, and a person who has
/// turned motion off has told us something. Everything in this file honours it.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A number that moves to its new value instead of teleporting.
///
/// A count that snaps from 17 to 18 is indistinguishable from a count that did
/// not register the tap at all. This makes the change legible.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.placeholder = '—',
  });

  /// Null renders [placeholder] — "not counted" is not the same as zero.
  final int? value;
  final TextStyle style;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return Text(placeholder, style: style);

    if (reduceMotion(context)) {
      return Text('$v', style: style);
    }

    return TweenAnimationBuilder<double>(
      // Keyed on the value so each change starts a fresh tween from wherever
      // the last one got to.
      tween: Tween(begin: v.toDouble(), end: v.toDouble()),
      duration: Motion.fast,
      builder: (context, _, _) => AnimatedSwitcher(
        duration: Motion.fast,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.86, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Motion.settle),
            ),
            child: child,
          ),
        ),
        child: Text('$v', key: ValueKey(v), style: style),
      ),
    );
  }
}

/// A tick that draws itself when a section is completed.
///
/// Completing a section is the small win an agent gets nine times a visit. It
/// should feel like landing, not like a boolean flipping.
class TickMark extends StatelessWidget {
  const TickMark({super.key, required this.done, this.size = 22, this.color});

  final bool done;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.good;

    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.base,
      curve: Motion.settle,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: done ? c : Colors.transparent,
        shape: BoxShape.circle,
        border: done ? null : Border.all(color: AppColors.ink3, width: 1.5),
      ),
      child: AnimatedScale(
        scale: done ? 1 : 0,
        duration: reduceMotion(context) ? Duration.zero : Motion.base,
        curve: Motion.settle,
        child: Icon(
          Icons.check,
          size: size * 0.6,
          color: const Color(0xFF04210B),
        ),
      ),
    );
  }
}

/// A dot that breathes **only while a sync is actually in flight**.
///
/// Deliberately not tied to "there is pending work": holding captures on the
/// phone is the normal state offline, and a permanently pulsing dot would read
/// as an alarm — and would make `pumpAndSettle` hang in every test that renders
/// an agent screen.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  // Created eagerly, NOT `late final`. A lazily-created controller is first
  // constructed by dispose() when build never touched it (an inactive pulse, or
  // reduced motion) — and building a Ticker against a dead element throws.
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // NOT started here: MediaQuery — and therefore the agent's reduce-motion
    // preference — is not available until didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    final shouldPulse = widget.active && !reduceMotion(context);
    if (shouldPulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!shouldPulse && _c.isAnimating) {
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
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    if (!widget.active || reduceMotion(context)) return dot;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // A halo that swells and fades — the dot itself stays put, so the row
        // never shifts.
        return SizedBox(
          width: 7,
          height: 7,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: 1 + _c.value * 1.9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: dot,
    );
  }
}

/// A row that arrives, rather than simply existing.
///
/// Staggered so the list reads top-to-bottom on first paint — which is the
/// order the agent is going to work in.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });

  final int index;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || reduceMotion(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Motion.stagger * index,
      curve: Interval(
        // Each row starts a little after the one above it, but they all finish
        // together — so the list never feels like it is loading.
        math.min(0.6, index * 0.06),
        1,
        curve: Motion.enter,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// A control that acknowledges the press under the thumb.
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1,
        duration: reduceMotion(context) ? Duration.zero : Motion.fast,
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Physical feedback for the things that matter.
///
/// An agent is looking at a shelf, not at the phone. A tick they can *feel* is
/// worth more than one they have to look down to see.
class Buzz {
  Buzz._();

  /// A count changed.
  static void tick() => HapticFeedback.selectionClick();

  /// Something completed — a section done, a visit submitted.
  static void done() => HapticFeedback.mediumImpact();

  /// A finding was recorded: an out-of-stock. Heavier, because it is heavier —
  /// it raises a task for a manager.
  static void finding() => HapticFeedback.heavyImpact();
}

/// Sliding a section in from the right says "this is a place you went into, and
/// can come back out of" — which is exactly what the hub/section relationship
/// is.
Route<T> agentSectionRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Motion.base,
    reverseTransitionDuration: Motion.fast,
    pageBuilder: (_, _, _) => child,
    transitionsBuilder: (context, animation, secondary, child) {
      if (reduceMotion(context)) return child;
      return SlideTransition(
        position: Tween(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Motion.enter)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
