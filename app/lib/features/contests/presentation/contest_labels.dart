import '../../../core/widgets/torchlight/marks.dart';
import '../data/contests_repository.dart';

/// English copy for the manager console's contest screens (#124). The console
/// is English-only; the agent's view reads its words from `app_*.arb`.

String contestStatusWord(String status) => switch (status) {
  'upcoming' => 'Upcoming',
  'active' => 'Active',
  'ended' => 'Ended',
  'cancelled' => 'Cancelled',
  _ => status,
};

/// A contest's lifecycle as a [StatusChip] level.
///
/// Two levels, and the reason is that the other three are verdicts this system
/// refuses to invent. A **running** contest is genuinely [StatusLevel.live] —
/// something is happening right now and the dot says so. Everything else is
/// [StatusLevel.held]: Oatmeal, a square, and the word. Upcoming, Ended and
/// Cancelled are not degrees of wrong, so none of them may wear crimson, and
/// none of them is "fine", so none may wear the on-target circle either.
///
/// What separates the three is the **word** — which is the channel that
/// survives greyscale, deuteranopia, glare and a screen reader — and it is
/// stated twice: once in the chip and once, in full, in
/// [contestWhenSummary] on the row's own line.
StatusLevel contestLevel(String status) =>
    status == 'active' ? StatusLevel.live : StatusLevel.held;

String contestEventWord(String type) => switch (type) {
  'visit_submitted' => 'Visits submitted',
  'task_closed' => 'Tasks closed',
  'scorecard' => 'Scorecards',
  _ => type,
};

/// "All points", or the counted kinds in the backend's order.
String contestCountsSummary(Contest contest) => contest.eventTypes.isEmpty
    ? 'All points'
    : contest.eventTypes.map(contestEventWord).join(', ');

String contestScopeSummary(Contest contest) => contest.territoryId == null
    ? 'All territories'
    : (contest.territoryName ?? 'One territory');

/// Where the contest is in time: "3 days left", "Starts 2026-10-01", …
String contestWhenSummary(Contest contest) => switch (contest.status) {
  'active' =>
    contest.daysLeft == 1 ? 'Last day' : '${contest.daysLeft ?? 0} days left',
  'upcoming' => 'Starts ${contest.startDate}',
  'ended' => 'Ended ${contest.endDate}',
  _ => 'Cancelled',
};
