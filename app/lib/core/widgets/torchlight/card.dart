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
/// **Veld does not get one.** A soft translucent block on white under glare
/// stops reading as a block, so in Veld this is the same content with no
/// fill, no radius and the skin's own 2px border — which is the rule Veld
/// applies to everything else.
///
/// Cost: one `DecoratedBox`. No shadow, no gradient, no `saveLayer`, and
/// nothing that may not appear inside a `ListView.builder`.
class TorchCard extends StatelessWidget {
  const TorchCard({super.key, required this.child, this.padding});

  final Widget child;

  /// Overrides the card's own inset. The default is s4 on every side, which
  /// is what the rows use.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final veld = skin.density == TiqDensity.veld;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: veld ? null : skin.palette.surface,
        borderRadius: veld ? null : BorderRadius.circular(skin.radii.card),
        border: veld
            ? Border.all(
                color: skin.palette.edgeStructure,
                width: skin.depth.borderWidth,
              )
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(TiqSpace.s4),
        child: child,
      ),
    );
  }
}
