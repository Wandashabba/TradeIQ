import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'tiq_chip.dart';
import 'tiq_mark.dart';

/// The five standings a thing can be in.
///
/// Hue **plus** silhouette **plus** word, bound in one token, so a level
/// cannot be given a colour without also being given a shape and a label —
/// which is the mechanism behind "colour is never the only signal", stated as
/// a type rather than as a review comment.
///
/// There is deliberately no `unknown` member. A grey "Unknown" chip is a claim
/// that the system looked and found nothing; the truth, where a level has not
/// been computed, is that no chip renders and an em dash carries the figure
/// with "not scored" in words beside it (unify §4).
///
/// **There is no amber level and there cannot be one.** "Watch" is the place
/// every designer reaches for amber, and it is crimson at the lower of two
/// commitment levels instead: outline for Watch, solid for Critical. Amber is
/// emitted light and a status is a label.
enum StatusLevel {
  /// Something is wrong now. Solid crimson, filled triangle. Its owning row
  /// also takes the 3px severity bar — which belongs to the row, not here.
  critical,

  /// Something is going wrong. The same crimson, outlined, half-filled
  /// triangle. One hue, one commitment level down, a different silhouette.
  watch,

  /// Fine. Outlined green, filled circle.
  onTarget,

  /// Queued, not failed. Oatmeal (ink-2) square on the well — unify §1.13.
  /// Deliberately not a severity: held work is the normal state of South
  /// African field connectivity, and Truffle is the comparison series and
  /// nothing else.
  held,

  /// A human is in an outlet right now, a tool is executing, a fix is being
  /// sought. A dot and the word.
  ///
  /// The breathing amber pulse that can accompany presence is a separate
  /// emitter on the `TorchScope` ladder, claimed by the surface that owns the
  /// presence (a person row, a day trail). **This chip never emits it**: a
  /// static amber chip is the exact failure the amber law exists to prevent,
  /// and a chip that sometimes lights would make the census depend on which
  /// row scrolled into view.
  live,
}

/// The resolved appearance of one [StatusLevel] in one skin.
@immutable
class StatusLevelToken {
  const StatusLevelToken({
    required this.level,
    required this.word,
    required this.shape,
    required this.ink,
    this.fill,
    this.border,
  });

  final StatusLevel level;

  /// The English default. A localised screen passes its own through
  /// [StatusChip.label]; the word is never absent.
  final String word;

  final MarkShape shape;
  final Color ink;
  final Color? fill;
  final Color? border;

  /// Resolve [level] against [skin].
  ///
  /// Veld takes the same structure with the solid columns and a 2px border —
  /// there is no separate Veld branch here because a skin is a value set, not
  /// a code path, and every difference is already in the palette.
  static StatusLevelToken of(TiqSkin skin, StatusLevel level) {
    final p = skin.palette;
    return switch (level) {
      StatusLevel.critical => StatusLevelToken(
        level: level,
        word: 'Critical',
        shape: MarkShape.criticalTriangle,
        ink: p.onBadSolid,
        fill: p.badSolid,
      ),
      StatusLevel.watch => StatusLevelToken(
        level: level,
        word: 'Watch',
        shape: MarkShape.watchTriangle,
        ink: p.bad,
        border: p.bad,
      ),
      StatusLevel.onTarget => StatusLevelToken(
        level: level,
        word: 'On target',
        shape: MarkShape.onTargetCircle,
        ink: p.good,
        border: p.good,
      ),
      StatusLevel.held => StatusLevelToken(
        level: level,
        word: 'Held',
        shape: MarkShape.heldSquare,
        ink: p.ink2,
        fill: p.well,
        border: p.edgeControl,
      ),
      StatusLevel.live => StatusLevelToken(
        level: level,
        word: 'Live',
        shape: MarkShape.dot,
        ink: p.ink2,
        fill: p.well,
        border: p.edgeControl,
      ),
    };
  }
}

/// The current standing of the thing it sits on.
///
/// Replaces `status_pill_colors.dart` and every pill built on it.
///
/// ```dart
/// StatusChip(
///   level: StatusLevel.watch,
///   detail: l10n.asAt('08:15'),   // staleness is a word, never a fade
/// )
/// ```
///
/// At most one status chip per row. A row that would carry two statuses
/// carries the more severe one and moves the other into its detail.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.level,
    this.label,
    this.detail,
    this.onTap,
    this.semanticsLabel,
  });

  final StatusLevel level;

  /// The localised word. Defaults to the level token's English.
  final String? label;

  /// Hung off the word after a middle dot: `Watch · as at 08:15`,
  /// `Held · 3 visits`. This is where staleness lives — see [TiqChip].
  final String? detail;

  final VoidCallback? onTap;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final token = StatusLevelToken.of(skin, level);
    // The Live dot is smaller than a severity silhouette by declaration
    // (8dp against 12dp) — it is a presence marker, not a verdict.
    final glyphBase = level == StatusLevel.live ? 8.0 : 12.0;
    return TiqChip(
      shape: token.shape,
      label: label ?? token.word,
      detail: detail,
      ink: token.ink,
      fill: token.fill,
      border: token.border,
      glyphBase: glyphBase,
      onTap: onTap,
      semanticsLabel: semanticsLabel,
    );
  }
}
