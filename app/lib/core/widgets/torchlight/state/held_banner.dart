import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../mark/tiq_mark.dart';

/// WHAT IS ON THIS PHONE, AND WHAT IT IS DOING.
///
/// Seven states, six silhouettes, and **held is not a fault**.
///
/// Working offline is the normal state of South African field work. Towers go
/// down with the grid, a back aisle is a Faraday cage, and "12 captures held"
/// is a normal Tuesday. So held is **Oatmeal (`ink2`) plus a square plus a
/// word** (unify §1.13) — never crimson, and never Truffle either: Truffle is
/// the comparison series ("them, unlit") and giving it a second meaning is
/// exactly the failure the severity system avoids. Two surfaces used Truffle
/// here for held, offline, session-ended *and* "incomplete"; the ruling took
/// it back.
///
/// [SyncState.needsYou] is the **only** state that raises a colour, because it
/// is the only one where something is actually wrong.
enum SyncState {
  /// Nothing held. Renders for a few seconds and then goes: a permanent green
  /// banner is noise.
  allSent,

  /// The normal state.
  held,

  /// Going out now.
  sending,

  /// The one state that raises a colour.
  needsYou,

  /// No signal at all.
  offline,

  /// Paused to save data.
  paused,
}

/// The resolved look of one [SyncState].
@immutable
class SyncStateToken {
  const SyncStateToken({
    required this.state,
    required this.shape,
    required this.ink,
    required this.word,
    this.leadingBar,
  });

  final SyncState state;
  final MarkShape shape;
  final Color ink;

  /// The English default. Localised by the caller.
  final String word;

  /// `needsYou` only.
  final Color? leadingBar;

  static SyncStateToken of(TiqSkin skin, SyncState state) {
    final p = skin.palette;
    return switch (state) {
      SyncState.allSent => SyncStateToken(
        state: state,
        shape: MarkShape.onTargetCircle,
        ink: p.good,
        word: 'Everything sent',
      ),
      // Oatmeal. Not crimson, not Truffle.
      SyncState.held => SyncStateToken(
        state: state,
        shape: MarkShape.heldSquare,
        ink: p.ink2,
        word: 'held on this phone',
      ),
      SyncState.sending => SyncStateToken(
        state: state,
        shape: MarkShape.heldSquare,
        ink: p.ink2,
        word: 'Sending',
      ),
      SyncState.needsYou => SyncStateToken(
        state: state,
        shape: MarkShape.criticalTriangle,
        ink: p.bad,
        word: 'need you',
        leadingBar: p.badSolid,
      ),
      SyncState.offline => SyncStateToken(
        state: state,
        shape: MarkShape.flagBrokenRing,
        ink: p.ink2,
        word: 'No signal',
      ),
      SyncState.paused => SyncStateToken(
        state: state,
        shape: MarkShape.hollowSquare,
        ink: p.ink2,
        word: 'Paused to save data',
      ),
    };
  }
}

/// The banner form of the sync status — one component, two forms (unify
/// §1.14). The chip is the default and lives in the header; this band renders
/// only for [SyncState.needsYou] and [SyncState.offline], plus wherever a
/// screen genuinely wants the standing statement.
///
/// ## The accessibility bug this API exists to prevent
///
/// The first draft put `liveRegion` on the whole banner with the **count**
/// inside its label. The count animates. So an agent capturing twelve items
/// during a visit heard "13 captures held on this phone, tap to open your
/// work" interrupt her mid-sentence twelve times, during the one workflow
/// where an interruption loses data.
///
/// Now: the banner is a `button` whose **label** is the state sentence and
/// whose **value** is the count, read on focus. The live region is scoped to a
/// child node carrying only the state **word**, which changes six times in a
/// day rather than twelve times in a visit.
class OfflineHeldBanner extends StatelessWidget {
  const OfflineHeldBanner({
    super.key,
    required this.state,
    this.count,
    this.subtitle,
    this.onTap,
    this.label,
    this.openLabel = 'tap to open your work',
  });

  final SyncState state;

  /// Rendered in tabular mono inside the title. Null where a state has no
  /// count ("No signal").
  final int? count;

  /// One meta line. "They will send themselves · nothing is lost."
  final String? subtitle;

  final VoidCallback? onTap;

  /// Overrides the token's English word.
  final String? label;

  final String openLabel;

  /// 56 on Night and Day, 72 in Veld. **Every state is the same height**, so
  /// content beneath never jumps when the state changes.
  static double heightFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? 72 : 56;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final token = SyncStateToken.of(skin, state);
    final word = label ?? token.word;
    final title = count == null ? word : null;

    final content = Row(
      children: <Widget>[
        TiqMark(
          shape: token.shape,
          color: token.ink,
          size: MarkScale.glyph(context, 20),
        ),
        const SizedBox(width: TiqSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (title != null)
                // THE LIVE REGION IS SCOPED TO THE WORD, and to nothing else.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    title,
                    style: skin.text.bodyStrong.style(color: p.ink1),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    // The figure is EXCLUDED from the tree, not because it is
                    // decoration but because it is already the node's `value`.
                    // Left in, it joins the merged label — and the merged
                    // label is what a live region announces, which is how the
                    // count came to interrupt an agent twelve times a visit.
                    ExcludeSemantics(
                      child: FigureSlot(
                        value: count,
                        role: skin.text.figureS,
                        color: p.ink1,
                      ),
                    ),
                    const SizedBox(width: TiqSpace.s1),
                    Flexible(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          word,
                          style: skin.text.bodyStrong.style(color: p.ink1),
                        ),
                      ),
                    ),
                  ],
                ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: TiqSpace.s1),
                Text(subtitle!, style: skin.text.meta.style(color: p.ink3)),
              ],
            ],
          ),
        ),
        if (onTap != null) ...<Widget>[
          const SizedBox(width: TiqSpace.s3),
          TiqMark(
            shape: MarkShape.flagThreeQuarterArc,
            color: p.ink3,
            size: MarkScale.glyph(context, 16),
          ),
        ],
      ],
    );

    // THE SEVERITY BAR IS A CHILD, NOT A BORDER SIDE. A `BoxDecoration` refuses
    // a radius on a border whose sides differ in colour — and it is right to:
    // a 3px crimson edge that has to follow a 14dp corner arc is a crimson
    // corner, which is a shape nobody drew. It is a straight bar down the
    // leading edge, inside the outline.
    final band = Container(
      constraints: BoxConstraints(minHeight: heightFor(skin)),
      decoration: BoxDecoration(
        color: p.well,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: p.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: skin.space.gutter,
        vertical: TiqSpace.s3,
      ),
      child: token.leadingBar == null
          ? content
          : Stack(
              children: <Widget>[
                content,
                PositionedDirectional(
                  start: -skin.space.gutter + skin.depth.borderWidth,
                  top: -TiqSpace.s3,
                  bottom: -TiqSpace.s3,
                  width: skin.depth.borderWidth * 3,
                  child: ColoredBox(color: token.leadingBar!),
                ),
              ],
            ),
    );

    return Semantics(
      button: onTap != null,
      label: onTap == null ? word : '$word, $openLabel',
      // The count lives here, read on focus, and NEVER in the live label.
      value: count == null ? null : '$count',
      // THE ACTION, not only the flag. Without it the labelled node carries no
      // tap and the tappable descendant carries no label: a banner a screen
      // reader can read and cannot open.
      onTap: onTap,
      // It is never dismissible: held work is a standing fact.
      child: onTap == null
          ? band
          : TorchPressable(
              onPressed: onTap,
              pressScale: 1,
              borderRadius: BorderRadius.circular(skin.radii.panel),
              builder: (context, pressed) => DecoratedBox(
                decoration: BoxDecoration(
                  color: pressed ? torchPressSurface(skin).fill : null,
                  borderRadius: BorderRadius.circular(skin.radii.panel),
                ),
                child: band,
              ),
            ),
    );
  }
}
