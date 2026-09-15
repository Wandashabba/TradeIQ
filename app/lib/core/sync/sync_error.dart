import 'package:dio/dio.dart';

import '../../l10n/l10n.dart';

/// Why a queued capture did not send, in the kinds an agent can tell apart.
enum SyncProblem {
  /// The parent visit has not reached the server yet, so this child cannot
  /// name it. Ordinary, and self-healing on the next flush.
  waitingForVisit,

  /// No response at all — offline, or the request never got through.
  noConnection,

  /// A 401 or 403: the session is gone.
  signedOut,

  /// A 413: the server will never take this payload as it is.
  tooLarge,

  /// A 5xx: the server's fault, and worth retrying.
  serverProblem,

  /// Any other HTTP status: the server looked at it and said no.
  rejected,

  /// Anything else.
  couldNotSend,
}

/// A failed send, stored on the outbox row as a [code] and worded only when a
/// screen shows it — in the agent's language, via [message].
///
/// The outbox outlives app updates and language changes, so it must never hold
/// a translated sentence: an Afrikaans line written today would still read
/// Afrikaans after the agent switches to English. Rows written before the
/// codes existed hold the English line itself; [parse] still recognises those,
/// and anything it cannot recognise is shown as stored.
class SyncError {
  const SyncError(this.problem, [this.status]);

  final SyncProblem problem;

  /// The HTTP status behind a [SyncProblem.rejected], shown to the agent.
  final int? status;

  /// Classifies a flush failure.
  static SyncError of(Object error) {
    if (error is StateError) return const SyncError(SyncProblem.waitingForVisit);
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == null) return const SyncError(SyncProblem.noConnection);
      if (status == 401 || status == 403) {
        return const SyncError(SyncProblem.signedOut);
      }
      if (status == 413) return const SyncError(SyncProblem.tooLarge);
      if (status >= 500) return const SyncError(SyncProblem.serverProblem);
      return SyncError(SyncProblem.rejected, status);
    }
    return const SyncError(SyncProblem.couldNotSend);
  }

  static const _prefix = 'sync:';

  /// What is written to `SyncQueueItems.lastError`: `sync:noConnection`,
  /// `sync:rejected:422`. Never shown to anyone.
  String get code => status == null
      ? '$_prefix${problem.name}'
      : '$_prefix${problem.name}:$status';

  /// The failure a stored `lastError` describes, or null when it is not one we
  /// can name — in which case the stored text is what gets shown.
  static SyncError? parse(String? stored) {
    if (stored == null) return null;
    if (stored.startsWith(_prefix)) {
      final parts = stored.substring(_prefix.length).split(':');
      final problem = SyncProblem.values
          .where((p) => p.name == parts.first)
          .firstOrNull;
      final status = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (problem == null ||
          (problem == SyncProblem.rejected) != (status != null)) {
        // A code this build does not know (written by a newer one): it still
        // failed to send, so say that rather than show the code.
        return const SyncError(SyncProblem.couldNotSend);
      }
      return SyncError(problem, status);
    }
    return _legacy(stored);
  }

  /// The English lines earlier builds stored verbatim. Frozen here on purpose:
  /// they are what is already sitting in outboxes, whatever the copy says now.
  static SyncError? _legacy(String stored) {
    final problem = switch (stored) {
      'Waiting for the visit to send first' => SyncProblem.waitingForVisit,
      'No connection' => SyncProblem.noConnection,
      'Signed out — sign in again' => SyncProblem.signedOut,
      'Too large to send' => SyncProblem.tooLarge,
      'Server problem — will retry' => SyncProblem.serverProblem,
      'Could not send' => SyncProblem.couldNotSend,
      _ => null,
    };
    if (problem != null) return SyncError(problem);
    final rejected = RegExp(r'^Rejected by the server \((\d+)\)$')
        .firstMatch(stored);
    if (rejected != null) {
      return SyncError(SyncProblem.rejected, int.parse(rejected.group(1)!));
    }
    return null;
  }

  /// A failure that clears itself on a later flush, so it is not the agent's to
  /// fix: the visit-first ordering, no signal, and a server outage.
  bool get clearsItself => switch (problem) {
    SyncProblem.waitingForVisit ||
    SyncProblem.noConnection ||
    SyncProblem.serverProblem => true,
    _ => false,
  };

  /// The line for this failure in [l10n]'s language — English when omitted.
  String message([AppLocalizations? l10n]) {
    final l = l10n ?? englishLocalizations;
    return switch (problem) {
      SyncProblem.waitingForVisit => l.syncErrorWaitingForVisit,
      SyncProblem.noConnection => l.syncErrorNoConnection,
      SyncProblem.signedOut => l.syncErrorSignedOut,
      SyncProblem.tooLarge => l.syncErrorTooLarge,
      SyncProblem.serverProblem => l.syncErrorServerProblem,
      SyncProblem.rejected => l.syncErrorRejected(status ?? 0),
      SyncProblem.couldNotSend => l.syncErrorCouldNotSend,
    };
  }
}
