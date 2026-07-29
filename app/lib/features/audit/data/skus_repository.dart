import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

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
  /// One page of GET /skus. [limit]/[cursor] mirror the backend's
  /// `?limit=&cursor=` — see `PaginatedResponse`.
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  });
}

/// The highest `?limit=` the backend's `parsePagination` accepts (see
/// `backend/src/lib/pagination.ts`'s `MAX_LIMIT`). `_fetchAllSkus` below
/// requests pages at this size purely to minimise round trips over a field
/// agent's connection — the backend still enforces its own cap regardless of
/// what is asked for.
const _maxPageSize = 200;

class DioSkusRepository implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async {
    final response = await dio.get(
      '/skus',
      queryParameters: {
        'outletId': outletId,
        'limit': ?limit?.toString(),
        'cursor': ?cursor,
      },
    );
    return PaginatedResponse<Sku>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Sku.fromJson(e as Map<String, dynamic>),
    );
  }
}

final skusRepositoryProvider = Provider<SkusRepository>(
  (ref) => DioSkusRepository(),
);

/// Walks every page of GET /skus for [outletId] and concatenates them.
///
/// SKUs are the check-in catalog an agent records facings/stock against, not
/// an activity feed: `visit_progress.dart`'s "N of M done" count is `.length`
/// against this exact list, and `s2_stock_screen.dart` /
/// `s5_pricing_promotions_screen.dart` render it as the literal set of rows a
/// visit must cover. Capping at the first page would both under-report
/// progress and make SKUs past page 1 impossible to record data for — the
/// same silent-truncation failure `outlets_repository.dart`'s
/// `_fetchAllOutlets` documents, not the deliberate "screen shows the most
/// recent 50" tradeoff the rest of the pagination sweep makes. So this
/// provider pages through the whole catalog itself; the backend request per
/// call is still bounded.
Future<List<Sku>> _fetchAllSkus(SkusRepository repo, String outletId) async {
  final skus = <Sku>[];
  String? cursor;
  do {
    final page = await repo.listSkus(
      outletId: outletId,
      limit: _maxPageSize,
      cursor: cursor,
    );
    skus.addAll(page.data);
    cursor = page.nextCursor;
  } while (cursor != null);
  return skus;
}

final skusListProvider = FutureProvider.family<List<Sku>, String>(
  (ref, outletId) =>
      _fetchAllSkus(ref.read(skusRepositoryProvider), outletId),
);
