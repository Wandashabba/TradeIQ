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
    this.channelType = '',
    this.status = 'active',
    this.visited = false,
  });
  final String id;
  final String name;
  final String code;
  final double lat;
  final double lng;

  /// Empty when the response that built this outlet did not carry it — the
  /// coverage endpoint returns a narrower shape than `/outlets` does.
  final String channelType;

  /// `active` or `closed` (#386). Defaults to active rather than being
  /// nullable: a backend that predates the field is not telling us the outlet
  /// is in some unknown state, it is telling us every outlet is as it was.
  final String status;

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
    channelType: json['channelType'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    visited: json['visited'] as bool? ?? false,
  );
}

/// A rejected check-in — an agent who stood somewhere and was told they were
/// not at the shop, with where they actually were (#386).
///
/// This is the evidence a manager judges a pin by. Several of these clustered
/// on one spot hundreds of metres from the pin is what a wrong pin looks like.
class CheckInAttemptEvidence {
  const CheckInAttemptEvidence({
    required this.id,
    required this.agentLabel,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.createdAt,
    this.accuracyM,
    this.isMocked,
  });

  final String id;
  final String agentLabel;
  final double lat;
  final double lng;
  final double distanceM;

  /// What the device said about this fix: its reported horizontal accuracy in
  /// metres, and whether the platform called it a mock location. Null means
  /// the device did not say — not that it was fine, and the card says so.
  ///
  /// They matter because "use their position" adopts this coordinate as the
  /// outlet's pin: from then on, check-ins from this spot pass cleanly.
  final double? accuracyM;
  final bool? isMocked;
  final DateTime createdAt;

  factory CheckInAttemptEvidence.fromJson(Map<String, dynamic> json) =>
      CheckInAttemptEvidence(
        id: json['id'] as String,
        agentLabel: json['agentLabel'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        distanceM: (json['distanceM'] as num).toDouble(),
        accuracyM: (json['accuracyM'] as num?)?.toDouble(),
        isMocked: json['isMocked'] as bool?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Whether this fix may become an outlet's pin. A mocked position never can;
  /// an unknown one still can, because an older handset that reports nothing
  /// must not lock a manager out of fixing a pin. Mirrors the server's rule
  /// (outlets.service), which is the one that actually decides.
  bool get isAdoptable =>
      isMocked != true && (accuracyM == null || accuracyM! <= 100);
}

/// An agent's explicit "the pin is wrong" claim (#386).
class PinDispute {
  const PinDispute({
    required this.id,
    required this.outletId,
    required this.outletName,
    required this.outletCode,
    required this.visitId,
    required this.agentLabel,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.outletLat,
    required this.outletLng,
    required this.note,
    required this.status,
    required this.resolvedByLabel,
    required this.resolvedAt,
    required this.createdAt,
    required this.photos,
    this.accuracyM,
    this.isMocked,
    this.agentIsOnlyVisitor = false,
  });

  final String id;
  final String outletId;
  final String outletName;
  final String outletCode;
  final String visitId;
  final String agentLabel;
  final double lat;
  final double lng;
  final double distanceM;

  /// The pin AS IT READ when the claim was made, not as it reads now. A claim
  /// reviewed after someone corrected the pin must still show what the agent
  /// was arguing with, or it reads as a complaint about coordinates nobody
  /// ever had.
  final double outletLat;
  final double outletLng;

  final String? note;

  /// `open`, `applied` or `rejected`.
  final String status;
  final String? resolvedByLabel;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  /// What the device said about the fix behind this claim. See
  /// [CheckInAttemptEvidence.accuracyM].
  final double? accuracyM;
  final bool? isMocked;

  /// True when the agent who filed this is the only person who has ever
  /// visited the outlet — so no other agent's visits can contradict a pin
  /// moved onto their position. A warning, not a verdict: a genuinely new
  /// store has exactly one visitor too.
  final bool agentIsOnlyVisitor;

  /// Storefront evidence the agent attached — the bytes are fetched separately
  /// through `GET /photos/:id/thumbnail`.
  final List<PinDisputePhoto> photos;

  /// The photo ids alone, for callers that only need to count or fetch them.
  List<String> get photoIds => [for (final p in photos) p.id];

  bool get isOpen => status == 'open';

  factory PinDispute.fromJson(Map<String, dynamic> json) => PinDispute(
    id: json['id'] as String,
    outletId: json['outletId'] as String,
    outletName: json['outletName'] as String? ?? '',
    outletCode: json['outletCode'] as String? ?? '',
    visitId: json['visitId'] as String,
    agentLabel: json['agentLabel'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    distanceM: (json['distanceM'] as num).toDouble(),
    outletLat: (json['outletLat'] as num).toDouble(),
    outletLng: (json['outletLng'] as num).toDouble(),
    note: json['note'] as String?,
    status: json['status'] as String? ?? 'open',
    resolvedByLabel: json['resolvedByLabel'] as String?,
    resolvedAt: json['resolvedAt'] == null
        ? null
        : DateTime.parse(json['resolvedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    isMocked: json['isMocked'] as bool?,
    agentIsOnlyVisitor: json['agentIsOnlyVisitor'] as bool? ?? false,
    photos: [
      for (final p in (json['photos'] as List<dynamic>? ?? const []))
        PinDisputePhoto.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// One storefront photo offered as evidence for a wrong-pin claim (#386).
///
/// [timestamp] is the DEVICE clock and the agent's own account of the photo.
/// [receivedAt] is when this server took delivery of it and [source] is how it
/// was obtained, and those two are the ones a manager can lean on: a picture
/// chosen from the gallery carries the time it was PICKED, so a screenshot
/// taken at home arrives with a fresh timestamp and a matching home position
/// and nothing contradicts it. The server refuses a gallery image for this
/// section; an older row may still carry no source at all, which reads as
/// unknown.
class PinDisputePhoto {
  const PinDisputePhoto({
    required this.id,
    required this.timestamp,
    required this.receivedAt,
    required this.source,
  });

  final String id;
  final DateTime timestamp;
  final DateTime receivedAt;
  final String? source;

  bool get fromCamera => source == 'camera';

  factory PinDisputePhoto.fromJson(Map<String, dynamic> json) =>
      PinDisputePhoto(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        receivedAt: DateTime.parse(
          (json['createdAt'] ?? json['timestamp']) as String,
        ),
        source: json['source'] as String?,
      );
}

/// One change somebody made to an outlet, and what it was before (#386).
class OutletChange {
  const OutletChange({
    required this.id,
    required this.userLabel,
    required this.before,
    required this.after,
    required this.pinSource,
    required this.createdAt,
    this.fromAgentId,
    this.fromAttemptId,
  });

  final String id;
  final String userLabel;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;

  /// `manual`, `agent_position`, or null when the change did not move the pin.
  final String? pinSource;

  /// For `agent_position`: whose position it was, and which attempt row it was
  /// read from. Null on every change that did not adopt one, and on rows
  /// written before the ledger recorded it.
  final String? fromAgentId;
  final String? fromAttemptId;
  final DateTime createdAt;

  factory OutletChange.fromJson(Map<String, dynamic> json) => OutletChange(
    id: json['id'] as String,
    userLabel: json['userLabel'] as String? ?? '',
    before: Map<String, dynamic>.from(
      json['before'] as Map? ?? const <String, dynamic>{},
    ),
    after: Map<String, dynamic>.from(
      json['after'] as Map? ?? const <String, dynamic>{},
    ),
    pinSource: json['pinSource'] as String?,
    fromAgentId: json['fromAgentId'] as String?,
    fromAttemptId: json['fromAttemptId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// GET /outlets/:id — the pin plus everything a manager needs to judge it.
class OutletDetail {
  const OutletDetail({
    required this.outlet,
    required this.failedAttempts,
    required this.disputes,
    required this.changes,
  });

  final Outlet outlet;
  final List<CheckInAttemptEvidence> failedAttempts;
  final List<PinDispute> disputes;
  final List<OutletChange> changes;

  factory OutletDetail.fromJson(Map<String, dynamic> json) => OutletDetail(
    outlet: Outlet.fromJson(json['outlet'] as Map<String, dynamic>),
    failedAttempts: [
      for (final a in (json['failedAttempts'] as List<dynamic>? ?? const []))
        CheckInAttemptEvidence.fromJson(a as Map<String, dynamic>),
    ],
    disputes: [
      for (final d in (json['disputes'] as List<dynamic>? ?? const []))
        PinDispute.fromJson(d as Map<String, dynamic>),
    ],
    changes: [
      for (final c in (json['changes'] as List<dynamic>? ?? const []))
        OutletChange.fromJson(c as Map<String, dynamic>),
    ],
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

/// The manager's half of outlet administration (#386): reading one outlet's
/// pin evidence, correcting it, and working the queue of agents' reports.
///
/// Deliberately a SEPARATE interface rather than three more members on
/// [OutletsRepository]. Every screen that picks an outlet from a list — beat
/// plans, campaigns, orders, reports, the dashboard — has a fake of that
/// interface in its tests, and widening it would make all of them stop
/// compiling for methods none of them will ever call. It is also an honest
/// split: these are supervisory, manager/admin-only operations, and the
/// backend enforces exactly that boundary.
abstract class OutletAdminRepository {
  /// GET /outlets/:id — one outlet with the evidence about its pin (#386).
  Future<OutletDetail> getOutlet(String id);

  /// PATCH /outlets/:id — correct a wrongly pinned outlet (#386).
  ///
  /// The pin has ONE source and the request says which: [lat]/[lng] typed in,
  /// or [fromAttemptId] — the agent's recorded position, whose coordinates the
  /// server reads out of that check-in attempt itself. Sending both is a 400,
  /// so callers must not try to be helpful by sending the numbers alongside
  /// the attempt id.
  ///
  /// [disputeId] resolves that claim in the same transaction: applied when the
  /// pin moved, rejected when it did not.
  Future<Outlet> updateOutlet({
    required String id,
    String? name,
    double? lat,
    double? lng,
    String? status,
    String? fromAttemptId,
    String? disputeId,
    String? resolutionNote,
  });

  /// GET /outlets/pin-disputes — the manager's queue, open claims by default.
  Future<PaginatedResponse<PinDispute>> listPinDisputes({
    String? status,
    String? outletId,
    int? limit,
    String? cursor,
  });
}

/// The highest `?limit=` the backend's `parsePagination` accepts (see
/// `backend/src/lib/pagination.ts`'s `MAX_LIMIT`). `fetchAllOutlets` below
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

class DioOutletsRepository implements OutletsRepository, OutletAdminRepository {
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
    final response = await dio.post(
      '/outlets',
      data: {
        'name': name,
        'code': code,
        'channelType': channelType,
        'lat': lat,
        'lng': lng,
        'territoryId': territoryId,
      },
    );
    return Outlet.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<OutletDetail> getOutlet(String id) async {
    final response = await dio.get('/outlets/$id');
    return OutletDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Outlet> updateOutlet({
    required String id,
    String? name,
    double? lat,
    double? lng,
    String? status,
    String? fromAttemptId,
    String? disputeId,
    String? resolutionNote,
  }) async {
    // The backend rejects unknown fields, so only the ones actually being
    // changed are sent — an explicit null would be an unknown-shaped value,
    // not "leave it alone".
    final response = await dio.patch(
      '/outlets/$id',
      data: {
        'name': ?name,
        'lat': ?lat,
        'lng': ?lng,
        'status': ?status,
        'fromAttemptId': ?fromAttemptId,
        'disputeId': ?disputeId,
        'resolutionNote': ?resolutionNote,
      },
    );
    return Outlet.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PaginatedResponse<PinDispute>> listPinDisputes({
    String? status,
    String? outletId,
    int? limit,
    String? cursor,
  }) async {
    final response = await dio.get(
      '/outlets/pin-disputes',
      queryParameters: {
        'status': ?status,
        'outletId': ?outletId,
        'limit': ?limit?.toString(),
        'cursor': ?cursor,
      },
    );
    return PaginatedResponse<PinDispute>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => PinDispute.fromJson(e as Map<String, dynamic>),
    );
  }
}

final outletsRepositoryProvider = Provider<OutletsRepository>(
  (ref) => DioOutletsRepository(),
);

final outletAdminRepositoryProvider = Provider<OutletAdminRepository>(
  (ref) => DioOutletsRepository(),
);

/// One outlet's detail, by id (#386). `autoDispose` and family: a manager
/// opens one store, fixes it, and leaves — keeping every store they have ever
/// looked at in memory serves nobody.
final outletDetailProvider = FutureProvider.autoDispose
    .family<OutletDetail, String>((ref, id) {
      return ref.read(outletAdminRepositoryProvider).getOutlet(id);
    });

/// The open "the pin is wrong" queue (#386).
final openPinDisputesProvider = FutureProvider.autoDispose<List<PinDispute>>((
  ref,
) async {
  final page = await ref.read(outletAdminRepositoryProvider).listPinDisputes();
  return page.data;
});

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
Future<List<Outlet>> fetchAllOutlets(
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
      throw StateError(
        'Outlet paging stalled: the server repeated cursor "$next".',
      );
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
  return fetchAllOutlets(ref.read(outletsRepositoryProvider), mine: false);
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
  return fetchAllOutlets(ref.read(outletsRepositoryProvider), mine: mine);
});
