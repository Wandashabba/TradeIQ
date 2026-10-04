import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../chrome/nav_pill.dart' show torchPillRadius;
import 'tiq_mark.dart';

/// THE WASH — a level's own ink at 14% over [TiqPalette.raised].
///
/// The recipe the approved mockup uses for every filled chip and every state
/// glyph: *the fill is the ink's own hue, quietly, over the tier the chip
/// sits in*. `.good` is `rgba(111,224,174,0.14)` under `#6FE0AE`, `.crit` is
/// `rgba(255,125,140,0.16)` under `#FF7D8C`, and both of those hexes are this
/// product's Night `good` and `bad` verbatim — the mockup was drawn in this
/// palette, so the arithmetic below is a check of its own numbers and not a
/// translation of somebody else's.
///
/// **It composites over `raised`, not over "whatever is behind".** The mockup
/// lays its washes on one ground because a web page has one ground; a chip in
/// this app lands on `ground`, `well`, `surface` and `raised`, and a
/// translucent fill would give a different ink-on-fill ratio on each of them —
/// four ratios per level, none of which any test could name. Pinning the
/// composite to `raised` makes each level's fill **one declared colour per
/// skin**, which `torchlight_contrast_test.dart` measures like any other
/// pairing. The cost is that a chip sitting *on* `raised` has no fill step at
/// all; that is the same cost `TorchFilterChip` took for `surface` in #479,
/// and it is paid by the label, the silhouette and the ink, which are the
/// channels that identify a chip.
///
/// Taking it over `raised` rather than over `ground` is also what makes the
/// Day skin possible at all. Day's `good` is `#14664A`, a dark forest green
/// with 5.03:1 on the Day `well` — a 14% wash of it over that well leaves
/// 4.17:1 and **breaks the 4.5:1 text floor**. Over `raised` the same 14%
/// leaves 4.99:1. The mockup's alpha is a Night number; it survives Day only
/// because the tier under it is declared.
Color torchChipWash(TiqSkin skin, Color ink) =>
    Color.alphaBlend(ink.withValues(alpha: 0.14), skin.palette.raised);

/// The one chip material, shared by the status chip and the flag chip family.
///
/// Both are "a silhouette, a word, and a fill". They differ in what they
/// *claim* — a status is the thing's current standing, a flag is a fact about
/// how a record was produced — and that difference is carried by the level
/// tokens, not by two chip implementations that would drift apart in a month.
///
/// Geometry (unify §1.6): **radius `torchPillRadius`**, visual height 28
/// inline / 32 Field inside a ≥48dp hit box when tappable, 10dp of horizontal
/// padding, a 6dp gap to the leading glyph, label in sentence case.
///
/// ## A PILL, NOT A BOX — owner override, 29 September 2026
///
/// *"The agent side is still rectangular."* #479 made `TorchFilterChip` a
/// filled pill and moved nothing else, so radius 6 and a 1px border survived
/// here — and a survey of the three signed-off manager screens found no
/// `TiqChip` on any of them, which made the boxed chip an **agent-only**
/// signature. It is the green "All sent" box in every agent header, the
/// crimson "4 still required" in the visit hub's card, and both REQUIRED TO
/// SUBMIT badges beneath it.
///
/// This is the second grant from `torchPillRadius`, recorded the way #479
/// recorded the first rather than smuggled in as a token change: `TiqRadii`
/// deliberately carries no 999, and `radii.chip` keeps its 6 for the other
/// surfaces that use it.
///
/// [border] survives the change and is not vestigial. A level that cannot be
/// told apart on fill and ink alone may still ask for an outline — #479's
/// rule that **a disabled control keeps its outline, because it has no fill
/// to be seen by** has to stay expressible. Every level in `StatusLevelToken`
/// and `FlagKindToken` now passes a fill instead, and each one says why in
/// its own comment.
///
/// **Opacity is never a state channel here.** A previous draft dimmed a stale
/// Watch chip to 0.6, which computes to 3.29:1 for 11px text and passed CI
/// because CI measured the undimmed pair. Staleness is a word — pass it as
/// [detail] and it renders as "Watch · as at 08:15", which is more precise
/// than a fade and is the thing the reader actually needs.
class TiqChip extends StatelessWidget {
  const TiqChip({
    super.key,
    required this.shape,
    required this.label,
    required this.ink,
    this.fill,
    this.border,
    this.glyphBase = 12,
    this.glyphStroke,
    this.detail,
    this.onTap,
    this.semanticsLabel,
  });

  final MarkShape shape;

  /// The word. Sentence case: uppercase at 11px in glare fills the counters.
  final String label;

  /// A detail hung off the word after a middle dot — a distance, a fraction, a
  /// timestamp. Set in the same run as the label.
  final String? detail;

  final Color ink;

  /// Null for a transparent chip.
  ///
  /// Every level in the shipped families now passes one — Watch and On target
  /// were the two transparent ones and they are washes as of 29 September
  /// 2026, because a transparent chip with its outline taken away is not a
  /// chip at all.
  final Color? fill;

  /// An outline, for a level that has earned one. Null on every shipped level;
  /// see the class doc.
  final Color? border;

  /// The glyph's size at 1.0×. It scales with text from here.
  final double glyphBase;

  final double? glyphStroke;

  /// A chip that does nothing takes no press feedback at all, so it cannot be
  /// mistaken for a control.
  final VoidCallback? onTap;

  /// What a screen reader says. Every chip in this system ships one in the
  /// same token as its hue and its silhouette, so a level cannot be added
  /// without a word.
  final String? semanticsLabel;

  /// The chip's visual height — not its hit box. **28 at both densities since
  /// 4 October 2026**; it was `TiqDensity.field => 32` before.
  ///
  /// > *"Too big and spaced out — cards, text and gaps are larger than the
  /// > manager side, so it feels less professional."* — the owner, 4 October
  /// > 2026.
  ///
  /// THE HIT BOX IS NOT IN THIS NUMBER AND DOES NOT MOVE WITH IT. A tappable
  /// chip wraps itself in a `ConstrainedBox` at `skin.space.tapTarget` — 44 on
  /// both surfaces — and centres the visual box inside it (unify §1.6, and the
  /// comment at that `ConstrainedBox` says so). So a 28dp chip is still a 44dp
  /// target, and this change moves **how big the pill looks**, never how big it
  /// is to a thumb. That is the whole reason this one is safe to take: it is
  /// the rare case where the professional-density argument and the car-park
  /// argument are about two different boxes.
  ///
  /// WHAT THE 32 WAS FOR, AND WHY IT NO LONGER HOLDS. §1.6 set 28 inline / 32
  /// Field as a pair with **13/600 Field** type inside it, so the taller pill
  /// was carrying taller words. The type half of that pair went on 29
  /// September 2026 — see [labelRole], which is 11/700 at both densities now —
  /// and the note there says what was left behind: *"a 13pt word in a 32dp
  /// pill becomes an 11pt word in a 32dp pill — more air around the label, not
  /// a smaller chip."* That sentence was an accurate description of a loose
  /// end, and this is the loose end. An 11pt word in a 28dp pill is the
  /// proportion §1.6 actually specified; the agent chip had been 4dp of
  /// padding around nothing for five days.
  ///
  /// Neither 28 nor 32 is on the [TiqSpace] scale, and that is reported rather
  /// than fixed: 28 is the manager console's shipped height, the manager side
  /// is the reference, and putting a chip on a scale step would move it.
  ///
  /// TO RESTORE: give [TiqDensity.field] back its own arm at 32 — and restore
  /// [labelRole]'s field arm with it, because the two were one ruling.
  static double visualHeight(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console || TiqDensity.field => 28,
  };

  /// The chip label role, derived from `label` so it is a token and not a
  /// seventeenth text style: **11/700 at both densities**.
  ///
  /// > *"Make the font on the agentside the same as the manager side,
  /// > literally everything including colours"* — the owner, 29 September
  /// > 2026.
  ///
  /// SUPERSEDED: unify §1.6's **11/700 Console, 13/600 Field**, which read
  /// `TiqDensity.field => skin.text.label.copyWith(size: 13, weight:
  /// FontWeight.w600)`. The Field step existed for the same reason the field
  /// type scale did — a chip read at arm's length in sunlight — and it goes
  /// for the same reason: there is one type scale now, and a chip is the
  /// smallest labelled object in the product, so it is the last place that
  /// should be carrying a size nothing else does.
  ///
  /// ~~Note what does **not** move with it. The chip's **visual height stays
  /// 28 inline / 32 Field** ([visualHeight], directly above) and its 48dp hit
  /// box is untouched: §1.6's geometry is a density ruling about the thumb,
  /// not a type ruling, and `TiqSpace.field` is deliberately not part of this
  /// change. A 13pt word in a 32dp pill becomes an 11pt word in a 32dp pill —
  /// more air around the label, not a smaller chip.~~
  ///
  /// **THE HEIGHT FOLLOWED, 4 October 2026 — and this paragraph is the reason
  /// it did.** It was correct on the day it was written and it named its own
  /// consequence exactly: *"more air around the label, not a smaller chip"*.
  /// That air is what the owner was looking at five days later when they said
  /// the agent side is *"too big and spaced out … it feels less professional"*.
  /// [visualHeight] is 28 at both densities now, so an 11pt word sits in a 28dp
  /// pill — §1.6's own proportion, restored at §1.6's own type size.
  ///
  /// **The hit box is still untouched, and that part of the paragraph stands.**
  /// A tappable chip's `ConstrainedBox` reads `skin.space.tapTarget` — 44 on
  /// both surfaces — and never [visualHeight], so no target moved with the
  /// pill. What was wrong above was only the claim that the two halves of
  /// §1.6's pair could be separated indefinitely.
  ///
  /// TO RESTORE: give [TiqDensity.field] back its own arm of the switch. It
  /// is independent of the button role next door, unlike that one.
  static TiqTypeToken labelRole(TiqSkin skin) =>
      skin.text.label.copyWith(size: 11, weight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final text = detail == null ? label : '$label · $detail';
    final chip = Container(
      constraints: BoxConstraints(minHeight: visualHeight(skin)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(torchPillRadius),
        border: border == null
            ? null
            : Border.all(color: border!, width: skin.depth.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          TiqMark(
            shape: shape,
            color: ink,
            size: MarkScale.glyph(context, glyphBase),
            strokeWidth: glyphStroke,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: labelRole(skin).style(color: ink),
              // Every label wraps at every size; nothing in this system is
              // pinned to one line.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final labelled = Semantics(
      label: semanticsLabel ?? text,
      button: onTap != null,
      excludeSemantics: true,
      child: chip,
    );

    if (onTap == null) return labelled;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        // The visual box is centred in the hit box (unify §1.6), so a 28dp
        // chip is still a 48dp target without being a 48dp object.
        constraints: BoxConstraints(minHeight: skin.space.tapTarget),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: labelled,
        ),
      ),
    );
  }
}
