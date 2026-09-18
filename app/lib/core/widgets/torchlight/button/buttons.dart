/// The Torchlight button family.
///
/// Five members and no sixth. Every commit, alternative, inline action,
/// destruction and glyph control in the app is one of these:
///
/// | | replaces | amber |
/// |---|---|---|
/// | [TorchPrimaryButton] | `ElevatedButton`, `AgentButton`, `PrimaryActionButton` | `TorchClaim.primaryCommit` |
/// | [TorchSecondaryButton] | `OutlinedButton` | none |
/// | [TorchTertiaryButton] | `TextButton` | none |
/// | [TorchDestructiveButton] | *(new)* | none, categorically |
/// | [TorchIconButton] | 26 unlabelled `IconButton`s | none |
///
/// Press, focus and haptics are [TorchPressable]'s, once, for all five.
library;

export 'destructive_button.dart';
export 'icon_button.dart';
export 'primary_button.dart';
export 'secondary_button.dart';
export 'tertiary_button.dart';
export 'torch_button.dart'
    show TorchBarNote, TorchBusyDots, TorchGlyph, TorchTriangle;
export 'torch_press.dart'
    show
        TorchBuzz,
        TorchFocusRing,
        TorchPressSurface,
        TorchPressable,
        torchAbyssal,
        torchFocusRing,
        torchOnAbyssal,
        torchPressSurface;
