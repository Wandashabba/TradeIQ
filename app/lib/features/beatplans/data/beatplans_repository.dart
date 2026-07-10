import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

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
  Future<List<BeatPlan>> listBeatPlans();
  Future<BeatPlanDetail> getBeatPlan(String id);
  Future<void> markStopVisited(String planId, String stopId, bool visited);
}

class DioBeatPlansRepository implements BeatPlansRepository {
  @override
  Future<List<BeatPlan>> listBeatPlans() async {
    final response = await dio.get('/beatplans');
    return (response.data as List)
        .map((json) => BeatPlan.fromJson(json as Map<String, dynamic>))
        .toList();
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
}

final beatPlansRepositoryProvider =
    Provider<BeatPlansRepository>((ref) => DioBeatPlansRepository());

final beatPlansListProvider = FutureProvider<List<BeatPlan>>((ref) {
  return ref.read(beatPlansRepositoryProvider).listBeatPlans();
});

final beatPlanDetailProvider =
    FutureProvider.family<BeatPlanDetail, String>((ref, id) {
  return ref.read(beatPlansRepositoryProvider).getBeatPlan(id);
});
