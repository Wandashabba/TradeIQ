import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

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
  Future<List<Campaign>> listCampaigns();
  Future<CampaignCompliance> getCompliance(String id);
}

class DioCampaignsRepository implements CampaignsRepository {
  @override
  Future<List<Campaign>> listCampaigns() async {
    final response = await dio.get('/campaigns');
    return (response.data as List)
        .map((json) => Campaign.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CampaignCompliance> getCompliance(String id) async {
    final response = await dio.get('/campaigns/$id/compliance');
    return CampaignCompliance.fromJson(response.data as Map<String, dynamic>);
  }
}

final campaignsRepositoryProvider =
    Provider<CampaignsRepository>((ref) => DioCampaignsRepository());

final campaignsListProvider = FutureProvider<List<Campaign>>((ref) {
  return ref.read(campaignsRepositoryProvider).listCampaigns();
});
