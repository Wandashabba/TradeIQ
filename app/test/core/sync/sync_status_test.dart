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
  // Built by hand rather than via db.enqueue: this fixture needs to set
  // synced/attempts/lastError, which enqueue deliberately does not expose —
  // production code only ever queues fresh, unsent, unattempted work.
  await db
      .into(db.syncQueueItems)
      .insert(
        SyncQueueItemsCompanion.insert(
          entityType: entityType,
          entityId: '$entityType-${DateTime.now().microsecondsSinceEpoch}',
          payloadJson: '{}',
          userId: Value(currentLocalUserId),
          synced: Value(synced),
          attempts: Value(attempts),
          lastError: Value(lastError),
          lastAttemptAt: Value(
            synced || lastError != null ? DateTime.now() : null,
          ),
        ),
      );
}

void main() {
  late LocalDb db;
  late ProviderContainer container;

  setUp(() {
    // The sync screen shows only the signed-in agent's own queue, so these
    // tests need somebody signed in — as the app does.
    currentLocalUserId = 'user-a';
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
    final sub = container.listen<AsyncValue<SyncStatus>>(syncStatusProvider, (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null && !completer.isCompleted) completer.complete(value);
    }, fireImmediately: true);
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
    await _queue(
      db,
      entityType: 'visit',
      lastError: 'No connection',
      attempts: 3,
    );

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

  test(
    'entity types are named in the agent’s language, not the schema’s',
    () async {
      await _queue(db, entityType: 'visit_submit');
      await _queue(db, entityType: 'capability');

      final s = await read();

      final labels = s.pending.map((i) => i.label).toSet();
      expect(labels, containsAll(['Submitted visit', 'Team capability']));
    },
  );

  test(
    'the decoded payload size reaches the screen, and unknown stays unknown',
    () async {
      // #410 stored it; this is the hop that makes OutboxRow able to show it.
      await db.enqueue(
        entityType: 'stock',
        entityId: 'measured',
        payloadJson: '{"items":[]}',
      );
      // A row queued before the column existed was never measured. It must
      // reach the screen as null — an unmeasured row is not a row of 0 bytes.
      await db
          .into(db.syncQueueItems)
          .insert(
            SyncQueueItemsCompanion.insert(
              entityType: 'photo',
              entityId: 'legacy',
              payloadJson: '{}',
              userId: Value(currentLocalUserId),
            ),
          );

      final s = await read();
      final byType = {for (final i in s.pending) i.entityType: i};
      expect(byType['stock']!.payloadBytes, '{"items":[]}'.length);
      expect(byType['photo']!.payloadBytes, isNull);
    },
  );

  test(
    'the screen reads the classification rather than re-deriving it',
    () async {
      await _queue(db, entityType: 'stock', lastError: 'sync:waitingForVisit');
      await _queue(db, entityType: 'photo', lastError: 'sync:signedOut');
      await _queue(db, entityType: 'pricing', lastError: 'sync:rejected:422');
      await _queue(db, entityType: 'risk', lastError: 'sync:tooLarge');
      await _queue(db, entityType: 'task');

      final s = await read();
      SyncItem of(String type) =>
          s.pending.firstWhere((i) => i.entityType == type);

      expect(of('stock').waitsForVisit, isTrue);
      expect(of('stock').needsAttention, isFalse);
      expect(of('photo').sessionEnded, isTrue);
      expect(of('pricing').isRejected, isTrue);
      expect(of('risk').isRejected, isTrue, reason: 'a 413 fails identically');
      expect(of('task').isRejected, isFalse);

      // Waiting is the normal state and never counted with the ones that need
      // a human; the session-ended subset is what moves the screen's amber.
      expect(s.waiting.map((i) => i.entityType).toSet(), {'stock', 'task'});
      expect(s.sessionEnded.map((i) => i.entityType), ['photo']);
    },
  );

  // unify §1.13: session-ended is a HELD state. It sends itself after sign-in,
  // so it is never counted with the captures that raise a colour.
  test('a session that ended is held, not stuck', () async {
    await _queue(db, entityType: 'photo', lastError: 'sync:signedOut');
    await _queue(db, entityType: 'pricing', lastError: 'sync:rejected:422');
    await _queue(db, entityType: 'task');

    final s = await read();
    expect(s.stuck.map((i) => i.entityType), ['pricing']);
    expect(s.held.map((i) => i.entityType).toSet(), {'photo', 'task'});
    // Held and stuck partition what is on the phone.
    expect(s.held.length + s.stuck.length, s.pendingCount);
  });
}
