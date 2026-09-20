import 'package:flutter/material.dart';

import 'tiq_type.dart';

/// The text-scaling policy.
///
/// The audit found no `textScale` handling anywhere in the app, which means
/// the app's behaviour at the OS's largest font setting was whatever the
/// layouts happened to do. The policy has three parts and all three are here:
///
/// 1. **Clamp at [maxScale] = 2.0**, in every density. Not 1.3 or 1.6 — a
///    ceiling below 2.0 on body text is a WCAG 1.4.4 failure wearing a layout
///    argument.
/// 2. **Layouts absorb it.** The hero cluster is a `Wrap` so the delta drops to
///    its own line; a 2×2 stat grid collapses to 1×4 on a `LayoutBuilder` width
///    threshold, not on a scale guess; the hero uses the glyph-count rule and
///    then `FittedBox(fit: BoxFit.scaleDown)`.
/// 3. **One documented exception.** `hero.figure` caps at 1.6, because above
///    that no fitting rule saves a 72px number on a 360dp screen. The cap lives
///    on the token ([TiqTypeToken.maxTextScale]), not in a wrapper, so it is
///    visible to anyone reading the scale.
class TiqTextScale {
  TiqTextScale._();

  /// The app-wide ceiling.
  static const double maxScale = 2.0;

  /// The floor. Below 1.0 the type scale's own optical sizing stops holding.
  static const double minScale = 1.0;

  /// Clamp an ambient scaler to the app policy.
  static TextScaler clamp(TextScaler scaler) =>
      scaler.clamp(minScaleFactor: minScale, maxScaleFactor: maxScale);

  /// The scaler a given role should be painted at: the app clamp, further
  /// capped by the role's own [TiqTypeToken.maxTextScale] if it declares one.
  static TextScaler forToken(TextScaler ambient, TiqTypeToken token) {
    final clamped = clamp(ambient);
    final cap = token.maxTextScale;
    if (cap == null) return clamped;
    return clamped.clamp(minScaleFactor: minScale, maxScaleFactor: cap);
  }

  /// The resolved font size for [token] under [ambient] — what a test should
  /// assert on, and what the hero fitting rule measures against.
  static double sizeOf(TextScaler ambient, TiqTypeToken token) =>
      forToken(ambient, token).scale(token.size);
}

/// Applies the app-wide clamp to everything beneath it.
///
/// Wrap it around the app once, in `MaterialApp.builder`. It is deliberately
/// *not* a `TextScaler.linear(1.0)` lock: a clamp still lets a reader who
/// needs 180% text have 180% text.
class TiqTextScaleScope extends StatelessWidget {
  const TiqTextScaleScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TiqTextScale.clamp(media.textScaler)),
      child: child,
    );
  }
}

/// Paints one role at its own capped scale.
///
/// Used for `hero.figure` and nothing else today. It re-reads the ambient
/// scaler rather than assuming [TiqTextScaleScope] ran, so it is correct in a
/// widget test that pumps a bare `MediaQuery`.
class TiqRoleTextScale extends StatelessWidget {
  const TiqRoleTextScale({required this.token, required this.child, super.key});

  final TiqTypeToken token;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TiqTextScale.forToken(media.textScaler, token),
      ),
      child: child,
    );
  }
}
