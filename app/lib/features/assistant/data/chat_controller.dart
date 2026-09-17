import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_events.dart';
import 'assistant_repository.dart';

/// One artifact the assistant produced, as the transcript holds it.
class ChatArtifact {
  const ChatArtifact({
    required this.id,
    required this.type,
    required this.params,
    required this.data,
    this.toolCall,
  });

  final String id;
  final String type;
  final dynamic params;
  final dynamic data;

  /// Which tool call in the turn this artifact followed — an index into
  /// [ChatMessage.tools] — or null when none preceded it.
  ///
  /// The wire carries no call id on an artifact, but a tool's events arrive
  /// together (`tool_start`, `tool_end`, its card, then its `stat_tiles` /
  /// `ranked_bars`), so "the most recent call" is exact. It is what lets a
  /// tool's tiles stand in for that same tool's `pillar_metrics` card without
  /// parsing id formats.
  final int? toolCall;
}

/// What a tool did, for the working-steps timeline.
class ToolActivity {
  const ToolActivity({
    required this.name,
    required this.pillar,
    this.ok,
    this.startedAt,
    this.endedAt,
  });

  final String name;
  final String pillar;

  /// `null` while running. Set when the tool finishes.
  final bool? ok;

  /// When this client saw `tool_start` and `tool_end`. **Client-measured**:
  /// the wire carries no timings, and what a manager waited is what the
  /// timeline should say — network included.
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// How long the step took, once it has finished.
  Duration? get duration => startedAt == null || endedAt == null
      ? null
      : endedAt!.difference(startedAt!);

  ToolActivity finished(bool succeeded, {DateTime? at}) => ToolActivity(
        name: name,
        pillar: pillar,
        ok: succeeded,
        startedAt: startedAt,
        endedAt: at,
      );
}

/// The clock the timeline measures against. A provider so a test can step it.
final assistantClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.artifacts = const [],
    this.tools = const [],
    this.sources = const [],
    this.error,
    this.streaming = false,
  });

  final ChatRole role;
  final String text;
  final List<ChatArtifact> artifacts;
  final List<ToolActivity> tools;

  /// The live web pages the answer cited, from the turn's `sources` event.
  final List<WebSource> sources;

  /// A user-safe message from the server. Rendered instead of prose, not
  /// alongside it — a half-answer followed by an error reads as a bug.
  final String? error;
  final bool streaming;

  ChatMessage copyWith({
    String? text,
    List<ChatArtifact>? artifacts,
    List<ToolActivity>? tools,
    List<WebSource>? sources,
    String? error,
    bool? streaming,
  }) =>
      ChatMessage(
        role: role,
        text: text ?? this.text,
        artifacts: artifacts ?? this.artifacts,
        tools: tools ?? this.tools,
        sources: sources ?? this.sources,
        error: error ?? this.error,
        streaming: streaming ?? this.streaming,
      );
}

class ChatState {
  const ChatState({this.messages = const [], this.sending = false});

  final List<ChatMessage> messages;
  final bool sending;

  ChatState copyWith({List<ChatMessage>? messages, bool? sending}) => ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

/// Drives one conversation.
///
/// History is held here rather than on the server for Phase 0: the backend is
/// stateless per turn and replays what it is given, which keeps the turn
/// contract simple while there is nothing to persist. Phase 2 introduces real
/// conversation rows, and this is the seam that changes.
class ChatController extends Notifier<ChatState> {
  CancelToken? _cancelToken;
  StreamSubscription<AssistantEvent>? _subscription;

  /// The server's id for this conversation, learned from the first turn.
  ///
  /// Held here rather than in [ChatState] because nothing renders it — it is
  /// transport state. It is what makes an artifact created three turns ago
  /// still refinable by name, and what lets the server tell the model that the
  /// user has since moved a filter.
  String? _conversationId;

  /// Exposed for the artifact screen and for tests. Null until the first turn.
  String? get conversationId => _conversationId;

  @override
  ChatState build() {
    // A user who leaves the screen mid-turn should stop paying for the rest of
    // it. Every turn is a metered provider call, so this is a cost path, not
    // just a tidiness one.
    ref.onDispose(cancel);
    return const ChatState();
  }

  /// How many prior turns go back with the next message.
  ///
  /// History is replayed on every turn, so its length is a direct multiplier on
  /// cost and latency. The server caps it at 40 and rejects more; stopping
  /// short of that here means a long conversation degrades by forgetting its
  /// oldest turns rather than by failing outright.
  static const historyLimit = 20;

  Future<void> send(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.sending) return;

    final history = _history();

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, text: trimmed),
        const ChatMessage(role: ChatRole.assistant, text: '', streaming: true),
      ],
      sending: true,
    );

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    final completer = Completer<void>();
    _subscription = ref
        .read(assistantRepositoryProvider)
        .chat(
          message: trimmed,
          history: history,
          conversationId: _conversationId,
          cancelToken: cancelToken,
        )
        .listen(
          _apply,
          onError: (Object err) {
            // A cancelled request is the user's own doing, not a failure to
            // report back to them.
            if (err is DioException && CancelToken.isCancel(err)) {
              _finish();
            } else {
              _apply(const ErrorEvent(
                code: 'network',
                message: 'Could not reach the assistant. Check your connection.',
              ));
              _finish();
            }
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            _finish();
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    await completer.future;
  }

  List<ChatHistoryEntry> _history() {
    final entries = <ChatHistoryEntry>[];
    for (final message in state.messages) {
      // An errored turn is deliberately excluded: replaying "Could not reach
      // the assistant" as though the model had said it teaches it that such a
      // reply is in character.
      if (message.error != null || message.text.isEmpty) continue;
      entries.add(ChatHistoryEntry(
        role: message.role == ChatRole.user ? 'user' : 'assistant',
        content: message.text,
      ));
    }
    if (entries.length <= historyLimit) return entries;
    return entries.sublist(entries.length - historyLimit);
  }

  void _apply(AssistantEvent event) {
    final messages = [...state.messages];
    if (messages.isEmpty) return;
    final index = messages.length - 1;
    final current = messages[index];

    switch (event) {
      case ConversationEvent(:final id):
        // Transport state, not transcript state — recorded and not rendered.
        // Returning early keeps it out of the message rebuild below, which has
        // nothing to change.
        _conversationId = id;
        return;
      case TokenEvent(:final text):
        messages[index] = current.copyWith(text: current.text + text);
      case ToolStartEvent(:final name, :final pillar):
        messages[index] = current.copyWith(
          tools: [
            ...current.tools,
            ToolActivity(
              name: name,
              pillar: pillar,
              startedAt: ref.read(assistantClockProvider)(),
            ),
          ],
        );
      case ToolEndEvent(:final name, :final ok):
        final tools = [...current.tools];
        // **FIFO: the oldest unresolved call of this name.**
        //
        // `tool_end` carries no call id — that is the wire protocol, not an
        // oversight — so matching a result to a chip is inherently a heuristic
        // when one turn calls the same tool twice. It does not bite today,
        // because the orchestrator emits each pair strictly sequentially
        // (start, run, end, then the next call), so there is never more than
        // one unresolved chip of a given name. FIFO is the convention to hold
        // if that ever changes to run tools concurrently.
        final at = tools.indexWhere((t) => t.name == name && t.ok == null);
        if (at != -1) {
          tools[at] = tools[at].finished(
            ok,
            at: ref.read(assistantClockProvider)(),
          );
        }
        messages[index] = current.copyWith(tools: tools);
      case ArtifactEvent(:final id, :final type, :final params, :final data):
        final artifacts = [...current.artifacts];
        // Same id patches in place. Appending instead is what turns a chat into
        // a graveyard of near-identical cards.
        final at = artifacts.indexWhere((a) => a.id == id);
        final artifact = ChatArtifact(
          id: id,
          type: type,
          params: params,
          data: data,
          // A patch keeps the call the card first came from.
          toolCall: at != -1
              ? artifacts[at].toolCall
              : (current.tools.isEmpty ? null : current.tools.length - 1),
        );
        if (at == -1) {
          artifacts.add(artifact);
        } else {
          artifacts[at] = artifact;
        }
        messages[index] = current.copyWith(artifacts: artifacts);
      case SourcesEvent(:final sources):
        // One per turn by contract; a repeat replaces rather than duplicates.
        messages[index] = current.copyWith(sources: sources);
      case ErrorEvent(:final message):
        messages[index] = current.copyWith(error: message, streaming: false);
      case UsageEvent():
        // Nothing to render. The cost dashboard reads this server-side; the
        // manager asking about stock does not need a token count.
        return;
      case DoneEvent():
        messages[index] = current.copyWith(streaming: false);
    }

    state = state.copyWith(messages: messages);
  }

  void _finish() {
    final messages = [...state.messages];
    if (messages.isNotEmpty) {
      final index = messages.length - 1;
      final last = messages[index];
      // A stream that ended without a `done` frame — a dropped connection —
      // must still clear the streaming flag, or the caret blinks forever on a
      // turn that is never coming back.
      if (last.streaming) {
        messages[index] = last.copyWith(
          streaming: false,
          error: last.text.isEmpty && last.error == null
              ? 'The assistant stopped responding. Please try again.'
              : null,
        );
      }
    }
    state = state.copyWith(messages: messages, sending: false);
    _cancelToken = null;
    _subscription = null;
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel('left the conversation');
    }
    _cancelToken = null;
  }

  void clear() {
    cancel();
    // A cleared screen is a new conversation. Keeping the id would carry the
    // old one's artifacts into a thread the user believes is empty, and the
    // manifest would offer the model views that are no longer on screen.
    _conversationId = null;
    state = const ChatState();
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
