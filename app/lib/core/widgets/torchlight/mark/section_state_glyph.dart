import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'tiq_chip.dart' show torchChipWash;
import 'tiq_mark.dart';

/// THE TILE'S CORNER — owner decision, 29 September 2026.
///
/// Recorded here rather than added to [TiqRadii], the way `torchPillRadius`
/// was recorded in `chrome/nav_pill.dart`, because `TiqRadii` is four
/// materials and a tile 28dp square is not a fifth: at 11 on 28 it is a
/// squircle, and every [TiqRadii] member is either too square for that
/// (`chip` 6) or, on a 28dp box, a circle (`panel` 14 is exactly half the
/// side, and a circular tile holding a ring glyph is two concentric circles).
///
/// 11 is the approved mockup's own number — its `.glyph` is `width: 30px;
/// border-radius: 11px`, and our tile is 28. It does not scale with the text
/// factor, for the same reason a 22dp card radius does not.
const double torchGlyphTileRadius = 11;

/// The four states a capturable section can be in (#375).
///
/// ## Why there are four and not three
///
/// The product shipped three — a tick, a half-circle and an empty ring — and
/// an agent who could not confirm a section had to choose between lying (tick)
/// and looking lazy (empty). [cantConfirm] is the fourth, and it is excluded
/// from the readiness count: the whole point is that it is not a failure.
///
/// ## Why "can't confirm" is a silhouette and not a hatch
///
/// This is unify §1.5, and it is the ruling this component exists to carry.
/// Three of the five surfaces proposed hatching the tile. A 3dp stripe inside
/// a 28dp tile aliases to a **flat grey disc** on a sub-R2000 Android at 40%
/// backlight — and a flat grey disc is exactly what [inProgress] looks like.
/// So the fourth state is a fourth shape: a ring at the empty ring's stroke
/// weight with a 2px diagonal bar through it. Four silhouettes — a ring,
/// a half disc, a tick, a barred ring — and `section_state_glyph_test.dart`
/// proves the fourth is distinguishable from the second **in greyscale**,
/// which is the test the hatch would have failed.
enum SectionState {
  /// Not started. An empty ring.
  notStarted,

  /// In progress. A half disc — the ring with its lower half filled solid.
  /// A glyph inside the tile, not a half-filled tile: a half-filled tile
  /// measures 1.49:1 against the well, which the device floor forbids.
  inProgress,

  /// Done. A filled disc with the tick knocked out of it.
  done,

  /// Could not be confirmed, and **is not counted against the agent**. A ring
  /// with a 2px diagonal bar.
  cantConfirm,
}

/// The resolved appearance of one [SectionState].
@immutable
class SectionStateToken {
  const SectionStateToken({
    required this.state,
    required this.word,
    required this.shape,
    required this.ink,
    required this.countsTowardReadiness,
  });

  final SectionState state;

  /// The English default. The word always renders next to the glyph; the glyph
  /// is never alone.
  final String word;

  final MarkShape shape;
  final Color ink;

  /// Whether this state is counted in "6 of 9 captured".
  ///
  /// False for [SectionState.cantConfirm] — the readiness denominator drops
  /// instead. A section nobody could measure is not a section somebody
  /// skipped, and counting it as one is how a gate blocks a submit that
  /// should go through.
  final bool countsTowardReadiness;

  static SectionStateToken of(TiqSkin skin, SectionState state) {
    final p = skin.palette;
    return switch (state) {
      SectionState.notStarted => SectionStateToken(
        state: state,
        word: 'Not started',
        shape: MarkShape.sectionRing,
        ink: p.ink3,
        countsTowardReadiness: true,
      ),
      SectionState.inProgress => SectionStateToken(
        state: state,
        word: 'In progress',
        shape: MarkShape.sectionHalfDisc,
        ink: p.ink2,
        countsTowardReadiness: true,
      ),
      SectionState.done => SectionStateToken(
        state: state,
        word: 'Done',
        shape: MarkShape.sectionTickDisc,
        ink: p.good,
        countsTowardReadiness: true,
      ),
      SectionState.cantConfirm => SectionStateToken(
        state: state,
        word: "Can't confirm",
        shape: MarkShape.sectionBarredRing,
        ink: p.ink2,
        countsTowardReadiness: false,
      ),
    };
  }
}

/// The capture marker used on every ladder row, the submit gate and the
/// outcome breakdown.
///
/// A 28dp tile (48dp at 2.0×) **filled, not outlined**, at
/// [torchGlyphTileRadius], holding a 16dp glyph (32dp at 2.0×). The tile is
/// the container; the glyph is the state.
///
/// ```dart
/// SectionStateGlyph(state: SectionState.cantConfirm)
/// ```
///
/// The tile never turns red. A section you have not reached is not a failure,
/// and a section you could not measure is not one either — the row's severity
/// bar exists for the cases that are.
///
/// ## The outline goes and the four silhouettes stay — amending §1.5
///
/// Owner override, 29 September 2026: *"The agent side is still
/// rectangular."* With #483 turning the blocks into soft cards, these tiles
/// were among the last rectangles on the visit hub — three radius-6 boxes
/// down the leading lane, two of them at a 2px border.
///
/// §1.5 declares this component as a tile carrying four silhouettes, and an
/// earlier survey was right to refuse to delete it: the silhouettes are the
/// one channel on that screen that survives greyscale. **They are untouched.**
/// A ring, a half disc, a tick disc and a barred ring, at the same 16dp, in
/// the same inks. What §1.5 protects is the silhouette set, not the border —
/// and the approved mockup keeps the tile too (`.glyph`, 30px, radius 11,
/// `background: rgba(238,233,223,0.08)`, **no border**) while tinting fill and
/// ink together for the states that have a colour.
///
/// So the tile is filled rather than outlined, by the same recipe the chips
/// use ([torchChipWash]) and for the same reason: it is one arithmetic
/// exercise, not two.
class SectionStateGlyph extends StatelessWidget {
  const SectionStateGlyph({
    super.key,
    required this.state,
    this.semanticsLabel,
    this.required_ = false,
  });

  final SectionState state;

  /// The state word plus the section name: "Pricing, can't confirm". Where it
  /// is null the glyph carries no semantics at all, because the row it sits on
  /// renders the word beside it and two nodes would read it twice.
  final String? semanticsLabel;

  /// A required section that has not been started: the tile **brightens**. It
  /// still never turns red — the row carries a REQUIRED flag and the gate
  /// carries the consequence.
  ///
  /// It was a 2px ink-1 border, and that was the whole of the channel. With
  /// the outline gone it is an ink-1 wash instead — 1.49:1 against the plain
  /// tile on Night, 1.30:1 on Day — which is weaker than a 2px edge and is
  /// said plainly rather than dressed up. It can afford to be: `required_` is
  /// set from exactly one call site (`audit_shell_screen`), and that call site
  /// puts a crimson `REQUIRED TO SUBMIT` chip and the word "Not started" in
  /// the same row. The tile was the third statement of a fact already made
  /// twice in words.
  ///
  /// Named with a trailing underscore because `required` is a reserved word in
  /// Dart, which is the whole of the reason.
  final bool required_;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final token = SectionStateToken.of(skin, state);
    final tile = MarkScale.tile(context);
    final glyph = MarkScale.glyph(context, 16);

    // The state's own ink, quietly, over `raised` — except for the three
    // states whose ink is neutral (ink-2, ink-3), which take `raised` flat.
    // A neutral wash is ink-1 over the tier, and on Day that darkens the tile
    // under an ink-3 ring; `raised` is the safer and more visible answer, and
    // it is the same call the neutral chip levels make.
    final Color fill;
    if (required_) {
      fill = torchChipWash(skin, p.ink1);
    } else if (state == SectionState.done) {
      fill = torchChipWash(skin, token.ink);
    } else {
      fill = p.raised;
    }

    final box = Container(
      width: tile,
      height: tile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(torchGlyphTileRadius),
      ),
      child: TiqMark(
        shape: token.shape,
        color: token.ink,
        size: glyph,
        // The tick is knocked out of the disc in **the tile's own fill**, not
        // in `palette.ground`. It was the ground while the tile was an empty
        // outline and the ground really was what showed through; now the tile
        // is filled, and knocking out to the ground would print a near-black
        // tick on a green disc sitting on a `raised` card.
        ground: fill,
      ),
    );

    if (semanticsLabel == null) return box;
    return Semantics(label: semanticsLabel, excludeSemantics: true, child: box);
  }
}
