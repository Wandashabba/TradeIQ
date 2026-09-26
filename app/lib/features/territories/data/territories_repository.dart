import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../outlets/data/outlets_repository.dart' show Outlet;

/// A sales territory returned by GET /territories.
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.code,
    this.region,
  });
  final String id;
  final String name;
  final String code;
  final String? region;

  factory Territory.fromJson(Map<String, dynamic> json) => Territory(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    region: json['region'] as String?,
  );
}

/// Coverage summary for one territory returned by GET /territories/:id/coverage.
class TerritoryCoverage {
  const TerritoryCoverage({
    required this.outletCount,
    required this.agentCount,
    this.outlets = const [],
    this.outletsVisited,
    this.outletsTotal,
    this.coverageRate,
  });
  final int outletCount;
  final int agentCount;

  /// The outlets themselves, each tagged with whether it was visited — the
  /// data the territory map screen renders as pins.
  final List<Outlet> outlets;

  /// Null when the server sent no coverage block at all. **Never defaulted to
  /// zero**: a territory whose coverage the server did not compute has not
  /// been measured, and "0 of 0 visited" is a verdict nobody reached.
  final int? outletsVisited;
  final int? outletsTotal;

  /// The percentage of this territory's outlets visited in the window, or
  /// null when there is nothing to take a percentage of.
  ///
  /// The wire sends `0` for an empty territory — `outletsTotal > 0 ? … : 0` in
  /// `territories.service.ts` — and a nought there is an invented total, not a
  /// measurement. A territory with no outlets in it is 0% covered in exactly
  /// the sense that an empty shelf is 0% full: the question does not have an
  /// answer yet. [coverageMeasured] is the predicate, so the two callers
  /// cannot disagree about it.
  final double? coverageRate;

  /// Whether [coverageRate] is a figure rather than a placeholder.
  bool get coverageMeasured => coverageRate != null && (outletsTotal ?? 0) > 0;

  /// The rate when it was measured, and null when it was not.
  double? get measuredCoverageRate => coverageMeasured ? coverageRate : null;

  factory TerritoryCoverage.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'] as Map<String, dynamic>?;
    return TerritoryCoverage(
      outletCount: (json['outlets'] as List?)?.length ?? 0,
      agentCount: (json['agents'] as List?)?.length ?? 0,
      outlets:
          (json['outlets'] as List?)
              ?.map((o) => Outlet.fromJson(o as Map<String, dynamic>))
              .toList() ??
          const [],
      outletsVisited: (coverage?['outletsVisited'] as num?)?.toInt(),
      outletsTotal: (coverage?['outletsTotal'] as num?)?.toInt(),
      coverageRate: (coverage?['coverageRate'] as num?)?.toDouble(),
    );
  }
}

abstract class TerritoriesRepository {
  /// One page of `GET /territories`. [cursor] is the previous page's
  /// `nextCursor`; [limit] is a request the backend may cap.
  Future<PaginatedResponse<Territory>> listTerritories({
    int? limit,
    String? cursor,
  });
  Future<TerritoryCoverage> getCoverage(String id);

  /// POST /territories (manager/admin). [code] must be unique per client.
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  });

  /// POST /territories/:id/agents (manager/admin) — assign a field agent.
  Future<void> assignAgent(String territoryId, String userId);
}

class DioTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<PaginatedResponse<Territory>> listTerritories({
    int? limit,
    String? cursor,
  }) async {
    final response = await dio.get(
      '/territories',
      queryParameters: <String, dynamic>{
        'limit': ?limit?.toString(),
        'cursor': ?cursor,
      },
    );
    return PaginatedResponse<Territory>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Territory.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<TerritoryCoverage> getCoverage(String id) async {
    final response = await dio.get('/territories/$id/coverage');
    return TerritoryCoverage.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async {
    final response = await dio.post(
      '/territories',
      data: {'name': name, 'code': code, 'region': ?region},
    );
    return Territory.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> assignAgent(String territoryId, String userId) async {
    await dio.post(
      '/territories/$territoryId/agents',
      data: {'userId': userId},
    );
  }
}

final territoriesRepositoryProvider = Provider<TerritoriesRepository>(
  (ref) => DioTerritoriesRepository(),
);

// THE WHOLE LIST, NOT PAGE ONE OF IT — 26 September 2026.
//
// This read one page and dropped `nextCursor`, on the reading that the "terse
// territory-picker UIs it feeds want the current set". They want the set they
// can assign from: this provider backs the pickers in the beat-plan form, the
// sales-target form, the contest form and The Floor's own scope sheet, so a
// territory on page two was simply unassignable — with nothing anywhere
// saying so. The territories screen had the other half of it, printing the
// length of page one as the count beside its marker.
//
// It walks, like `fetchAllOutlets` does and for the same stated reason:
// territories are **reference data somebody finds by identity**, not an
// activity feed, so a "there are more" footer on the list screen would not
// have helped a picker at all. The loop is bounded three ways — a page cap, a
// null cursor, and a cursor that fails to advance — because an unbounded
// client loop is a bug this codebase has already been bitten by.
//
// Retries are disabled: Riverpod's default policy backs off silently for
// several seconds before surfacing an error, which would leave the list
// showing a skeleton with no explanation. Failing fast and offering the
// error state's one Retry is the better trade for a screen somebody is
// looking at — the same call `territory_map_screen.dart` made first.
const _maxTerritoryPageSize = 200;
const _maxTerritoryPages = 50;

final territoriesListProvider = FutureProvider<List<Territory>>((ref) async {
  final repo = ref.read(territoriesRepositoryProvider);
  final territories = <Territory>[];
  String? cursor;
  for (var page = 0; page < _maxTerritoryPages; page += 1) {
    final result = await repo.listTerritories(
      limit: _maxTerritoryPageSize,
      cursor: cursor,
    );
    territories.addAll(result.data);
    final next = result.nextCursor;
    if (next == null) return territories;
    if (next == cursor) {
      throw StateError(
        'Territory paging stalled: the server repeated "$next".',
      );
    }
    cursor = next;
  }
  throw StateError(
    'Territory paging exceeded $_maxTerritoryPages pages of '
    '$_maxTerritoryPageSize.',
  );
}, retry: (retryCount, error) => null);
