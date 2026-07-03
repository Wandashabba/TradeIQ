import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Outlet {
  const Outlet({required this.id, required this.name, required this.code});
  final String id;
  final String name;
  final String code;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
      );
}

abstract class OutletsRepository {
  Future<List<Outlet>> listOutlets();
}

class DioOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async {
    final response = await dio.get('/outlets');
    return (response.data as List)
        .map((json) => Outlet.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final outletsRepositoryProvider = Provider<OutletsRepository>((ref) => DioOutletsRepository());

final outletsListProvider = FutureProvider<List<Outlet>>((ref) {
  return ref.read(outletsRepositoryProvider).listOutlets();
});
