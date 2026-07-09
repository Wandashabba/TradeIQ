import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    required this.code,
    required this.lat,
    required this.lng,
  });
  final String id;
  final String name;
  final String code;
  final double lat;
  final double lng;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

abstract class OutletsRepository {
  Future<List<Outlet>> listOutlets();
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  });
}

class DioOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async {
    final response = await dio.get('/outlets');
    return (response.data as List)
        .map((json) => Outlet.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async {
    final response = await dio.post('/outlets', data: {
      'name': name,
      'code': code,
      'channelType': channelType,
      'lat': lat,
      'lng': lng,
      'territoryId': territoryId,
    });
    return Outlet.fromJson(response.data as Map<String, dynamic>);
  }
}

final outletsRepositoryProvider = Provider<OutletsRepository>((ref) => DioOutletsRepository());

final outletsListProvider = FutureProvider<List<Outlet>>((ref) {
  return ref.read(outletsRepositoryProvider).listOutlets();
});
