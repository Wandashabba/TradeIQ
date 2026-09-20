import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'tiq_mark.dart';

/// The one chip material, shared by the status chip and the flag chip family.
///
/// Both are "a silhouette, a word, and an edge". They differ in what they
/// *claim* — a status is the thing's current standing, a flag is a fact about
/// how a record was produced — and that difference is carried by the level
/// tokens, not by two chip implementations that would drift apart in a month.
///
/// Geometry (unify §1.6): radius `chip` (6, 0 in Veld), visual height 28
/// inline / 32 Field / 40 Veld inside a ≥48dp hit box when tappable, 10dp of
/// horizontal padding, a 6dp gap to the leading glyph, label in sentence case.
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

  /// Null for a transparent chip. A transparent chip is a real state (Watch
  /// and On target are outlined, not filled) and not an absence.
  final Color? fill;

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

  /// The chip's visual height for a density — not its hit box.
  static double visualHeight(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console => 28,
    TiqDensity.field => 32,
    TiqDensity.veld => 40,
  };

  /// The chip label role, derived from `label` so it is a token and not a
  /// seventeenth text style: 11/700 Console, 13/600 Field, 16/600 Veld.
  static TiqTypeToken labelRole(TiqSkin skin) => switch (skin.density) {
    TiqDensity.console => skin.text.label.copyWith(
      size: 11,
      weight: FontWeight.w700,
    ),
    TiqDensity.field => skin.text.label.copyWith(
      size: 13,
      weight: FontWeight.w600,
    ),
    TiqDensity.veld => skin.text.label.copyWith(
      size: 16,
      weight: FontWeight.w600,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final text = detail == null ? label : '$label · $detail';
    final chip = Container(
      constraints: BoxConstraints(minHeight: visualHeight(skin)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(skin.radii.chip),
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
