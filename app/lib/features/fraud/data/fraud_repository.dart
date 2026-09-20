import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A single risk signal contributing to a flagged visit's score.
class FraudSignal {
  const FraudSignal({
    required this.code,
    required this.detail,
  });
  final String code;
  final String detail;

  factory FraudSignal.fromJson(Map<String, dynamic> json) => FraudSignal(
        code: json['code'] as String,
        detail: json['detail'] as String,
      );
}

/// The three rulings a reviewer may reach, as the wire spells them.
///
/// The words on screen are not these: `dismissed` is **Cleared** (the visit
/// stands), `confirmed` is **Confirmed** (the work was faked) and
/// `inconclusive` is **Needs evidence** (nobody can tell yet, and that is a
/// decision too). Mapping happens once, here, so a screen never types a wire
/// value and the wire never carries a label somebody rewrote.
enum FraudVerdictKind {
  /// The accusation does not stand. The agent did the work.
  cleared('dismissed'),

  /// The accusation stands.
  confirmed('confirmed'),

  /// Not decidable on what is here. A note is required.
  needsEvidence('inconclusive');

  const FraudVerdictKind(this.wire);

  final String wire;

  static FraudVerdictKind? fromWire(String? value) {
    for (final kind in FraudVerdictKind.values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// One standing ruling on one visit (#392).
class FraudVerdict {
  const FraudVerdict({
    required this.visitId,
    required this.kind,
    required this.reviewerLabel,
    required this.decidedAt,
    this.note,
    this.riskScoreAtReview,
  });

  final String visitId;
  final FraudVerdictKind kind;

  /// Who ruled, as the ledger froze them — a renamed or deactivated reviewer
  /// does not rewrite a decision they made.
  final String reviewerLabel;

  final DateTime decidedAt;

  /// Free text the reviewer added, or null when they added none — never ''.
  final String? note;

  /// The stored score the reviewer was actually looking at. Null when the
  /// visit was unscored at review time: a rescore can move the number
  /// afterwards, and without this a clearing read later looks as though it was
  /// made against a figure nobody ever saw.
  final int? riskScoreAtReview;

  factory FraudVerdict.fromJson(Map<String, dynamic> json) => FraudVerdict(
        visitId: json['visitId'] as String? ?? '',
        kind: FraudVerdictKind.fromWire(json['verdict'] as String?) ??
            FraudVerdictKind.needsEvidence,
        reviewerLabel:
            (json['reviewer'] as Map<String, dynamic>?)?['label'] as String? ??
                '',
        note: json['note'] as String?,
        riskScoreAtReview: (json['riskScoreAtReview'] as num?)?.toInt(),
        decidedAt: DateTime.parse(json['decidedAt'] as String),
      );
}

/// A second reviewer got there first (#392).
///
/// The verdict is INSERTed against a unique `visit_id`, so the loser of a race
/// is answered 409 with the ruling that stands — which is how they learn whose
/// decision applies instead of believing theirs did.
class FraudVerdictConflict implements Exception {
  const FraudVerdictConflict(this.standing);

  final FraudVerdict standing;

  @override
  String toString() =>
      '${standing.reviewerLabel} already ruled this visit.';
}

/// A visit flagged by the fraud engine, returned by GET /fraud/flagged.
class FlaggedVisit {
  const FlaggedVisit({
    required this.visitId,
    required this.outletId,
    required this.agentId,
    required this.riskScore,
    required this.signals,
    this.scoredAt,
    this.verdict,
  });
  final String visitId;
  final String outletId;
  final String agentId;
  final double riskScore;
  final List<FraudSignal> signals;

  /// When the stored score's inputs were read: how old this snapshot is
  /// (#236). Null for a score the server did not date.
  final DateTime? scoredAt;

  /// The manager's standing ruling, or null when nobody has ruled (#392).
  /// Null is the honest answer for "not yet reviewed" — a row without a
  /// verdict has not been cleared, it has not been looked at.
  final FraudVerdict? verdict;

  factory FlaggedVisit.fromJson(Map<String, dynamic> json) => FlaggedVisit(
        visitId: json['visitId'] as String,
        outletId: json['outletId'] as String,
        agentId: json['agentId'] as String,
        riskScore: (json['riskScore'] as num).toDouble(),
        signals: (json['signals'] as List?)
                ?.map((s) => FraudSignal.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        scoredAt: json['scoredAt'] == null
            ? null
            : DateTime.parse(json['scoredAt'] as String),
        verdict: json['verdict'] == null
            ? null
            : FraudVerdict.fromJson(json['verdict'] as Map<String, dynamic>),
      );
}

/// Which side of the review line `GET /fraud/flagged` answers about (#392).
enum FlaggedReviewFilter {
  /// The DEFAULT: the open queue. A ruled visit leaves it, because a queue
  /// that never shortens is a queue people stop opening.
  open('false'),

  /// The decided list.
  decided('true'),

  /// Both.
  all('all');

  const FlaggedReviewFilter(this.wire);

  final String wire;
}

/// One page of GET /fraud/flagged: the standard `{data, nextCursor}` envelope,
/// highest risk first, plus [unscored].
///
/// The list reads the score stored on each visit at submit (#236). A submitted
/// visit with no stored score yet can be neither listed nor ruled out, so the
/// backend counts those instead of hiding them.
class FlaggedPage extends PaginatedResponse<FlaggedVisit> {
  const FlaggedPage({
    required super.data,
    required super.nextCursor,
    this.unscored = 0,
  });

  /// Submitted visits in the review window that have not been scored yet.
  final int unscored;

  factory FlaggedPage.fromJson(Map<String, dynamic> json) {
    final page = PaginatedResponse<FlaggedVisit>.fromJson(
      json,
      (e) => FlaggedVisit.fromJson(e as Map<String, dynamic>),
    );
    return FlaggedPage(
      data: page.data,
      nextCursor: page.nextCursor,
      unscored: (json['unscored'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class FraudRepository {
  Future<FlaggedPage> flagged({
    int? minScore,
    FlaggedReviewFilter reviewed = FlaggedReviewFilter.open,
  });

  /// POST /fraud/visits/:id/verdict — record the manager's ruling (#392).
  ///
  /// Throws [FraudVerdictConflict] when somebody else ruled first.
  Future<FraudVerdict> recordVerdict({
    required String visitId,
    required FraudVerdictKind kind,
    String? note,
  });
}

class DioFraudRepository implements FraudRepository {
  @override
  Future<FlaggedPage> flagged({
    int? minScore,
    FlaggedReviewFilter reviewed = FlaggedReviewFilter.open,
  }) async {
    final query = <String, dynamic>{'reviewed': reviewed.wire};
    if (minScore != null) query['minScore'] = minScore;
    final response = await dio.get('/fraud/flagged', queryParameters: query);
    return FlaggedPage.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FraudVerdict> recordVerdict({
    required String visitId,
    required FraudVerdictKind kind,
    String? note,
  }) async {
    try {
      final response = await dio.post(
        '/fraud/visits/${Uri.encodeComponent(visitId)}/verdict',
        data: <String, dynamic>{
          'verdict': kind.wire,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return FraudVerdict.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (error.response?.statusCode == 409 &&
          body is Map<String, dynamic> &&
          body['verdict'] is Map<String, dynamic>) {
        throw FraudVerdictConflict(
          FraudVerdict.fromJson(body['verdict'] as Map<String, dynamic>),
        );
      }
      rethrow;
    }
  }
}

final fraudRepositoryProvider =
    Provider<FraudRepository>((ref) => DioFraudRepository());

// The FIRST PAGE of the OPEN queue, riskiest first. "Load more" is out of
// scope, as for every list (see the pagination spec); the screen says when
// there is more, and the unscored count says what is not on either side.
final flaggedVisitsProvider =
    FutureProvider.family<FlaggedPage, FlaggedReviewFilter>((ref, filter) {
  return ref.read(fraudRepositoryProvider).flagged(reviewed: filter);
});
