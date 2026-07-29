import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    required this.code,
    required this.lat,
    required this.lng,
    this.visited = false,
  });
  final String id;
  final String name;
  final String code;
  final double lat;
  final double lng;

  /// Whether this outlet had at least one submitted visit within the
  /// coverage query's date window. Only meaningful on an `Outlet` that came
  /// from `GET /territories/:id/coverage` — plain `/outlets` responses leave
  /// this at its default of `false`.
  final bool visited;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        visited: json['visited'] as bool? ?? false,
      );
}

abstract class OutletsRepository {
  /// When [mine] is true the backend narrows the list to the caller's assigned
  /// territories. It is a filter, not a permission: the same call without it
  /// still returns every outlet in the tenant.
  ///
  /// One page of GET /outlets. [limit]/[cursor] mirror the backend's
  /// `?limit=&cursor=` — see `PaginatedResponse`.
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  });
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  });
}

/// The highest `?limit=` the backend's `parsePagination` accepts (see
/// `backend/src/lib/pagination.ts`'s `MAX_LIMIT`). `_fetchAllOutlets` below
/// requests pages at this size purely to minimise round trips over a field
/// agent's connection — the backend still enforces its own cap regardless of
/// what is asked for.
const _maxPageSize = 200;

/// A hard page cap on the fetch-all loops below.
///
/// Not paranoia: those loops trust the server's cursor to terminate, and this
/// whole sweep exists because unbounded reads kill processes. An unbounded
/// client loop is the same bug wearing different clothes. 50 pages × 200 is
/// 10,000 outlets — far beyond any real tenant — so reaching it means the
/// server is misbehaving, and failing loudly beats hanging silently.
const _maxFetchAllPages = 50;

class DioOutletsRepository implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async {
    final response = await dio.get(
      '/outlets',
      queryParameters: {
        if (mine) 'mine': 'true',
        'limit': ?limit?.toString(),
        'cursor': ?cursor,
      },
    );
    return PaginatedResponse<Outlet>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Outlet.fromJson(e as Map<String, dynamic>),
    );
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

/// Walks every page of GET /outlets and concatenates them.
///
/// Outlets are reference data an agent finds by identity, not an activity
/// feed a "most recent 50" view suits: the check-in screen looks an outlet up
/// by id (`audit_shell_screen.dart`), `today_route.dart` resolves a beat
/// plan's stops the same way, every outlet-picking form (campaigns, orders,
/// reports, beat plans, dispatch) renders the set as a dropdown/checklist a
/// user must find a specific store in, and the dashboard map plots the whole
/// tenant as a base layer under the agent pins. Capping any of those at the
/// first page is not the "screen shows the most recent N" tradeoff the rest
/// of the pagination sweep makes deliberately — it is silent data loss: an
/// outlet past page 1 becomes impossible to check into, route to, pick, or
/// plot. So — unlike the sweep's other list providers, which expose the
/// repository's first page as-is — this one pages through the whole set
/// itself. The backend request is still bounded per call (the OOM concern
/// pagination#141 exists to fix); only the app-side reassembly is unbounded,
/// and only where completeness is a correctness requirement, not a UX nicety.
Future<List<Outlet>> _fetchAllOutlets(
  OutletsRepository repo, {
  required bool mine,
}) async {
  final outlets = <Outlet>[];
  String? cursor;

  for (var page = 0; page < _maxFetchAllPages; page += 1) {
    final result = await repo.listOutlets(
      mine: mine,
      limit: _maxPageSize,
      cursor: cursor,
    );
    outlets.addAll(result.data);

    final next = result.nextCursor;
    if (next == null) return outlets;
    // A cursor that does not advance means the server is wrong — a stale id
    // whose `skip: 1` re-yields the same page would otherwise spin here
    // forever, accumulating rows until the app dies.
    if (next == cursor) {
      throw StateError('Outlet paging stalled: the server repeated cursor "$next".');
    }
    cursor = next;
  }

  throw StateError(
    'Outlet paging exceeded $_maxFetchAllPages pages of $_maxPageSize. '
    'Either this tenant is far larger than the design anticipated, or the '
    'server is returning an endless cursor.',
  );
}

final outletsListProvider = FutureProvider<List<Outlet>>((ref) {
  return _fetchAllOutlets(ref.read(outletsRepositoryProvider), mine: false);
});

/// Whether the agent's picker is currently narrowed to their own territories.
///
/// Starts narrowed, because a shorter list of the right shops is the point of
/// having territories at all. It is a view preference, not a permission — see
/// [assignedOutletsProvider].
class OnlyMyTerritoriesNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final onlyMyTerritoriesProvider =
    NotifierProvider<OnlyMyTerritoriesNotifier, bool>(
      OnlyMyTerritoriesNotifier.new,
    );

/// The agent's outlet list, narrowed or not.
///
/// The narrowing lives here rather than in the backend's authorisation layer
/// on purpose. Territory data is imperfect and field work is not: an agent
/// covering a colleague's patch, or standing in a shop filed under the wrong
/// territory, must still be able to check in. Hiding those outlets by policy
/// would strand them somewhere they cannot fix it from.
final assignedOutletsProvider = FutureProvider<List<Outlet>>((ref) {
  final mine = ref.watch(onlyMyTerritoriesProvider);
  return _fetchAllOutlets(ref.read(outletsRepositoryProvider), mine: mine);
});
