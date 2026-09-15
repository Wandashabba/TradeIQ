import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../storage/local_db.dart';
import 'sync_error.dart';
import 'sync_service.dart';

export 'sync_error.dart' show SyncError, SyncProblem;

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

  /// The last failure as stored: a [SyncError.code], or — on a row written
  /// before the codes — the English line itself. Word it with [problemIn].
  final String? lastError;
  final DateTime? lastAttemptAt;

  /// The last failure, when it is one we can name.
  SyncError? get error => SyncError.parse(lastError);

  /// A failure the agent has to do something about, rather than one that will
  /// clear itself.
  ///
  /// Waiting for the visit to send first is the normal ordering dependency —
  /// a child capture cannot name its visit until the visit reaches the server —
  /// so it is *not* a failure, even though it throws. Likewise a plain lack of
  /// connection: that is what offline looks like, not something broken.
  bool get needsAttention =>
      !synced && lastError != null && !(error?.clearsItself ?? false);

  /// The last failure in [l10n]'s language (English when omitted), or null if
  /// the last attempt did not fail. A stored line we cannot name is shown as
  /// it was stored.
  String? problemIn([AppLocalizations? l10n]) {
    final stored = lastError;
    if (stored == null) return null;
    return error?.message(l10n) ?? stored;
  }

  /// What this row is, in the agent's words — not the entity type. English;
  /// see [labelIn].
  String get label => labelIn();

  /// [label] in [l10n]'s language — English when omitted.
  String labelIn([AppLocalizations? l10n]) {
    final l = l10n ?? englishLocalizations;
    return switch (entityType) {
      'visit' => l.syncItemCheckIn,
      'visit_submit' => l.syncItemSubmittedVisit,
      'stock' => l.syncItemStockCount,
      'visibility' => l.syncItemVisibility,
      'pricing' => l.syncItemPricing,
      'competitive' => l.syncItemCompetitive,
      'capability' => l.syncItemCapability,
      'risk' => l.syncItemRisks,
      'task' => l.syncItemActionPlan,
      'scorecard' => l.syncItemScore,
      'photo' => l.syncItemPhoto,
      _ => entityType,
    };
  }
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

  // Only ever the signed-in agent's own queue. Listing another user's pending
  // captures would disclose where they have been and what they photographed,
  // and no agent can act on work that is not theirs anyway.
  final owner = currentLocalUserId;
  final query = db.select(db.syncQueueItems)
    ..where(
      (t) => owner == null
          ? const Constant(false)
          // Location pings and notice answers are not the agent's work — see
          // `locationEntityTypes`.
          : t.userId.equals(owner) & t.entityType.isNotIn(locationEntityTypes),
    )
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

/// True only while a flush is actually in flight.
///
/// This is what the pulsing dot means: *sending, right now*. It deliberately
/// does NOT mean "there is pending work" — holding captures on the phone is the
/// normal state in a shop with no signal, and a permanently pulsing dot would
/// read as an alarm. (It would also make `pumpAndSettle` hang in every test that
/// renders an agent screen, since a forever-repeating animation never settles.)
class SyncingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final syncingProvider =
    NotifierProvider<SyncingNotifier, bool>(SyncingNotifier.new);

/// A manual "try sending now". The queue flushes itself, but an agent who has
/// just walked into signal should be able to make it happen rather than wonder.
final syncNowProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.read(syncingProvider.notifier).set(true);
    try {
      await ref.read(syncServiceProvider).flushPending();
    } catch (_) {
      // Per-item failures are already recorded on the rows themselves.
    } finally {
      ref.read(syncingProvider.notifier).set(false);
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
