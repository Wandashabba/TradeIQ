import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

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
  });
  final int outletCount;
  final int agentCount;

  factory TerritoryCoverage.fromJson(Map<String, dynamic> json) =>
      TerritoryCoverage(
        outletCount: (json['outlets'] as List?)?.length ?? 0,
        agentCount: (json['agents'] as List?)?.length ?? 0,
      );
}

abstract class TerritoriesRepository {
  Future<List<Territory>> listTerritories();
  Future<TerritoryCoverage> getCoverage(String id);
}

class DioTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<List<Territory>> listTerritories() async {
    final response = await dio.get('/territories');
    return (response.data as List)
        .map((json) => Territory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TerritoryCoverage> getCoverage(String id) async {
    final response = await dio.get('/territories/$id/coverage');
    return TerritoryCoverage.fromJson(response.data as Map<String, dynamic>);
  }
}

final territoriesRepositoryProvider =
    Provider<TerritoriesRepository>((ref) => DioTerritoriesRepository());

final territoriesListProvider = FutureProvider<List<Territory>>((ref) {
  return ref.read(territoriesRepositoryProvider).listTerritories();
});
