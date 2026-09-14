import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/person_label.dart';
import '../../../core/network/api_client.dart';

/// One candidate agent returned by POST /dispatch, ranked for an outlet.
class DispatchCandidate {
  const DispatchCandidate({
    required this.agentId,
    required this.email,
    required this.inTerritory,
    this.distanceM,
    this.displayName,
  });
  final String agentId;
  final String email;
  final double? distanceM;
  final bool inTerritory;

  /// What people call this agent. Null for agents never given a name.
  final String? displayName;

  /// The name when there is one, otherwise the email.
  String get label => personLabel(displayName, email);

  factory DispatchCandidate.fromJson(Map<String, dynamic> json) =>
      DispatchCandidate(
        agentId: json['agentId'] as String,
        email: json['email'] as String,
        distanceM: (json['distanceM'] as num?)?.toDouble(),
        inTerritory: json['inTerritory'] as bool? ?? false,
        displayName: json['displayName'] as String?,
      );
}

/// The result of ranking agents for an outlet via POST /dispatch.
class DispatchResult {
  const DispatchResult({
    required this.candidates,
    this.recommended,
  });
  final List<DispatchCandidate> candidates;
  final DispatchCandidate? recommended;

  factory DispatchResult.fromJson(Map<String, dynamic> json) {
    final recommended = json['recommended'];
    return DispatchResult(
      candidates: (json['candidates'] as List)
          .map((e) => DispatchCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommended: recommended == null
          ? null
          : DispatchCandidate.fromJson(recommended as Map<String, dynamic>),
    );
  }
}

abstract class DispatchRepository {
  Future<DispatchResult> dispatch(String outletId);
}

class DioDispatchRepository implements DispatchRepository {
  @override
  Future<DispatchResult> dispatch(String outletId) async {
    final response = await dio.post('/dispatch', data: {'outletId': outletId});
    return DispatchResult.fromJson(response.data as Map<String, dynamic>);
  }
}

final dispatchRepositoryProvider =
    Provider<DispatchRepository>((ref) => DioDispatchRepository());

final dispatchResultProvider =
    FutureProvider.family<DispatchResult, String>((ref, outletId) {
  return ref.read(dispatchRepositoryProvider).dispatch(outletId);
});
