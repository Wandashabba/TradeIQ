import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

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
  Future<PaginatedResponse<OrderItem>> listOrders({String? status, String? outletId});

  /// Queues an order for POST /orders (field_agent/manager) and tries to send
  /// it now. [lines] must be non-empty.
  ///
  /// Returns once the order is safely on the phone — not once the server has
  /// it. An order taken in a shop with no signal is still an order, and the
  /// agent should not have to stand at the counter waiting for a bar of
  /// reception to find out whether their capture survived.
  Future<void> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  });
}

/// Reads orders over HTTP; writes them through the offline outbox.
///
/// The split is the point. A list is only worth showing when it is current, so
/// it is fetched live. A capture must never depend on connectivity, so it is
/// queued locally and flushed by [SyncService] — the same path every visit
/// capture takes.
class DioOrdersRepository implements OrdersRepository {
  DioOrdersRepository({
    required this.db,
    required this.syncService,
    this.flushTimeout = _defaultFlushTimeout,
  });

  final LocalDb db;
  final SyncService syncService;

  /// How long a create will wait for the outbox to drain before carrying on
  /// without it. Same reasoning as `DriftVisitsRepository.flushTimeout`: the
  /// order is already queued before the flush starts, so this bounds only the
  /// waiting, not the safety.
  final Duration flushTimeout;

  static const _defaultFlushTimeout = Duration(seconds: 10);

  static const _uuid = Uuid();

  @override
  Future<PaginatedResponse<OrderItem>> listOrders({
    String? status,
    String? outletId,
  }) async {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (outletId != null) query['outletId'] = outletId;
    final response = await dio.get('/orders', queryParameters: query);
    return PaginatedResponse<OrderItem>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => OrderItem.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<void> createOrder({
    required String outletId,
    required List<OrderLine> lines,
  }) async {
    await db.enqueue(
      entityType: orderEntity,
      entityId: _uuid.v4(),
      payloadJson: jsonEncode({
        'outletId': outletId,
        'lines': [for (final line in lines) line.toJson()],
        // Stamped NOW, on the device — the moment the agent took the order,
        // not whenever the outbox happens to reach a tower (#338). Without it
        // an order taken offline on the 30th is dated the 1st by the server
        // and counts toward the wrong month's sell-in target.
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    // Best-effort: the order is already on disk and queued, so a failed or
    // slow flush just leaves it for the next attempt.
    try {
      await syncService.flushPending().timeout(flushTimeout);
    } catch (_) {
      // Deliberately swallowed — see above.
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => DioOrdersRepository(
    db: ref.read(localDbProvider),
    syncService: ref.read(syncServiceProvider),
  ),
);

// The provider exposes the FIRST PAGE as a plain list: the orders screen
// wants the most recent orders, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final ordersListProvider = FutureProvider<List<OrderItem>>((ref) async {
  final page = await ref.read(ordersRepositoryProvider).listOrders();
  return page.data;
});
