import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';

/// Matches the backend's own `ISO_INSTANT_RE` in agents.routes.ts — the exact
/// pattern the server 400s on if the client sends anything looser.
final _isoInstantRe = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$',
);

/// A fake HTTP layer that records the outgoing request and returns a
/// canned body, following the pattern in
/// `test/core/sync/sync_service_test.dart`.
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

class _FakeAgentsRepository implements AgentsRepository {
  _FakeAgentsRepository(this.page);
  final AgentActivityPage page;

  /// The `now` the provider under test actually asked for — what proves it
  /// went through `nowProvider` rather than calling `DateTime.now()` itself.
  DateTime? capturedFrom;

  @override
  Future<AgentActivityPage> listActivity({
    required DateTime from,
    required DateTime to,
    String? territoryId,
  }) async {
    capturedFrom = from;
    return page;
  }
}

void main() {
  group('AgentActivity.fromJson', () {
    test('parses an agent with stops', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a1',
        'name': 'thabo@example.com',
        'state': 'at_store',
        'currentOutlet': {'id': 'o1', 'name': 'Sandton Spar'},
        'lastSeenAt': '2026-07-22T08:00:00.000Z',
        'stops': [
          {
            'visitId': 'v1',
            'outletId': 'o1',
            'outletName': 'Sandton Spar',
            'lat': -26.1,
            'lng': 28.05,
            'checkinTs': '2026-07-22T08:00:00.000Z',
            'status': 'in_progress',
          },
        ],
      });

      expect(activity.agentId, 'a1');
      expect(activity.state, AgentState.atStore);
      expect(activity.currentOutletName, 'Sandton Spar');
      expect(activity.stops, hasLength(1));
      expect(activity.stops.first.lat, -26.1);
      expect(activity.lastSeenAt, DateTime.utc(2026, 7, 22, 8));
    });

    test('parses an idle agent with no stops and no last-seen', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a2',
        'name': 'sipho@example.com',
        'state': 'idle',
        'currentOutlet': null,
        'lastSeenAt': null,
        'stops': <Map<String, dynamic>>[],
      });

      expect(activity.state, AgentState.idle);
      expect(activity.currentOutletName, isNull);
      expect(activity.lastSeenAt, isNull);
      expect(activity.stops, isEmpty);
    });

    // An unknown state must not crash the panel. Falling back to idle is the
    // honest default: it claims nothing.
    test('falls back to idle on an unrecognised state', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a3',
        'name': 'x@example.com',
        'state': 'teleporting',
        'currentOutlet': null,
        'lastSeenAt': null,
        'stops': <Map<String, dynamic>>[],
      });
      expect(activity.state, AgentState.idle);
    });
  });

  group('dayBoundsLocal', () {
    // The client owns the timezone decision — see the route comment on
    // GET /agents/activity. These must be local midnights, not UTC ones.
    test('returns local midnight to the next local midnight', () {
      final (from, to) = dayBoundsLocal(DateTime(2026, 7, 22, 14, 30));
      expect(from, DateTime(2026, 7, 22));
      expect(to, DateTime(2026, 7, 23));
    });

    test('spans exactly one day across a month boundary', () {
      final (from, to) = dayBoundsLocal(DateTime(2026, 7, 31, 9));
      expect(from, DateTime(2026, 7, 31));
      expect(to, DateTime(2026, 8, 1));
    });
  });

  group('AgentActivity.lastOutletName', () {
    // The backend's deriveAgentState() re-sorts by checkinTs rather than
    // trust the query's ordering, because a caller-trusted ordering that
    // silently breaks would report a confidently wrong outlet with no throw
    // and no signal. The client must not reintroduce that trust on its side.
    test('reflects the stop with the latest checkinTs, not list order', () {
      final activity = AgentActivity(
        agentId: 'a1',
        name: 'thabo@example.com',
        state: AgentState.inTransit,
        stops: [
          AgentStop(
            visitId: 'v2',
            outletId: 'o2',
            outletName: 'Later Outlet',
            lat: 0,
            lng: 0,
            checkinTs: DateTime.utc(2026, 7, 22, 10),
            inProgress: false,
          ),
          AgentStop(
            visitId: 'v1',
            outletId: 'o1',
            outletName: 'Earlier Outlet',
            lat: 0,
            lng: 0,
            checkinTs: DateTime.utc(2026, 7, 22, 8),
            inProgress: false,
          ),
        ],
      );

      expect(activity.lastOutletName, 'Later Outlet');
    });

    test('is null when there are no stops', () {
      const activity = AgentActivity(
        agentId: 'a1',
        name: 'thabo@example.com',
        state: AgentState.idle,
        stops: [],
      );
      expect(activity.lastOutletName, isNull);
    });
  });

  group('DioAgentsRepository.listActivity', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = dio.httpClientAdapter;
    });

    tearDown(() {
      dio.httpClientAdapter = originalAdapter;
    });

    test(
      'sends full ISO-8601 instants, limit=200, and omits territoryId when null',
      () async {
        final adapter = _RecordingAdapter('{"agents": [], "nextCursor": null}');
        dio.httpClientAdapter = adapter;

        await DioAgentsRepository().listActivity(
          from: DateTime.utc(2026, 7, 22),
          to: DateTime.utc(2026, 7, 23),
        );

        final query = adapter.lastRequest!.queryParameters;
        expect(_isoInstantRe.hasMatch(query['from'] as String), isTrue);
        expect(_isoInstantRe.hasMatch(query['to'] as String), isTrue);
        expect(query['limit'], 200);
        expect(query.containsKey('territoryId'), isFalse);
      },
    );

    test('sends territoryId when provided', () async {
      final adapter = _RecordingAdapter('{"agents": [], "nextCursor": null}');
      dio.httpClientAdapter = adapter;

      await DioAgentsRepository().listActivity(
        from: DateTime.utc(2026, 7, 22),
        to: DateTime.utc(2026, 7, 23),
        territoryId: 'JHB-01',
      );

      expect(adapter.lastRequest!.queryParameters['territoryId'], 'JHB-01');
    });

    test('truncated is true when the server returns a nextCursor', () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"agents": [], "nextCursor": "some-agent-id"}',
      );

      final page = await DioAgentsRepository().listActivity(
        from: DateTime.utc(2026, 7, 22),
        to: DateTime.utc(2026, 7, 23),
      );

      expect(page.truncated, isTrue);
    });

    test('truncated is false when nextCursor is null', () async {
      dio.httpClientAdapter = _RecordingAdapter(
        '{"agents": [], "nextCursor": null}',
      );

      final page = await DioAgentsRepository().listActivity(
        from: DateTime.utc(2026, 7, 22),
        to: DateTime.utc(2026, 7, 23),
      );

      expect(page.truncated, isFalse);
    });
  });

  group('agentActivityTodayProvider', () {
    test('reads "now" from nowProvider rather than DateTime.now()', () async {
      final fakeRepo = _FakeAgentsRepository(
        const AgentActivityPage(agents: [], truncated: false),
      );
      final pinnedNow = DateTime(2026, 1, 15, 9);

      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          nowProvider.overrideWithValue(() => pinnedNow),
        ],
      );
      addTearDown(container.dispose);

      await container.read(agentActivityTodayProvider.future);

      expect(fakeRepo.capturedFrom, DateTime(2026, 1, 15));
    });
  });

  group('agentActivityForDayProvider', () {
    test(
      'is autoDispose: its state is gone once the last listener drops',
      () async {
        final fakeRepo = _FakeAgentsRepository(
          const AgentActivityPage(agents: [], truncated: false),
        );
        final container = ProviderContainer(
          overrides: [agentsRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        final day = DateTime(2026, 7, 22);
        final provider = agentActivityForDayProvider(day);

        final subscription = container.listen(provider, (_, _) {});
        expect(container.exists(provider), isTrue);

        subscription.close();
        // Disposal for autoDispose providers is scheduled for the end of the
        // current event loop, not synchronous — container.pump() is Riverpod's
        // own hook for awaiting exactly that.
        await container.pump();
        expect(container.exists(provider), isFalse);
      },
    );
  });
}
