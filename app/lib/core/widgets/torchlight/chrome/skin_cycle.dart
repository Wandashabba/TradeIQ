import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_button.dart';
import '../button/torch_press.dart';

/// THE SKIN CYCLE — sun, paper, moon, in one 56dp control.
///
/// Three positions, **each a different glyph**: sun is Veld, paper is Day, moon
/// is Night. A tap advances Day → Veld → Night → Day. There is no colour cue
/// and there is no label at rest; the state is the silhouette, and the sentence
/// is the semantic label.
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
         'Double-tap for Veld, the outdoor high-contrast screen." A toggle '
         'that announces where it is and not where it goes makes a blind '
         'user press it to find out.',
       );

  /// The skin showing now. [SkinMode.auto] resolves to whichever of the three
  /// it produced, so the control always shows a real glyph.
  final SkinMode mode;

  final ValueChanged<SkinMode> onChanged;

  /// Names the next state, and is announced as a live region when it changes.
  final String semanticLabel;

  /// Opens the three-row sheet naming all three skins.
  final VoidCallback? onLongPress;

  /// Day → Veld → Night → Day.
  ///
  /// It starts at Day because Day is the agent default and the agent is who
  /// reaches for this; the cycle then goes *outward* (brighter, for the
  /// forecourt) before it goes dark.
  static SkinMode next(SkinMode mode) => switch (mode) {
    SkinMode.day => SkinMode.veld,
    SkinMode.veld => SkinMode.night,
    SkinMode.night => SkinMode.day,
    SkinMode.auto => SkinMode.day,
  };

  /// The glyph for a skin. sun = Veld, paper = Day, moon = Night.
  static IconData glyphFor(SkinMode mode) => switch (mode) {
    SkinMode.veld => Icons.wb_sunny_outlined,
    SkinMode.night => Icons.dark_mode_outlined,
    _ => Icons.article_outlined,
  };

  /// The control's edge length, before text scale.
  static double sizeFor(TiqSkin skin) => skin.mode == SkinMode.veld ? 64 : 56;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final scaler = MediaQuery.textScalerOf(context);
    final base = sizeFor(skin);
    // 56 → 72 at 2.0×, 64 → 80 in Veld. The control grows under the
    // glyph-scale rule; it is never pinned.
    final side = scaler.scale(base).clamp(base, base + 16);
    final glyph = scaler.scale(24).clamp(24.0, 48.0);
    final press = torchPressSurface(skin);
    final radius = BorderRadius.circular(skin.radii.control);

    return Semantics(
      button: true,
      liveRegion: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: () => onChanged(next(mode)),
        onLongPress: onLongPress,
        borderRadius: radius,
        // Veld kills the press scale along with every other motion; the fill
        // inversion is the whole cue there.
        pressScale: skin.mode == SkinMode.veld ? 1 : torchPressScaleControl,
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
