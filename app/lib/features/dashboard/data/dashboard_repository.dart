import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// One perfect-store score band and how many outlets sit in it. The server
/// counts each outlet once, at its most recent scored visit in the window —
/// doors, not visits.
class ScoreBand {
  const ScoreBand({
    required this.label,
    required this.minScore,
    required this.outlets,
  });

  final String label;
  final double minScore;
  final int outlets;

  factory ScoreBand.fromJson(Map<String, dynamic> json) => ScoreBand(
        label: json['label'] as String? ?? '',
        minScore: (json['minScore'] as num?)?.toDouble() ?? 0,
        outlets: (json['outlets'] as num?)?.toInt() ?? 0,
      );
}

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
    this.scoreBands = const [],
  });
  final double numericDistribution;
  final double weightedDistribution;
  final double osaPct;
  final double executionScore;
  final double priceCompliancePct;
  final double visibilityCompliancePct;
  final double shareOfShelf;
  final double perfectStoreRate;

  /// The perfect-store distribution, highest band first. Empty when the
  /// server predates the field — the console then hides the panel rather
  /// than drawing five zero-height bars as if they were data.
  final List<ScoreBand> scoreBands;

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
      scoreBands: [
        for (final band in (json['scoreBands'] as List?) ?? const [])
          if (band is Map<String, dynamic>) ScoreBand.fromJson(band),
      ],
    );
  }
}

/// The window the console is looking at.
///
/// A window is what makes a *delta* possible: "92.1% on-shelf availability" is a
/// fact, but "92.1%, up 0.8 on the previous 30 days" is a decision. Without a
/// bounded window there is no previous period to compare against, and every
/// arrow on the screen would be invented.
enum DashboardRange {
  last7(label: '7d', days: 7),
  last30(label: '30d', days: 30),
  last90(label: '90d', days: 90),
  ytd(label: 'YTD', days: null),
  allTime(label: 'All', days: null);

  const DashboardRange({required this.label, required this.days});

  final String label;
  final int? days;

  /// The window itself. Null start = unbounded (all time).
  (DateTime?, DateTime) window(DateTime now) => switch (this) {
        DashboardRange.ytd => (DateTime(now.year), now),
        DashboardRange.allTime => (null, now),
        _ => (now.subtract(Duration(days: days!)), now),
      };

  /// The equally-long window immediately before this one — the thing we measure
  /// "up 0.8" against. Null when there is nothing to compare to: all-time has no
  /// "before", and we will not fabricate one.
  (DateTime, DateTime)? previousWindow(DateTime now) {
    final (start, end) = window(now);
    if (start == null) return null;
    final span = end.difference(start);
    return (start.subtract(span), start);
  }
}

/// Active dashboard filter. Wired to GET /dashboard's territoryId/from/to.
class DashboardFilter {
  const DashboardFilter({
    this.territoryId,
    this.range = DashboardRange.last30,
  });

  final String? territoryId;
  final DashboardRange range;

  bool get isActive =>
      territoryId != null || range != DashboardRange.last30;

  DashboardFilter copyWith({
    String? territoryId,
    bool clearTerritory = false,
    DashboardRange? range,
  }) =>
      DashboardFilter(
        territoryId: clearTerritory ? null : (territoryId ?? this.territoryId),
        range: range ?? this.range,
      );
}

/// One territory's KPI block, as returned by GET /dashboard/by-territory.
class TerritoryDashboardKpis {
  const TerritoryDashboardKpis({
    required this.territoryId,
    required this.territoryName,
    required this.kpis,
  });
  final String territoryId;
  final String territoryName;
  final DashboardKpis kpis;

  factory TerritoryDashboardKpis.fromJson(Map<String, dynamic> json) => TerritoryDashboardKpis(
        territoryId: json['territoryId'] as String,
        territoryName: json['territoryName'] as String,
        // DashboardKpis.fromJson reads json['kpis'], so passing the whole
        // per-territory object (not just its kpis sub-map) is correct here.
        kpis: DashboardKpis.fromJson(json),
      );
}

abstract class DashboardRepository {
  Future<DashboardKpis> fetchKpis({String? territoryId, String? from, String? to});

  /// Every territory's KPI block in a single request — see
  /// [dashboardByTerritoryProvider] for why this replaced one `fetchKpis`
  /// call per territory (#97).
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({String? from, String? to});
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

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({String? from, String? to}) async {
    final query = <String, dynamic>{};
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;
    final response = await dio.get('/dashboard/by-territory', queryParameters: query);
    return (response.data as List)
        .map((json) => TerritoryDashboardKpis.fromJson(json as Map<String, dynamic>))
        .toList();
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
    NotifierProvider<DashboardFilterNotifier, DashboardFilter>(
  DashboardFilterNotifier.new,
);

/// The clock, injected so a test can pin "now" instead of racing it.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// One KPI, its value now, and the same KPI over the window immediately before.
class KpiDelta {
  const KpiDelta({required this.current, this.previous});

  final double current;

  /// Null when there is nothing honest to compare against — an all-time view has
  /// no "before", and a delta would be a fabrication.
  final double? previous;

  /// The change in percentage POINTS, not a percentage change of a percentage.
  /// These KPIs are already rates: "up 0.8" means 91.3% became 92.1%, and saying
  /// "up 0.9%" of a percentage is a different — and wrong — number.
  double? get change => previous == null ? null : current - previous!;

  bool get hasDelta => change != null && change!.abs() >= 0.05;
}

/// The dashboard, with the previous window fetched alongside it.
///
/// Two requests, not one: `GET /dashboard` has no comparison built in, and the
/// alternative — inventing a baseline — is exactly the kind of plausible-looking
/// number this codebase has been busy removing.
class DashboardSnapshot {
  const DashboardSnapshot({required this.current, this.previous});

  final DashboardKpis current;
  final DashboardKpis? previous;

  KpiDelta of(double Function(DashboardKpis) read) => KpiDelta(
        current: read(current),
        previous: previous == null ? null : read(previous!),
      );
}

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((ref) async {
  final filter = ref.watch(dashboardFilterProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  final now = ref.read(nowProvider)();

  final (from, to) = filter.range.window(now);
  final previous = filter.range.previousWindow(now);

  final current = await repo.fetchKpis(
    territoryId: filter.territoryId,
    from: from?.toIso8601String(),
    to: to.toIso8601String(),
  );

  if (previous == null) {
    return DashboardSnapshot(current: current);
  }

  // A failed comparison must not take the dashboard down. No previous figure
  // simply means no arrow — which is honest, and better than a wrong one.
  try {
    final prior = await repo.fetchKpis(
      territoryId: filter.territoryId,
      from: previous.$1.toIso8601String(),
      to: previous.$2.toIso8601String(),
    );
    return DashboardSnapshot(current: current, previous: prior);
  } catch (_) {
    return DashboardSnapshot(current: current);
  }
});

/// Back-compat for callers that only need the current figures.
final dashboardKpisProvider = FutureProvider<DashboardKpis>(
  (ref) async => (await ref.watch(dashboardSnapshotProvider.future)).current,
);

/// Every territory's KPIs in a single `GET /dashboard/by-territory` call —
/// see #97. This replaced one `GET /dashboard?territoryId=…` request per
/// territory, which was both an N+1 query pattern and, more seriously,
/// silently broken: it filtered outlets by `Territory.id`, a UUID that never
/// matches the free-text `Outlet.territoryId` column (which stores
/// `Territory.code`), so every per-territory figure was a quiet zero.
final dashboardByTerritoryProvider = FutureProvider<List<TerritoryDashboardKpis>>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  final now = ref.read(nowProvider)();
  final (from, to) = filter.range.window(now);

  return ref.read(dashboardRepositoryProvider).fetchByTerritory(
        from: from?.toIso8601String(),
        to: to.toIso8601String(),
      );
});
