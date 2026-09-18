import 'package:flutter/widgets.dart';

import '../theme/torchlight/tiq_skin.dart';

/// Whether this frame moves at all — **one** boolean, resolved from three
/// inputs, read by every animated thing in the app.
///
/// The design says motion is off under reduce-motion, in Veld and in battery
/// saver. Before this existed each of those was checked (or not checked) by
/// each widget separately: the audit found four ambient loops, two of which
/// honoured `disableAnimations` and none of which knew about Veld. A single
/// boolean is the only version of that sentence that can be true.
///
/// ```dart
/// if (MotionBudget.of(context).still) {
///   // paint the resting frame: a filled square and the word "Live"
/// } else {
///   // run the 3200ms pulse
/// }
/// ```
///
/// Durations do not need this — `skin.motion.resolve(d)` already returns
/// `Duration.zero` when a skin's motion is off. [MotionBudget] is for the
/// decisions a duration cannot express: whether to start a `Ticker` at all,
/// whether to subscribe to the app-wide loop, and which of two *different*
/// renderings to paint (a breathing dot versus a square plus a word).
@immutable
class MotionBudget {
  const MotionBudget({
    required this.disableAnimations,
    required this.veld,
    required this.powerSave,
  });

  /// `MediaQuery.disableAnimationsOf(context)` — the platform's reduce-motion
  /// switch.
  final bool disableAnimations;

  /// Veld kills every ambient loop: outdoors, motion is glare that moves.
  final bool veld;

  /// Battery saver.
  ///
  /// **There is no channel for this yet.** Reading the OS power-save state
  /// needs roughly forty lines of platform code on each of Android and iOS,
  /// and that work is #407. Until it lands this input is wired as
  /// `const false` — deliberately, and here in the open, so that the sentence
  /// "motion stops in battery saver" is a promise with a ticket number
  /// attached rather than a lie in a design document.
  ///
  /// TODO(#407): replace [powerSave] with the real platform channel. When it
  /// lands, `MotionBudget.of` reads it and nothing else in the app changes —
  /// that is the point of there being one boolean.
  final bool powerSave;

  /// The answer. Anything that moves asks this and nothing else.
  bool get still => disableAnimations || veld || powerSave;

  /// The reason, for a test failure message or a debug overlay.
  String get reason {
    if (!still) return 'motion on';
    return <String>[
      if (disableAnimations) 'reduce-motion',
      if (veld) 'Veld',
      if (powerSave) 'battery saver',
    ].join(' + ');
  }

  /// Resolve from the ambient `MediaQuery` and skin.
  ///
  /// A [MotionBudgetScope] ancestor wins if there is one — that is how a test
  /// or a Phase 1 golden pins a budget without faking a platform. There is no
  /// scope in the running app, on purpose: adding one would be a widget in the
  /// tree that could be forgotten, and this is a value that can always be
  /// computed.
  static MotionBudget of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MotionBudgetScope>();
    if (scope != null) return scope.budget;
    return MotionBudget(
      disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      veld: !context.skin.motion.enabled,
      // TODO(#407): no power-save channel exists yet. See [powerSave]. This
      // is `false` and not a guess; when #407 lands it becomes the real read
      // and every animated widget in the app inherits the fix for free.
      powerSave: false,
    );
  }

  /// Everything moves. The default a widget assumes with no context.
  static const MotionBudget moving = MotionBudget(
    disableAnimations: false,
    veld: false,
    powerSave: false,
  );

  /// Nothing moves.
  static const MotionBudget frozen = MotionBudget(
    disableAnimations: true,
    veld: false,
    powerSave: false,
  );

  @override
  bool operator ==(Object other) =>
      other is MotionBudget &&
      other.disableAnimations == disableAnimations &&
      other.veld == veld &&
      other.powerSave == powerSave;

  @override
  int get hashCode => Object.hash(disableAnimations, veld, powerSave);

  @override
  String toString() => 'MotionBudget(still: $still — $reason)';
}

/// Pins a [MotionBudget] for a subtree. Tests and goldens only.
class MotionBudgetScope extends InheritedWidget {
  const MotionBudgetScope({
    super.key,
    required this.budget,
    required super.child,
  });

  final MotionBudget budget;

  @override
  bool updateShouldNotify(MotionBudgetScope oldWidget) =>
      oldWidget.budget != budget;
}
