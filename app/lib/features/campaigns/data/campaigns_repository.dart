import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A campaign returned by GET /campaigns.
class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.outletCount,
    this.objective,
    this.budget,
  });
  final String id;
  final String name;
  final String status;
  final String startDate;
  final String endDate;
  final int outletCount;
  final String? objective;
  final double? budget;

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        outletCount:
            (json['_count'] as Map<String, dynamic>?)?['outlets'] as int? ?? 0,
        objective: json['objective'] as String?,
        budget: (json['budget'] as num?)?.toDouble(),
      );
}

/// The compliance rollup returned by GET /campaigns/:id/compliance.
class CampaignCompliance {
  const CampaignCompliance({
    required this.outletsTotal,
    required this.outletsVisited,
    required this.visitCoverageRate,
    required this.avgPlanogramCompliancePct,
    required this.avgAbsPriceDeviationPct,
    required this.promoComplianceRate,
  });
  final double outletsTotal;
  final double outletsVisited;
  final double visitCoverageRate;
  final double avgPlanogramCompliancePct;
  final double avgAbsPriceDeviationPct;
  final double promoComplianceRate;

  factory CampaignCompliance.fromJson(Map<String, dynamic> json) =>
      CampaignCompliance(
        outletsTotal: (json['outletsTotal'] as num?)?.toDouble() ?? 0,
        outletsVisited: (json['outletsVisited'] as num?)?.toDouble() ?? 0,
        visitCoverageRate: (json['visitCoverageRate'] as num?)?.toDouble() ?? 0,
        avgPlanogramCompliancePct:
            (json['avgPlanogramCompliancePct'] as num?)?.toDouble() ?? 0,
        avgAbsPriceDeviationPct:
            (json['avgAbsPriceDeviationPct'] as num?)?.toDouble() ?? 0,
        promoComplianceRate:
            (json['promoComplianceRate'] as num?)?.toDouble() ?? 0,
      );
}

abstract class CampaignsRepository {
  Future<PaginatedResponse<Campaign>> listCampaigns();
  Future<CampaignCompliance> getCompliance(String id);

  /// POST /campaigns. Dates are ISO strings; [outletIds] seeds the initial
  /// outlet assignment. Requires a manager/admin session.
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  });

  /// PATCH /campaigns/:id. Only name/objective/budget/status are editable —
  /// the backend does not accept date or outlet changes on update.
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  });
}

class DioCampaignsRepository implements CampaignsRepository {
  @override
  Future<PaginatedResponse<Campaign>> listCampaigns() async {
    final response = await dio.get('/campaigns');
    return PaginatedResponse<Campaign>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Campaign.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<CampaignCompliance> getCompliance(String id) async {
    final response = await dio.get('/campaigns/$id/compliance');
    return CampaignCompliance.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async {
    final response = await dio.post('/campaigns', data: {
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      'objective': ?objective,
      'budget': ?budget,
      if (outletIds != null && outletIds.isNotEmpty) 'outletIds': outletIds,
    });
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async {
    final response = await dio.patch('/campaigns/$id', data: {
      'name': ?name,
      'objective': ?objective,
      'budget': ?budget,
      'status': ?status,
    });
    return Campaign.fromJson(response.data as Map<String, dynamic>);
  }
}

final campaignsRepositoryProvider =
    Provider<CampaignsRepository>((ref) => DioCampaignsRepository());

// The provider exposes the FIRST PAGE as a plain list: the campaigns screen
// wants the current campaigns, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final campaignsListProvider = FutureProvider<List<Campaign>>((ref) async {
  final page = await ref.read(campaignsRepositoryProvider).listCampaigns();
  return page.data;
});
