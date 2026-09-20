/// THE TORCHLIGHT INPUTS — Phase 2, the trough grammar.
///
/// ```dart
/// import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
/// ```
///
/// | | replaces | amber |
/// |---|---|---|
/// | [TorchTextField] | `TextField` decoration | none |
/// | [TorchNumericField] | *(new)* — the locale formatter, the overflow anchor | none |
/// | [CountStepper] | the current stepper | none |
/// | [TorchToggle] | `Switch` | none |
/// | [TorchCheckbox] / [TorchCheckboxGroup] | `Checkbox` | none |
/// | [ChoiceRow] | *(new)* — nothing-selected is a state | none |
/// | [TorchPickerField] | `DropdownButtonFormField` — a sheet of rows | none |
/// | [TorchFilterChip] / [TorchFilterRail] | `ChoiceChip` | none |
/// | [TorchHandednessScope] | *(new)* — #407 | none |
/// | [VerdictControl] | *(new)* — the fraud queue's ruling (#392) | its commit |
///
/// **Every input is a trough**: radius 10 at the BOTTOM corners and 0 at the
/// top, because a trough holds at the bottom and the shape says so before a
/// word is read. See [TroughSpec] for the geometry and for the one deliberate
/// deviation in this folder — the focused field's rule is 2px ink-1 rather
/// than 2px flame-700, because no Phase 2 component emits light.
///
/// **Nothing here declares a `TorchClaim` or names a flame token.** The one
/// apparent exception proves it: [CountStepper]'s number sheet uses
/// `TorchPrimaryButton` for its `Set` action, which asks `TorchScope` like
/// every other primary in the app and renders its ink form when nothing
/// granted it a light.
///
/// **Selected has one vocabulary** across this folder and the chips: `lifted`
/// fill, a 1px ink-1 border, a mark, and weight 700. Three channels, never a
/// fill step alone, never amber.
library;

export 'input/checkbox.dart';
export 'input/choice_row.dart';
export 'input/count_stepper.dart';
export 'input/field_shell.dart';
export 'input/filter_chip.dart';
export 'input/handedness.dart';
export 'input/numeric_field.dart';
export 'input/picker_field.dart';
export 'input/text_field.dart';
export 'input/toggle.dart';
export 'input/trough.dart';
export 'input/verdict_control.dart';
