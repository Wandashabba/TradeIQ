import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Sku {
  const Sku({required this.id, required this.name, required this.category});
  final String id;
  final String name;
  final String category;

  factory Sku.fromJson(Map<String, dynamic> json) => Sku(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
      );
}

abstract class SkusRepository {
  Future<List<Sku>> listSkus();
}

class DioSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus() async {
    final response = await dio.get('/skus');
    return (response.data as List)
        .map((json) => Sku.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final skusRepositoryProvider = Provider<SkusRepository>((ref) => DioSkusRepository());

final skusListProvider = FutureProvider<List<Sku>>((ref) {
  return ref.read(skusRepositoryProvider).listSkus();
});
