import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart' as api;
import '../../fraud/data/fraud_repository.dart' show FraudSignal;

/// The outlet a visit was made at.
class VisitOutletRef {
  const VisitOutletRef({
    required this.id,
    required this.name,
    required this.code,
    required this.channelType,
  });

  final String id;
  final String name;
  final String code;
  final String channelType;

  factory VisitOutletRef.fromJson(Map<String, dynamic> json) => VisitOutletRef(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    channelType: json['channelType'] as String? ?? '',
  );
}

/// The agent who made the visit. `User` has no display-name column, so the
/// email is the name the console shows.
class VisitAgentRef {
  const VisitAgentRef({required this.id, required this.email});

  final String id;
  final String email;

  factory VisitAgentRef.fromJson(Map<String, dynamic> json) =>
      VisitAgentRef(id: json['id'] as String, email: json['email'] as String);
}

/// One perfect-store dimension. A null [score] means not measurable (for
/// example, no competitor was captured), which is not the same as zero.
class ScoreDimension {
  const ScoreDimension({required this.key, required this.score});

  final String key;
  final double? score;

  factory ScoreDimension.fromJson(Map<String, dynamic> json) => ScoreDimension(
    key: json['key'] as String,
    score: (json['score'] as num?)?.toDouble(),
  );
}

class VisitScore {
  const VisitScore({
    required this.weightedTotal,
    required this.ratingBand,
    required this.target,
    required this.dimensions,
  });

  final double weightedTotal;

  /// `green` | `amber` | `red`, as stored when the visit was scored.
  final String ratingBand;

  /// The client's green line: the standard the total is read against.
  final double target;
  final List<ScoreDimension> dimensions;

  factory VisitScore.fromJson(Map<String, dynamic> json) => VisitScore(
    weightedTotal: (json['weightedTotal'] as num).toDouble(),
    ratingBand: json['ratingBand'] as String,
    target: (json['target'] as num?)?.toDouble() ?? 80,
    dimensions: [
      for (final d in (json['dimensions'] as List? ?? const []))
        ScoreDimension.fromJson(d as Map<String, dynamic>),
    ],
  );
}

/// What one capture section found.
class VisitSectionSummary {
  const VisitSectionSummary({
    required this.key,
    required this.count,
    required this.flagged,
    required this.findings,
    this.truncated = false,
  });

  /// `stock` | `visibility` | `pricing` | `competitive` | `risks`.
  final String key;
  final int count;

  /// Rows needing a manager's attention.
  final int flagged;
  final List<String> findings;
  final bool truncated;

  factory VisitSectionSummary.fromJson(Map<String, dynamic> json) =>
      VisitSectionSummary(
        key: json['key'] as String,
        count: (json['count'] as num?)?.toInt() ?? 0,
        flagged: (json['flagged'] as num?)?.toInt() ?? 0,
        findings: [
          for (final f in (json['findings'] as List? ?? const [])) f as String,
        ],
        truncated: json['truncated'] as bool? ?? false,
      );
}

/// Photo METADATA only. The bytes come from the thumbnail route by [id]; the
/// detail payload never carries an image.
class VisitPhotoRef {
  const VisitPhotoRef({
    required this.id,
    required this.section,
    required this.timestamp,
  });

  final String id;
  final String section;
  final DateTime timestamp;

  factory VisitPhotoRef.fromJson(Map<String, dynamic> json) => VisitPhotoRef(
    id: json['id'] as String,
    section: json['section'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// The visit's answers to its client's audit template: the client-questions
/// section that supplements S1–S10 (#122). Never part of the perfect-store
/// score.
class VisitTemplateAnswers {
  const VisitTemplateAnswers({
    required this.templateId,
    required this.templateName,
    required this.templateVersion,
    required this.currentVersion,
    required this.schema,
    required this.answers,
    this.recordedAt,
  });

  final String templateId;
  final String templateName;

  /// The version the agent answered against.
  final int templateVersion;

  /// The template's version now. [schema] is this version's schema: the
  /// server keeps no history, so labels may have moved on since.
  final int currentVersion;
  final Map<String, dynamic> schema;
  final Map<String, dynamic> answers;
  final DateTime? recordedAt;

  bool get answeredOlderVersion => templateVersion < currentVersion;

  factory VisitTemplateAnswers.fromJson(Map<String, dynamic> json) {
    final recorded = json['recordedAt'] as String?;
    final version = (json['templateVersion'] as num?)?.toInt() ?? 1;
    return VisitTemplateAnswers(
      templateId: json['templateId'] as String,
      templateName: json['templateName'] as String? ?? '',
      templateVersion: version,
      currentVersion: (json['currentVersion'] as num?)?.toInt() ?? version,
      schema: json['schema'] is Map<String, dynamic>
          ? json['schema'] as Map<String, dynamic>
          : const {},
      answers: json['answers'] is Map<String, dynamic>
          ? json['answers'] as Map<String, dynamic>
          : const {},
      recordedAt: recorded == null ? null : DateTime.tryParse(recorded),
    );
  }
}

/// `GET /visits/:id`: one visit, as a manager reviews it.
class VisitDetail {
  const VisitDetail({
    required this.id,
    required this.status,
    required this.outlet,
    required this.agent,
    required this.checkinTs,
    required this.submittedAtClient,
    required this.geofencePass,
    required this.distanceM,
    required this.score,
    required this.sections,
    required this.photoTotal,
    required this.photos,
    required this.riskScore,
    required this.signals,
    this.templateResponses = const [],
    this.pinDispute,
  });

  /// The reason behind a `geofencePass: false` (#386): the agent said the
  /// outlet's pin is wrong and started the visit outside the fence. Null on
  /// every visit that passed the fence, and on an older server.
  final VisitPinDispute? pinDispute;

  final String id;

  /// Answers to the client's audit template (#122). Empty for a client
  /// without one, or a visit where none were given.
  final List<VisitTemplateAnswers> templateResponses;

  /// `in_progress` | `submitted`.
  final String status;
  final VisitOutletRef outlet;
  final VisitAgentRef agent;

  /// Device clock at check-in.
  final DateTime checkinTs;

  /// Device clock at submit; null for a draft.
  final DateTime? submittedAtClient;
  final bool geofencePass;
  final double? distanceM;
  final VisitScore? score;
  final List<VisitSectionSummary> sections;
  final int photoTotal;
  final List<VisitPhotoRef> photos;
  final double riskScore;
  final List<FraudSignal> signals;

  bool get isDraft => status != 'submitted';

  /// Minutes from check-in to submit on the device clock, or null when it is
  /// not measurable (a draft, or the clock moved backwards).
  int? get dwellMinutes {
    final end = submittedAtClient;
    if (end == null) return null;
    final d = end.difference(checkinTs);
    return d.isNegative ? null : d.inMinutes;
  }

  factory VisitDetail.fromJson(Map<String, dynamic> json) {
    final geofence = json['geofence'] as Map<String, dynamic>? ?? const {};
    final photos = json['photos'] as Map<String, dynamic>? ?? const {};
    final fraud = json['fraud'] as Map<String, dynamic>? ?? const {};
    final submitted = json['submittedAtClient'] as String?;
    return VisitDetail(
      id: json['id'] as String,
      status: json['status'] as String,
      outlet: VisitOutletRef.fromJson(json['outlet'] as Map<String, dynamic>),
      agent: VisitAgentRef.fromJson(json['agent'] as Map<String, dynamic>),
      checkinTs: DateTime.parse(json['checkinTs'] as String),
      submittedAtClient: submitted == null ? null : DateTime.parse(submitted),
      geofencePass: geofence['pass'] as bool? ?? false,
      distanceM: (geofence['distanceM'] as num?)?.toDouble(),
      score: json['score'] == null
          ? null
          : VisitScore.fromJson(json['score'] as Map<String, dynamic>),
      sections: [
        for (final s in (json['sections'] as List? ?? const []))
          VisitSectionSummary.fromJson(s as Map<String, dynamic>),
      ],
      photoTotal: (photos['total'] as num?)?.toInt() ?? 0,
      photos: [
        for (final p in (photos['items'] as List? ?? const []))
          VisitPhotoRef.fromJson(p as Map<String, dynamic>),
      ],
      riskScore: (fraud['riskScore'] as num?)?.toDouble() ?? 0,
      signals: [
        for (final s in (fraud['signals'] as List? ?? const []))
          FraudSignal.fromJson(s as Map<String, dynamic>),
      ],
      templateResponses: [
        for (final r in (json['templateResponses'] as List? ?? const []))
          VisitTemplateAnswers.fromJson(r as Map<String, dynamic>),
      ],
      pinDispute: json['pinDispute'] is Map<String, dynamic>
          ? VisitPinDispute.fromJson(json['pinDispute'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// "The pin is wrong", as the visit carries it (#386).
class VisitPinDispute {
  const VisitPinDispute({
    required this.id,
    required this.distanceM,
    required this.status,
    this.note,
    this.resolvedByLabel,
  });

  final String id;

  /// Measured by the server from the agent's position to the pin as it read
  /// at the time — never a number the device supplied.
  final double distanceM;

  /// `open` | `applied` | `rejected`.
  final String status;
  final String? note;
  final String? resolvedByLabel;

  factory VisitPinDispute.fromJson(Map<String, dynamic> json) => VisitPinDispute(
    id: json['id'] as String,
    distanceM: (json['distanceM'] as num).toDouble(),
    status: json['status'] as String? ?? 'open',
    note: json['note'] as String?,
    resolvedByLabel: json['resolvedByLabel'] as String?,
  );
}

/// The visit does not exist, or belongs to another tenant: the server answers
/// both with 404, and so does the screen.
class VisitNotFoundException implements Exception {
  const VisitNotFoundException(this.visitId);
  final String visitId;

  @override
  String toString() => 'Visit $visitId not found';
}

abstract class VisitDetailRepository {
  Future<VisitDetail> fetch(String visitId);
}

class DioVisitDetailRepository implements VisitDetailRepository {
  /// Injectable for tests; defaults to the app's authed client.
  DioVisitDetailRepository({Dio? client}) : _client = client ?? api.dio;

  final Dio _client;

  @override
  Future<VisitDetail> fetch(String visitId) async {
    try {
      final response = await _client.get(
        '/visits/${Uri.encodeComponent(visitId)}',
      );
      return VisitDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw VisitNotFoundException(visitId);
      }
      rethrow;
    }
  }
}

final visitDetailRepositoryProvider = Provider<VisitDetailRepository>(
  (ref) => DioVisitDetailRepository(),
);

/// One visit's detail. Framework auto-retry is off, like [visitPhotosProvider]:
/// a 404 will not become a 200 by retrying, and a manager should see the
/// not-found or error state immediately rather than a spinner through a
/// backoff. The error arm's Retry is the recovery path.
final visitDetailProvider = FutureProvider.autoDispose
    .family<VisitDetail, String>(
      (ref, visitId) => ref.watch(visitDetailRepositoryProvider).fetch(visitId),
      retry: (_, _) => null,
    );
