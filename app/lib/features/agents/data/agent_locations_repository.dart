import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../dashboard/data/dashboard_repository.dart'
    show dashboardFilterProvider;

/// Where an agent is, from their foreground location heartbeat (#153 T1).
///
/// Four states, where T0's check-in trail ([AgentState]) has three: a heartbeat
/// can observe that pings have stopped, so `offline` is finally something we
/// see rather than guess. Derived on the server; see
/// `backend/src/modules/agents/agentLocations.service.ts`.
enum LiveAgentState { atStore, inTransit, stale, offline }

/// One agent's latest shared position, as of [AgentLocationsPage.serverTime].
class AgentLocation {
  const AgentLocation({
    required this.agentId,
    required this.name,
    required this.state,
    this.lat,
    this.lng,
    this.accuracyM,
    this.recordedAt,
    this.ageSeconds,
    this.currentOutletName,
    this.lastOutletName,
    this.lastOutletFromPing = false,
  });

  final String agentId;
  final String name;
  final LiveAgentState state;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final DateTime? recordedAt;

  /// Age of the position at [AgentLocationsPage.serverTime]; null if the agent
  /// has never shared one.
  final int? ageSeconds;

  /// Set only when [state] is [LiveAgentState.atStore].
  final String? currentOutletName;

  /// The best-known last store — from the latest ping's geofence when
  /// [lastOutletFromPing], otherwise from the latest confirmed check-in.
  final String? lastOutletName;
  final bool lastOutletFromPing;

  bool get hasPosition => lat != null && lng != null;

  factory AgentLocation.fromJson(Map<String, dynamic> json) {
    final ping = json['lastPing'] as Map<String, dynamic>?;
    final current = json['currentOutlet'] as Map<String, dynamic>?;
    final last = json['lastOutlet'] as Map<String, dynamic>?;
    return AgentLocation(
      agentId: json['agentId'] as String,
      name: json['name'] as String,
      state: switch (json['state']) {
        'at_store' => LiveAgentState.atStore,
        'in_transit' => LiveAgentState.inTransit,
        'stale' => LiveAgentState.stale,
        // Anything unrecognised is offline: the state that claims the least.
        _ => LiveAgentState.offline,
      },
      lat: (ping?['lat'] as num?)?.toDouble(),
      lng: (ping?['lng'] as num?)?.toDouble(),
      accuracyM: (ping?['accuracyM'] as num?)?.toDouble(),
      recordedAt: ping == null
          ? null
          : DateTime.parse(ping['recordedAt'] as String),
      ageSeconds: (json['ageSeconds'] as num?)?.toInt(),
      currentOutletName: current?['name'] as String?,
      lastOutletName: last?['name'] as String?,
      lastOutletFromPing: last?['source'] == 'ping',
    );
  }
}

class AgentLocationsPage {
  const AgentLocationsPage({
    required this.serverTime,
    required this.intervalSeconds,
    required this.staleAfterSeconds,
    required this.offlineAfterSeconds,
    required this.agents,
    required this.truncated,
  });

  /// The instant every age was measured from — the honest "last updated".
  final DateTime serverTime;
  final int intervalSeconds;
  final int staleAfterSeconds;
  final int offlineAfterSeconds;
  final List<AgentLocation> agents;

  /// The server had more agents than one page; say so rather than imply a team.
  final bool truncated;

  factory AgentLocationsPage.fromJson(Map<String, dynamic> json) =>
      AgentLocationsPage(
        serverTime: DateTime.parse(json['serverTime'] as String),
        intervalSeconds: (json['intervalSeconds'] as num).toInt(),
        staleAfterSeconds: (json['staleAfterSeconds'] as num).toInt(),
        offlineAfterSeconds: (json['offlineAfterSeconds'] as num).toInt(),
        agents: ((json['data'] as List?) ?? const [])
            .map((e) => AgentLocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        truncated: json['nextCursor'] != null,
      );
}

abstract class AgentLocationsRepository {
  /// GET /agents/locations (manager/admin).
  Future<AgentLocationsPage> listLocations({String? territoryId});
}

class DioAgentLocationsRepository implements AgentLocationsRepository {
  @override
  Future<AgentLocationsPage> listLocations({String? territoryId}) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/agents/locations',
      queryParameters: {
        // The server's maximum page, as the T0 panel does: truncation is then
        // unlikely, and flagged when it happens rather than paged silently.
        'limit': 200,
        'territoryId': ?territoryId,
      },
    );
    return AgentLocationsPage.fromJson(res.data ?? const {});
  }
}

final agentLocationsRepositoryProvider = Provider<AgentLocationsRepository>(
  (ref) => DioAgentLocationsRepository(),
);

/// How often the manager's live layer re-polls. Thirty seconds: well inside the
/// agents' two-minute heartbeat, so a new ping shows within half a minute of
/// reaching the server, without hammering it from every open console. Null
/// turns polling off (tests).
final liveLocationsPollIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 30),
);

/// The live layer's data, re-fetched every [liveLocationsPollIntervalProvider].
///
/// Auto-disposed, so polling stops the moment no screen shows it. Scoped by
/// the dashboard's territory filter so the live layer agrees with the rest of
/// the dashboard. Retries off, like the T0 providers: the poll IS the retry.
final liveAgentLocationsProvider =
    FutureProvider.autoDispose<AgentLocationsPage>((ref) {
      final filter = ref.watch(dashboardFilterProvider);
      final every = ref.watch(liveLocationsPollIntervalProvider);
      if (every != null) {
        final timer = Timer(every, ref.invalidateSelf);
        ref.onDispose(timer.cancel);
      }
      return ref
          .read(agentLocationsRepositoryProvider)
          .listLocations(territoryId: filter.territoryId);
    }, retry: (retryCount, error) => null);

/// "45s", "4 min", "2 h 5 min", "3 d" — the age of a position, from the
/// server's own measurement rather than this device's clock.
String formatAgeSeconds(int? seconds) {
  if (seconds == null) return 'never shared';
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  if (hours < 24) {
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
  return '${hours ~/ 24} d';
}

String liveStateLabel(LiveAgentState state) => switch (state) {
  LiveAgentState.atStore => 'At store',
  LiveAgentState.inTransit => 'In transit',
  LiveAgentState.stale => 'Stale',
  LiveAgentState.offline => 'Offline',
};
