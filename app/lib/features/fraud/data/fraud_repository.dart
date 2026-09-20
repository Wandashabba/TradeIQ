import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// A single risk signal contributing to a flagged visit's score.
class FraudSignal {
  const FraudSignal({required this.code, required this.detail});
  final String code;
  final String detail;

  factory FraudSignal.fromJson(Map<String, dynamic> json) => FraudSignal(
    code: json['code'] as String,
    detail: json['detail'] as String,
  );
}

/// A visit flagged by the fraud engine, returned by GET /fraud/flagged.
class FlaggedVisit {
  const FlaggedVisit({
    required this.visitId,
    required this.outletId,
    required this.agentId,
    required this.riskScore,
    required this.signals,
  });
  final String visitId;
  final String outletId;
  final String agentId;
  final double riskScore;
  final List<FraudSignal> signals;

  factory FlaggedVisit.fromJson(Map<String, dynamic> json) => FlaggedVisit(
    visitId: json['visitId'] as String,
    outletId: json['outletId'] as String,
    agentId: json['agentId'] as String,
    riskScore: (json['riskScore'] as num).toDouble(),
    signals:
        (json['signals'] as List?)
            ?.map((s) => FraudSignal.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
  );
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
  Future<FlaggedPage> flagged({int? minScore});
}

class DioFraudRepository implements FraudRepository {
  @override
  Future<FlaggedPage> flagged({int? minScore}) async {
    final query = <String, dynamic>{};
    if (minScore != null) query['minScore'] = minScore;
    final response = await dio.get('/fraud/flagged', queryParameters: query);
    return FlaggedPage.fromJson(response.data as Map<String, dynamic>);
  }
}

final fraudRepositoryProvider = Provider<FraudRepository>(
  (ref) => DioFraudRepository(),
);

// The FIRST PAGE, riskiest first. "Load more" is out of scope, as for every
// list (see the pagination spec); the screen says when there is more.
final flaggedVisitsProvider = FutureProvider<FlaggedPage>((ref) {
  return ref.read(fraudRepositoryProvider).flagged();
});
