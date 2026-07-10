import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// One order returned by GET /orders. A field_agent sees their own orders;
/// a manager sees the client's.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.outletId,
    required this.status,
    required this.total,
    required this.lineCount,
  });
  final String id;
  final String outletId;
  final String status;
  final double total;
  final int lineCount;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        outletId: json['outletId'] as String,
        status: json['status'] as String,
        total: (json['total'] as num).toDouble(),
        lineCount: (json['_count'] as Map<String, dynamic>?)?['lines'] as int? ?? 0,
      );
}

abstract class OrdersRepository {
  Future<List<OrderItem>> listOrders({String? status, String? outletId});
}

class DioOrdersRepository implements OrdersRepository {
  @override
  Future<List<OrderItem>> listOrders({String? status, String? outletId}) async {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (outletId != null) query['outletId'] = outletId;
    final response = await dio.get('/orders', queryParameters: query);
    return (response.data as List)
        .map((json) => OrderItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final ordersRepositoryProvider =
    Provider<OrdersRepository>((ref) => DioOrdersRepository());

final ordersListProvider = FutureProvider<List<OrderItem>>((ref) {
  return ref.read(ordersRepositoryProvider).listOrders();
});
