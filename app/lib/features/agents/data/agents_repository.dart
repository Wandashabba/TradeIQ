import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../dashboard/data/dashboard_repository.dart'
    show dashboardFilterProvider, nowProvider;

/// Where an agent is, as far as check-in data can tell us.
///
/// Three states, not four. #153 sketched an `offline` state, but T0 has no
/// heartbeat: it cannot distinguish a phone that is off from an agent driving
/// between stores. A marker claiming `offline` would assert something we do
/// not observe.
enum AgentState { atStore, inTransit, idle }

/// One confirmed store presence.
class AgentStop {
  const AgentStop({
    required this.visitId,
    required this.outletId,
    required this.outletName,
    required this.lat,
    required this.lng,
    required this.checkinTs,
    required this.inProgress,
  });

  final String visitId;
  final String outletId;
  final String outletName;
  final double lat;
  final double lng;
  final DateTime checkinTs;
  final bool inProgress;

  factory AgentStop.fromJson(Map<String, dynamic> json) => AgentStop(
    visitId: json['visitId'] as String,
    outletId: json['outletId'] as String,
    outletName: json['outletName'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    checkinTs: DateTime.parse(json['checkinTs'] as String),
    inProgress: json['status'] == 'in_progress',
  );
}

/// One agent's day, as returned by GET /agents/activity.
class AgentActivity {
  const AgentActivity({
    required this.agentId,
    required this.name,
    required this.state,
    required this.stops,
    this.currentOutletName,
    this.lastSeenAt,
  });

  final String agentId;

  /// Carries the agent's EMAIL, not a personal name — `User` has no
  /// display-name column. Named for the role it plays in the UI (what to show
  /// for this agent) rather than the value it happens to hold today.
  final String name;
  final AgentState state;
  final List<AgentStop> stops;

  /// Set only when [state] is [AgentState.atStore].
  final String? currentOutletName;

  /// The latest check-in IN THE REQUESTED RANGE, or null if there was none.
  final DateTime? lastSeenAt;

  /// The last outlet the agent was confirmed at, whether or not they are still
  /// there. Drives the "left Pick n Pay" half of the panel copy.
  ///
  /// Sorts by `checkinTs` rather than trusting `stops` to already be in
  /// order — `deriveAgentState` on the backend does the same for the same
  /// reason: a caller-trusted ordering that silently breaks would report a
  /// confidently wrong outlet with no throw and no signal.
  String? get lastOutletName {
    if (stops.isEmpty) return null;
    final sorted = [...stops]
      ..sort((a, b) => a.checkinTs.compareTo(b.checkinTs));
    return sorted.last.outletName;
  }

  factory AgentActivity.fromJson(Map<String, dynamic> json) {
    final outlet = json['currentOutlet'] as Map<String, dynamic>?;
    final lastSeen = json['lastSeenAt'] as String?;
    return AgentActivity(
      agentId: json['agentId'] as String,
      name: json['name'] as String,
      state: switch (json['state']) {
        'at_store' => AgentState.atStore,
        'in_transit' => AgentState.inTransit,
        // Anything unrecognised falls back to idle rather than throwing. Idle
        // is the state that claims the least.
        _ => AgentState.idle,
      },
      currentOutletName: outlet?['name'] as String?,
      lastSeenAt: lastSeen == null ? null : DateTime.parse(lastSeen),
      stops: ((json['stops'] as List?) ?? const [])
          .map((s) => AgentStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Local midnight to the next local midnight around [day].
///
/// The server does no timezone reasoning — see the comment on
/// `GET /agents/activity`. The day boundary is decided here, on the client,
/// which is the only place that knows the manager's locale.
(DateTime, DateTime) dayBoundsLocal(DateTime day) {
  final from = DateTime(day.year, day.month, day.day);
  return (from, from.add(const Duration(days: 1)));
}

/// One page of agent activity, plus whether the server had more to give.
///
/// `truncated` exists because silently showing the first N agents and calling
/// it "your team" is the one thing this feature must never do — a manager who
/// cannot see an agent assumes they did not work, not that the list was cut.
class AgentActivityPage {
  const AgentActivityPage({required this.agents, required this.truncated});
  final List<AgentActivity> agents;
  final bool truncated;
}

abstract class AgentsRepository {
  /// GET /agents/activity (manager/admin).
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  });
}

class DioAgentsRepository implements AgentsRepository {
  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/agents/activity',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        // The backend's own MAX_LIMIT — sent explicitly so truncation is
        // unlikely at realistic team sizes rather than a near-certainty at
        // the server's DEFAULT_LIMIT of 50.
        'limit': 200,
        'territoryId': ?territoryId,
      },
    );
    // Reads the shared envelope like every other list — this endpoint used to
    // key its rows under `agents` and was the app's one exception to
    // PaginatedResponse. The exception is what made it easy to forget.
    final page = PaginatedResponse<AgentActivity>.fromJson(
      response.data ?? const <String, dynamic>{},
      (json) => AgentActivity.fromJson(json as Map<String, dynamic>),
    );
    return AgentActivityPage(
      agents: page.data,
      // Deliberately not a cursor the caller can follow: the panel asks for
      // the server's MAX_LIMIT in one go, so a non-null cursor means the team
      // is larger than one page and the panel says so rather than paging.
      truncated: page.nextCursor != null,
    );
  }
}

final agentsRepositoryProvider = Provider<AgentsRepository>(
  (ref) => DioAgentsRepository(),
);

/// Today's activity, scoped by the dashboard's territory filter so the panel
/// agrees with every other panel by construction rather than by convention.
///
/// Retries disabled, matching `territory_map_screen.dart`: Riverpod's default
/// backs off silently for seconds before surfacing an error, leaving a bare
/// spinner with no explanation on a screen the manager is looking at.
final agentActivityTodayProvider = FutureProvider<AgentActivityPage>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  // Through nowProvider, not DateTime.now() directly — see its doc comment
  // in dashboard_repository.dart: injected so a test can pin "now" instead
  // of racing wall-clock time.
  final now = ref.read(nowProvider)();
  final (from, to) = dayBoundsLocal(now);
  return ref
      .read(agentsRepositoryProvider)
      .listActivity(from: from, to: to, territoryId: filter.territoryId);
}, retry: (retryCount, error) => null);

/// One chosen day's activity, for the drill-in map's date picker.
///
/// `.autoDispose`, unlike the other families in this repo: those key on a
/// bounded set (an outlet id, a territory id), but this one keys on a date —
/// every distinct day a manager browses in a session would otherwise cache
/// forever, each instance still watching `dashboardFilterProvider`, so
/// changing the territory filter would re-fire a request for every day ever
/// viewed.
final agentActivityForDayProvider = FutureProvider.autoDispose
    .family<AgentActivityPage, DateTime>((ref, day) {
      final filter = ref.watch(dashboardFilterProvider);
      final (from, to) = dayBoundsLocal(day);
      return ref
          .read(agentsRepositoryProvider)
          .listActivity(from: from, to: to, territoryId: filter.territoryId);
    }, retry: (retryCount, error) => null);
