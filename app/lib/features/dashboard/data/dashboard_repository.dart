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
    this.sampleSizes = const DashboardSampleSizes(),
    this.outletsVisited,
    this.outletsTotal,
    this.visits,
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

  /// How many rows each KPI was computed from. **Null is not zero** — it means
  /// "this figure has no denominator", and a figure with no denominator gets
  /// the unknown treatment rather than a thin-sample warning.
  final DashboardSampleSizes sampleSizes;

  /// `totals` — the window's coverage, which is what tells a first-run tenant
  /// apart from a quiet week. Null where the server predates the field.
  final int? outletsVisited;
  final int? outletsTotal;
  final int? visits;

  /// Whether this window measured anything at all.
  ///
  /// The distinction The Floor turns on: a window with no visits is an
  /// ABSENCE and renders em dashes and a sentence; a window with visits and a
  /// KPI of 0 is a FINDING and renders `0`. Deciding that from the figures
  /// themselves is impossible — eight genuine zeros look exactly like eight
  /// missing ones — which is the whole reason `totals` is on the wire.
  bool get measuredSomething => (visits ?? 0) > 0 || (outletsVisited ?? 0) > 0;

  /// True only when the tenant has nothing at all: no outlets on the books.
  /// A tenant with outlets and no visits is not first-run, it is unmeasured,
  /// and those are two different screens.
  bool get hasNoOutlets => outletsTotal != null && outletsTotal == 0;

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    final kpis = (json['kpis'] as Map<String, dynamic>?) ?? const {};
    final totals = (json['totals'] as Map<String, dynamic>?) ?? const {};
    double read(String field) => (kpis[field] as num?)?.toDouble() ?? 0;
    int? count(String field) => (totals[field] as num?)?.toInt();
    return DashboardKpis(
      sampleSizes: DashboardSampleSizes.fromJson(
        json['sampleSizes'] as Map<String, dynamic>?,
      ),
      outletsVisited: count('outletsVisited'),
      outletsTotal: count('outletsTotal'),
      visits: count('visits'),
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

/// The denominator behind each KPI — `sampleSizes` on the wire.
///
/// The server's contract, restated because it is the part that is easy to get
/// wrong: **null means "not a ratio, no denominator", and is never 0 for
/// unknown.** A `0` here is a real, measured emptiness — nothing was counted —
/// and a null is the server declining to claim one.
///
/// `GET /dashboard` deliberately carries no `baselineSampleSizes`: it answers
/// for one window. The baseline denominator on The Floor is the *previous*
/// window's own `sampleSizes`, which the console already fetches as the second
/// half of a [DashboardSnapshot] — so a thin baseline is a fact about a real
/// second request rather than an inference.
class DashboardSampleSizes {
  const DashboardSampleSizes({
    this.numericDistribution,
    this.weightedDistribution,
    this.osaPct,
    this.executionScore,
    this.priceCompliancePct,
    this.visibilityCompliancePct,
    this.shareOfShelf,
    this.perfectStoreRate,
  });

  final int? numericDistribution;
  final int? weightedDistribution;

  /// Counted stock lines only — it matches `osaPct`'s own numerator, so the
  /// two cannot disagree about what was measured.
  final int? osaPct;

  final int? executionScore;
  final int? priceCompliancePct;
  final int? visibilityCompliancePct;
  final int? shareOfShelf;
  final int? perfectStoreRate;

  factory DashboardSampleSizes.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DashboardSampleSizes();
    int? n(String field) => (json[field] as num?)?.toInt();
    return DashboardSampleSizes(
      numericDistribution: n('numericDistribution'),
      weightedDistribution: n('weightedDistribution'),
      osaPct: n('osaPct'),
      executionScore: n('executionScore'),
      priceCompliancePct: n('priceCompliancePct'),
      visibilityCompliancePct: n('visibilityCompliancePct'),
      shareOfShelf: n('shareOfShelf'),
      perfectStoreRate: n('perfectStoreRate'),
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

  /// The window itself, `[from, to)`. Null start = unbounded (all time).
  ///
  /// **Complete days whenever there is a delta (#365).** Today is always
  /// partial while visits are still coming in, so a window ending at "now" set
  /// against one of whole days reads a half-finished morning as a fall. Every
  /// range with a [previousWindow] therefore ends at the start of today, and
  /// both sides are local midnights — the same rule the assistant's
  /// `comparisonRanges` (backend `compare.ts`) applies, so a figure in chat and
  /// the same figure on the console agree:
  ///
  /// - 7d / 30d / 90d: the last N complete days, against the N days before
  ///   them. These are rolling windows, so "the same days of last month" has no
  ///   meaning here; each side is N whole days.
  /// - YTD: 1 January to the start of today, against the same calendar days of
  ///   last year (29 Feb rolls to 1 Mar, as on the server).
  /// - 1 January: YTD has no complete days yet. Rather than an empty window
  ///   and a fake −100%, the tiles show today so far with no arrow at all.
  /// - All: everything up to now, and never an arrow.
  ///
  /// Days are stepped with the `DateTime(y, m, d)` constructor, which lands on
  /// local midnight even across a DST change, never with `Duration(days:)`.
  /// "Local" is the device's zone: the console has no client timezone to hand,
  /// where the assistant counts in the client's.
  (DateTime?, DateTime) window(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DashboardRange.allTime => (null, now),
      DashboardRange.ytd when _isNewYearsDay(now) => (today, now),
      DashboardRange.ytd => (DateTime(now.year), today),
      _ => (DateTime(now.year, now.month, now.day - days!), today),
    };
  }

  /// The like-for-like window "up 0.8" is measured against — see [window].
  /// Null when there is nothing honest to compare to: all-time has no
  /// "before", and on 1 January the year has no complete days yet.
  (DateTime, DateTime)? previousWindow(DateTime now) => switch (this) {
    DashboardRange.allTime => null,
    DashboardRange.ytd when _isNewYearsDay(now) => null,
    DashboardRange.ytd => (
      DateTime(now.year - 1),
      DateTime(now.year - 1, now.month, now.day),
    ),
    _ => (
      DateTime(now.year, now.month, now.day - 2 * days!),
      DateTime(now.year, now.month, now.day - days!),
    ),
  };

  static bool _isNewYearsDay(DateTime now) => now.month == 1 && now.day == 1;
}

/// A window boundary as `GET /dashboard` expects it.
///
/// Sent in UTC with its `Z`, so a local midnight means the same instant on the
/// server. The endpoint's `to` is INCLUSIVE (`lte`), so the exclusive end of a
/// `[from, to)` window goes out a millisecond early — otherwise a visit at
/// exactly midnight would count in both of two adjacent windows.
String dashboardQueryFrom(DateTime from) => from.toUtc().toIso8601String();
String dashboardQueryTo(DateTime to) =>
    to.subtract(const Duration(milliseconds: 1)).toUtc().toIso8601String();

/// Active dashboard filter. Wired to GET /dashboard's territoryId/from/to.
class DashboardFilter {
  const DashboardFilter({this.territoryId, this.range = DashboardRange.last30});

  final String? territoryId;
  final DashboardRange range;

  bool get isActive => territoryId != null || range != DashboardRange.last30;

  DashboardFilter copyWith({
    String? territoryId,
    bool clearTerritory = false,
    DashboardRange? range,
  }) => DashboardFilter(
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

  factory TerritoryDashboardKpis.fromJson(Map<String, dynamic> json) =>
      TerritoryDashboardKpis(
        territoryId: json['territoryId'] as String,
        territoryName: json['territoryName'] as String,
        // DashboardKpis.fromJson reads json['kpis'], so passing the whole
        // per-territory object (not just its kpis sub-map) is correct here.
        kpis: DashboardKpis.fromJson(json),
      );
}

abstract class DashboardRepository {
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  });

  /// Every territory's KPI block in a single request — see
  /// [dashboardByTerritoryProvider] for why this replaced one `fetchKpis`
  /// call per territory (#97).
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  });
}

class DioDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardKpis> fetchKpis({
    String? territoryId,
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{};
    if (territoryId != null) query['territoryId'] = territoryId;
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;
    final response = await dio.get('/dashboard', queryParameters: query);
    return DashboardKpis.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<TerritoryDashboardKpis>> fetchByTerritory({
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{};
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;
    final response = await dio.get(
      '/dashboard/by-territory',
      queryParameters: query,
    );
    return (response.data as List)
        .map(
          (json) =>
              TerritoryDashboardKpis.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DioDashboardRepository(),
);

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

/// One KPI, its value now, and the same KPI over the like-for-like window before.
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

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((
  ref,
) async {
  final filter = ref.watch(dashboardFilterProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  final now = ref.read(nowProvider)();

  final (from, to) = filter.range.window(now);
  final previous = filter.range.previousWindow(now);

  final current = await repo.fetchKpis(
    territoryId: filter.territoryId,
    from: from == null ? null : dashboardQueryFrom(from),
    to: dashboardQueryTo(to),
  );

  if (previous == null) {
    return DashboardSnapshot(current: current);
  }

  // A failed comparison must not take the dashboard down. No previous figure
  // simply means no arrow — which is honest, and better than a wrong one.
  try {
    final prior = await repo.fetchKpis(
      territoryId: filter.territoryId,
      from: dashboardQueryFrom(previous.$1),
      to: dashboardQueryTo(previous.$2),
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
final dashboardByTerritoryProvider =
    FutureProvider<List<TerritoryDashboardKpis>>((ref) {
      final filter = ref.watch(dashboardFilterProvider);
      final now = ref.read(nowProvider)();
      final (from, to) = filter.range.window(now);

      // The same window as the tiles, so a territory's score and the headline
      // figure are measured over the same days.
      return ref
          .read(dashboardRepositoryProvider)
          .fetchByTerritory(
            from: from == null ? null : dashboardQueryFrom(from),
            to: dashboardQueryTo(to),
          );
    });
