/// The Torchlight Aisle **soft row** — Phase 1's first component, and the
/// single most-used object in the product.
///
/// One component in two forms and three densities, plus four configurations
/// of it. A configuration chooses a density, a mark, a severity and some
/// strings; it never paints a fill, an edge, a rule or a radius of its own,
/// which is what stops "the outbox row" and "the decision row" drifting into
/// two different rows.
///
/// ```dart
/// import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
/// ```
///
/// | | |
/// |---|---|
/// | [SoftRow] | the component — list / standalone, compact / standard / tall |
/// | [SoftRowSpec] | its resolved geometry, for a screen aligning something beside it |
/// | [SoftRowChevron] | the one chevron |
/// | [RowMarkTile] | the drawn state silhouettes |
/// | [OutboxRow] | #382 — one queued capture, alive |
/// | [HeldWorkRow] | #391 — the console's mirror of the same object |
/// | [DecisionRow] | the manager's "needs a decision" item |
/// | [PersonRow] | #399/#400 — a human, never an id, never a photo |
///
/// **A row never emits light.** Nothing in this directory declares a
/// `TorchClaim` or names a flame token, in any state, on any skin.
library;

export 'decision_row.dart';
export 'held_work_row.dart';
export 'outbox_row.dart';
export 'person_row.dart';
export 'row_marks.dart';
export 'soft_row.dart';
export 'soft_row_spec.dart';
