import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A field agent's beat plan summary returned by GET /beatplans.
class BeatPlan {
  const BeatPlan({
    required this.id,
    required this.name,
    required this.status,
    required this.scheduledDate,
  });
  final String id;
  final String name;
  final String status;
  final String scheduledDate;

  factory BeatPlan.fromJson(Map<String, dynamic> json) => BeatPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    status: json['status'] as String,
    scheduledDate: json['scheduledDate'] as String,
  );
}

/// One outlet stop on a beat plan.
class BeatPlanStop {
  const BeatPlanStop({
    required this.id,
    required this.outletId,
    required this.sequence,
    required this.visited,
  });
  final String id;
  final String outletId;
  final int sequence;
  final bool visited;

  factory BeatPlanStop.fromJson(Map<String, dynamic> json) => BeatPlanStop(
    id: json['id'] as String,
    outletId: json['outletId'] as String,
    sequence: json['sequence'] as int,
    visited: json['visited'] as bool? ?? false,
  );
}

/// A beat plan with its stops and adherence returned by GET /beatplans/:id.
class BeatPlanDetail {
  const BeatPlanDetail({
    required this.plan,
    required this.stops,
    required this.stopsTotal,
    required this.stopsVisited,
    required this.adherenceRate,
  });
  final BeatPlan plan;
  final List<BeatPlanStop> stops;
  final int stopsTotal;
  final int stopsVisited;
  final double adherenceRate;

  factory BeatPlanDetail.fromJson(Map<String, dynamic> json) {
    final adherence = json['adherence'] as Map<String, dynamic>;
    return BeatPlanDetail(
      plan: BeatPlan.fromJson(json),
      stops: (json['stops'] as List)
          .map((stop) => BeatPlanStop.fromJson(stop as Map<String, dynamic>))
          .toList(),
      stopsTotal: adherence['stopsTotal'] as int,
      stopsVisited: adherence['stopsVisited'] as int,
      adherenceRate: (adherence['adherenceRate'] as num).toDouble(),
    );
  }
}

abstract class BeatPlansRepository {
  /// One page of `GET /beatplans`, newest `scheduledDate` first.
  ///
  /// [cursor] is the previous page's `nextCursor`. It exists because the list
  /// is ordered **descending by scheduled date** and recurrence creates plans
  /// ahead of today: a daily plan set up for a year puts three hundred future
  /// dates above today's, so "today's route" is not reliably on page one.
  Future<PaginatedResponse<BeatPlan>> listBeatPlans({String? cursor});
  Future<BeatPlanDetail> getBeatPlan(String id);
  Future<void> markStopVisited(String planId, String stopId, bool visited);

  /// POST /beatplans (manager/admin). [outletIds] order becomes the stop
  /// sequence. Requires a non-empty [outletIds]; [territoryId] is optional.
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  });
}

class DioBeatPlansRepository implements BeatPlansRepository {
  @override
  Future<PaginatedResponse<BeatPlan>> listBeatPlans({String? cursor}) async {
    final response = await dio.get(
      '/beatplans',
      queryParameters: <String, dynamic>{'cursor': ?cursor},
    );
    return PaginatedResponse<BeatPlan>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => BeatPlan.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<BeatPlanDetail> getBeatPlan(String id) async {
    final response = await dio.get('/beatplans/$id');
    return BeatPlanDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> markStopVisited(
    String planId,
    String stopId,
    bool visited,
  ) async {
    await dio.patch(
      '/beatplans/$planId/stops/$stopId',
      data: {'visited': visited},
    );
  }

  @override
  Future<BeatPlan> createBeatPlan({
    required String agentId,
    required String name,
    required String scheduledDate,
    required List<String> outletIds,
    String? territoryId,
  }) async {
    final response = await dio.post(
      '/beatplans',
      data: {
        'agentId': agentId,
        'name': name,
        'scheduledDate': scheduledDate,
        'outletIds': outletIds,
        'territoryId': ?territoryId,
      },
    );
    return BeatPlan.fromJson(response.data as Map<String, dynamic>);
  }
}

final beatPlansRepositoryProvider = Provider<BeatPlansRepository>(
  (ref) => DioBeatPlansRepository(),
);

/// The FIRST PAGE of GET /beatplans, cursor and all.
///
/// "Load more" is still out of scope, but the *fact that the list was cut* is
/// not: a count under a section rule that is really a count of one page is a
/// number nobody can act on. The page carries `nextCursor`, so the screen can
/// say what it is showing.
final beatPlansPageProvider = FutureProvider<PaginatedResponse<BeatPlan>>((
  ref,
) async {
  return ref.read(beatPlansRepositoryProvider).listBeatPlans();
});

/// The same page as a plain list, for callers that do not care that it is one
/// — today's route, which looks for one date among them.
final beatPlansListProvider = FutureProvider<List<BeatPlan>>(
  (ref) async => (await ref.watch(beatPlansPageProvider.future)).data,
);

final beatPlanDetailProvider = FutureProvider.family<BeatPlanDetail, String>((
  ref,
  id,
) {
  return ref.read(beatPlansRepositoryProvider).getBeatPlan(id);
});
