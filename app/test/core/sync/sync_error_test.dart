import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

DioException _http(int? status) {
  final options = RequestOptions(path: '/stock');
  return DioException(
    requestOptions: options,
    type: status == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

class _ThrowingFlusher implements QueueFlusher {
  _ThrowingFlusher(this.error);
  final Object error;

  @override
  Future<void> flush(SyncQueueItem item) async => throw error;
}

SyncItem _row({required String entityType, String? lastError}) => SyncItem(
  id: 1,
  entityType: entityType,
  queuedAt: DateTime(2026, 9, 15),
  synced: false,
  attempts: 1,
  lastError: lastError,
);

void main() {
  final af = lookupAppLocalizations(const Locale('af'));

  group('SyncError', () {
    test('each flush failure maps to its problem', () {
      expect(
        SyncError.of(StateError('Visit v1 not synced yet')).problem,
        SyncProblem.waitingForVisit,
      );
      expect(SyncError.of(_http(null)).problem, SyncProblem.noConnection);
      expect(SyncError.of(_http(401)).problem, SyncProblem.signedOut);
      expect(SyncError.of(_http(403)).problem, SyncProblem.signedOut);
      expect(SyncError.of(_http(413)).problem, SyncProblem.tooLarge);
      expect(SyncError.of(_http(503)).problem, SyncProblem.serverProblem);
      final rejected = SyncError.of(_http(422));
      expect(rejected.problem, SyncProblem.rejected);
      expect(rejected.status, 422);
      expect(
        SyncError.of(Exception('boom')).problem,
        SyncProblem.couldNotSend,
      );
    });

    test('every problem maps to English and Afrikaans copy', () {
      const english = {
        SyncProblem.waitingForVisit: 'Waiting for the visit to send first',
        SyncProblem.noConnection: 'No connection',
        SyncProblem.signedOut: 'Signed out — sign in again',
        SyncProblem.tooLarge: 'Too large to send',
        SyncProblem.serverProblem: 'Server problem — will retry',
        SyncProblem.rejected: 'Rejected by the server (422)',
        SyncProblem.couldNotSend: 'Could not send',
      };
      const afrikaans = {
        SyncProblem.waitingForVisit: 'Wag dat die besoek eers gestuur word',
        SyncProblem.noConnection: 'Geen verbinding nie',
        SyncProblem.signedOut: 'Uitgeteken — teken weer in',
        SyncProblem.tooLarge: 'Te groot om te stuur',
        SyncProblem.serverProblem: 'Bedienerprobleem — sal weer probeer',
        SyncProblem.rejected: 'Deur die bediener geweier (422)',
        SyncProblem.couldNotSend: 'Kon nie stuur nie',
      };
      expect(english.keys, containsAll(SyncProblem.values));
      for (final problem in SyncProblem.values) {
        final error = SyncError(
          problem,
          problem == SyncProblem.rejected ? 422 : null,
        );
        expect(error.message(), english[problem], reason: '$problem en');
        expect(error.message(af), afrikaans[problem], reason: '$problem af');
      }
    });

    test('codes round-trip through storage', () {
      for (final problem in SyncProblem.values) {
        final error = SyncError(
          problem,
          problem == SyncProblem.rejected ? 409 : null,
        );
        final parsed = SyncError.parse(error.code)!;
        expect(parsed.problem, problem);
        expect(parsed.status, error.status);
        expect(error.code, startsWith('sync:'));
      }
      expect(const SyncError(SyncProblem.tooLarge).code, 'sync:tooLarge');
      expect(
        const SyncError(SyncProblem.rejected, 422).code,
        'sync:rejected:422',
      );
    });

    test('a code from a newer build still reads as a failed send', () {
      expect(
        SyncError.parse('sync:quotaExceeded')!.problem,
        SyncProblem.couldNotSend,
      );
    });

    test('the English lines older builds stored are still recognised', () {
      final legacy = {
        'Waiting for the visit to send first': SyncProblem.waitingForVisit,
        'No connection': SyncProblem.noConnection,
        'Signed out — sign in again': SyncProblem.signedOut,
        'Too large to send': SyncProblem.tooLarge,
        'Server problem — will retry': SyncProblem.serverProblem,
        'Rejected by the server (422)': SyncProblem.rejected,
        'Could not send': SyncProblem.couldNotSend,
      };
      legacy.forEach((stored, problem) {
        final parsed = SyncError.parse(stored)!;
        expect(parsed.problem, problem, reason: stored);
        // Worded again, it is the line that was stored.
        expect(parsed.message(), stored);
      });
      expect(SyncError.parse('Payload rejected'), isNull);
      expect(SyncError.parse(null), isNull);
    });
  });

  group('SyncItem wording', () {
    test('every entity type has an English and an Afrikaans label', () {
      const labels = {
        'visit': ('Check-in', 'Aanmelding'),
        'visit_submit': ('Submitted visit', 'Ingediende besoek'),
        'stock': ('Stock count', 'Voorraadtelling'),
        'visibility': ('Visibility & display', 'Sigbaarheid & uitstalling'),
        'pricing': ('Pricing', 'Pryse'),
        'competitive': ('Competitive', 'Mededinging'),
        'capability': ('Team capability', 'Spanvermoë'),
        'risk': ('Risks', 'Risiko’s'),
        'task': ('Action plan', 'Aksieplan'),
        'scorecard': ('Score', 'Telling'),
        'photo': ('Photo', 'Foto'),
      };
      labels.forEach((type, words) {
        final item = _row(entityType: type);
        expect(item.label, words.$1, reason: type);
        expect(item.labelIn(englishLocalizations), words.$1, reason: type);
        expect(item.labelIn(af), words.$2, reason: type);
      });
      // A type this build does not know keeps its schema name.
      expect(_row(entityType: 'mystery').labelIn(af), 'mystery');
    });

    test('shared callers without an l10n get English', () {
      // Nothing outside the agent flow passes an AppLocalizations, so these
      // defaults are what any console surface would render.
      final item = _row(entityType: 'photo', lastError: 'sync:tooLarge');
      expect(item.label, 'Photo');
      expect(item.problemIn(), 'Too large to send');
    });

    test('old rows holding English still display and still triage', () {
      final legacy = _row(entityType: 'photo', lastError: 'Too large to send');
      expect(legacy.problemIn(), 'Too large to send');
      expect(legacy.problemIn(af), 'Te groot om te stuur');
      expect(legacy.needsAttention, isTrue);

      final offline = _row(entityType: 'visit', lastError: 'No connection');
      expect(offline.needsAttention, isFalse);

      // A line no build of ours wrote is shown exactly as stored.
      final unknown = _row(entityType: 'photo', lastError: 'Payload rejected');
      expect(unknown.problemIn(af), 'Payload rejected');
      expect(unknown.needsAttention, isTrue);
    });

    test('coded rows triage like the English lines did', () {
      bool attention(String code) =>
          _row(entityType: 'stock', lastError: code).needsAttention;
      expect(attention('sync:waitingForVisit'), isFalse);
      expect(attention('sync:noConnection'), isFalse);
      expect(attention('sync:serverProblem'), isFalse);
      expect(attention('sync:signedOut'), isTrue);
      expect(attention('sync:tooLarge'), isTrue);
      expect(attention('sync:rejected:422'), isTrue);
      expect(attention('sync:couldNotSend'), isTrue);
    });
  });

  group('SyncService storage', () {
    setUp(() => currentLocalUserId = 'user-a');
    tearDown(() => currentLocalUserId = null);

    Future<String?> storedFor(Object error) async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.enqueue(entityType: 'stock', entityId: 's1', payloadJson: '{}');
      await SyncService(
        db: db,
        flusher: _ThrowingFlusher(error),
      ).flushPending();
      final row = await db.select(db.syncQueueItems).getSingle();
      return row.lastError;
    }

    test('a failed send stores a code, never a sentence', () async {
      expect(await storedFor(_http(422)), 'sync:rejected:422');
      expect(await storedFor(_http(null)), 'sync:noConnection');
      expect(
        await storedFor(StateError('Visit v1 not synced yet')),
        'sync:waitingForVisit',
      );
      expect(await storedFor(Exception('boom')), 'sync:couldNotSend');
    });
  });
}
