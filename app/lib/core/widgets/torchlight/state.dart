/// THE TORCHLIGHT STATES — Phase 2. What a screen shows when it has no
/// content, bad content, or content that has not arrived.
///
/// ```dart
/// import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
/// ```
///
/// | | replaces | amber |
/// |---|---|---|
/// | [Skeleton] / [SkeletonLine] / [SkeletonShell] / [SkeletonRows] | `CircularProgressIndicator` | none |
/// | [EmptyState] (+ [EmptyStateDrawing], [EmptyDrawing]) | a centred "No data" | none |
/// | [ErrorState] (+ [TorchErrorMessage], [TorchErrorRegion]) | raw error text | none |
/// | [OfflineHeldBanner] | the ad-hoc sync banners | none |
/// | [TorchProgressBar] (+ [ProgressMilestone]) | *(new)* — #391/#396 | none |
/// | [TorchToast] / `showTorchToast` | `SnackBar` | none |
/// | [PaginationFooter] | *(new)* | none |
///
/// The section rule is **not** here: `SectionRule` landed in Phase 1
/// (`lib/core/widgets/torchlight/section_rule.dart`) and already generalises —
/// count slot, action slot, empty line, the 2.0× wrap and the Veld
/// above-the-rule form. Phase 2 adds nothing to it.
///
/// **Nothing in this folder emits light.** Not the skeleton's travelling rule
/// (Oatmeal — a skeleton is loading, not live), not the held banner (Oatmeal
/// plus a square plus a word — working offline is the normal state of South
/// African field work, not a fault), not the reward bar (the most motivating
/// object in the product and the most tempting to light; the near-reward amber
/// exception was written, argued and deleted), and not a toast, which is a
/// report. Where one of these blocks carries a primary action, that action
/// asks `TorchScope` like every other primary in the app.
library;

export 'state/empty_drawing.dart';
export 'state/empty_state.dart';
export 'state/error_state.dart';
export 'state/held_banner.dart';
export 'state/pagination_footer.dart';
export 'state/progress_bar.dart';
export 'state/skeleton.dart';
export 'state/toast.dart';
