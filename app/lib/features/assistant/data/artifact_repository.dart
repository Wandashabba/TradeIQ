import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// One artifact as the server holds it — the Expanded mode's whole data source.
///
/// **[params] are the TOOL's arguments, not the view spec's.** The artifact row
/// stores what to re-run, so `refine` validates against the tool's own Zod
/// schema — the single contract the model and these filter controls both write
/// through. It is a near-miss for the spec params the chat stream carries
/// (`agent_scorecard` streams `agentId`; the row holds `agent`), and confusing
/// the two produces a 400 that reads like a bug in the filter.
///
/// [data] is whatever the tool returned this second. Nothing is cached
/// server-side: reopening a week-old artifact re-runs its tool through a roster
/// built for whoever is asking now, which is why there is no stale copy of
/// tenant data anywhere in this feature.
class ArtifactDetail {
  const ArtifactDetail({
    required this.id,
    required this.type,
    required this.toolName,
    required this.params,
    required this.data,
    required this.canUndo,
  });

  final String id;

  /// The view-spec type from the closed catalog — `trend_chart`, `outlet_map`, …
  final String type;
  final String toolName;
  final Map<String, dynamic> params;
  final dynamic data;

  /// Whether the server has a previous params set to step back to. The control
  /// is hidden rather than disabled when there is nothing behind it.
  final bool canUndo;

  factory ArtifactDetail.fromJson(Map<String, dynamic> json) {
    // Type-tested, never cast. This screen is reached by URL, so it can be
    // pointed at a response shape an older build did not expect, and a throw
    // here would render a crash instead of an artifact.
    final params = json['params'];
    final canUndo = json['canUndo'];
    return ArtifactDetail(
      id: json['id'] is String ? json['id'] as String : '',
      type: json['type'] is String ? json['type'] as String : '',
      toolName: json['toolName'] is String ? json['toolName'] as String : '',
      params: params is Map<String, dynamic> ? params : const {},
      data: json['data'],
      canUndo: canUndo is bool && canUndo,
    );
  }
}

/// A refusal from the server, carrying the message it wrote.
///
/// The server's `error` string is user-safe by contract — it is the same one
/// the chat stream renders verbatim — so it is shown rather than replaced with
/// "something went wrong", which tells the user nothing about which filter it
/// disliked.
class ArtifactRequestException implements Exception {
  const ArtifactRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `/assistant/artifacts/:id` — read, refine, undo.
///
/// **None of these calls the model.** A filter change is a re-query: it re-runs
/// the same tool closure with the same RBAC, so it costs a database read rather
/// than a paid turn, and a hand-edited payload cannot widen scope because scope
/// was never a parameter.
class ArtifactRepository {
  const ArtifactRepository();

  Future<ArtifactDetail> fetch(String id, {CancelToken? cancelToken}) => _read(
    () => dio.get<Map<String, dynamic>>(
      '/assistant/artifacts/$id',
      cancelToken: cancelToken,
    ),
  );

  Future<ArtifactDetail> refine(
    String id,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) => _read(
    () => dio.post<Map<String, dynamic>>(
      '/assistant/artifacts/$id/refine',
      data: {'params': params},
      cancelToken: cancelToken,
    ),
  );

  Future<ArtifactDetail> undo(String id, {CancelToken? cancelToken}) => _read(
    () => dio.post<Map<String, dynamic>>(
      '/assistant/artifacts/$id/undo',
      cancelToken: cancelToken,
    ),
  );

  Future<ArtifactDetail> _read(
    Future<Response<Map<String, dynamic>>> Function() send,
  ) async {
    try {
      final response = await send();
      final body = response.data;
      if (body == null) {
        throw const ArtifactRequestException('The server returned nothing.');
      }
      return ArtifactDetail.fromJson(body);
    } on DioException catch (err) {
      throw ArtifactRequestException(_messageFrom(err));
    }
  }

  static String _messageFrom(DioException err) {
    final body = err.response?.data;
    if (body is Map && body['error'] is String) return body['error'] as String;
    if (err.response?.statusCode == 404) {
      // Deliberately the same answer the server gives for "not yours" — see
      // ArtifactNotFoundError. Nothing here should un-blur that.
      return 'That view is no longer available.';
    }
    return 'Could not reach the server. Check your connection.';
  }
}

final artifactRepositoryProvider = Provider<ArtifactRepository>(
  (ref) => const ArtifactRepository(),
);
