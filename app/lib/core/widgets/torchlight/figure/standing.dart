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
///    and do not (Night `badSolid` is 3.66:1 on `surface`). A figure therefore
///    takes one crimson whichever commitment level it is at — the *mark*
///    beside it is what carries the level, by fill against outline.
/// 3. **Colour is never the only signal.** Nothing here produces a colour on
///    its own: every caller already prints the standing as a word, a severity
///    mark, a target on the meta line, or a triangle. This function only says
///    which ink, never whether the reader is told.
///
/// Amber is not in this file and cannot be: amber marks the expected next
/// move. Green and crimson carry judgement; amber does not.

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

/// The ink a figure takes from its standing, or **null for plain ink**.
///
/// Null is the common answer and the safe one: a caller passes the result
/// straight into `FigureSlot.color`, where null means "the state decides",
/// which is exactly the treatment an unjudged figure should get.
Color? standingInk(
  TiqSkin skin,
  StatusLevel? level, {
  FigureState state = FigureState.measured,
}) {
  // A figure that cannot be judged is never coloured — the em dash, the
  // never-measured cell, the thin sample and the provisional all keep the ink
  // their own state gives them. This check is first on purpose: a standing
  // computed from a value the screen is not confident in is a verdict the
  // screen has not earned.
  if (state != FigureState.measured) return null;
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
/// The owner's second rule: *"severity figures on rows should match the row's
/// own severity mark rather than sitting in neutral ink beside a crimson
/// dot"*. The figure and the dot are one reading, and a row that draws them in
/// two different inks is a row that reads as two.
Color? severityInk(
  TiqSkin skin,
  SeverityMarkKind? kind, {
  FigureState state = FigureState.measured,
}) {
  if (state != FigureState.measured) return null;
  return switch (kind) {
    SeverityMarkKind.critical || SeverityMarkKind.watch => skin.palette.bad,
    SeverityMarkKind.onTarget => skin.palette.good,
    // `held` is Oatmeal and `notMeasured` is an absence. Neither is a verdict,
    // and neither colours a figure.
    SeverityMarkKind.held || SeverityMarkKind.notMeasured || null => null,
  };
}
