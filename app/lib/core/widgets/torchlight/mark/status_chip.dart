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
  /// There is no per-skin branch here because a skin is a value set, not a
  /// code path, and every difference is already in the palette.
  ///
  /// ## FIVE LEVELS, NO OUTLINES — and what carries each one
  ///
  /// #479 argued once that a fill is not what identifies a filter chip. Two
  /// states needed one argument; **five levels need five**, because a fill
  /// alone will not separate five standings on a near-black ground — the
  /// washes below sit between 1.10:1 and 1.39:1 of each other in greyscale
  /// and no amount of tuning will change that. So the argument is made per
  /// level, and every level's answer is the same two channels that survive
  /// greyscale and a torn screen protector — **a silhouette and a word** —
  /// with ink as the third:
  ///
  /// | level | silhouette | word | ink on its own fill (N / D) |
  /// |---|---|---|---|
  /// | critical | filled triangle | Critical | 4.55 / 6.95 |
  /// | watch | half-filled triangle | Watch | 5.14 / 6.26 |
  /// | onTarget | filled circle | On target | 7.10 / 4.99 |
  /// | held | square | Held | 8.93 / 8.50 |
  /// | live | dot, 8dp not 12dp | Live | 8.93 / 8.50 |
  ///
  /// Every one clears the 4.5:1 text floor on the fill it is printed on, and
  /// `torchlight_contrast_test.dart` measures all ten.
  ///
  /// **Critical is the one level whose fill is a signal**, and it keeps it:
  /// solid `badSolid` with the ink inverted against it, 4.55:1 on the Night
  /// ground and 5.74:1 on the Day one, which is the only chip fill in the
  /// family that clears WCAG 1.4.11's 3:1 as a boundary. It is also the only
  /// one whose ink is *dark on light* — a polarity flip no other level has.
  /// That is deliberate: a severity that is happening *now* should not depend
  /// on the reader telling two pastels apart.
  ///
  /// **Held and Live share a treatment, exactly as they did before this
  /// change**, and are told apart by silhouette and word alone — a 12dp
  /// square against an 8dp dot. Removing their outline does not widen that
  /// gap and this change does not claim it does.
  static StatusLevelToken of(TiqSkin skin, StatusLevel level) {
    final p = skin.palette;
    return switch (level) {
      // UNCHANGED, on purpose. It was already a solid badge with no outline;
      // it takes the new radius and nothing else.
      StatusLevel.critical => StatusLevelToken(
        level: level,
        word: 'Critical',
        shape: MarkShape.criticalTriangle,
        ink: p.onBadSolid,
        fill: p.badSolid,
      ),
      // Was a bare crimson outline over nothing. The outline was the whole
      // object — there was no fill — so it could not simply be deleted; it is
      // a crimson wash now, at 1.51:1 on the Night ground against the 1.21:1
      // the mockup's own translucent version would have managed.
      //
      // THIS IS ALSO THE `REQUIRED TO SUBMIT` BADGE (`audit_shell_screen`),
      // and the mockup appears to contradict itself there: its `.req` marker
      // keeps a 1px `rgba(255,125,140,.45)` border. It is a different object.
      // `.req` is 7.5px mono, letter-spaced, **with no glyph** — a marker so
      // small it has neither silhouette nor room for one, and the border is
      // what makes it an object at all. The mockup's crimson *chip* — "Out of
      // stock", `rgba(255,125,140,.18)` — carries no border, and that is the
      // one this maps onto: a full chip, with a triangle and a five-word
      // label. Keeping the border here would re-line the exact screen the
      // owner was looking at when they said it is still rectangular.
      StatusLevel.watch => StatusLevelToken(
        level: level,
        word: 'Watch',
        shape: MarkShape.watchTriangle,
        ink: p.bad,
        fill: torchChipWash(skin, p.bad),
      ),
      // The other bare outline, and the one this change was measured against:
      // it is the green "All sent" box top-right of every agent screen.
      StatusLevel.onTarget => StatusLevelToken(
        level: level,
        word: 'On target',
        shape: MarkShape.onTargetCircle,
        ink: p.good,
        fill: torchChipWash(skin, p.good),
      ),
      // `well` → `raised`. NOT the wash: the neutral levels' ink is ink-2 and
      // ink-3, and a neutral wash is ink-1 over the tier, which on Day means
      // `ink-3 on well` — the tightest declared pairing in the whole Day set
      // at **4.52:1 against a 4.5 floor**. There is no headroom there to
      // spend, so the neutral chip takes an existing tier instead of an
      // alpha. `raised` is the one that reads: it is 1.19:1 on the Night
      // ground where `well` was 1.06:1, which is the mockup's own neutral
      // (1.18:1) to within a rounding error, and it *improves* the Day
      // pairing to 5.48:1 rather than spending it.
      StatusLevel.held => StatusLevelToken(
        level: level,
        word: 'Held',
        shape: MarkShape.heldSquare,
        ink: p.ink2,
        fill: p.raised,
      ),
      StatusLevel.live => StatusLevelToken(
        level: level,
        word: 'Live',
        shape: MarkShape.dot,
        ink: p.ink2,
        fill: p.raised,
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
