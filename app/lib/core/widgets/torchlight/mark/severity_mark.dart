import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'tiq_mark.dart';

/// The whole severity vocabulary, in five drawn marks.
///
/// One hue at two commitment levels, plus a silhouette, plus a word — and the
/// one mark that means "nobody measured this".
///
/// ## There is no amber warning in this system
///
/// This is the component that makes that true. Severity never enters the
/// 25–45° band: [critical] and [watch] are the same crimson at two commitment
/// levels (solid and outlined), and the level is carried by the silhouette
/// first, the weight second and the hue third. An amber "warning" would put a
/// severity on the same ladder as the primary commit action and the plate's
/// strip light, which is how a screen ends up with twelve amber objects and no
/// brightest one.
///
/// ## Two of the five are not severities at all
///
/// [held] is Oatmeal and [notMeasured] is ink-3, and both are in this set on
/// purpose: they are the marks a row reaches for *instead* of a severity, and
/// putting them anywhere else is how "queued" and "unscored" get drawn in
/// crimson by somebody in a hurry.
enum SeverityMarkKind {
  /// Something is wrong now. A filled crimson triangle.
  critical,

  /// Something is going wrong. The same triangle outlined with its lower half
  /// filled — a second silhouette, not a paler first one.
  watch,

  /// Fine. A filled green circle.
  onTarget,

  /// Queued. An Oatmeal square (unify §1.13). Not a severity, and not Truffle:
  /// Truffle is the comparison series and giving it a second meaning is
  /// exactly the failure this set avoids.
  held,

  /// Nobody could measure it. A hollow square with a 2dp diagonal bar.
  ///
  /// **Not hatched.** A 12dp square filled with stripes at any period a phone
  /// can draw averages to the flat grey block the hatch exists not to be; the
  /// hatch registry forbids a pattern inside a glyph for that reason. The
  /// hatch belongs on a *track* — see `NotMeasured` — where it can run the
  /// full width and mean something.
  notMeasured,
}

/// The resolved appearance of one [SeverityMarkKind].
@immutable
class SeverityMarkToken {
  const SeverityMarkToken({
    required this.kind,
    required this.word,
    required this.shape,
    required this.ink,
  });

  final SeverityMarkKind kind;

  /// The English default. The word always renders beside the mark; the mark is
  /// never alone.
  final String word;

  final MarkShape shape;
  final Color ink;

  static SeverityMarkToken of(TiqSkin skin, SeverityMarkKind kind) {
    final p = skin.palette;
    return switch (kind) {
      SeverityMarkKind.critical => SeverityMarkToken(
        kind: kind,
        word: 'Critical',
        shape: MarkShape.criticalTriangle,
        ink: p.badSolid,
      ),
      SeverityMarkKind.watch => SeverityMarkToken(
        kind: kind,
        word: 'Watch',
        shape: MarkShape.watchTriangle,
        ink: p.bad,
      ),
      SeverityMarkKind.onTarget => SeverityMarkToken(
        kind: kind,
        word: 'On target',
        shape: MarkShape.onTargetCircle,
        ink: p.good,
      ),
      SeverityMarkKind.held => SeverityMarkToken(
        kind: kind,
        word: 'Held',
        shape: MarkShape.heldSquare,
        ink: p.ink2,
      ),
      SeverityMarkKind.notMeasured => SeverityMarkToken(
        kind: kind,
        word: 'Not measured',
        shape: MarkShape.notMeasuredBarredSquare,
        ink: p.ink3,
      ),
    };
  }
}

/// One severity mark, drawn.
///
/// Static. It never pulses: the pulse means a human is present, and a
/// breathing severity would collide with it.
///
/// ```dart
/// Row(children: [
///   const SeverityMark(kind: SeverityMarkKind.watch),
///   const SizedBox(width: 6),
///   Text(l10n.watch, style: skin.text.label.style(color: skin.palette.ink1)),
/// ])
/// ```
class SeverityMark extends StatelessWidget {
  const SeverityMark({
    super.key,
    required this.kind,
    this.base = 12,
    this.semanticsLabel,
  });

  final SeverityMarkKind kind;

  /// The mark's extent at 1.0×. Meaning-bearing, so it scales with text.
  final double base;

  /// Normally null: the word beside the mark is what a screen reader reads,
  /// and severity is announced first in every row. Pass one only where the
  /// mark genuinely stands alone, which should be nowhere.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final token = SeverityMarkToken.of(skin, kind);
    final mark = TiqMark(
      shape: token.shape,
      color: token.ink,
      size: MarkScale.glyph(context, base),
    );
    if (semanticsLabel == null) return mark;
    return Semantics(label: semanticsLabel, child: mark);
  }
}
