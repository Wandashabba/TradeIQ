import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// The manager dashboard KPI set returned by GET /dashboard.
class DashboardKpis {
  const DashboardKpis({
    required this.numericDistribution,
    required this.weightedDistribution,
    required this.osaPct,
    required this.executionScore,
    required this.priceCompliancePct,
    required this.visibilityCompliancePct,
    required this.shareOfShelf,
    required this.perfectStoreRate,
  });
  final double numericDistribution;
  final double weightedDistribution;
  final double osaPct;
  final double executionScore;
  final double priceCompliancePct;
  final double visibilityCompliancePct;
  final double shareOfShelf;
  final double perfectStoreRate;

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    final kpis = (json['kpis'] as Map<String, dynamic>?) ?? const {};
    double read(String field) => (kpis[field] as num?)?.toDouble() ?? 0;
    return DashboardKpis(
      numericDistribution: read('numericDistribution'),
      weightedDistribution: read('weightedDistribution'),
      osaPct: read('osaPct'),
      executionScore: read('executionScore'),
      priceCompliancePct: read('priceCompliancePct'),
      visibilityCompliancePct: read('visibilityCompliancePct'),
      shareOfShelf: read('shareOfShelf'),
      perfectStoreRate: read('perfectStoreRate'),
    );
  }
}

abstract class DashboardRepository {
  Future<DashboardKpis> fetchKpis();
}

class DioDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis() async {
    final response = await dio.get('/dashboard');
    return DashboardKpis.fromJson(response.data as Map<String, dynamic>);
  }
}

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DioDashboardRepository());

final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) {
  return ref.read(dashboardRepositoryProvider).fetchKpis();
});
