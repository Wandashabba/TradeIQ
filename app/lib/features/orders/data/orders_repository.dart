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

/// One line on a new order. [quantity] must be a positive integer and
/// [unitPrice] non-negative (enforced by the backend).
class OrderLine {
  const OrderLine({
    required this.skuId,
    required this.quantity,
    required this.unitPrice,
  });
  final String skuId;
  final int quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'skuId': skuId,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

abstract class OrdersRepository {
  Future<List<OrderItem>> listOrders({String? status, String? outletId});

  /// POST /orders (field_agent/manager). [lines] must be non-empty.
  Future<OrderItem> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  });
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

  @override
  Future<OrderItem> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) async {
    final response = await dio.post('/orders', data: {
      'outletId': outletId,
      'lines': lines.map((line) => line.toJson()).toList(),
    });
    return OrderItem.fromJson(response.data as Map<String, dynamic>);
  }
}

final ordersRepositoryProvider =
    Provider<OrdersRepository>((ref) => DioOrdersRepository());

final ordersListProvider = FutureProvider<List<OrderItem>>((ref) {
  return ref.read(ordersRepositoryProvider).listOrders();
});
