// GENERATED LEDGER — see torchlight_lint_test.dart.
//
// The style debt that existed in `lib/features/**` when the Torchlight Aisle
// tokens landed, one entry per file. 477 hardcoded style decisions in 74 of
// 133 files: 409 bare `TextStyle(`, 38 raw `Color(0x…)` and 30 uses of
// Material's `Colors.` palette. The submit gate (13) and the visit outcome
// (24) came off it when the closing screens were migrated, and the manager's
// worklists — alerts, alert rules and tasks — took 68 more across five files.
// Ask TradeIQ's answer surface, Today and the audit shell took it to 324 in
// 55 files.
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
const Map<String, int> torchlightStyleDebt = <String, int>{
  'agents/presentation/agent_trail_screen.dart': 20,
  'agents/presentation/live_location_layer.dart': 13,
  'assistant/presentation/artifact_filters.dart': 9,
  'assistant/presentation/artifact_screen.dart': 6,
  'assistant/view_specs/expanded_views.dart': 6,
  'audit/presentation/sections/client_questions_screen.dart': 3,
  'audit/presentation/sections/s10_scorecard_screen.dart': 8,
  'audit/presentation/sections/s1_outlet_info_screen.dart': 5,
  'audit/presentation/sections/s2_stock_screen.dart': 10,
  'audit/presentation/sections/s3_4_visibility_display_screen.dart': 1,
  'audit/presentation/sections/s5_pricing_promotions_screen.dart': 2,
  'audit/presentation/sections/s6_competitive_screen.dart': 2,
  'audit/presentation/sections/s7_capability_screen.dart': 2,
  'audit/presentation/sections/s8_risks_screen.dart': 4,
  'audit/presentation/sections/s9_action_plan_screen.dart': 3,
  'auth/presentation/landing_screen.dart': 5,
  'auth/presentation/login_screen.dart': 13,
  'beatplans/presentation/beat_plan_form_screen.dart': 5,
  'beatplans/presentation/beatplans_screen.dart': 2,
  'campaigns/presentation/campaign_form_screen.dart': 4,
  'campaigns/presentation/campaign_return_view.dart': 3,
  'campaigns/presentation/campaigns_screen.dart': 1,
  'clients/presentation/client_config_screen.dart': 21,
  'collaboration/presentation/message_attachment_thumb.dart': 3,
  'collaboration/presentation/messages_screen.dart': 9,
  'contests/presentation/contest_form_screen.dart': 2,
  'contests/presentation/contest_standings_screen.dart': 4,
  'contests/presentation/contests_screen.dart': 1,
  'contests/presentation/my_contests_screen.dart': 13,
  'dashboard/presentation/dashboard_shell_screen.dart': 32,
  'dispatch/presentation/dispatch_screen.dart': 2,
  'fraud/presentation/fraud_screen.dart': 4,
  'gamification/presentation/agent_points_screen.dart': 2,
  'gamification/presentation/leaderboard_screen.dart': 2,
  'incentives/presentation/incentives_screen.dart': 2,
  'notifications/presentation/notification_preferences_screen.dart': 2,
  'orders/presentation/order_form_screen.dart': 5,
  'orders/presentation/orders_screen.dart': 2,
  'outlets/presentation/create_outlet_screen.dart': 7,
  'outlets/presentation/outlets_list_screen.dart': 1,
  'reports/presentation/report_form_screen.dart': 2,
  'reports/presentation/report_run_history_screen.dart': 13,
  'reports/presentation/report_schedule_form_screen.dart': 3,
  'reports/presentation/report_schedules_screen.dart': 1,
  'sales_targets/presentation/sales_attainment_panel.dart': 3,
  'sales_targets/presentation/sales_targets_screen.dart': 11,
  'templates/presentation/dynamic_template_form.dart': 4,
  'templates/presentation/templates_screen.dart': 3,
  'territories/presentation/territories_screen.dart': 2,
  'territories/presentation/territory_form_screen.dart': 1,
  'territories/presentation/territory_map_screen.dart': 5,
  'trends/presentation/trends_screen.dart': 9,
  'users/presentation/users_screen.dart': 3,
  'visits/presentation/visit_detail_screen.dart': 17,
  'webhooks/presentation/webhooks_screen.dart': 6,
};

/// The totals the ledger above adds up to, asserted separately so a
/// find-and-replace that quietly rewrites the whole map still trips.
const int torchlightStyleDebtTotal = 324;
