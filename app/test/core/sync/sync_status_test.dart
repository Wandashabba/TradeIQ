import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';

Future<void> _queue(
  LocalDb db, {
  required String entityType,
  bool synced = false,
  String? lastError,
  int attempts = 0,
}) async {
  await db.into(db.syncQueueItems).insert(
        SyncQueueItemsCompanion.insert(
          entityType: entityType,
          entityId: '$entityType-${DateTime.now().microsecondsSinceEpoch}',
          payloadJson: '{}',
          synced: Value(synced),
          attempts: Value(attempts),
          lastError: Value(lastError),
          lastAttemptAt: Value(synced || lastError != null ? DateTime.now() : null),
        ),
      );
}

void main() {
  late LocalDb db;
  late ProviderContainer container;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [localDbProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    // Dispose the container FIRST. It holds the Drift watch() subscription, and
    // closing the database out from under a live subscription hangs.
    container.dispose();
    await db.close();
  });

  /// Riverpod 3 auto-disposes a provider with nothing listening, so awaiting
  /// `.future` on its own disposes the stream before it can emit. Listen the way
  /// a widget does, and take the first value that arrives.
  Future<SyncStatus> read() async {
    final completer = Completer<SyncStatus>();
    final sub = container.listen<AsyncValue<SyncStatus>>(
      syncStatusProvider,
      (_, next) {
        final value = next.value;
        if (value != null && !completer.isCompleted) completer.complete(value);
      },
      fireImmediately: true,
    );
    final value = await completer.future;
    sub.close();
    return value;
  }

  test('an empty outbox means everything is sent', () async {
    final s = await read();

    expect(s.allSent, isTrue);
    expect(s.pendingCount, 0);
    expect(s.needsAttention, isEmpty);
  });

  test('unsent captures are pending, not failures', () async {
    await _queue(db, entityType: 'stock');
    await _queue(db, entityType: 'pricing');

    final s = await read();

    // Holding work on the phone is the NORMAL state in a shop with no signal.
    // It is not an error, and the agent must not be told it is one.
    expect(s.pendingCount, 2);
    expect(s.needsAttention, isEmpty);
    expect(s.allSent, isFalse);
  });

  test('waiting for the parent visit is not a failure', () async {
    // A child capture cannot name its visit until the visit reaches the server.
    // It throws, and it is retried, and it resolves itself — so it must not be
    // paraded in front of the agent as something they have to fix.
    await _queue(
      db,
      entityType: 'stock',
      lastError: 'Waiting for the visit to send first',
      attempts: 1,
    );

    final s = await read();

    expect(s.pendingCount, 1);
    expect(s.needsAttention, isEmpty);
  });

  test('no connection is not a failure either', () async {
    await _queue(db, entityType: 'visit', lastError: 'No connection', attempts: 3);

    final s = await read();

    expect(s.needsAttention, isEmpty);
  });

  test('a terminal rejection DOES need the agent', () async {
    // This is the one that matters. A photo the server will never accept looks
    // identical to one waiting for signal unless we say so — and only one of
    // them requires the agent to do anything.
    await _queue(
      db,
      entityType: 'photo',
      lastError: 'Too large to send',
      attempts: 2,
    );

    final s = await read();

    expect(s.needsAttention, hasLength(1));
    expect(s.needsAttention.single.label, 'Photo');
    expect(s.needsAttention.single.lastError, 'Too large to send');
  });

  test('sent items are reported as sent, with a last-sent time', () async {
    await _queue(db, entityType: 'visit', synced: true, attempts: 1);
    await _queue(db, entityType: 'stock');

    final s = await read();

    expect(s.sent, hasLength(1));
    expect(s.pendingCount, 1);
    expect(s.lastSentAt, isNotNull);
  });

  test('entity types are named in the agent’s language, not the schema’s',
      () async {
    await _queue(db, entityType: 'visit_submit');
    await _queue(db, entityType: 'capability');

    final s = await read();

    final labels = s.pending.map((i) => i.label).toSet();
    expect(labels, containsAll(['Submitted visit', 'Team capability']));
  });
}
