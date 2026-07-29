import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

/// A fake HTTP layer that returns a canned body, following the pattern in
/// `test/features/tasks/tasks_admin_repository_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);
  final String body;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Returns two pages then stops, so a test can prove the "fetch every page"
/// provider (see `outlets_repository.dart`'s `_fetchAllOutlets`) actually
/// walks the cursor rather than stopping at page 1 like every other list
/// provider in the sweep.
class _TwoPageOutletsRepository implements OutletsRepository {
  final List<({bool mine, int? limit, String? cursor})> calls = [];

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async {
    calls.add((mine: mine, limit: limit, cursor: cursor));
    if (cursor == null) {
      return const PaginatedResponse(
        data: [Outlet(id: 'o1', name: 'Shop One', code: 'S1', lat: 0, lng: 0)],
        nextCursor: 'o1',
      );
    }
    return const PaginatedResponse(
      data: [Outlet(id: 'o2', name: 'Shop Two', code: 'S2', lat: 0, lng: 0)],
      nextCursor: null,
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
  }) => throw UnimplementedError();
}

void main() {
  group('DioOutletsRepository.listOutlets', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test('parses the {data, nextCursor} envelope into a PaginatedResponse',
        () async {
      final adapter = _RecordingAdapter(
        '{"data": [{"id": "o1", "name": "Test Hypermarket", "code": "TH-001", '
        '"lat": -26.2041, "lng": 28.0473}], "nextCursor": "cursor-1"}',
      );
      dio.httpClientAdapter = adapter;

      final page = await DioOutletsRepository().listOutlets();

      expect(page, isA<PaginatedResponse<Outlet>>());
      expect(page.data, hasLength(1));
      expect(page.data.first.id, 'o1');
      expect(page.nextCursor, 'cursor-1');
    });

    test('forwards mine/limit/cursor as query parameters', () async {
      final adapter = _RecordingAdapter(
        '{"data": [], "nextCursor": null}',
      );
      dio.httpClientAdapter = adapter;

      await DioOutletsRepository().listOutlets(
        mine: true,
        limit: 25,
        cursor: 'abc',
      );

      final params = adapter.lastRequest!.queryParameters;
      expect(params['mine'], 'true');
      expect(params['limit'], '25');
      expect(params['cursor'], 'abc');
    });

    test('omits mine/limit/cursor from the query when not supplied', () async {
      final adapter = _RecordingAdapter('{"data": [], "nextCursor": null}');
      dio.httpClientAdapter = adapter;

      await DioOutletsRepository().listOutlets();

      final params = adapter.lastRequest!.queryParameters;
      expect(params.containsKey('mine'), isFalse);
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });
  });

  group('outletsListProvider / assignedOutletsProvider', () {
    test(
      'outletsListProvider walks every page and concatenates them, in order',
      () async {
        final repo = _TwoPageOutletsRepository();
        final container = ProviderContainer(
          overrides: [outletsRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final outlets = await container.read(outletsListProvider.future);

        // Both pages made it into the result — capping at the first page
        // (the rest of the sweep's precedent) would drop 'o2' here, and that
        // is exactly the silent truncation this provider exists to avoid.
        expect(outlets.map((o) => o.id), ['o1', 'o2']);
        expect(repo.calls, hasLength(2));
        expect(repo.calls[0].cursor, isNull);
        expect(repo.calls[1].cursor, 'o1');
        // Every call asks for the largest page the backend allows, to
        // minimise round trips.
        expect(repo.calls.every((c) => c.limit == 200), isTrue);
      },
    );

    test('assignedOutletsProvider forwards mine through every page it walks',
        () async {
      final repo = _TwoPageOutletsRepository();
      final container = ProviderContainer(
        overrides: [
          outletsRepositoryProvider.overrideWithValue(repo),
          onlyMyTerritoriesProvider.overrideWith(() => _FixedOnlyMine(true)),
        ],
      );
      addTearDown(container.dispose);

      final outlets = await container.read(assignedOutletsProvider.future);

      expect(outlets.map((o) => o.id), ['o1', 'o2']);
      expect(repo.calls.every((c) => c.mine == true), isTrue);
    });
  });
}

class _FixedOnlyMine extends OnlyMyTerritoriesNotifier {
  _FixedOnlyMine(this._value);
  final bool _value;

  @override
  bool build() => _value;
}
