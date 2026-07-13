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

/// Active dashboard filter. All fields null = whole-client, all-time (the
/// default). Wired to GET /dashboard's territoryId/from/to query params.
class DashboardFilter {
  const DashboardFilter({this.territoryId, this.from, this.to});
  final String? territoryId;
  final String? from; // ISO date
  final String? to; // ISO date

  bool get isActive => territoryId != null || from != null || to != null;
}

abstract class DashboardRepository {
  Future<DashboardKpis> fetchKpis({String? territoryId, String? from, String? to});
}

class DioDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({String? territoryId, String? from, String? to}) async {
    final query = <String, dynamic>{};
    if (territoryId != null) query['territoryId'] = territoryId;
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;
    final response = await dio.get('/dashboard', queryParameters: query);
    return DashboardKpis.fromJson(response.data as Map<String, dynamic>);
  }
}

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DioDashboardRepository());

class DashboardFilterNotifier extends Notifier<DashboardFilter> {
  @override
  DashboardFilter build() => const DashboardFilter();

  void set(DashboardFilter filter) => state = filter;
}

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterNotifier, DashboardFilter>(DashboardFilterNotifier.new);

final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.read(dashboardRepositoryProvider).fetchKpis(
        territoryId: filter.territoryId,
        from: filter.from,
        to: filter.to,
      );
});

/// KPIs scoped to a single territory.
///
/// `GET /territories/:id/coverage` returns outlet and agent *lists*, not a
/// score, so the only honest way to rank territories by execution score is to
/// re-query `GET /dashboard` per territory. That is one request per territory —
/// acceptable at the current scale (a client has a handful), but the right fix
/// is a server-side `GET /dashboard/by-territory` rollup if the list grows.
final territoryKpisProvider =
    FutureProvider.family<DashboardKpis, String>((ref, territoryId) {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.read(dashboardRepositoryProvider).fetchKpis(
        territoryId: territoryId,
        from: filter.from,
        to: filter.to,
      );
});
