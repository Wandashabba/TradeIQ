import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'assistant_events.dart';

/// One turn of the conversation as it goes back to the server.
class ChatHistoryEntry {
  const ChatHistoryEntry({required this.role, required this.content});

  /// `user` or `assistant`. The server rejects anything else.
  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// The transport for `POST /assistant/chat`.
///
/// **SSE over a POST, read with a stream response — not `EventSource`.** Two
/// reasons, and both are load-bearing: the request carries the message and the
/// history, which have no business in a URL where they would land in access
/// logs; and `EventSource` cannot set an `Authorization` header, which every
/// request in this app needs.
class AssistantRepository {
  const AssistantRepository();

  /// Stream one turn.
  ///
  /// The returned stream closes when the server ends the response. Cancelling
  /// the subscription aborts the request — which matters here in a way it does
  /// not elsewhere: every turn is a metered provider call, so a user who backs
  /// out of the screen should stop paying for the rest of it.
  Stream<AssistantEvent> chat({
    required String message,
    List<ChatHistoryEntry> history = const [],
    String? conversationId,
    CancelToken? cancelToken,
  }) async* {
    final response = await dio.post<ResponseBody>(
      '/assistant/chat',
      data: {
        'message': message,
        // Absent on the first turn — the server mints one and announces it. Sent
        // on every turn after that, which is what keeps this conversation's
        // artifacts findable: without it the server opens a fresh conversation
        // each turn, and both the live-artifact manifest and the params-change
        // note quietly have nothing to report.
        if (conversationId != null) 'conversationId': conversationId,
        if (history.isNotEmpty)
          'history': history.map((entry) => entry.toJson()).toList(),
      },
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        // The default receive timeout applies between chunks, which is right
        // for a normal download and wrong for this: a model thinking for a
        // while sends nothing, and being cut off mid-thought looks like a
        // crash. The server bounds the turn; the client should not race it.
        receiveTimeout: Duration.zero,
      ),
    );

    final body = response.data;
    if (body == null) {
      yield const ErrorEvent(
        code: 'empty_response',
        message: 'The assistant did not respond. Please try again.',
      );
      return;
    }

    final parser = SseParser();
    // `utf8.decoder` rather than decoding each chunk on its own: a multi-byte
    // character can straddle a chunk boundary, and decoding per chunk turns an
    // outlet name with an accent into a replacement character.
    final decoded = body.stream
        .cast<List<int>>()
        .transform<String>(utf8.decoder);

    await for (final chunk in decoded) {
      for (final event in parser.add(chunk)) {
        yield event;
      }
    }
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => const AssistantRepository(),
);
