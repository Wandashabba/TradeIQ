/// PRESS, FOCUS AND HAPTICS — the three feedback channels, defined once.
///
/// Every pressable thing in the Torchlight Aisle goes through
/// [TorchPressable]. Before this existed, "pressed" was an `InkWell` splash in
/// one file, an `AnimatedScale` in another and a colour swap with an opacity
/// multiplier in thirty more — which is how a state channel that the design
/// bans (opacity) survived three audits.
///
/// **Press is two channels, never one.** A scale to 0.98 (0.94 for a glyph-only
/// target) at 120ms, *plus* a fill change to a declared token. Under
/// reduce-motion the scale is dropped and only the fill changes, so the
/// component that presses must always change its fill — a press that was only
/// a scale would be invisible to the readers who most need it.
///
/// **Focus is a ring, and only for a keyboard.** 2px flame-700 at a 2dp offset
/// outside the control's own border in Night (10.38:1 on surface); 2px ink-1 at
/// 2dp in Day; 3px ink-1 at 3dp in Veld, where a 1.79:1 amber ring is simply
/// not there. It renders only under `FocusHighlightMode.traditional` — keyboard,
/// switch access or a D-pad — and never on a touch tap. The Night ring is the
/// one amber the ladder does not count, by declaration: it never co-occurs with
/// a touch frame and never appears for a touch user.
///
/// **Four things vibrate and nothing else.** [TorchBuzz].
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';

/// Physical feedback for the four things that are allowed to vibrate.
///
/// An agent is looking at a shelf, not at the phone. A tick they can *feel* is
/// worth more than one they have to look down to see — and a phone that buzzes
/// at everything is a phone with haptics switched off.
class TorchBuzz {
  TorchBuzz._();

  /// Every ordinary selection, step and press.
  static void tick() => HapticFeedback.selectionClick();

  /// A completed commit. Light, doubled by the platform.
  static void success() => HapticFeedback.lightImpact();

  /// A destructive first press, and a failure toast.
  static void warning() => HapticFeedback.mediumImpact();

  /// A zero that is a finding — it raises a task for a manager, so it is
  /// heavier than the tick that recorded it.
  static void finding() => HapticFeedback.heavyImpact();
}

/// The fill and ink a control takes while it is held down.
@immutable
class TorchPressSurface {
  const TorchPressSurface({required this.fill, required this.ink});

  final Color fill;
  final Color ink;
}

/// The press surface for a control that has no fill of its own — a ghost
/// button, an icon button, a nav slot.
///
/// Night steps **up** to `lifted`, Day steps **down** to `well`, and Veld —
/// which has no fill steps at all, every one of its surface tokens being white
/// — inverts to the ink block with white on it. That inversion is the same one
/// the palette already reaches for in [TiqPalette.veld]'s `amberPressed`, and
/// for the same reason: outdoors there is no glow, no shadow and no gradient to
/// spend, so the only press cue Veld can afford is the one that swaps ground
/// for ink.
TorchPressSurface torchPressSurface(TiqSkin skin) => switch (skin.mode) {
  SkinMode.day => TorchPressSurface(
    fill: skin.palette.well,
    ink: skin.palette.ink1,
  ),
  SkinMode.veld => TorchPressSurface(
    fill: skin.palette.lifted,
    ink: torchOnAbyssal(skin),
  ),
  _ => TorchPressSurface(fill: skin.palette.lifted, ink: skin.palette.ink1),
};

/// THE ABYSSAL BLOCK — the one non-amber way this system says "this one".
///
/// A selected nav slot on a light ground, a toggled-on icon button in every
/// skin, the pressed state of a Veld control. It is `lifted` in all three
/// skins, which is not a coincidence: the token's own doc comment says it is
/// "the ink block behind an active nav slot" on Day, and Veld collapses every
/// other surface onto white precisely so that this one can stay ink.
Color torchAbyssal(TiqSkin skin) => skin.palette.lifted;

/// The ink that goes **on** an Abyssal block.
///
/// [TiqSkin.onFill] cannot answer this and should not be taught to: `lifted` is
/// a dark *ground* in Night, where ink-1 belongs on it, and a dark *ink block*
/// in Day and Veld, where the skin's own ink-1 would be invisible on it. So the
/// answer is Palladian in Night and Day (9.43:1 on `#2C3B4D` — the figure the
/// nav's Day form is specified at) and white in Veld (15.33:1 on `#1B2632`).
/// Both are existing tokens read from a sibling palette, not new hexes.
Color torchOnAbyssal(TiqSkin skin) => switch (skin.mode) {
  SkinMode.day => TiqPalette.night.ink1, // Palladian
  SkinMode.veld => TiqPalette.veld.ground, // white
  _ => skin.palette.ink1,
};

/// Scale for a control-sized target: a button, a row, a nav slot.
const double torchPressScaleControl = 0.98;

/// Scale for a glyph-only target: an icon button, a nav glyph.
const double torchPressScaleGlyph = 0.94;

/// The gesture, the scale, the haptic and the keyboard focus ring.
///
/// It draws no fill of its own — the component does, because only the component
/// knows whether it is a ghost, a block or a circle. [builder] is handed the
/// pressed flag and returns the whole visual.
///
/// ```dart
/// TorchPressable(
///   onPressed: enabled ? _commit : null,
///   borderRadius: BorderRadius.circular(skin.radii.control),
///   builder: (context, pressed) => DecoratedBox(
///     decoration: BoxDecoration(color: pressed ? press.fill : null),
///     child: …,
///   ),
/// )
/// ```
class TorchPressable extends StatefulWidget {
  const TorchPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.pressScale = torchPressScaleControl,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.haptic,
    this.debounce = Duration.zero,
    this.onLongPress,
    this.focusNode,
  });

  /// Null disables the control. A disabled control is **never focusable and
  /// never pressable** — it is skipped in the focus order rather than focused
  /// and then refused.
  final VoidCallback? onPressed;

  final Widget Function(BuildContext context, bool pressed) builder;

  /// 0.98 for a control, 0.94 for a glyph. Dropped entirely when the frame is
  /// [MotionBudget.still].
  final double pressScale;

  /// The control's own radius. The focus ring follows it, one step out.
  final BorderRadius? borderRadius;

  /// [BoxShape.circle] for the nav circle; the ring follows.
  final BoxShape shape;

  /// Defaults to [TorchBuzz.tick]. A destructive first press passes
  /// [TorchBuzz.warning].
  final VoidCallback? haptic;

  /// Swallow a second tap inside this window. The primary commit action sets
  /// 400ms, because the cost of a double-tapped commit is a duplicate visit.
  final Duration debounce;

  final VoidCallback? onLongPress;

  final FocusNode? focusNode;

  @override
  State<TorchPressable> createState() => _TorchPressableState();
}

class _TorchPressableState extends State<TorchPressable> {
  bool _pressed = false;
  bool _focused = false;
  bool _keyboardHighlight =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
  DateTime? _lastFired;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard == _keyboardHighlight || !mounted) return;
    setState(() => _keyboardHighlight = keyboard);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _fire() {
    final callback = widget.onPressed;
    if (callback == null) return;
    final now = DateTime.now();
    final last = _lastFired;
    if (widget.debounce > Duration.zero &&
        last != null &&
        now.difference(last) < widget.debounce) {
      return;
    }
    _lastFired = now;
    (widget.haptic ?? TorchBuzz.tick)();
    callback();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.onPressed == null) return KeyEventResult.ignored;
    final isActivate =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isActivate) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _setPressed(true);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _setPressed(false);
      _fire();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final enabled = widget.onPressed != null;
    final still = MotionBudget.of(context).still;

    Widget child = widget.builder(context, _pressed && enabled);

    // Two channels, and the fill is the one that survives reduce-motion. The
    // scale is the second, not the first.
    if (!still && widget.pressScale != 1) {
      child = AnimatedScale(
        scale: _pressed && enabled ? widget.pressScale : 1,
        duration: skin.motion.resolve(TiqMotion.press),
        curve: TiqMotion.stateCurve,
        child: child,
      );
    }

    if (_focused && _keyboardHighlight && enabled) {
      final ring = torchFocusRing(skin);
      child = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          child,
          Positioned(
            left: -ring.offset,
            top: -ring.offset,
            right: -ring.offset,
            bottom: -ring.offset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: widget.shape,
                  borderRadius: widget.shape == BoxShape.circle
                      ? null
                      : _ringRadius(widget.borderRadius, ring.offset),
                  border: Border.all(color: ring.color, width: ring.width),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: enabled,
      skipTraversal: !enabled,
      onKeyEvent: _onKey,
      onFocusChange: (value) {
        if (!mounted) return;
        setState(() => _focused = value);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled ? _fire : null,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }

  /// The ring sits [offset] outside the control, so its radius is the
  /// control's plus that offset — otherwise a 999 pill gets a ring with square
  /// shoulders.
  static BorderRadius? _ringRadius(BorderRadius? radius, double offset) {
    if (radius == null) return null;
    Radius grow(Radius r) => Radius.elliptical(r.x + offset, r.y + offset);
    return BorderRadius.only(
      topLeft: grow(radius.topLeft),
      topRight: grow(radius.topRight),
      bottomLeft: grow(radius.bottomLeft),
      bottomRight: grow(radius.bottomRight),
    );
  }
}

/// The keyboard focus ring for a skin.
@immutable
class TorchFocusRing {
  const TorchFocusRing({
    required this.color,
    required this.width,
    required this.offset,
  });

  final Color color;
  final double width;
  final double offset;
}

/// Night is amber and exempt; Day and Veld are ink, because an amber ring on a
/// light ground measures 1.79:1 and is a decoration pretending to be a state.
TorchFocusRing torchFocusRing(TiqSkin skin) => switch (skin.mode) {
  SkinMode.veld => TorchFocusRing(
    color: skin.palette.ink1,
    width: 3,
    offset: 3,
  ),
  SkinMode.day => TorchFocusRing(color: skin.palette.ink1, width: 2, offset: 2),
  _ => TorchFocusRing(color: skin.palette.flame700, width: 2, offset: 2),
};
