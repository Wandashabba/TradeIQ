import 'dart:typed_data';

import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../outlets/data/outlets_repository.dart' show Outlet;

/// A sales territory returned by GET /territories.
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.code,
    this.region,
  });
  final String id;
  final String name;
  final String code;
  final String? region;

  factory Territory.fromJson(Map<String, dynamic> json) => Territory(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    region: json['region'] as String?,
  );
}

/// Coverage summary for one territory returned by GET /territories/:id/coverage.
class TerritoryCoverage {
  const TerritoryCoverage({
    required this.outletCount,
    required this.agentCount,
    this.outlets = const [],
    this.outletsVisited,
    this.outletsTotal,
    this.coverageRate,
  });
  final int outletCount;
  final int agentCount;

  /// The outlets themselves, each tagged with whether it was visited — the
  /// data the territory map screen renders as pins.
  final List<Outlet> outlets;

  /// Null when the server sent no coverage block at all. **Never defaulted to
  /// zero**: a territory whose coverage the server did not compute has not
  /// been measured, and "0 of 0 visited" is a verdict nobody reached.
  final int? outletsVisited;
  final int? outletsTotal;

  /// The percentage of this territory's outlets visited in the window, or
  /// null when there is nothing to take a percentage of.
  ///
  /// The wire sends `0` for an empty territory — `outletsTotal > 0 ? … : 0` in
  /// `territories.service.ts` — and a nought there is an invented total, not a
  /// measurement. A territory with no outlets in it is 0% covered in exactly
  /// the sense that an empty shelf is 0% full: the question does not have an
  /// answer yet. [coverageMeasured] is the predicate, so the two callers
  /// cannot disagree about it.
  final double? coverageRate;

  /// Whether [coverageRate] is a figure rather than a placeholder.
  bool get coverageMeasured => coverageRate != null && (outletsTotal ?? 0) > 0;

  /// The rate when it was measured, and null when it was not.
  double? get measuredCoverageRate => coverageMeasured ? coverageRate : null;

  factory TerritoryCoverage.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'] as Map<String, dynamic>?;
    return TerritoryCoverage(
      outletCount: (json['outlets'] as List?)?.length ?? 0,
      agentCount: (json['agents'] as List?)?.length ?? 0,
      outlets:
          (json['outlets'] as List?)
              ?.map((o) => Outlet.fromJson(o as Map<String, dynamic>))
              .toList() ??
          const [],
      outletsVisited: (coverage?['outletsVisited'] as num?)?.toInt(),
      outletsTotal: (coverage?['outletsTotal'] as num?)?.toInt(),
      coverageRate: (coverage?['coverageRate'] as num?)?.toDouble(),
    );
  }
}

/// WHERE A PLACE IMAGE CAME FROM — the server's `X-Image-Source`, as a type.
///
/// Two values, and they make two different claims:
///
/// * [generated] — a model drew it from a prompt. It is an **illustration**,
///   and the plate says so, because a picture nobody photographed must never
///   be readable as one somebody did.
/// * [supplied] — the owner handed over a real photograph of the place. It is
///   a **photograph**, and calling it an illustration would be exactly as
///   false as the other way round.
///
/// What neither of them is, is evidence from a visit. That half of the
/// sentence the plate speaks does not move with the source, because it is not
/// a fact about how the picture was made — it is a fact about which table it
/// lives in.
///
/// There is no third value and no `unknown` member on purpose: a header this
/// client does not recognise parses to **null**, which the plate speaks as an
/// origin nobody stated. Widening this enum without giving the plate a
/// sentence for the new value would be a silent default, and a silent default
/// here is a false statement on a manager's screen.
enum PlaceImageSource {
  generated('generated'),
  supplied('supplied');

  const PlaceImageSource(this.wire);

  /// The value `X-Image-Source` carries. Matched exactly, never inferred.
  final String wire;

  /// [header] as a source, or null when it is absent or unrecognised.
  static PlaceImageSource? parse(String? header) {
    for (final value in PlaceImageSource.values) {
      if (value.wire == header) return value;
    }
    return null;
  }
}

/// A PICTURE OF A PLACE — and never a picture of a shelf.
///
/// The bytes The Floor's plate paints: a view of the territory in scope, or of
/// the whole footprint under "All territories". It changes when the scope
/// changes, which is the whole point of it — switch territory and the picture
/// of the place switches too.
///
/// [source] is the server's `X-Image-Source`, carried rather than assumed. It
/// is [PlaceImageSource.generated] for an illustration a model made and
/// [PlaceImageSource.supplied] for a photograph the owner handed over, and the
/// plate says which out loud in its spoken label. That is the one fact about
/// these pictures that may never get lost between the database and the screen
/// — a townscape is context, and it must never be readable as evidence a
/// manager could act on, whichever way it was made.
///
/// Nothing here touches `PhotosRepository`. Visit evidence, the review strip
/// and the pin-dispute storefront are real captures on a different route, and a
/// place image is never substituted for one of them.
@immutable
class PlaceImage {
  const PlaceImage({required this.bytes, required this.source});

  final Uint8List bytes;

  /// What the server said this is. Null when the header was absent or carried
  /// a value this build does not know — an origin nobody stated, which the
  /// plate speaks as exactly that rather than promoting it to either kind.
  final PlaceImageSource? source;

  /// Whether this picture was made by a model rather than taken by a person.
  bool get isGenerated => source == PlaceImageSource.generated;
}

abstract class TerritoriesRepository {
  /// One page of `GET /territories`. [cursor] is the previous page's
  /// `nextCursor`; [limit] is a request the backend may cap.
  Future<PaginatedResponse<Territory>> listTerritories({
    int? limit,
    String? cursor,
  });
  Future<TerritoryCoverage> getCoverage(String id);

  /// `GET /territories/:id/place-image`, or `GET /territories/place-image`
  /// when [territoryId] is null — the whole footprint.
  ///
  /// Bytes through the authed client, for the same reason as a photo
  /// thumbnail: `Image.network` cannot carry a bearer token on web. Throws
  /// when the scope has no picture, and The Floor draws its designed
  /// no-picture state rather than substituting one.
  Future<PlaceImage> placeImage(String? territoryId);

  /// POST /territories (manager/admin). [code] must be unique per client.
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  });

  /// POST /territories/:id/agents (manager/admin) — assign a field agent.
  Future<void> assignAgent(String territoryId, String userId);
}

class DioTerritoriesRepository implements TerritoriesRepository {
  @override
  Future<PaginatedResponse<Territory>> listTerritories({
    int? limit,
    String? cursor,
  }) async {
    final response = await dio.get(
      '/territories',
      queryParameters: <String, dynamic>{
        'limit': ?limit?.toString(),
        'cursor': ?cursor,
      },
    );
    return PaginatedResponse<Territory>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => Territory.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<TerritoryCoverage> getCoverage(String id) async {
    final response = await dio.get('/territories/$id/coverage');
    return TerritoryCoverage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Place images by scope, LRU-bounded, keyed by territory id (`''` is the
  /// footprint).
  ///
  /// The whole reason this control is worth having is that a manager flips
  /// between territories to compare them, and re-downloading 60 kB on every
  /// flip back is the kind of thing a prepaid bundle notices. A place image is
  /// replaced by a reseed and never edited in place — the server serves it
  /// `immutable` — so a cached one cannot go stale within a session. The bound
  /// is small because a client has territories in the dozens, not thousands.
  final _placeImageCache = <String, PlaceImage>{};
  static const placeImageCacheCap = 24;

  @override
  Future<PlaceImage> placeImage(String? territoryId) async {
    final key = territoryId ?? '';
    final cached = _placeImageCache.remove(key);
    if (cached != null) {
      _placeImageCache[key] = cached; // re-insert = most recently used
      return cached;
    }

    final response = await dio.get<List<int>>(
      territoryId == null
          ? '/territories/place-image'
          : '/territories/$territoryId/place-image',
      options: Options(responseType: ResponseType.bytes),
    );
    final image = PlaceImage(
      bytes: Uint8List.fromList(response.data!),
      // Read, never inferred. A picture whose origin the server did not state
      // — or stated in a word this build does not know — is not promoted to
      // either kind here; it parses to null and the plate says so.
      source: PlaceImageSource.parse(response.headers.value('x-image-source')),
    );
    // Only a successful fetch is cached, so a retry after a dead-signal
    // moment actually retries.
    _placeImageCache[key] = image;
    if (_placeImageCache.length > placeImageCacheCap) {
      _placeImageCache.remove(_placeImageCache.keys.first);
    }
    return image;
  }

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async {
    final response = await dio.post(
      '/territories',
      data: {'name': name, 'code': code, 'region': ?region},
    );
    return Territory.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> assignAgent(String territoryId, String userId) async {
    await dio.post(
      '/territories/$territoryId/agents',
      data: {'userId': userId},
    );
  }
}

final territoriesRepositoryProvider = Provider<TerritoriesRepository>(
  (ref) => DioTerritoriesRepository(),
);

// THE WHOLE LIST, NOT PAGE ONE OF IT — 26 September 2026.
//
// This read one page and dropped `nextCursor`, on the reading that the "terse
// territory-picker UIs it feeds want the current set". They want the set they
// can assign from: this provider backs the pickers in the beat-plan form, the
// sales-target form, the contest form and The Floor's own scope sheet, so a
// territory on page two was simply unassignable — with nothing anywhere
// saying so. The territories screen had the other half of it, printing the
// length of page one as the count beside its marker.
//
// It walks, like `fetchAllOutlets` does and for the same stated reason:
// territories are **reference data somebody finds by identity**, not an
// activity feed, so a "there are more" footer on the list screen would not
// have helped a picker at all. The loop is bounded three ways — a page cap, a
// null cursor, and a cursor that fails to advance — because an unbounded
// client loop is a bug this codebase has already been bitten by.
//
// Retries are disabled: Riverpod's default policy backs off silently for
// several seconds before surfacing an error, which would leave the list
// showing a skeleton with no explanation. Failing fast and offering the
// error state's one Retry is the better trade for a screen somebody is
// looking at — the same call `territory_map_screen.dart` made first.
const _maxTerritoryPageSize = 200;
const _maxTerritoryPages = 50;

final territoriesListProvider = FutureProvider<List<Territory>>((ref) async {
  final repo = ref.read(territoriesRepositoryProvider);
  final territories = <Territory>[];
  String? cursor;
  for (var page = 0; page < _maxTerritoryPages; page += 1) {
    final result = await repo.listTerritories(
      limit: _maxTerritoryPageSize,
      cursor: cursor,
    );
    territories.addAll(result.data);
    final next = result.nextCursor;
    if (next == null) return territories;
    if (next == cursor) {
      throw StateError(
        'Territory paging stalled: the server repeated "$next".',
      );
    }
    cursor = next;
  }
  throw StateError(
    'Territory paging exceeded $_maxTerritoryPages pages of '
    '$_maxTerritoryPageSize.',
  );
}, retry: (retryCount, error) => null);
