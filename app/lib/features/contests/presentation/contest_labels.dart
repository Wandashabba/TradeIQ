import '../../../core/widgets/console.dart';
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

/// A running contest is the one a manager watches; a cancelled one was a
/// decision someone should be able to explain. Upcoming and ended are records.
StatusLevel contestLevel(String status) => switch (status) {
  'active' => StatusLevel.good,
  'cancelled' => StatusLevel.critical,
  _ => StatusLevel.neutral,
};

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
