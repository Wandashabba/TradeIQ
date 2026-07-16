import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Sku {
  const Sku({
    required this.id,
    required this.name,
    required this.category,
    required this.minFacingsStandard,
    required this.rrp,
    required this.daysOutOfStock,
    required this.velocityAvg,
    required this.effectivePrice,
  });
  final String id;
  final String name;
  final String category;
  final int minFacingsStandard;
  final double rrp;
  final int daysOutOfStock;
  final double velocityAvg;
  final double effectivePrice;

  factory Sku.fromJson(Map<String, dynamic> json) => Sku(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        minFacingsStandard: (json['minFacingsStandard'] as num).toInt(),
        rrp: (json['rrp'] as num).toDouble(),
        daysOutOfStock: (json['daysOutOfStock'] as num).toInt(),
        velocityAvg: (json['velocityAvg'] as num).toDouble(),
        effectivePrice: (json['effectivePrice'] as num).toDouble(),
      );
}

abstract class SkusRepository {
  Future<List<Sku>> listSkus({required String outletId});
}

class DioSkusRepository implements SkusRepository {
  @override
  Future<List<Sku>> listSkus({required String outletId}) async {
    final response = await dio.get('/skus', queryParameters: {'outletId': outletId});
    return (response.data as List)
        .map((json) => Sku.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final skusRepositoryProvider = Provider<SkusRepository>((ref) => DioSkusRepository());

final skusListProvider = FutureProvider.family<List<Sku>, String>(
  (ref, outletId) => ref.read(skusRepositoryProvider).listSkus(outletId: outletId),
);
