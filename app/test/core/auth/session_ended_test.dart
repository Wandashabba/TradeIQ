import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/auth/session_ended.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/network/api_client.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// THE SESSION THAT ENDED UNDER SOMEBODY (#380/#392).
///
/// The half of the feature that is not a widget: counting what is still on
/// the phone, and counting it **before** the sign-out clears the owner the
/// outbox is keyed by. That ordering is the whole thing — a second later
/// there is nobody to count the work for, and the proof block would come up
/// empty on exactly the phone that most needed it.

class _FakeTokenStore implements TokenStore {
  StoredSession? session;

  @override
  Future<void> save(StoredSession value) async => session = value;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> clear() async => session = null;
}

class _FakeAuth implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async =>
      AuthResult(token: fakeJwtFor('agent-1'), role: 'field_agent');
}

/// A token shaped like the one the server issues, carrying [userId] and
/// nothing else. The client never verifies a signature — it holds no secret —
/// and `userId` is the claim the outbox is keyed by.
///
/// **Assembled rather than pasted.** A JWT-shaped string literal in a source
/// file is what a secret scanner is for, and one in a test is a false positive
/// that teaches everybody to skim the scanner's output.
String fakeJwtFor(String userId) {
  String segment(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return <String>[
    segment(<String, String>{'alg': 'none'}),
    segment(<String, String>{'userId': userId}),
    'unsigned',
  ].join('.');
}

LocalDb _db() {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<void> _queue(
  LocalDb db, {
  required String owner,
  required String entityType,
  int count = 1,
  bool synced = false,
}) async {
  for (var i = 0; i < count; i++) {
    await db
        .into(db.syncQueueItems)
        .insert(
          SyncQueueItemsCompanion.insert(
            entityType: entityType,
            entityId: '$entityType-$i',
            payloadJson: '{}',
            userId: Value<String?>(owner),
            synced: Value<bool>(synced),
          ),
        );
  }
}

void main() {
  group('countHeldWork', () {
    test('groups the unsent rows by kind, biggest first', () async {
      final db = _db();
      await _queue(db, owner: 'agent-1', entityType: 'photo', count: 3);
      await _queue(db, owner: 'agent-1', entityType: 'stock');
      await _queue(db, owner: 'agent-1', entityType: 'visit_submit', count: 2);

      final held = await countHeldWork(db, 'agent-1');

      expect(held, <HeldLine>[
        const HeldLine(entityType: 'photo', count: 3),
        const HeldLine(entityType: 'visit_submit', count: 2),
        const HeldLine(entityType: 'stock', count: 1),
      ]);
    });

    test('a row already on the server is not held work', () async {
      final db = _db();
      await _queue(db, owner: 'agent-1', entityType: 'photo', synced: true);

      expect(await countHeldWork(db, 'agent-1'), isEmpty);
    });

    test('somebody else\'s queue is not this person\'s proof', () async {
      final db = _db();
      await _queue(db, owner: 'agent-2', entityType: 'photo', count: 4);

      expect(await countHeldWork(db, 'agent-1'), isEmpty);
    });

    test('no owner counts nothing rather than everything', () async {
      final db = _db();
      await _queue(db, owner: 'agent-1', entityType: 'photo');

      expect(await countHeldWork(db, null), isEmpty);
    });
  });

  group('the words the proof block prints', () {
    test('reuse the outbox\'s own vocabulary, in both languages', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final af = lookupAppLocalizations(const Locale('af'));
      const line = HeldLine(entityType: 'stock', count: 3);

      expect(sessionHeldLineText(en, line), '3 × Stock count');
      expect(sessionHeldLineText(af, line), '3 × Voorraadtelling');
    });
  });

  group('a 401 records what is held; a deliberate sign-out does not', () {
    late ProviderContainer container;
    late LocalDb db;
    late _FakeTokenStore tokens;

    Future<void> signIn() async {
      await container
          .read(sessionControllerProvider.notifier)
          .login('agent@example.com', 'password');
    }

    setUp(() {
      db = _db();
      tokens = _FakeTokenStore();
      container = ProviderContainer(
        overrides: <Override>[
          localDbProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
          authRepositoryProvider.overrideWithValue(_FakeAuth()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() => onUnauthorized = null);
    });

    test('the 401 counts the outbox BEFORE the owner is cleared', () async {
      await container.read(sessionControllerProvider.future);
      await signIn();
      await _queue(db, owner: 'agent-1', entityType: 'photo', count: 2);

      await container
          .read(sessionControllerProvider.notifier)
          .logout(expired: true);

      final ended = container.read(sessionEndedProvider);
      expect(ended, isNotNull);
      expect(ended!.lines, <HeldLine>[
        const HeldLine(entityType: 'photo', count: 2),
      ]);
      expect(ended.total, 2);
      expect(ended.answered, isFalse);
      expect(
        container.read(sessionControllerProvider).value!.role,
        isNull,
        reason: 'counting must not stop the sign-out',
      );
    });

    test('a 401 on a clean phone records an empty ending, not a sheet', () async {
      await container.read(sessionControllerProvider.future);
      await signIn();

      await container
          .read(sessionControllerProvider.notifier)
          .logout(expired: true);

      expect(container.read(sessionEndedProvider)!.isEmpty, isTrue);
    });

    test('a deliberate sign-out clears any previous ending', () async {
      await container.read(sessionControllerProvider.future);
      container.read(sessionEndedProvider.notifier).record(
        <HeldLine>[const HeldLine(entityType: 'photo', count: 2)],
      );

      await container.read(sessionControllerProvider.notifier).logout();

      expect(
        container.read(sessionEndedProvider),
        isNull,
        reason:
            'a held line left over from a previous ending is a lie on the '
            'sign-in screen of somebody who chose to leave',
      );
    });

    test('signing back in clears it too', () async {
      await container.read(sessionControllerProvider.future);
      container.read(sessionEndedProvider.notifier).record(
        <HeldLine>[const HeldLine(entityType: 'photo', count: 2)],
      );

      await signIn();

      expect(container.read(sessionEndedProvider), isNull);
    });

    test('answered keeps the lines and never fires twice', () {
      final notifier = container.read(sessionEndedProvider.notifier);
      notifier.record(<HeldLine>[const HeldLine(entityType: 'photo', count: 2)]);
      notifier.answered();
      final once = container.read(sessionEndedProvider);
      notifier.answered();

      expect(once!.answered, isTrue);
      expect(once.lines, hasLength(1));
      expect(identical(container.read(sessionEndedProvider), once), isTrue);
    });

    test('the unauthorized hook only fires for a signed-in session', () async {
      await container.read(sessionControllerProvider.future);
      // Nobody is signed in: a 401 on an anonymous request must not invent an
      // ending for a person who was never here.
      onUnauthorized!();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sessionEndedProvider), isNull);
    });
  });
}
