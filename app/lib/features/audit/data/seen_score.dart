import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';

/// WHAT THE AGENT ACTUALLY SAW — the referent for the reconciliation line.
///
/// A score that is changed on review after the agent has already read it is
/// the event that breaks trust in every subsequent score. The fix is one line
/// — "Now scored 71 — it was 84 when you saw it" — and that line needs to know
/// what was on the screen the first time.
///
/// Nothing on the wire carries that. It is not a server fact at all: the
/// server knows what it scored, not what this phone displayed. So it is
/// recorded here, on the phone, the moment the outcome screen paints a number.
///
/// Deliberately **not** a drift table and **not** the outbox:
///
/// * a drift migration for a per-visit integer that nobody queries is a schema
///   version for a preference;
/// * a queued item for an endpoint that does not exist retries until it is
///   `stuck`, and a stuck row renders as "needs you" — turning a silent record
///   into a chore the agent cannot discharge.
///
/// It is the same `flutter_secure_storage` the pin report (#386) and the theme
/// preference already use. Not a secret, but not worth a second storage stack.
abstract class SeenScoreStore {
  Future<Map<String, int>> read();

  Future<void> write(Map<String, int> scores);
}

class SecureSeenScoreStore implements SeenScoreStore {
  SecureSeenScoreStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  static const _key = 'tiq.seenScores';

  @override
  Future<Map<String, int>> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const <String, int>{};
      return decode(raw);
    } catch (_) {
      // Unreadable is empty. A screen that shows a score must never fail to
      // show it because a bookkeeping record would not parse.
      return const <String, int>{};
    }
  }

  @override
  Future<void> write(Map<String, int> scores) async {
    try {
      await _storage.write(key: _key, value: encode(scores));
    } catch (e) {
      // Best-effort: an unpersisted record only means the reconciliation line
      // does not appear, which is the same as nothing having changed.
      debugPrint('Seen score not persisted: $e');
    }
  }

  /// `visit-1=84;visit-2=71`. A hand-rolled pair list rather than JSON because
  /// the value set is two primitives and the storage is a string either way.
  static String encode(Map<String, int> scores) =>
      scores.entries.map((e) => '${e.key}=${e.value}').join(';');

  static Map<String, int> decode(String raw) {
    final out = <String, int>{};
    for (final pair in raw.split(';')) {
      if (pair.isEmpty) continue;
      final equals = pair.indexOf('=');
      if (equals <= 0) continue;
      final value = int.tryParse(pair.substring(equals + 1));
      // A malformed pair is dropped, never guessed at: a wrong "you saw 8"
      // is worse than no line.
      if (value == null) continue;
      out[pair.substring(0, equals)] = value;
    }
    return out;
  }
}

final seenScoreStoreProvider = Provider<SeenScoreStore>(
  (ref) => SecureSeenScoreStore(),
);

/// Visit draft id → the score this phone last showed for it.
///
/// A plain [Notifier] over a map, not an `AsyncNotifier`, for the same reason
/// the pin report is one: the screen that reads it is showing a score, and a
/// loading state wrapped around a score is a screen that says nothing. It
/// starts empty and fills in when the store answers — the worst case is that
/// a reconciliation line appears on the *next* open instead of this one, which
/// is exactly when the design says it should appear anyway.
class SeenScores extends Notifier<Map<String, int>> {
  /// Completes when the disk has answered. [record] awaits it, so a write
  /// started on the first frame cannot land *before* the read and clobber what
  /// the agent actually saw last time — which would erase the referent the
  /// reconciliation line exists to keep.
  late Future<void> _ready;

  @override
  Map<String, int> build() {
    _ready = _load();
    return const <String, int>{};
  }

  Future<void> _load() async {
    final stored = await ref.read(seenScoreStoreProvider).read();
    if (stored.isEmpty) return;
    // Anything recorded this run wins: it is newer than the disk.
    state = <String, int>{...stored, ...state};
  }

  /// What this phone showed for [visitDraftId], or null if it has never shown
  /// a number for it.
  int? seen(String visitDraftId) => state[visitDraftId];

  /// Record the number now on the screen.
  ///
  /// Idempotent, and **it does not overwrite**: the first number the agent saw
  /// is the one the reconciliation line is about. Recording the second one
  /// would quietly make the line say "now 71 — it was 71" and then never
  /// appear again.
  Future<void> record(String visitDraftId, int score) async {
    await _ready;
    if (state.containsKey(visitDraftId)) return;
    final next = <String, int>{...state, visitDraftId: score};
    state = next;
    await ref.read(seenScoreStoreProvider).write(next);
  }
}

final seenScoresProvider = NotifierProvider<SeenScores, Map<String, int>>(
  SeenScores.new,
);
