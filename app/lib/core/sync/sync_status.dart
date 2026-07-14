import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_db.dart';
import 'sync_service.dart';

/// One item in the agent's outbox, described in words they can act on.
class SyncItem {
  const SyncItem({
    required this.id,
    required this.entityType,
    required this.queuedAt,
    required this.synced,
    required this.attempts,
    this.lastError,
    this.lastAttemptAt,
  });

  final int id;
  final String entityType;
  final DateTime queuedAt;
  final bool synced;
  final int attempts;
  final String? lastError;
  final DateTime? lastAttemptAt;

  /// A failure the agent has to do something about, rather than one that will
  /// clear itself.
  ///
  /// "Waiting for the visit to send first" is the normal ordering dependency —
  /// a child capture cannot name its visit until the visit reaches the server —
  /// so it is *not* a failure, even though it throws. Likewise a plain lack of
  /// connection: that is what offline looks like, not something broken.
  bool get needsAttention =>
      !synced &&
      lastError != null &&
      lastError != 'Waiting for the visit to send first' &&
      lastError != 'No connection' &&
      lastError != 'Server problem — will retry';

  /// What this row is, in the agent's language — not the entity type.
  String get label => switch (entityType) {
        'visit' => 'Check-in',
        'visit_submit' => 'Submitted visit',
        'stock' => 'Stock count',
        'visibility' => 'Visibility & display',
        'pricing' => 'Pricing',
        'competitive' => 'Competitive',
        'capability' => 'Team capability',
        'risk' => 'Risks',
        'task' => 'Action plan',
        'scorecard' => 'Score',
        'photo' => 'Photo',
        _ => entityType,
      };
}

/// The answer to the question a field agent asks all day: *is my work safe?*
class SyncStatus {
  const SyncStatus({
    required this.pending,
    required this.sent,
    required this.needsAttention,
  });

  /// Captures held on the phone, not yet on the server.
  final List<SyncItem> pending;

  /// Captures the server has.
  final List<SyncItem> sent;

  /// Pending items that will never send on their own.
  final List<SyncItem> needsAttention;

  int get pendingCount => pending.length;

  bool get allSent => pending.isEmpty;

  /// When we last got something through. Null if we never have.
  DateTime? get lastSentAt {
    final stamps = sent.map((i) => i.lastAttemptAt).whereType<DateTime>().toList();
    if (stamps.isEmpty) return null;
    stamps.sort();
    return stamps.last;
  }

  static const empty = SyncStatus(pending: [], sent: [], needsAttention: []);
}

/// Reads the outbox. A [Stream] rather than a [Future] so the chip on every
/// agent screen updates the moment a capture is queued or a flush succeeds —
/// the agent should never have to pull-to-refresh to find out whether their
/// work is safe.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final db = ref.read(localDbProvider);

  final query = db.select(db.syncQueueItems)
    ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]);

  return query.watch().map((rows) {
    final items = rows
        .map(
          (r) => SyncItem(
            id: r.id,
            entityType: r.entityType,
            queuedAt: r.queuedAt,
            synced: r.synced,
            attempts: r.attempts,
            lastError: r.lastError,
            lastAttemptAt: r.lastAttemptAt,
          ),
        )
        .toList();

    final pending = items.where((i) => !i.synced).toList();

    return SyncStatus(
      pending: pending,
      sent: items.where((i) => i.synced).toList(),
      needsAttention: pending.where((i) => i.needsAttention).toList(),
    );
  });
});

/// A manual "try sending now". The queue flushes itself, but an agent who has
/// just walked into signal should be able to make it happen rather than wonder.
final syncNowProvider = Provider<Future<void> Function()>((ref) {
  final service = ref.read(syncServiceProvider);
  return () async {
    try {
      await service.flushPending();
    } catch (_) {
      // Per-item failures are already recorded on the rows themselves.
    }
  };
});

/// Which outlet a queued visit belongs to, for labelling rows on the sync
/// screen. Best-effort: a malformed payload must never take the screen down.
String? outletIdFromPayload(String payloadJson) {
  try {
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    return map['outletId'] as String?;
  } catch (_) {
    return null;
  }
}
