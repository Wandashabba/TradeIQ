/// THE MARKS AND THE FIGURES — Torchlight Aisle, Phase 1.
///
/// The things that carry state, and the things that carry numbers. Import this
/// rather than the individual files: the point of a system is that a screen
/// reaches for one door.
///
/// ```dart
/// import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
/// ```
///
/// What lives here, and what each one replaces:
///
/// | component | replaces |
/// |---|---|
/// | `StatusChip` | the status pills and `status_pill_colors.dart` |
/// | `FlagChip` | nothing — new (#393) |
/// | `SeverityMark` | ad-hoc coloured dots |
/// | `SectionStateGlyph` | `agent_state_glyph.dart` (#375) |
/// | `Delta` / `DeltaSlot` | `DeltaChip`, `DeltaPill`, `TileDelta.text` |
/// | `StatTile` / `StatCluster` | the `rich_figures.dart` tiles |
/// | `Meter` | nothing — new |
/// | `NotMeasured` | a zero with no explanation |
/// | `ProvisionalMarker` / `ReconciliationLine` | nothing — new (#377/#390/#398) |
/// | `Eyebrow` | `Text(label.toUpperCase())` |
///
/// **Nothing here emits amber.** Not one of these components names a flame
/// token or declares a `TorchClaim`, and `marks_amber_test.dart` renders every
/// state of every one of them in all three skins and counts the flame-hued
/// pixels. Amber is emitted light and every object in this file is a label.
library;

export '../../design/figure_slot.dart';
export '../../design/tiq_number.dart' show FigureState, TiqUnit, emDash;
export 'figure/eyebrow.dart';
export 'figure/meter.dart';
export 'figure/not_measured.dart';
export 'figure/provisional.dart';
export 'figure/sample_threshold.dart';
export 'figure/stat_cluster.dart';
export 'figure/stat_tile.dart';
export 'mark/delta.dart';
export 'mark/flag_chip.dart';
export 'mark/section_state_glyph.dart';
export 'mark/severity_mark.dart';
export 'mark/status_chip.dart';
export 'mark/tiq_chip.dart';
export 'mark/tiq_mark.dart';
