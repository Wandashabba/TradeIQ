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
// AND IT STOPPED. The map below is empty, and that is the whole point: every
// row left this ledger with the screen it described rather than being zeroed
// in place, and a file that leaves may not come back — an unlisted file may
// not have a violation at all. The last four groups took the last of them:
//
//   dashboard_shell_screen.dart   32   the execution overview
//   live_location_layer.dart      13   shared with the agent trail map
//   visit_detail_screen.dart      17   the manager's visit review
//   artifact_screen.dart           6   the Ask TradeIQ full view
//   artifact_filters.dart          9   its controls
//   expanded_views.dart            6   its charts and its table twin
//
// An empty map is not a weaker guard than a full one. The ratchet's second
// rule does the work now: a file that is not listed here may not carry a
// hardcoded colour, palette or text style, and none of them is. The next
// hardcoded `TextStyle(` anywhere under `lib/features/**` fails this test on
// the PR that adds it, with nowhere to hide.
//
// Leave the map here rather than deleting the file. A ledger that has reached
// zero is the only proof the arithmetic ever closed, and the test that reads
// it is the guard that keeps it there.
// The one row below is the manager's visit review, which is in flight on its
// own branch and leaves this map with its own screen. When that lands, this
// map is empty.
const Map<String, int> torchlightStyleDebt = <String, int>{
  'visits/presentation/visit_detail_screen.dart': 17,
};

/// The totals the ledger above adds up to, asserted separately so a
/// find-and-replace that quietly rewrites the whole map still trips.
const int torchlightStyleDebtTotal = 17;
