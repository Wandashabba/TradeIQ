// GENERATED LEDGER — see torchlight_lint_test.dart.
//
// The style debt that existed in `lib/features/**` when the Torchlight Aisle
// tokens landed, one entry per file. 477 hardcoded style decisions in 74 of
// 133 files: 409 bare `TextStyle(`, 38 raw `Color(0x…)` and 30 uses of
// Material's `Colors.` palette. The submit gate (13) and the visit outcome
// (24) came off it when the closing screens were migrated: 440 in 72 files.
// The manager's worklists then took it to 372 in 67 files — but only 12 of
// those 68 are theirs (alerts 5, alert rules 2, tasks 5). The other 56 were
// STALE entries for `audit_shell_screen` (26) and `today_screen` (30), two
// files already clean whose rows had never been regenerated out. A ledger
// that takes credit for somebody else's work is a ledger nobody can read the
// ratchet off. Later migrations have taken it further; the map below and the
// total at the foot are what count. Operations — outlets, orders, beat plans
// and sales targets — took all eight of its files off the map (36), so the
// group has no row here at all, which is the only score a finished migration
// should have.
//
// The ratchet is one-sided on purpose. A file may not gain a violation and a
// file that is not listed may not have one at all — that is what stops the
// drift coming back. A file that LOSES violations passes, and the test prints
// the number to lower this ledger to; two other agents are editing these
// folders right now and a two-sided ratchet would fail their PRs for making
// things better.
//
// To regenerate after a migration: run
//   flutter test test/core/theme/torchlight/torchlight_lint_test.dart
// and paste the map it prints.
//
// WHERE THIS STOPS, AND WHY. The six rows below are not leftover debt in
// screens that have already moved. They ARE the app's last un-migrated
// screens — the same six files that still import GlassPane, LumenGlass,
// LumenPalette, AppColors and TiqColors:
//
//   dashboard_shell_screen.dart   a live route (app_router.dart:201)
//   visit_detail_screen.dart      a live route (app_router.dart:452)
//   artifact_screen.dart          a live route (app_router.dart:361)
//   artifact_filters.dart         built by artifact_screen.dart
//   expanded_views.dart           built by artifact_screen.dart
//   live_location_layer.dart      shared with the migrated trail map
//
// Sixty-three of the 83 are a bare `TextStyle(` at a size the Torchlight
// scale does not have — 10.5, 11.5 and 12.5 are not members of it, and where
// a size does exist (12 is `meta`, 13 is `label`, 14 is `body`) the role
// carries a line-height and a tracking these call sites do not set. The
// other twenty — 13 raw `Color(0x…)` and 7 `Colors.*` — are map-pin and
// chart colours: white pin rings, alpha-white gridlines and axes, the
// agent-pin blues. There is no token for those and there should not be one;
// they are a basemap's colours, not the product's.
//
// So there is no entry here that can be converted without restyling a screen
// that is still painted in Lumen Glass, and half-migrating one would put
// Torchlight type inside violet glass panes, which is neither system. Each
// row leaves this map with its screen. The map empties when the last of the
// six is migrated, and not before — the same ordering GlassPane is deleted
// under.
const Map<String, int> torchlightStyleDebt = <String, int>{
  // STILL HERE ON PURPOSE. The live layer is a shared component: the trail
  // map draws its squares and so does the dashboard's "Where are my agents"
  // panel, which has not been migrated. Moving it now would restyle an
  // unmigrated screen mid-flight and break its goldens for a change that is
  // not about it — the same ordering GlassPane is being deleted under, where
  // the component goes when its call sites are empty and not before. It
  // belongs to whoever migrates the dashboard shell.
  'agents/presentation/live_location_layer.dart': 13,
  'assistant/presentation/artifact_filters.dart': 9,
  'assistant/presentation/artifact_screen.dart': 6,
  'assistant/view_specs/expanded_views.dart': 6,
  'dashboard/presentation/dashboard_shell_screen.dart': 32,
  'visits/presentation/visit_detail_screen.dart': 17,
};

/// The totals the ledger above adds up to, asserted separately so a
/// find-and-replace that quietly rewrites the whole map still trips.
const int torchlightStyleDebtTotal = 83;
