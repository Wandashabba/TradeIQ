import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';

class _RecordingFlusher implements QueueFlusher {
  final flushed = <SyncQueueItem>[];

  @override
  Future<void> flush(SyncQueueItem item) async => flushed.add(item);
}

void main() {
  test('PhotoUploadResult.fromJson parses id and url', () {
    final result = PhotoUploadResult.fromJson(const {
      'id': 'photo-1',
      'url': 'https://cdn.example.com/photo-1.png',
    });

    expect(result.id, 'photo-1');
    expect(result.url, 'https://cdn.example.com/photo-1.png');
  });

  group('DriftQueuedPhotosRepository', () {
    test('queues a section photo against the LOCAL visit draft id', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final flusher = _RecordingFlusher();
      final repo = DriftQueuedPhotosRepository(
        db: db,
        syncService: SyncService(db: db, flusher: flusher),
      );

      await repo.queuePhoto(
        visitDraftId: 'local-v1',
        section: 'visibility',
        dataUrl: 'data:image/jpeg;base64,AQID',
      );

      final queued = await db.select(db.syncQueueItems).get();
      expect(queued, hasLength(1));
      expect(queued.single.entityType, 'photo');

      final payload =
          jsonDecode(queued.single.payloadJson) as Map<String, dynamic>;
      // The visit may not exist on the server yet — the photo carries the local
      // draft id and the flusher resolves it at send time.
      expect(payload['visitDraftId'], 'local-v1');
      expect(payload['section'], 'visibility');
      expect(payload['dataUrl'], 'data:image/jpeg;base64,AQID');
      expect(payload['timestamp'], isNotEmpty);
    });

    test('a photo taken offline survives a failing flush', () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);

      // The flush blows up (no network). The capture must still be on disk —
      // an agent who walks out of the store must not lose their evidence.
      final repo = DriftQueuedPhotosRepository(
        db: db,
        syncService: SyncService(db: db, flusher: _ThrowingFlusher()),
      );

      await repo.queuePhoto(
        visitDraftId: 'local-v1',
        section: 'pricing',
        dataUrl: 'data:image/jpeg;base64,AQID',
      );

      final queued = await db.select(db.syncQueueItems).get();
      expect(queued, hasLength(1));
      expect(queued.single.synced, isFalse);
    });
  });
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async => throw Exception('offline');
}
