import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_button.dart';
import '../button/torch_press.dart';

/// THE SKIN CYCLE — paper and moon, in one 56dp control.
///
/// Two positions, **each a different glyph**: paper is Day, moon is Night. A
/// tap advances Day → Night → Day. There is no colour cue and there is no
/// label at rest; the state is the silhouette, and the sentence is the
/// semantic label.
///
/// It had a third position, the sun — Veld, the outdoor high-contrast skin.
/// The owner removed Veld on 28 September 2026; see `docs/design/spec/
/// unify.md` §4. The control, its label rule and its two homes are unchanged.
///
/// ## Where it lives, and where it does not
///
/// unify §1.2: **not on the nav row.** The agent surface put a 56dp cycle beside
/// the pill, and at 360dp that leaves 192dp for four slots. So:
///
/// * on a **tab root** it is the app header's single trailing icon button;
/// * on **every other screen** it is at the leading end of the thumb zone.
///
/// Those are the only two places, and the shell puts it in them.
///
/// ## The skin change is instant
///
/// No cross-fade. A 320ms full-screen dissolve reads as a crash on a 2GB
/// handset; the `ThemeExtension` swap is a rebuild and only the glyph animates.
class TorchSkinCycle extends StatelessWidget {
  const TorchSkinCycle({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.semanticLabel,
    this.onLongPress,
  }) : assert(
         semanticLabel.length > 0,
         'The label names the NEXT state, not this one: "Screen: Day. '
         'Double-tap for Night." A toggle that announces '
         'where it is and not where it goes makes a blind user press it to '
         'find out.',
       );

  /// The skin showing now. [SkinMode.auto] resolves to whichever of the two
  /// it produced, so the control always shows a real glyph.
  final SkinMode mode;

  final ValueChanged<SkinMode> onChanged;

  /// Names the next state, and is announced as a live region when it changes.
  final String semanticLabel;

  /// Opens the two-row sheet naming both skins.
  final VoidCallback? onLongPress;

  /// Day → Night → Day.
  ///
  /// [SkinMode.auto] lands on Day: it is the agent default, and the agent is
  /// who reaches for this.
  static SkinMode next(SkinMode mode) => switch (mode) {
    SkinMode.night => SkinMode.day,
    SkinMode.day || SkinMode.auto => SkinMode.night,
  };

  /// The glyph for a skin. paper = Day, moon = Night.
  static IconData glyphFor(SkinMode mode) => switch (mode) {
    SkinMode.night => Icons.dark_mode_outlined,
    _ => Icons.article_outlined,
  };

  /// The control's edge length, before text scale.
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final scaler = MediaQuery.textScalerOf(context);
    const base = size;
    // 56 → 72 at 2.0×. The control grows under the glyph-scale rule; it is
    // never pinned.
    final side = scaler.scale(base).clamp(base, base + 16);
    final glyph = scaler.scale(24).clamp(24.0, 48.0);
    final press = torchPressSurface(skin);
    final radius = BorderRadius.circular(skin.radii.control);

    return Semantics(
      button: true,
      liveRegion: true,
      label: semanticLabel,
      // THE ACTION, not only the flag: `excludeSemantics` drops the
      // gesture detector's own node, so without `onTap` here this is a
      // control a screen reader can focus and cannot activate.
      onTap: () => onChanged(next(mode)),
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: () => onChanged(next(mode)),
        onLongPress: onLongPress,
        borderRadius: radius,
        pressScale: torchPressScaleControl,
        builder: (context, pressed) => Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: pressed ? press.fill : p.well,
            borderRadius: radius,
            border: Border.all(
              color: p.edgeControl,
              width: skin.depth.borderWidth,
            ),
          ),
          child: Center(
            child: TorchGlyph(
              glyphFor(mode),
              size: glyph,
              color: pressed ? press.ink : p.ink1,
            ),
          ),
        ),
      ),
    );
  }
}
