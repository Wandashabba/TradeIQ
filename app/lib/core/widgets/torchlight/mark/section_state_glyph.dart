import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'tiq_mark.dart';

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
/// Veld's coarsened stripe period gives the same tile two stripes, which reads
/// as a rendering artefact rather than a state.
///
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
/// A 28dp tile (48dp at 2.0×) with a 2px `edge-control` border, holding a 16dp
/// glyph (32dp at 2.0×). The tile is the container; the glyph is the state.
///
/// ```dart
/// SectionStateGlyph(state: SectionState.cantConfirm)
/// ```
///
/// The tile never turns red. A section you have not reached is not a failure,
/// and a section you could not measure is not one either — the row's severity
/// bar exists for the cases that are.
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

  /// A required section that has not been started: the tile's border thickens
  /// to ink-1. It still never turns red — the row carries a REQUIRED flag and
  /// the gate carries the consequence.
  ///
  /// Named with a trailing underscore because `required` is a reserved word in
  /// Dart, which is the whole of the reason.
  final bool required_;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final token = SectionStateToken.of(skin, state);
    final tile = MarkScale.tile(context);
    final glyph = MarkScale.glyph(context, 16);
    final borderWidth = required_ ? 2.0 : skin.depth.borderWidth;
    final borderColor = required_
        ? skin.palette.ink1
        : skin.palette.edgeControl;

    final box = Container(
      width: tile,
      height: tile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.radii.chip),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: TiqMark(
        shape: token.shape,
        color: token.ink,
        size: glyph,
        // The tick is knocked out of the disc in the ground colour, which is
        // what the tile sits on.
        ground: skin.palette.ground,
      ),
    );

    if (semanticsLabel == null) return box;
    return Semantics(label: semanticsLabel, excludeSemantics: true, child: box);
  }
}
