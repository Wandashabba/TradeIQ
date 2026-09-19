/// THE TORCHLIGHT SHEETS — Phase 2. **One modal container, and no dialog.**
///
/// ```dart
/// import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
/// ```
///
/// | | replaces | amber |
/// |---|---|---|
/// | [TorchSheet] / `showTorchSheet` | `showModalBottomSheet` styling | none from the container |
/// | [TorchSheetSwap] | a second sheet | none |
/// | [ProofBlock] | "you have unsaved work" | none |
/// | [DecisionSheet] | *(new)* — #374 | its safe action's `primaryCommit` |
/// | [ConfirmSheet] | the manager's ad-hoc confirms | none, categorically |
/// | [SkipReasonPicker] | *(new)* — #395 | its commit's `primaryCommit` |
/// | [SessionEndedSheet] / [SessionHeldLine] | *(new)* — #380/#392 | its sign-in's `primaryCommit` |
///
/// **The dialog is deleted** (unify §1.7). A non-dismissible bottom sheet
/// covers every blocking case a dialog covered; two modal containers is two
/// sets of insets, two dismissal rules, two scrims and two answers to the
/// question of what happens to the amber underneath.
///
/// **While a sheet is up, every amber beneath it is extinguished.** The route
/// below wires `TorchScope(beneathSheet: …)` from [TorchSheets] — see
/// [TorchSheetAware] — so the nav's active tab drops to its ink form and the
/// plate's strip light goes out. That is what lets the scrim stay at 72% and
/// keep the held work visible, which #380 requires.
///
/// **No sheet in this folder emits light of its own.** The three that carry a
/// commit action declare a claim for *that action*, which is
/// `TorchPrimaryButton` asking `TorchScope` exactly as it does everywhere else
/// in the app. The containers, the proof block and the confirm sheet declare
/// nothing.
library;

// [ConfirmSheet] lives beside [DecisionSheet] rather than in a file of its
// own: unify §1.21 makes it an *instance* of the same anatomy, and two files
// is how two instances become two components.
export 'sheet/decision_sheet.dart';
export 'sheet/proof_block.dart';
export 'sheet/session_ended_sheet.dart';
export 'sheet/sheet_spec.dart';
export 'sheet/skip_reason_picker.dart';
export 'sheet/torch_sheet.dart';
