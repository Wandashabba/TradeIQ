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

  /// ## SEVEN MEMBERS, NO OUTLINES
  ///
  /// The easiest of the three families to argue, because it was designed for
  /// exactly this: **six of the seven already share one treatment and are
  /// told apart by silhouette and word alone**, with no colour difference
  /// between them at all. Deleting a border they all carry equally cannot
  /// separate them any less than it already does — the border was never a
  /// channel here, it was a container.
  ///
  /// So the per-member argument is short:
  ///
  /// - **Out of fence, For review, Unfinished, Skipped, Held, No GPS** — one
  ///   neutral fill, ink-2 at 8.93:1 (Night) / 8.50:1 (Day), and six distinct
  ///   drawn silhouettes plus six words. Unchanged in every channel but the
  ///   corner and the line.
  /// - **Sent back** — the one severity, and it was the one bare outline. It
  ///   is a crimson wash now, ink at 5.14:1 / 6.26:1, with the return-arrow
  ///   silhouette and the word. It reads apart from the six on hue, on fill
  ///   and on shape.
  /// - **Cleared** (a modifier, not a member) — ink-2 drops to ink-3 and the
  ///   word "Cleared" is appended. Its border was `edge-control`, the same
  ///   border the six already had, so it never distinguished anything; the
  ///   appended word always did. ink-3 on the new fill is 6.02:1 / 5.48:1,
  ///   which is **better** than the 6.79:1 / 4.52:1 it had on `well` in the
  ///   skin that was close to the floor.
  static FlagKindToken of(TiqSkin skin, FlagKind kind) {
    final p = skin.palette;
    // The neutral treatment, shared by six of the seven: fill `raised`,
    // no border, ink-2 label and glyph.
    //
    // `well` → `raised` for the reason `StatusLevelToken.held` gives at
    // length: a neutral wash would put ink-3 on a darkened Day well, and
    // `ink-3 on well` is already the tightest pairing in the Day set at
    // 4.52:1. `raised` is more visible on Night (1.19:1 against 1.06:1) and
    // safer on Day (5.48:1 against 4.52:1) — both directions improve.
    FlagKindToken neutral(String word, MarkShape shape) => FlagKindToken(
      kind: kind,
      word: word,
      shape: shape,
      ink: p.ink2,
      fill: p.raised,
    );
    return switch (kind) {
      FlagKind.outOfFence => neutral('Out of fence', MarkShape.flagBrokenRing),
      FlagKind.forReview => neutral('For review', MarkShape.flagEyeBarred),
      FlagKind.unfinished => neutral(
        'Unfinished',
        MarkShape.flagThreeQuarterArc,
      ),
      FlagKind.skipped => neutral('Skipped', MarkShape.flagStruckRing),
      FlagKind.held => neutral('Held', MarkShape.heldSquare),
      FlagKind.noGps => neutral('No GPS', MarkShape.flagPinWithGap),
      FlagKind.sentBack => FlagKindToken(
        kind: kind,
        word: 'Sent back',
        shape: MarkShape.flagReturnArrow,
        ink: p.bad,
        fill: torchChipWash(skin, p.bad),
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
    final detailParts = <String>[?detail, if (cleared) clearedWord];
    return TiqChip(
      shape: token.shape,
      label: word,
      detail: detailParts.isEmpty ? null : detailParts.join(' · '),
      ink: cleared ? skin.palette.ink3 : token.ink,
      // A CLEARED FLAG IS NEUTRAL, INCLUDING ITS FILL.
      //
      // The old rule swapped the *border* to `edge-control` when cleared,
      // which for six of the seven was the border they already had and did
      // nothing; the one place it did something was Sent back, where it
      // stopped the chip being crimson-edged. That job now belongs to the
      // fill, and it has to: ink-3 on the crimson wash measures **4.28:1 on
      // Day**, under the 4.5 floor. On the neutral fill it is 5.48:1.
      //
      // Which is the answer the meaning wanted anyway. A flag somebody has
      // resolved is not a severity any more, so it should not be sitting in
      // severity's colour with the label faded out on top of it.
      fill: cleared ? skin.palette.raised : token.fill,
      border: token.border,
      glyphBase: 14,
      onTap: onTap,
      semanticsLabel: semanticsLabel,
    );
  }
}
