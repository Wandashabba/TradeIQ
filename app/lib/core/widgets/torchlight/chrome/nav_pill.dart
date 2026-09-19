import 'package:flutter/widgets.dart';

import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_button.dart';
import '../button/torch_press.dart';

/// The 999 radius, which [TiqRadii] deliberately does not carry.
///
/// The radius set was written when the active-tab pill had been cut, and its
/// doc comment says so: "the 999 pill radius is gone entirely". Owner decision
/// 3 reinstated the pill, and unify §1.2 rules for it over three surfaces'
/// radius-14 bars. It is declared here rather than added to [TiqRadii] because
/// it is legal on exactly three objects — the floating bar, its active tab and
/// the nav circle — and all three are in this folder. A token that only one
/// component may use is a value.
const double torchPillRadius = 999;

/// One destination in the bar.
@immutable
class TorchNavSlot {
  const TorchNavSlot({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.semanticLabel,
  });

  /// The inactive silhouette. Outlined.
  final IconData icon;

  /// The active silhouette. Filled, and a **different shape** — not the same
  /// glyph on a different ground.
  ///
  /// It is required rather than defaulted because of what happens at 2.0×: the
  /// bar goes icon-only, the label and its 700 weight disappear, and if the
  /// glyph did not change then "selected" would be carried by the amber fill
  /// and nothing else. Colour is never the only signal — least of all on the
  /// screens whose readers asked for bigger text.
  final IconData activeIcon;

  /// Localised, and measured. See [TorchNavPill]'s large-text rule.
  final String label;

  /// A count that needs the person. Never the ordinary held count, never
  /// amber, never crimson.
  final int? badgeCount;

  final String? semanticLabel;
}

/// THE FLOATING PILL. Four slots, one lit tab, and no fifth anything.
///
/// ```
/// manager   Floor · Work · Ask · Menu
/// agent     Today · My work · Map · Me
/// ```
///
/// ## Geometry (unify §1.2)
///
/// Radius 999, 64 tall, inset 16 from each gutter, 20dp above the safe area,
/// `well` **fully opaque**, a 1px `edgeStructure` outline. There is no
/// `BackdropFilter` in this application and no scroll listener swaps the fill:
/// a bar that changes as you scroll is chrome that reads as a bug, and a
/// frosted bar is a blur the paint budget does not have.
///
/// The active tab is a solid pill inset 6dp horizontally within the bar, 48
/// tall, radius 999. In Night it is `flame600` with `#0B1017` on it at 10.65:1.
/// On a light ground it is a solid Abyssal block with Palladian or white ink —
/// **never amber**, because on a light ground amber is a carrier of ink and the
/// one object allowed to be that is the primary commit block.
///
/// **Veld docks the bar**: full bleed, 72dp, a 2px top border, radius 0. A
/// white pill floating on white under glare stops reading as a bar, and Veld
/// has no radius but 0. Docking also gives back 36dp of fold.
///
/// ## It claims amber; it does not paint it
///
/// The active tab asks [TorchScope] about [TorchScope.navActiveTabId], the id
/// the allocator grants itself whenever `navRenders` is true. The pill is
/// **counted**, not exempt — which is why a Night tab root has exactly one
/// content grant left, and why every amber here goes out when a sheet opens.
///
/// ## Large text
///
/// At build the bar lays out **every localised label** with a [TextPainter] at
/// the ambient scaler against the computed slot width. If any one of them
/// overflows, the whole bar goes icon-only — **all four, never a mixed bar and
/// never a two-row grid**. A 132dp nav grid plus a circle plus a thumb zone is
/// a third of a 640dp screen.
///
/// The failure case is real and it is Afrikaans: "Kompetisies" at 11/700 is
/// about 67px against a 63dp slot, and at the 1.3× that is common on cheap
/// Androids every label in the bar overflows at once.
class TorchNavPill extends StatelessWidget {
  const TorchNavPill({
    super.key,
    required this.slots,
    required this.activeIndex,
    required this.onSelect,
  }) : assert(
         slots.length >= 2 && slots.length <= 4,
         'Four slots maximum. At 360dp the bar has 252dp to give away once '
         'the insets and the circle are drawn; five slots is 50dp each, which '
         'is under the tap-target floor before the active pill takes its 6dp '
         'inset. A fifth destination goes behind Menu.',
       );

  final List<TorchNavSlot> slots;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  /// The bar's outer height for this skin, before any text-scale growth.
  static double heightFor(TiqSkin skin) => skin.mode == SkinMode.veld ? 72 : 64;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final docked = skin.mode == SkinMode.veld;
    final lit = TorchScope.lit(context, TorchScope.navActiveTabId);
    final scaler = MediaQuery.textScalerOf(context);

    // A meaning-bearing glyph scales with the text, and in an icon-only bar it
    // is the only thing carrying the destination. It is capped at 32 because
    // the active pill is 48 and a 48dp glyph in a 48dp pill is a glyph with no
    // pill around it.
    final glyphSize = scaler.scale(24).clamp(24.0, 32.0);

    final labelToken = skin.text.label.copyWith(
      size: docked ? 13 : 11,
      weight: FontWeight.w500,
    );
    final activeLabelToken = labelToken.copyWith(weight: FontWeight.w700);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final hInset = docked ? TiqSpace.s2 : 6.0;
        final slotWidth = (barWidth - hInset * 2) / slots.length;

        // THE MEASUREMENT. Every label, at the real scaler, against the real
        // slot. Not a guess at a text-scale threshold — layouts collapse on
        // measured width, never on a scale factor.
        var labelsFit = true;
        var labelHeight = 0.0;
        for (final slot in slots) {
          final painter = TextPainter(
            text: TextSpan(
              text: slot.label,
              style: activeLabelToken.style(color: p.ink1),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > slotWidth - TiqSpace.s2) labelsFit = false;
          if (painter.height > labelHeight) labelHeight = painter.height;
          painter.dispose();
        }

        final contentHeight =
            glyphSize + (labelsFit ? TiqSpace.s1 + labelHeight : 0);
        // 8dp above and below the active pill, which is what makes a 64dp bar
        // hold a 48dp tab. The bar only grows past 64 when the measured
        // content will not fit inside it — it is a minimum, never a pin.
        final vInset = docked ? TiqSpace.s2 : 8.0;
        final barHeight = [
          heightFor(skin),
          contentHeight + vInset * 2,
        ].reduce((a, b) => a > b ? a : b);

        return Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: p.well,
            borderRadius: docked
                ? null
                : BorderRadius.circular(torchPillRadius),
            border: docked
                // Docked, the bar is the bottom of the screen; the only edge it
                // needs is the one that separates it from the content above.
                ? Border(
                    top: BorderSide(
                      color: p.edgeStructure,
                      width: skin.depth.borderWidth,
                    ),
                  )
                : Border.all(
                    color: p.edgeStructure,
                    width: skin.depth.borderWidth,
                  ),
          ),
          padding: EdgeInsets.symmetric(horizontal: hInset, vertical: vInset),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < slots.length; i++)
                Expanded(
                  child: _Slot(
                    slot: slots[i],
                    index: i,
                    count: slots.length,
                    active: i == activeIndex,
                    lit: lit,
                    showLabel: labelsFit,
                    glyphSize: glyphSize,
                    labelToken: i == activeIndex
                        ? activeLabelToken
                        : labelToken,
                    onSelect: onSelect,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.slot,
    required this.index,
    required this.count,
    required this.active,
    required this.lit,
    required this.showLabel,
    required this.glyphSize,
    required this.labelToken,
    required this.onSelect,
  });

  final TorchNavSlot slot;
  final int index;
  final int count;
  final bool active;
  final bool lit;
  final bool showLabel;
  final double glyphSize;
  final TiqTypeToken labelToken;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final docked = skin.mode == SkinMode.veld;
    final radius = docked
        ? BorderRadius.zero
        : BorderRadius.circular(torchPillRadius);
    final press = torchPressSurface(skin);

    // Night, granted: the amber pill. Night beneath a sheet, and every light
    // ground: the Abyssal block. Both are a solid fill with real ink on it, and
    // the weight and the `selected` flag carry the state as well.
    final Color? activeFill = active
        ? (lit ? p.flame600 : torchAbyssal(skin))
        : null;
    final Color activeInk = lit ? p.onAmber : torchOnAbyssal(skin);

    return Semantics(
      button: true,
      selected: active,
      label: '${slot.semanticLabel ?? slot.label}, tab ${index + 1} of $count',
      // THE ACTION, not only the flag: `excludeSemantics` drops the
      // gesture detector's own node, so without `onTap` here this is a
      // control a screen reader can focus and cannot activate.
      onTap: () => onSelect(index),
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: () => onSelect(index),
        borderRadius: radius,
        pressScale: torchPressScaleGlyph,
        builder: (context, pressed) {
          final ink = active
              ? activeInk
              : (pressed ? press.ink : p.navInkInactive);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: active ? activeFill : (pressed ? press.fill : null),
              borderRadius: radius,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Glyph(
                    icon: active ? slot.activeIcon : slot.icon,
                    size: glyphSize,
                    color: ink,
                    badgeCount: slot.badgeCount,
                  ),
                  if (showLabel) ...<Widget>[
                    const SizedBox(height: TiqSpace.s1),
                    Text(
                      slot.label,
                      style: labelToken.style(color: ink),
                      maxLines: 1,
                      // The measurement upstream guarantees this never fires.
                      // It is here so that a bug in the measurement clips one
                      // label rather than throwing a yellow overflow stripe
                      // across a shop floor.
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.size,
    required this.color,
    required this.badgeCount,
  });

  final IconData icon;
  final double size;
  final Color color;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final glyph = TorchGlyph(icon, size: size, color: color);
    final badge = badgeCount;
    if (badge == null || badge <= 0) return glyph;

    final skin = context.skin;
    final p = skin.palette;
    // Never amber and never crimson: a badge is a count, and a count is not a
    // severity. ink-1 on the nav body is the loudest neutral there is.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        glyph,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: p.ink1,
              borderRadius: BorderRadius.circular(torchPillRadius),
            ),
            child: Center(
              child: Text(
                badge <= 9 ? '$badge' : '9+',
                style: skin.text.monoIdent
                    .copyWith(size: 10, weight: FontWeight.w600)
                    .style(color: p.ground),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
