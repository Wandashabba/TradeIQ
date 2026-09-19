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
    this.payloadBytes,
  });

  final int id;
  final String entityType;
  final DateTime queuedAt;
  final bool synced;
  final int attempts;

  /// The **decoded** payload size, as `SyncQueueItems.payloadBytes` stores it
  /// (#410): the base64 length overstates a photo by about a third, and the
  /// figure exists so an agent on a 1 GB bundle can decide whether to send
  /// now. Null on a row queued before the column existed — an unmeasured row
  /// is not a row of zero bytes, and the outbox row renders nothing rather
  /// than "0 kB".
  final int? payloadBytes;

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

  /// Blocked on the visit above it reaching the server. An ordering
  /// dependency, explicitly not a fault — the outbox row says so in those
  /// words and never calls it stuck.
  bool get waitsForVisit => error?.problem == SyncProblem.waitingForVisit;

  /// The session ended under it. The one failure whose fix is "sign in"
  /// rather than anything to do with this capture.
  bool get sessionEnded => error?.problem == SyncProblem.signedOut;

  /// A failure the server will never accept as it stands, so retrying it
  /// unchanged fails identically. #376: the app must never quietly repair the
  /// payload — the agent chooses between sending it to support and throwing
  /// it away.
  bool get isRejected =>
      error?.problem == SyncProblem.rejected ||
      error?.problem == SyncProblem.tooLarge;

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
      orderEntity => l.syncItemOrder,
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

  /// Pending captures that are simply waiting — the normal state. Never an
  /// error, and never counted with the ones that need a human.
  List<SyncItem> get waiting =>
      pending.where((i) => !i.needsAttention).toList();

  /// Pending captures held back because the session ended.
  ///
  /// Signing in is then the expected next move, and it is the one case where
  /// this screen's amber moves off "Send now" — pressing that button with no
  /// session sends nothing.
  List<SyncItem> get sessionEnded =>
      needsAttention.where((i) => i.sessionEnded).toList();

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
            payloadBytes: r.payloadBytes,
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

/// "Send this one now" — one capture, not the whole queue (#376).
///
/// Separate from [syncNowProvider] because the two are different promises: the
/// screen's button means *try everything*, and a row's action means *try this
/// photo*. Sharing one provider would make a row's tap flush forty other
/// items, which is not what the row says it does.
final sendOneProvider = Provider<Future<void> Function(int)>((ref) {
  return (int id) async {
    ref.read(syncingProvider.notifier).set(true);
    try {
      await ref.read(syncServiceProvider).sendOne(id);
    } catch (_) {
      // The outcome is recorded on the row itself; a throw here would take
      // the sheet down over a failure the row is about to display.
    } finally {
      ref.read(syncingProvider.notifier).set(false);
    }
  };
});

/// "Discard this capture" — the other half of #376.
///
/// The screen says what is lost before it calls this, and the row never
/// disappears on its own: a capture leaves the phone because the agent said
/// so, or because the server took it.
final discardCaptureProvider = Provider<Future<void> Function(int)>((ref) {
  return (int id) => ref.read(syncServiceProvider).discard(id);
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
