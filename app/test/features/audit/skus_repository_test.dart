import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';

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

class _FakeSkusRepository implements SkusRepository {
  String? receivedOutletId;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async {
    receivedOutletId = outletId;
    return const PaginatedResponse(
      data: [
        Sku(
          id: 's1',
          name: 'Test Cola',
          category: 'Beverages',
          minFacingsStandard: 4,
          rrp: 19.99,
          daysOutOfStock: 2,
          velocityAvg: 3.5,
          effectivePrice: 19.99,
        ),
      ],
      nextCursor: null,
    );
  }
}

/// Always hands back the SAME cursor — a server bug (or a stale id whose
/// `skip: 1` re-yields its own page). Without a guard, `_fetchAllSkus` would
/// spin on this forever, accumulating rows until the app died.
class _StalledCursorSkusRepository implements SkusRepository {
  int calls = 0;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async {
    calls += 1;
    return const PaginatedResponse(
      data: [
        Sku(
          id: 's1',
          name: 'Cola',
          category: 'Beverages',
          minFacingsStandard: 4,
          rrp: 10,
          daysOutOfStock: 0,
          velocityAvg: 0,
          effectivePrice: 10,
        ),
      ],
      nextCursor: 'stuck',
    );
  }
}

/// Returns two pages then stops, so a test can prove `skusListProvider`
/// walks the cursor rather than stopping at page 1 like every other list
/// provider in the sweep — see the divergence documented on
/// `_fetchAllSkus` in `skus_repository.dart`.
class _TwoPageSkusRepository implements SkusRepository {
  final List<String?> cursorsSeen = [];

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async {
    cursorsSeen.add(cursor);
    if (cursor == null) {
      return const PaginatedResponse(
        data: [
          Sku(
            id: 's1',
            name: 'Cola',
            category: 'Beverages',
            minFacingsStandard: 4,
            rrp: 10,
            daysOutOfStock: 0,
            velocityAvg: 0,
            effectivePrice: 10,
          ),
        ],
        nextCursor: 's1',
      );
    }
    return const PaginatedResponse(
      data: [
        Sku(
          id: 's2',
          name: 'Fanta',
          category: 'Beverages',
          minFacingsStandard: 3,
          rrp: 12,
          daysOutOfStock: 0,
          velocityAvg: 0,
          effectivePrice: 12,
        ),
      ],
      nextCursor: null,
    );
  }
}

void main() {
  test(
    'skusListProvider resolves the repository result for the given outlet',
    () async {
      final fake = _FakeSkusRepository();
      final container = ProviderContainer(
        overrides: [skusRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final skus = await container.read(skusListProvider('outlet-1').future);

      expect(skus, hasLength(1));
      expect(skus.first.name, 'Test Cola');
      expect(skus.first.daysOutOfStock, 2);
      expect(skus.first.velocityAvg, 3.5);
      expect(fake.receivedOutletId, 'outlet-1');
    },
  );

  test(
    'skusListProvider walks every page and concatenates them, in order',
    () async {
      final fake = _TwoPageSkusRepository();
      final container = ProviderContainer(
        overrides: [skusRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final skus = await container.read(skusListProvider('outlet-1').future);

      // Both pages made it into the result — capping at the first page would
      // drop 's2' here, corrupting the check-in "N of M" progress count and
      // hiding the SKU from the stock/pricing screens entirely.
      expect(skus.map((s) => s.id), ['s1', 's2']);
      expect(fake.cursorsSeen, [null, 's1']);
    },
  );

  // This sweep exists because unbounded reads kill processes. An unbounded
  // CLIENT loop is the same bug wearing different clothes, so the fetch-all
  // providers must not trust the server's cursor to terminate.
  test(
    'skusListProvider fails loudly on a cursor that never advances',
    () async {
      final fake = _StalledCursorSkusRepository();
      final container = ProviderContainer(
        overrides: [skusRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(skusListProvider('outlet-1').future),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('stalled'),
          ),
        ),
      );

      // Caught on the second call — the first cannot know the cursor is stuck,
      // the second can. It must not keep going.
      expect(fake.calls, 2);
    },
  );

  test('Sku.fromJson parses numeric fields', () {
    final sku = Sku.fromJson({
      'id': 's2',
      'name': 'Water 1L',
      'category': 'Beverages',
      'minFacingsStandard': 3,
      'rrp': 12.5,
      'daysOutOfStock': 1,
      'velocityAvg': 6.0,
      'effectivePrice': 11.0,
    });
    expect(sku.minFacingsStandard, 3);
    expect(sku.rrp, 12.5);
    expect(sku.daysOutOfStock, 1);
    expect(sku.velocityAvg, 6.0);
    expect(sku.effectivePrice, 11.0);
  });

  group('DioSkusRepository.listSkus', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test(
      'parses the {data, nextCursor} envelope into a PaginatedResponse',
      () async {
        dio.httpClientAdapter = _RecordingAdapter(
          '{"data": [{"id": "s1", "name": "Test Cola", "category": "Beverages", '
          '"minFacingsStandard": 4, "rrp": 19.99, "daysOutOfStock": 0, '
          '"velocityAvg": 0, "effectivePrice": 19.99}], "nextCursor": "cursor-1"}',
        );

        final page = await DioSkusRepository().listSkus(outletId: 'outlet-1');

        expect(page, isA<PaginatedResponse<Sku>>());
        expect(page.data, hasLength(1));
        expect(page.data.first.id, 's1');
        expect(page.nextCursor, 'cursor-1');
      },
    );

    test('forwards outletId/limit/cursor as query parameters', () async {
      final adapter = _RecordingAdapter('{"data": [], "nextCursor": null}');
      dio.httpClientAdapter = adapter;

      await DioSkusRepository().listSkus(
        outletId: 'outlet-1',
        limit: 25,
        cursor: 'abc',
      );

      final params = adapter.lastRequest!.queryParameters;
      expect(params['outletId'], 'outlet-1');
      expect(params['limit'], '25');
      expect(params['cursor'], 'abc');
    });
  });
}
