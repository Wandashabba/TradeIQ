import 'package:flutter/painting.dart';

import '../../../design/tiq_number.dart' show FigureState;
import '../../../theme/torchlight/tiq_skin.dart';
import '../mark/severity_mark.dart';
import '../mark/status_chip.dart';

/// WHERE A FIGURE STANDS, AND THE INK THAT SAYS SO.
///
/// The owner's rule, 28 September 2026, looking at The Floor on Palladian:
/// *"nothing on the screen tells you at a glance whether a number is good or
/// bad"*. This file is that rule made into one function, so that "when may a
/// figure be coloured" has a single answer instead of seven call sites each
/// deciding for themselves.
///
/// ## The rule
///
/// **A figure carries colour only where it carries a judgement.** A judgement
/// needs something to be judged against — a published standard, a configured
/// target, a server-stated sentiment. Where there is no target there is no
/// judgement, and the figure stays in plain ink. A figure is not coloured to
/// brighten a screen.
///
/// Three consequences, all enforced by [standingInk] rather than remembered:
///
/// 1. **A figure that cannot be judged is never coloured.** Missing, not
///    measured, provisional and low-sample all return null, so the em dash
///    stays ink-3 and a thin figure stays one ink step down. That is unify §4
///    and it outranks the standing.
/// 2. **The word grade, never the mark grade.** `good` and `bad` carry text at
///    4.5:1 on every fill in every skin; `goodSolid` and `badSolid` are fills
///    and do not (Night `badSolid` is 4.09:1 on `surface`). A figure therefore
///    takes one crimson whichever commitment level it is at — the *mark*
///    beside it is what carries the level, by fill against outline.
/// 3. **Colour is never the only signal.** Nothing here produces a colour on
///    its own: every caller already prints the standing as a word, a severity
///    mark, a target on the meta line, or a triangle. This function only says
///    which ink, never whether the reader is told.
///
/// Amber is not in this file and cannot be: amber marks the expected next
/// move. Green and crimson carry judgement; amber does not.
///
/// ## The fourth consequence, added 29 September 2026: the ground gets a vote
///
/// Everything above still holds. What changed is that "may this figure be
/// coloured" now has a second question after it — *on this ground?* — and the
/// answer is [TiqSkin.standingColoursFigures]. See [FigureRank] and the
/// reversal recorded on [severityInk].

/// On the standard, within [watchBand] of it, or breaching it.
///
/// Lifted out of the Execution overview so The Floor can read a figure against
/// the same published standard the overview does — a score of 73 is not
/// "watch" on one screen and plain ink on another.
StatusLevel againstStandard(
  double value,
  double target, {
  double watchBand = 10,
}) => value >= target
    ? StatusLevel.onTarget
    : value >= target - watchBand
    ? StatusLevel.watch
    : StatusLevel.critical;

/// The severity mark a standing maps onto, or null where it draws none.
///
/// `onTarget` is not a severity, so a figure meeting its standard draws **no
/// mark** — the word on the meta line is what says so. It still takes the
/// green ink from [standingInk]: an absent mark is not an absent verdict.
SeverityMarkKind? severityFor(StatusLevel level) => switch (level) {
  StatusLevel.critical => SeverityMarkKind.critical,
  StatusLevel.watch => SeverityMarkKind.watch,
  _ => null,
};

/// WHAT A FIGURE IS ON ITS SCREEN — and, on Night, whether it may be crimson.
///
/// The distinction only bites where [TiqSkin.standingColoursFigures] is false.
/// On paper both ranks take their verdict's ink exactly as they always have.
enum FigureRank {
  /// One figure among several of its kind: a row's trailing value, an
  /// indicator's rate, a cell in a cluster. **Never coloured on Night.** The
  /// artifact's `.srow .val` is bone while the dot beside it is crimson, and
  /// that is the whole reading: the dot carries the verdict, the figure
  /// carries the number.
  row,

  /// The one figure a screen is *about* — the headline of a panel, where the
  /// number IS the answer to the question the screen asked.
  ///
  /// On Night a headline keeps crimson **only at [StatusLevel.critical]**, and
  /// nothing else does. The artifact draws exactly one such figure: Ask's
  /// `−43,6%`, crimson, beside a `481 615` that is bone. A watch-band headline
  /// is not that, and neither is a hero — §16.2 already rules that a hero is
  /// ink-1 at every band, because a figure large enough for its colour to read
  /// as the whole message must not have one.
  headline,
}

/// The ink a figure takes from its standing, or **null for plain ink**.
///
/// Null is the common answer and the safe one: a caller passes the result
/// straight into `FigureSlot.color`, where null means "the state decides",
/// which is exactly the treatment an unjudged figure should get.
Color? standingInk(
  TiqSkin skin,
  StatusLevel? level, {
  FigureState state = FigureState.measured,
  FigureRank rank = FigureRank.row,
}) {
  // A figure that cannot be judged is never coloured — the em dash, the
  // never-measured cell, the thin sample and the provisional all keep the ink
  // their own state gives them. This check is first on purpose: a standing
  // computed from a value the screen is not confident in is a verdict the
  // screen has not earned.
  if (state != FigureState.measured) return null;
  // THE GROUND'S VOTE. On a near-black ground a figure is luminous bone and
  // the verdict is somewhere else; on paper it is the verdict. See
  // [TiqSkin.standingColoursFigures] for why, and [severityInk] for the
  // instruction that reversed this.
  if (!skin.standingColoursFigures) {
    return rank == FigureRank.headline && level == StatusLevel.critical
        ? skin.palette.bad
        : null;
  }
  return switch (level) {
    // One crimson for both commitment levels. The level is carried by the
    // mark beside the figure — a filled dot against an outlined one — because
    // `badSolid` is a fill grade and fails 4.5:1 as a word on Night's
    // `surface`.
    StatusLevel.critical || StatusLevel.watch => skin.palette.bad,
    StatusLevel.onTarget => skin.palette.good,
    // Held and Live are not verdicts and must never be mistaken for one.
    StatusLevel.held || StatusLevel.live || null => null,
  };
}

/// The ink a figure takes from the severity its own row is already showing.
///
/// ## A REVERSAL, ON THE RECORD. Do not re-apply the 28 September rule.
///
/// Both instructions below are the same owner's, one day apart, and the second
/// overrides the first **on Night only**. The first is kept here in full,
/// because deleting it is how it comes back: somebody reads a row of bone
/// figures beside crimson dots in six months, has exactly the thought the
/// owner had on 28 September, and undoes this.
///
/// **28 September 2026 — the rule this function was written for:**
///
/// > *"severity figures on rows should match the row's own severity mark
/// > rather than sitting in neutral ink beside a crimson dot"*
///
/// The reasoning was that the figure and the dot are one reading, and a row
/// that draws them in two different inks is a row that reads as two. That is
/// a good argument about a *row*. It is not an argument about a *screen*.
///
/// **29 September 2026 — the instruction that supersedes it**, written looking
/// at The Floor in the dark theme beside the approved artifact:
///
/// > *"Look at that grey, I need it on some of these cards instead this blue
/// > everywhere, this is on the dark theme and make the numbers lumunuous
/// > white and not red and some grey like the ones up here."*
///
/// What the first instruction could not see is what the rule looks like at
/// scale. Applied per row it is one crimson number beside one crimson dot;
/// applied down a list it is every number on the screen in crimson, on a
/// ground where crimson is *darker* than the ink around it — so the figures,
/// which are the brightest and most important objects on a console, become the
/// dimmest. The artifact resolves it the other way and is explicit about it:
/// `.srow .val` sets **no colour at all** and inherits the bone `#EEE9DF`,
/// while the `.dot` beside it is `#FF7D8C`. The dot carries the verdict. The
/// figure carries the number.
///
/// Note what did **not** reverse. The 28 September rule's own premise — that a
/// row must not state its severity in one place only — is not just intact, it
/// is load-bearing: this function may only return null where the mark it was
/// named after is actually drawn. Every caller is checked for that, and a
/// caller that has no mark gets one rather than keeping its colour.
///
/// And Day is untouched. The owner said "this is on the dark theme", so the
/// reversal is scoped by [TiqSkin.standingColoursFigures] rather than applied
/// to both grounds — see its own note for why paper needs the opposite answer.
Color? severityInk(
  TiqSkin skin,
  SeverityMarkKind? kind, {
  FigureState state = FigureState.measured,
  FigureRank rank = FigureRank.row,
}) {
  if (state != FigureState.measured) return null;
  if (!skin.standingColoursFigures) {
    return rank == FigureRank.headline && kind == SeverityMarkKind.critical
        ? skin.palette.bad
        : null;
  }
  return switch (kind) {
    SeverityMarkKind.critical || SeverityMarkKind.watch => skin.palette.bad,
    SeverityMarkKind.onTarget => skin.palette.good,
    // `held` is Oatmeal and `notMeasured` is an absence. Neither is a verdict,
    // and neither colours a figure.
    SeverityMarkKind.held || SeverityMarkKind.notMeasured || null => null,
  };
}
