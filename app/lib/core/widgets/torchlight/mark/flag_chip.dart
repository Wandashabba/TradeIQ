import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'tiq_chip.dart';
import 'tiq_mark.dart';

/// Facts about how a piece of work was produced (#393).
///
/// **Six neutral members and one severity.** A flag is not a verdict: out of
/// fence is a measurement, unfinished is an arithmetic, no GPS is a fact about
/// a radio. Colouring any of those crimson tells an agent they did something
/// wrong when what happened is that a fence is drawn at 100 m and the loading
/// bay is at 140. Unify §1.6 settles it: **flag chips are never crimson** —
/// except [sentBack], where a human read the work and rejected it, which is a
/// verdict and is the only one.
///
/// The family is identified by its uniform neutral treatment and the members
/// by glyph and word, which means the whole family is legible in greyscale by
/// construction: six different silhouettes with no colour difference between
/// them at all.
enum FlagKind {
  /// The check-in landed outside the geofence. The distance is the detail:
  /// `Out of fence · 140 m`.
  outOfFence,

  /// A reviewer has this record open.
  forReview,

  /// The visit closed with sections uncaptured. The fraction is the detail:
  /// `Unfinished · 6/9`.
  unfinished,

  /// A section was skipped, with a reason.
  skipped,

  /// Queued, waiting for a network. Not a severity, for the same reason the
  /// Held status level is not one.
  held,

  /// No position fix was available.
  noGps,

  /// **The one severity flag.** A human rejected the work and sent it back.
  /// Crimson at the outlined commitment level, because it is a standing fact
  /// about the record rather than something failing right now.
  sentBack,
}

/// The resolved appearance of one [FlagKind].
@immutable
class FlagKindToken {
  const FlagKindToken({
    required this.kind,
    required this.word,
    required this.shape,
    required this.ink,
    this.fill,
    this.border,
  });

  final FlagKind kind;
  final String word;
  final MarkShape shape;
  final Color ink;
  final Color? fill;
  final Color? border;

  /// Whether this member carries severity. True for exactly one of the seven,
  /// and `flag_chip_test.dart` asserts that it stays one.
  bool get isSeverity => kind == FlagKind.sentBack;

  static FlagKindToken of(TiqSkin skin, FlagKind kind) {
    final p = skin.palette;
    // The neutral treatment, shared by six of the seven: fill `well`, a 1px
    // `edge-control` border, ink-2 label and glyph. `edge-structure` is not
    // used here because on the Day well it measures 2.99:1.
    FlagKindToken neutral(String word, MarkShape shape) => FlagKindToken(
      kind: kind,
      word: word,
      shape: shape,
      ink: p.ink2,
      fill: p.well,
      border: p.edgeControl,
    );
    return switch (kind) {
      FlagKind.outOfFence => neutral('Out of fence', MarkShape.flagBrokenRing),
      FlagKind.forReview => neutral('For review', MarkShape.flagEyeBarred),
      FlagKind.unfinished =>
        neutral('Unfinished', MarkShape.flagThreeQuarterArc),
      FlagKind.skipped => neutral('Skipped', MarkShape.flagStruckRing),
      FlagKind.held => neutral('Held', MarkShape.heldSquare),
      FlagKind.noGps => neutral('No GPS', MarkShape.flagPinWithGap),
      FlagKind.sentBack => FlagKindToken(
        kind: kind,
        word: 'Sent back',
        shape: MarkShape.flagReturnArrow,
        ink: p.bad,
        border: p.bad,
      ),
    };
  }
}

/// One flag chip.
///
/// ```dart
/// FlagChip(kind: FlagKind.outOfFence, detail: '140 m', onTap: openTheMap)
/// ```
///
/// Every flag chip should be tappable to its explanation: a flag the agent
/// cannot interrogate is an accusation. Where a flag carries a real
/// consequence, the consequence is expressed on the owning row's severity bar
/// and reason line — never by recolouring the chip. That is the rule that
/// keeps the family readable: one treatment, seven meanings, escalation held
/// elsewhere.
class FlagChip extends StatelessWidget {
  const FlagChip({
    super.key,
    required this.kind,
    this.label,
    this.detail,
    this.cleared = false,
    this.clearedWord = 'Cleared',
    this.onTap,
    this.semanticsLabel,
  });

  final FlagKind kind;

  /// The localised word. Defaults to the kind token's English.
  final String? label;

  /// The measured part: `140 m`, `6/9`, a reason, a count. Set in the same run
  /// as the word after a middle dot.
  final String? detail;

  /// A flag that has been resolved. The ink drops one declared step to ink-3
  /// and the word "Cleared" is appended; it renders for one session, then
  /// stops.
  ///
  /// It is a token step and an appended word rather than the 0.6 opacity the
  /// first draft used, because opacity is banned as a state channel — a
  /// contrast walk cannot see it and the resulting pair measured 3.29:1. The
  /// 1.5px strike a later draft proposed is also gone: a 1.5px line at 40%
  /// backlight vanishes, and a struck label reads as an error the agent made
  /// rather than a flag somebody cleared.
  final bool cleared;

  final String clearedWord;

  final VoidCallback? onTap;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final token = FlagKindToken.of(skin, kind);
    final word = label ?? token.word;
    final detailParts = <String>[
      ?detail,
      if (cleared) clearedWord,
    ];
    return TiqChip(
      shape: token.shape,
      label: word,
      detail: detailParts.isEmpty ? null : detailParts.join(' · '),
      ink: cleared ? skin.palette.ink3 : token.ink,
      fill: token.fill,
      border: cleared ? skin.palette.edgeControl : token.border,
      glyphBase: 14,
      onTap: onTap,
      semanticsLabel: semanticsLabel,
    );
  }
}
