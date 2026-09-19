import 'package:flutter/widgets.dart';

/// WHICH HAND HOLDS THE PHONE — #407.
///
/// One preference, published as an [InheritedWidget], read by every control
/// whose layout has a near edge and a far one. Today that is the count
/// stepper; the skin cycle and the thumb zone are the obvious next two.
///
/// It defaults to [TorchHandedness.right] because roughly nine in ten people
/// are right-handed, and it is a **preference** rather than a guess: nothing
/// in this app infers handedness from tap coordinates. An agent who is told
/// their phone has been watching where their thumb lands has been told
/// something true and unpleasant, for a 56dp gain.
///
/// The value comes from the per-user preferences table that unify's open
/// question 13 asks for — the same table the collapsed plate and Veld memory
/// are waiting on. Until it exists, a screen may set it from local storage
/// and the default stands.
enum TorchHandedness {
  /// The stepper's `[−][+]` pair sits at the **trailing** edge, under a right
  /// thumb. The arrangement of every till and fuel pump in the country.
  right,

  /// Mirrored: the pair sits at the leading edge.
  left;

  /// Whether a control should mirror itself for this preference.
  bool get mirrored => this == TorchHandedness.left;
}

/// Publishes the preference to everything beneath it. One per app, usually at
/// the shell.
class TorchHandednessScope extends InheritedWidget {
  const TorchHandednessScope({
    super.key,
    required this.handedness,
    required super.child,
  });

  final TorchHandedness handedness;

  /// The ambient preference, or [TorchHandedness.right] outside a scope.
  /// Right-handed is the default and it is not an error to be outside a scope:
  /// a component in a Phase 2 golden has no app around it.
  static TorchHandedness of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TorchHandednessScope>()
          ?.handedness ??
      TorchHandedness.right;

  @override
  bool updateShouldNotify(TorchHandednessScope oldWidget) =>
      oldWidget.handedness != handedness;
}
