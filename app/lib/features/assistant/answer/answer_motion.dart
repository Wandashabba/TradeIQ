import 'package:flutter/material.dart';

import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_motion.dart';

/// Motion for the answer, after the approved "livelier Ask TradeIQ" mockup.
///
/// Three rules:
///
/// * **Reduced motion renders the final state on the first frame.** No tween
///   is built at all, so there is nothing to wait for.
/// * **Motion never holds back words.** Text is painted the frame its token
///   lands; only its block's position eases. The staggered, delayed entrances
///   are for figures and marks, which are not readable until drawn anyway.
/// * **Nothing loops once the turn is over.** The caret blinks only while the
///   answer is streaming, so `pumpAndSettle` settles on a finished transcript.

/// The mockup's `cubic-bezier(.2,.8,.2,1)`: quick out, long settle.
const answerCurve = Cubic(0.2, 0.8, 0.2, 1);

/// A block fading and rising into place as it arrives.
///
/// [enabled] is latched at mount: a list row rebuilt when scrolled back into
/// view mounts with `enabled: false` and is simply there.
class Arrive extends StatefulWidget {
  const Arrive({
    super.key,
    required this.child,
    this.enabled = true,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = 10,
    this.fromOpacity = 0,
  });

  final Widget child;
  final bool enabled;
  final Duration delay;
  final Duration duration;

  /// How far below its place the block starts, in logical pixels.
  final double offset;

  /// Where the fade starts. Text blocks start partly visible, so a word is
  /// legible the moment it lands.
  final double fromOpacity;

  @override
  State<Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<Arrive> {
  late final bool _animate = widget.enabled;
  bool _spent = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.delay + widget.duration;
    if (!_animate || _spent || total <= Duration.zero) return widget.child;
    if (reduceMotion(context)) {
      _spent = true;
      return widget.child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        widget.delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: answerCurve,
      ),
      // No `onEnd` swap to the bare child: dropping the wrappers would
      // remount the subtree, restarting a count-up or losing a selection.
      builder: (context, t, child) => Opacity(
        opacity: widget.fromOpacity + (1 - widget.fromOpacity) * t,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - t)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A 0 → 1 progress for a mark that grows (a bar, a meter), or 1 immediately
/// under reduced motion.
class GrowIn extends StatelessWidget {
  const GrowIn({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 800),
    this.delay = Duration.zero,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return builder(context, 1);
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: answerCurve,
      ),
      builder: (context, t, _) => builder(context, t),
    );
  }
}

/// The text caret at the end of an answer still being written.
class StreamingCaret extends StatefulWidget {
  const StreamingCaret({super.key, this.height = 15});

  final double height;

  @override
  State<StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A steady caret under reduced motion: it still says "more is coming".
    if (reduceMotion(context)) {
      _blink.stop();
      _blink.value = 0;
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = colors.glass ? context.lumen.accentSolid : colors.brand;
    return Semantics(
      label: 'Still writing',
      child: AnimatedBuilder(
        animation: _blink,
        // steps(1): fully on for the first half, fully off for the second.
        builder: (context, child) =>
            Opacity(opacity: _blink.value < 0.5 ? 1 : 0, child: child),
        child: Container(
          key: const ValueKey('streaming-caret'),
          width: 2,
          height: widget.height,
          margin: const EdgeInsets.only(left: 2),
          color: color,
        ),
      ),
    );
  }
}
