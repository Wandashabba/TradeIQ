import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/beatplans/data/today_route.dart'
    show invalidateRouteProgress;
import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';
import 'sync_error.dart';

abstract class QueueFlusher {
  Future<void> flush(SyncQueueItem item);
}

/// A foreground location ping (#153 T1). Sent in batches, never one by one —
/// see [SyncService.flushLocationQueue].
const locationPingEntity = 'location_ping';

/// A background location ping (#153 T2), taken by the Android foreground
/// service inside the client's working hours.
///
/// Its own outbox lane rather than a flag on the foreground rows, deliberately.
/// `POST /locations` takes ONE `source` for the whole batch, so the two must
/// never end up in the same request; and turning background tracking off has to
/// drop the background queue without touching foreground pings the agent is
/// still happy to send.
const locationBackgroundPingEntity = 'location_ping_background';

/// The agent's answer to a location notice — the foreground one (#153 T1) or
/// the background one (#153 T2). The payload names which.
const locationConsentEntity = 'location_consent';

/// An in-store order capture (#36). Unlike every other non-visit entity it
/// belongs to no visit: an agent can take an order without running an audit,
/// so it names its outlet directly and never waits on a visit to sync.
const orderEntity = 'order';

/// Outbox rows that are not the agent's work. They never appear in "Your
/// work" or the sync chip: a heartbeat queueing every two minutes would
/// otherwise keep telling an agent in a dead zone that "work" is waiting.
const locationEntityTypes = {
  locationPingEntity,
  locationBackgroundPingEntity,
  locationConsentEntity,
};

/// The most pings in one POST /locations — the server's own limit.
const maxPingsPerBatch = 100;

/// Sends one batch of pings. Abstracted so tests can count batches.
abstract class LocationPingSender {
  /// [source] is `foreground` or `background`, and covers the whole batch —
  /// it decides which notice the server requires and whether the client's
  /// working-hours window applies.
  Future<void> send(List<Map<String, dynamic>> pings, {required String source});
}

class HttpLocationPingSender implements LocationPingSender {
  HttpLocationPingSender({Dio? dio}) : _dio = dio ?? api_client.dio;
  final Dio _dio;

  @override
  Future<void> send(
    List<Map<String, dynamic>> pings, {
    required String source,
  }) => _dio.post('/locations', data: {'source': source, 'pings': pings});
}

/// Posts queued entities to their matching backend endpoint.
///
/// - `visit` → POST /visits, then records the server-assigned id on the
///   matching [VisitDrafts] row so children can reference the real visit.
/// - Every other entity type belongs to a visit: its payload carries the
///   LOCAL visit-draft id (`visitDraftId`), which is resolved to the server
///   visit id ([VisitDrafts.remoteId]) at flush time. If the visit hasn't
///   synced yet the item is left queued (throws) and retried on the next
///   flush (visit items sort earlier by id).
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({required this.db, Dio? dio}) : _dio = dio ?? api_client.dio;

  final LocalDb db;
  final Dio _dio;

  Future<String> _remoteVisitId(String localVisitId) async {
    final draft = await (db.select(db.visitDrafts)
          ..where((t) => t.id.equals(localVisitId)))
        .getSingleOrNull();
    final remoteId = draft?.remoteId;
    if (remoteId == null) {
      throw StateError('Visit $localVisitId not synced yet');
    }
    return remoteId;
  }

  @override
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        final res = await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        final remoteId = (res.data as Map<String, dynamic>)['id'] as String;
        await (db.update(db.visitDrafts)..where((t) => t.id.equals(item.entityId)))
            .write(VisitDraftsCompanion(remoteId: Value(remoteId)));
        return;
      case 'stock':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/stock', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      case 'visit_submit':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        // Carry the device's completion time through to the server. Without it
        // the fraud engine has no honest dwell measurement (#101).
        final submittedAtClient = payload['submittedAtClient'];
        await _dio.post(
          '/visits/$remoteId/submit',
          data: submittedAtClient == null
              ? null
              : {'submittedAtClient': submittedAtClient},
        );
        return;
      case 'visibility':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/visibility', data: {'visitId': remoteId, ...fields});
        return;
      case 'pricing':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/pricing', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      case 'competitive':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/competitive', data: {'visitId': remoteId, 'items': payload['items']});
        return;
      case 'capability':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/capability', data: {'visitId': remoteId, ...fields});
        return;
      case 'risk':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/risks', data: {'visitId': remoteId, 'risks': payload['risks']});
        return;
      case 'task':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/tasks', data: {'visitId': remoteId, ...fields});
        return;
      case 'scorecard':
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/scorecards', data: {'visitId': remoteId});
        return;
      case 'photo':
        // A section photo captured mid-audit (#41). Same rule as every other
        // child: it carries the local visit-draft id and waits for the visit to
        // sync before it can name a server visit.
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        final fields = Map<String, dynamic>.from(payload)..remove('visitDraftId');
        await _dio.post('/photos', data: {'visitId': remoteId, ...fields});
        return;
      case orderEntity:
        // Posted as queued. The payload already carries `capturedAt` — the
        // device's own capture time (#338) — and it must travel untouched:
        // re-stamping it here would date every offline order by the moment it
        // finally found signal, which is the bug the field exists to fix. A
        // payload queued by an older build simply has no such key, and the
        // server falls back to the time it received it.
        await _dio.post('/orders', data: jsonDecode(item.payloadJson));
        return;
      case locationConsentEntity:
        await _dio.post('/locations/consent', data: jsonDecode(item.payloadJson));
        return;
      case 'template_response':
        // The client-questions section (#122). The server upserts per (visit,
        // template), so a later save simply overwrites an earlier one. The
        // version is the one this device rendered: it may sync after the
        // manager has edited the template.
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final remoteId = await _remoteVisitId(payload['visitDraftId'] as String);
        await _dio.post('/template-responses', data: {
          'visitId': remoteId,
          'templateId': payload['templateId'],
          if (payload['templateVersion'] != null)
            'templateVersion': payload['templateVersion'],
          'answers': payload['answers'],
        });
        return;
      default:
        throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
    }
  }
}

class SyncService {
  SyncService({
    required this.db,
    required this.flusher,
    this.onItemSynced,
    this.pingSender,
  });

  final LocalDb db;
  final QueueFlusher flusher;

  /// Null means pings stay queued (tests that do not care about them).
  final LocationPingSender? pingSender;

  Future<void>? _locationFlight;

  /// Told about each item once the server has accepted it and the row is
  /// marked synced — the moment server-side effects of that item are real.
  ///
  /// A refresh hint, nothing more: it cannot fail the flush, and it is never
  /// called for an item that did not send.
  final void Function(SyncQueueItem item)? onItemSynced;

  Future<void> flushPending() async {
    // Nobody is signed in, so nothing is ours to send. Flushing here would
    // push captures under whatever token happened to be lying around.
    final owner = currentLocalUserId;
    if (owner == null) return;

    final pending = await (db.select(db.syncQueueItems)
          ..where(
            (tbl) =>
                tbl.synced.equals(false) &
                tbl.userId.equals(owner) &
                tbl.entityType.isNotIn(locationEntityTypes),
          )
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)]))
        .get();

    for (final item in pending) {
      await _sendOne(item);
    }

    await flushLocationQueue();
  }

  /// Sends one queued item and records the outcome on its row. True if it sent.
  Future<bool> _sendOne(SyncQueueItem item) async {
    try {
      await flusher.flush(item);
    } catch (e) {
      // One item's failure (network error, terminal rejection, an
      // unimplemented entity type, or a dependency not yet synced) must not
      // block the rest of the queue — it just stays unsynced for next time.
      //
      // But it is no longer swallowed. The failure is recorded, because
      // "waiting for signal" and "the server will never accept this" look
      // identical to an agent otherwise, and only one of them needs them to
      // do something about it.
      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(
        SyncQueueItemsCompanion(
          attempts: Value(item.attempts + 1),
          // A code, not a sentence: the row outlives the language the agent
          // had set when it failed. The screen words it (SyncError.message).
          lastError: Value(SyncError.of(e).code),
          lastAttemptAt: Value(DateTime.now()),
        ),
      );
      return false;
    }
    await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
        .write(
      SyncQueueItemsCompanion(
        synced: const Value(true),
        attempts: Value(item.attempts + 1),
        lastError: const Value(null),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
    try {
      onItemSynced?.call(item);
    } catch (_) {
      // The item is on the server either way; a listener that throws must
      // not stop the rest of the queue sending.
    }
    return true;
  }

  /// Try **one** queued capture now (#376).
  ///
  /// A stuck row has to offer the agent something to do, and "flush the whole
  /// queue" is not it: an agent looking at one photo that will not send wants
  /// that photo tried, not forty minutes of everything else. The payload is
  /// sent exactly as it was captured — nothing here repairs a rejected body
  /// behind the agent's back.
  ///
  /// Returns false when the row is gone, already sent, or not this agent's.
  Future<bool> sendOne(int id) async {
    final owner = currentLocalUserId;
    if (owner == null) return false;
    final row = await _ownUnsent(id, owner);
    if (row == null) return false;
    return _sendOne(row);
  }

  /// Throw one queued capture away (#376).
  ///
  /// The other half of "something to do": a payload the server will never
  /// take is otherwise a row that sits in the outbox for ever, and an agent
  /// who cannot clear it stops trusting the count. The screen states what is
  /// lost before it calls this, and only the agent's own unsent rows can be
  /// reached — a sent row is the receipt and is never thrown away.
  ///
  /// **A visit takes its captures with it.** Every section, photo and submit
  /// of a visit resolves the visit's server id at flush time, so once the
  /// visit is gone they wait for a parent that will never arrive — "waiting
  /// for the visit" for ever, with no way to clear them because a waiting row
  /// is not stuck. The sheet says how many go ([dependentsOf]) before the
  /// agent confirms; this removes them in the same transaction.
  ///
  /// Returns how many rows were removed, the capture itself included.
  Future<int> discard(int id) async {
    final owner = currentLocalUserId;
    if (owner == null) return 0;
    return db.transaction(() async {
      final row = await _ownUnsent(id, owner);
      if (row == null) return 0;
      final dependents = await _dependents(row, owner);
      await (db.delete(db.syncQueueItems)..where(
            (tbl) => tbl.id.isIn(<int>[row.id, ...dependents.map((d) => d.id)]),
          ))
          .go();
      return 1 + dependents.length;
    });
  }

  /// How many other queued captures cannot send without [id] — zero for
  /// anything but a visit. Read by the discard sheet so the statement of what
  /// is lost is the whole statement.
  Future<int> dependentsOf(int id) async {
    final owner = currentLocalUserId;
    if (owner == null) return 0;
    final row = await _ownUnsent(id, owner);
    if (row == null) return 0;
    return (await _dependents(row, owner)).length;
  }

  Future<SyncQueueItem?> _ownUnsent(int id, String owner) =>
      (db.select(db.syncQueueItems)..where(
            (tbl) =>
                tbl.id.equals(id) &
                tbl.userId.equals(owner) &
                tbl.synced.equals(false),
          ))
          .getSingleOrNull();

  /// The agent's unsent rows whose payload names [row]'s visit draft.
  Future<List<SyncQueueItem>> _dependents(
    SyncQueueItem row,
    String owner,
  ) async {
    if (row.entityType != 'visit') return const <SyncQueueItem>[];
    final candidates = await (db.select(db.syncQueueItems)..where(
          (tbl) =>
              tbl.userId.equals(owner) &
              tbl.synced.equals(false) &
              tbl.id.equals(row.id).not() &
              tbl.entityType.isNotIn(locationEntityTypes),
        ))
        .get();
    return candidates.where((c) {
      try {
        final payload = jsonDecode(c.payloadJson);
        return payload is Map && payload['visitDraftId'] == row.entityId;
      } on FormatException {
        // A payload that does not parse names no visit; it is not this
        // visit's to take.
        return false;
      }
    }).toList();
  }

  /// Sends the location outbox (#153 T1): answers to the location notice
  /// first, then pings in batches of [maxPingsPerBatch].
  ///
  /// Separate from [flushPending] so the heartbeat can send its pings every
  /// couple of minutes without re-walking — and possibly double-sending — the
  /// agent's visit captures while a visit flush is already under way. One
  /// flight at a time: a call while one is running joins it.
  Future<void> flushLocationQueue() => _locationFlight ??= _flushLocation()
      .whenComplete(() => _locationFlight = null);

  Future<void> _flushLocation() async {
    final owner = currentLocalUserId;
    if (owner == null) return;

    final answers = await (db.select(db.syncQueueItems)
          ..where(
            (t) =>
                t.synced.equals(false) &
                t.userId.equals(owner) &
                t.entityType.equals(locationConsentEntity),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
    for (final answer in answers) {
      // In order, stopping at the first failure. The server refuses pings
      // until it has the acknowledgement, and a later "stop" must never land
      // ahead of an earlier "yes".
      if (!await _sendOne(answer)) return;
    }

    final sender = pingSender;
    if (sender == null) return;
    // Foreground first: it is the fresher signal and the one a manager watching
    // the live map is actually looking at. Each lane is sent on its own, so a
    // background lane the server is refusing (the notice not yet on record)
    // cannot hold up the heartbeat, or the other way round.
    await _flushPingLane(sender, owner, locationPingEntity, 'foreground');
    await _flushPingLane(
      sender,
      owner,
      locationBackgroundPingEntity,
      'background',
    );
  }

  /// Sends one outbox lane of pings, in batches, until it is empty or the
  /// server stops accepting them.
  Future<void> _flushPingLane(
    LocationPingSender sender,
    String owner,
    String entityType,
    String source,
  ) async {
    for (;;) {
      final batch = await (db.select(db.syncQueueItems)
            ..where(
              (t) =>
                  t.synced.equals(false) &
                  t.userId.equals(owner) &
                  t.entityType.equals(entityType),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.id)])
            ..limit(maxPingsPerBatch))
          .get();
      if (batch.isEmpty) return;
      final ids = [for (final row in batch) row.id];
      final pings = <Map<String, dynamic>>[];
      for (final row in batch) {
        try {
          pings.add(jsonDecode(row.payloadJson) as Map<String, dynamic>);
        } catch (_) {
          // An unreadable row can never send; it is deleted with its batch.
        }
      }

      try {
        if (pings.isNotEmpty) await sender.send(pings, source: source);
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 400) {
          // The server validates a batch whole and will never accept this
          // one. Holding it would block every ping queued behind it, and a
          // ping is only worth anything while it is recent — so it goes.
          await _deleteRows(ids);
          continue;
        }
        // No signal, a server problem, or the notice not yet on record (403):
        // keep the pings and try again on the next flush.
        await (db.update(db.syncQueueItems)..where((t) => t.id.isIn(ids)))
            .write(
          SyncQueueItemsCompanion.custom(
            attempts: db.syncQueueItems.attempts + const Constant(1),
            lastError: Variable(SyncError.of(e).code),
            lastAttemptAt: Variable(DateTime.now()),
          ),
        );
        return;
      }
      // Sent. A ping the server has is of no further use on the phone, and a
      // trail of them is exactly what a lost device should not carry (#138).
      await _deleteRows(ids);
    }
  }

  Future<void> _deleteRows(List<int> ids) =>
      (db.delete(db.syncQueueItems)..where((t) => t.id.isIn(ids))).go();
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(localDbProvider);
  return SyncService(
    db: db,
    flusher: HttpQueueFlusher(db: db),
    pingSender: HttpLocationPingSender(),
    onItemSynced: (item) {
      // The server marks the beat-plan stop visited when a submit lands (#52).
      // Refresh the route only then — not when the agent taps submit, because
      // offline that would swap a usable cached route for a failed fetch.
      if (item.entityType == 'visit_submit') invalidateRouteProgress(ref);
    },
  );
});
