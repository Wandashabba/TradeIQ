import 'package:flutter/widgets.dart';

import '../../theme/torchlight/tiq_skin.dart';

/// THE CARD — the one soft block, for a block that is not a row.
///
/// The owner overruled unify §1.3's flush list row on 25 September 2026 (see
/// `docs/design/torchlight-aisle.md`), and a screen whose rows are cards and
/// whose one figure block is a bare column on the ground is a screen with two
/// grammars. So the figure block gets the same material: radius
/// [TiqRadii.card], a `surface` fill — the declared composited hex, never an
/// opacity — and no border.
///
/// **What this is not.** It is not a licence for every block on every screen
/// to gain a radius, which is the "uniform rounded cards" failure the ruling
/// was right to name. It is the container for a list of things a person acts
/// on and for the one figure that sends them there. A panel is still a
/// [TorchPanel] at radius 14, a chip is still radius 6, and a section marker
/// is still words on the ground.

///
/// Cost: one `DecoratedBox`. No shadow, no gradient, no `saveLayer`, and
/// nothing that may not appear inside a `ListView.builder`.
class TorchCard extends StatelessWidget {
  const TorchCard({super.key, required this.child, this.padding, this.fill});

  final Widget child;

  /// Overrides the card's own inset. The default is s4 on every side, which
  /// is what the rows use.
  final EdgeInsetsGeometry? padding;

  /// Overrides the `surface` material — for a card carrying a **finding**,
  /// and for nothing else.
  ///
  /// Added 29 September 2026 for the stock section, where a product counted at
  /// zero washes crimson. It is one of the three channels the approved mockup
  /// gives that state (the wash, the count's ink, the word), and it replaces a
  /// 3px bar drawn down the block's leading edge — the same bar
  /// `SoftRowSpec` dropped for a dot when the rows became cards, and for the
  /// same reason: inside a radius-22 silhouette a 3px stripe reads as a
  /// scratch on the fill.
  ///
  /// A caller passes a **declared composited colour** — `torchChipWash(skin,
  /// …)`, the one recipe the chips and the state tiles already use — never an
  /// opacity. Null is the default and every existing call site keeps it, so
  /// the signed-off console screens render byte for byte what they did.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.card),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(TiqSpace.s4),
        child: child,
      ),
    );
  }
}
