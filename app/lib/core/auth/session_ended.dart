import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../storage/local_db.dart';
import '../sync/sync_status.dart';

/// One countable kind of held work, as the proof block prints it.
@immutable
class HeldLine {
  const HeldLine({required this.entityType, required this.count});

  /// The outbox row's `entityType` — `photo`, `stock`, `visit_submit`. Worded
  /// by [sessionHeldLineText], which reuses the outbox's own vocabulary rather
  /// than inventing a second set of names for the same eleven things.
  final String entityType;

  final int count;

  @override
  bool operator ==(Object other) =>
      other is HeldLine &&
      other.entityType == entityType &&
      other.count == count;

  @override
  int get hashCode => Object.hash(entityType, count);

  @override
  String toString() => 'HeldLine($entityType × $count)';
}

/// THE SESSION ENDED, AND THIS IS WHAT IS STILL ON THE PHONE.
///
/// Captured at the moment the 401 lands and **before** the sign-out clears
/// `currentLocalUserId`, because the outbox query is scoped by owner: a
/// second later there is nobody to count the work for and the proof block
/// would be empty on exactly the phone that most needed it.
@immutable
class SessionEnded {
  const SessionEnded({required this.lines, this.answered = false});

  /// Held work, largest kind first. Empty when the outbox was clean — and an
  /// empty session-ended is not shown at all: a person who was signed out with
  /// nothing on the phone has nothing to be reassured about and a sheet in
  /// front of the sign-in form would only be in the way.
  final List<HeldLine> lines;

  /// The sheet has been answered once. It never appears twice for one ending;
  /// what stays afterwards is the line under the header.
  final bool answered;

  int get total => lines.fold<int>(0, (sum, line) => sum + line.count);

  bool get isEmpty => total == 0;
}

/// The words for one held line: the outbox's own label for the kind, and the
/// count beside it.
String sessionHeldLineText(AppLocalizations l10n, HeldLine line) =>
    l10n.sessionHeldEntry(
      line.count,
      SyncItem(
        id: 0,
        entityType: line.entityType,
        queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
        synced: false,
        attempts: 0,
      ).labelIn(l10n),
    );

/// Holds the one session ending the app has not answered yet.
///
/// Null means nothing to say — either nobody has been signed out, or the
/// person has signed back in and the outbox is somebody's problem again.
class SessionEndedController extends Notifier<SessionEnded?> {
  @override
  SessionEnded? build() => null;

  void record(List<HeldLine> lines) => state = SessionEnded(lines: lines);

  /// The sheet has been answered — "Sign in to send them" or "Not now". The
  /// lines stay, because the line under the header is drawn from them.
  void answered() {
    final current = state;
    if (current == null || current.answered) return;
    state = SessionEnded(lines: current.lines, answered: true);
  }

  void clear() => state = null;
}

final sessionEndedProvider =
    NotifierProvider<SessionEndedController, SessionEnded?>(
      SessionEndedController.new,
    );

/// Count what [owner] still has queued, grouped by kind.
///
/// Best-effort: a database that will not answer must never stop a sign-out.
/// An unreadable outbox yields no lines, which shows the person the plain
/// sign-in screen — the same screen they have always been shown — rather than
/// blocking the way back in behind a query.
Future<List<HeldLine>> countHeldWork(LocalDb db, String? owner) async {
  if (owner == null) return const <HeldLine>[];
  try {
    final rows = await (db.select(
      db.syncQueueItems,
    )..where((t) => t.synced.equals(false) & t.userId.equals(owner))).get();
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.entityType] = (counts[row.entityType] ?? 0) + 1;
    }
    final lines =
        <HeldLine>[
          for (final entry in counts.entries)
            HeldLine(entityType: entry.key, count: entry.value),
        ]..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.entityType.compareTo(b.entityType);
        });
    return lines;
  } catch (_) {
    return const <HeldLine>[];
  }
}
