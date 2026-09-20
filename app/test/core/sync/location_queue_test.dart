import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';

/// #153 T1 — location pings go through the offline outbox, in batches, behind
/// the agent's answer to the notice, and never pose as the agent's work.
class _RecordingFlusher implements QueueFlusher {
  final List<SyncQueueItem> sent = [];
  Object? failWith;

  @override
  Future<void> flush(SyncQueueItem item) async {
    if (failWith != null) throw failWith!;
    sent.add(item);
  }
}

class _RecordingSender implements LocationPingSender {
  final List<List<Map<String, dynamic>>> batches = [];

  /// The `source` each batch was posted with — foreground and background go in
  /// separate requests (#153 T2), and this is what proves they never mix.
  final List<String> sources = [];
  Object? failWith;

  @override
  Future<void> send(
    List<Map<String, dynamic>> pings, {
    required String source,
  }) async {
    if (failWith != null) throw failWith!;
    batches.add(pings);
    sources.add(source);
  }
}

/// A sender that can fail one lane and not the other — the case where the
/// server has the foreground acknowledgement but not the background one.
class _SelectiveSender implements LocationPingSender {
  _SelectiveSender({required this.onSend});

  final void Function(List<Map<String, dynamic>> pings, String source) onSend;

  @override
  Future<void> send(
    List<Map<String, dynamic>> pings, {
    required String source,
  }) async => onSend(pings, source);
}

DioException _http(int? status) {
  final options = RequestOptions(path: '/locations');
  return DioException(
    requestOptions: options,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  late LocalDb db;
  late _RecordingFlusher flusher;
  late _RecordingSender sender;
  late SyncService sync;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    flusher = _RecordingFlusher();
    sender = _RecordingSender();
    sync = SyncService(db: db, flusher: flusher, pingSender: sender);
    currentLocalUserId = 'agent-1';
  });

  tearDown(() async {
    currentLocalUserId = null;
    await db.close();
  });

  Future<void> queuePings(int count) async {
    for (var i = 0; i < count; i++) {
      final at = DateTime.utc(2026, 9, 15, 8).add(Duration(minutes: 2 * i));
      await db.enqueue(
        entityType: locationPingEntity,
        entityId: at.toIso8601String(),
        payloadJson: jsonEncode({
          'lat': -26.1,
          'lng': 28.05,
          'accuracyM': 9.0,
          'recordedAt': at.toIso8601String(),
        }),
      );
    }
  }

  Future<void> queueAnswer(String decision) => db.enqueue(
    entityType: locationConsentEntity,
    entityId: decision,
    payloadJson: jsonEncode({
      'decision': decision,
      'noticeVersion': 'v1',
      'decidedAt': '2026-09-15T07:00:00.000Z',
    }),
  );

  Future<List<SyncQueueItem>> rows() => db.select(db.syncQueueItems).get();

  test(
    'sends queued pings in batches of 100 and deletes them once sent',
    () async {
      await queuePings(250);
      await sync.flushLocationQueue();

      expect(sender.batches.map((b) => b.length), [100, 100, 50]);
      expect(sender.batches.first.first, {
        'lat': -26.1,
        'lng': 28.05,
        'accuracyM': 9.0,
        'recordedAt': '2026-09-15T08:00:00.000Z',
      });
      expect(sender.sources, ['foreground', 'foreground', 'foreground']);
      expect(await rows(), isEmpty);
    },
  );

  /// #153 T2 — background route points travel in their own lane. `POST
  /// /locations` takes one `source` for the whole batch, so the two must never
  /// share a request.
  group('background pings (#153 T2)', () {
    Future<void> queueBackgroundPings(int count) async {
      for (var i = 0; i < count; i++) {
        final at = DateTime.utc(2026, 9, 15, 9).add(Duration(minutes: 10 * i));
        await db.enqueue(
          entityType: locationBackgroundPingEntity,
          entityId: at.toIso8601String(),
          payloadJson: jsonEncode({
            'lat': -26.2,
            'lng': 28.1,
            'accuracyM': 18.0,
            'recordedAt': at.toIso8601String(),
          }),
        );
      }
    }

    test(
      'posts them with source background, never mixed with the heartbeat',
      () async {
        await queuePings(2);
        await queueBackgroundPings(3);

        await sync.flushLocationQueue();

        expect(sender.sources, ['foreground', 'background']);
        expect(sender.batches.map((b) => b.length), [2, 3]);
        // Foreground first: it is the fresher signal and the one a manager
        // watching the live map is actually looking at.
        expect(sender.batches.first.first['lat'], -26.1);
        expect(sender.batches.last.first['lat'], -26.2);
        expect(await rows(), isEmpty);
      },
    );

    test(
      'a background lane the server refuses does not hold up the heartbeat',
      () async {
        // The realistic case: the background notice is not on record yet (403),
        // while foreground sharing is perfectly fine.
        await queuePings(2);
        await queueBackgroundPings(2);
        var seen = 0;
        sync = SyncService(
          db: db,
          flusher: flusher,
          pingSender: _SelectiveSender(
            onSend: (pings, source) {
              seen++;
              if (source == 'background') throw _http(403);
            },
          ),
        );

        await sync.flushLocationQueue();

        expect(seen, 2);
        final left = await rows();
        // The foreground pings are gone (sent); the background ones are held for
        // the next flush, with the attempt recorded.
        expect(left.map((r) => r.entityType).toSet(), {
          locationBackgroundPingEntity,
        });
        expect(left, hasLength(2));
        expect(left.every((r) => r.attempts == 1), isTrue);
      },
    );

    test('batches background pings at the server limit too', () async {
      await queueBackgroundPings(150);
      await sync.flushLocationQueue();
      expect(sender.batches.map((b) => b.length), [100, 50]);
      expect(sender.sources, ['background', 'background']);
    });
  });

  test(
    'flushPending sends pings in a batch, never through the per-item flusher',
    () async {
      await db.enqueue(entityType: 'visit', entityId: 'v1', payloadJson: '{}');
      await queuePings(3);

      await sync.flushPending();

      expect(flusher.sent.map((i) => i.entityType), ['visit']);
      expect(sender.batches, hasLength(1));
      expect(sender.batches.single, hasLength(3));
    },
  );

  test('sends the answer to the notice first, then the pings', () async {
    await queueAnswer('acknowledged');
    await queuePings(2);

    await sync.flushLocationQueue();

    expect(flusher.sent.map((i) => i.entityType), [locationConsentEntity]);
    expect(sender.batches, hasLength(1));
    final answer = (await rows()).single;
    expect(answer.synced, isTrue);
  });

  test(
    'holds pings back while the answer to the notice has not sent',
    () async {
      flusher.failWith = _http(null);
      await queueAnswer('acknowledged');
      await queuePings(2);

      await sync.flushLocationQueue();

      expect(sender.batches, isEmpty);
      final all = await rows();
      expect(
        all.where((r) => r.entityType == locationPingEntity),
        hasLength(2),
      );
      expect(
        all.firstWhere((r) => r.entityType == locationConsentEntity).attempts,
        1,
      );
    },
  );

  test(
    'keeps pings queued with the attempt recorded when there is no signal',
    () async {
      sender.failWith = _http(null);
      await queuePings(3);

      await sync.flushLocationQueue();

      final left = await rows();
      expect(left, hasLength(3));
      expect(
        left.every(
          (r) => r.attempts == 1 && r.lastError == 'sync:noConnection',
        ),
        isTrue,
      );
      expect(left.every((r) => !r.synced), isTrue);
    },
  );

  test(
    'keeps pings when the server has not got the acknowledgement yet (403)',
    () async {
      sender.failWith = _http(403);
      await queuePings(1);
      await sync.flushLocationQueue();
      expect(await rows(), hasLength(1));
    },
  );

  test(
    'drops a batch the server rejects as malformed instead of blocking later pings',
    () async {
      sender.failWith = _http(400);
      await queuePings(120);

      await sync.flushLocationQueue();

      expect(await rows(), isEmpty);
    },
  );

  test('sends only the signed-in agent’s pings', () async {
    await queuePings(2);
    currentLocalUserId = 'agent-2';
    await queuePings(1);

    await sync.flushLocationQueue();

    expect(sender.batches.single, hasLength(1));
    final left = await rows();
    expect(left.every((r) => r.userId == 'agent-1'), isTrue);
    expect(left, hasLength(2));
  });

  test('a flush already in flight is joined, not repeated', () async {
    await queuePings(1);
    final first = sync.flushLocationQueue();
    final second = sync.flushLocationQueue();
    expect(identical(first, second), isTrue);
    await first;
    expect(sender.batches, hasLength(1));
  });

  test('location rows never appear in the agent’s sync status', () async {
    await db.enqueue(entityType: 'visit', entityId: 'v1', payloadJson: '{}');
    await queueAnswer('acknowledged');
    await queuePings(5);

    final container = ProviderContainer(
      overrides: [localDbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Listened, as the app's chip does: an unlistened provider is paused.
    final sub = container.listen(syncStatusProvider, (_, _) {});
    addTearDown(sub.close);
    final status = await container.read(syncStatusProvider.future);

    expect(status.pending.map((i) => i.entityType), ['visit']);
    expect(status.pendingCount, 1);
  });
}
