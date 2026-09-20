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
    this.outletsVisited = 0,
    this.outletsTotal = 0,
    this.coverageRate = 0,
  });
  final int outletCount;
  final int agentCount;

  /// The outlets themselves, each tagged with whether it was visited — the
  /// data the territory map screen renders as pins.
  final List<Outlet> outlets;
  final int outletsVisited;
  final int outletsTotal;
  final double coverageRate;

  factory TerritoryCoverage.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'] as Map<String, dynamic>?;
    return TerritoryCoverage(
      outletCount: (json['outlets'] as List?)?.length ?? 0,
      agentCount: (json['agents'] as List?)?.length ?? 0,
      outlets: (json['outlets'] as List?)
              ?.map((o) => Outlet.fromJson(o as Map<String, dynamic>))
              .toList() ??
          const [],
      outletsVisited: coverage?['outletsVisited'] as int? ?? 0,
      outletsTotal: coverage?['outletsTotal'] as int? ?? 0,
      coverageRate: (coverage?['coverageRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

abstract class TerritoriesRepository {
  Future<PaginatedResponse<Territory>> listTerritories();
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
  Future<PaginatedResponse<Territory>> listTerritories() async {
    final response = await dio.get('/territories');
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
    final response = await dio.post('/territories', data: {
      'name': name,
      'code': code,
      'region': ?region,
    });
    return Territory.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> assignAgent(String territoryId, String userId) async {
    await dio.post('/territories/$territoryId/agents', data: {'userId': userId});
  }
}

final territoriesRepositoryProvider =
    Provider<TerritoriesRepository>((ref) => DioTerritoriesRepository());

// The provider exposes the FIRST PAGE as a plain list: the terse
// territory-picker UIs it feeds want the current set, not the whole history,
// and "load more" UI is deliberately out of scope for the pagination sweep
// (see the spec). `nextCursor` is available on the repository for any screen
// that later needs to page; this provider intentionally drops it.
final territoriesListProvider = FutureProvider<List<Territory>>((ref) async {
  final page = await ref.read(territoriesRepositoryProvider).listTerritories();
  return page.data;
});
