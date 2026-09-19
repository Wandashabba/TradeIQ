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
    this.errorCode,
    this.notice,
    this.streaming = false,
    this.stopped = false,
    this.askedAt,
  });

  final ChatRole role;
  final String text;
  final List<ChatArtifact> artifacts;
  final List<ToolActivity> tools;

  /// The live web pages the answer cited, from the turn's `sources` event.
  final List<WebSource> sources;

  /// A user-safe message from the server. Rendered instead of prose, not
  /// alongside it — a half-answer followed by an error reads as a bug.
  ///
  /// **Already sanitised**: see [sanitiseAssistantError]. The old build
  /// rendered the wire's string verbatim on the strength of a prose comment
  /// saying the server guaranteed it was safe, which is the exact path by
  /// which a 500's exception text reaches a customer's screenshot.
  final String? error;

  /// The wire's `code`, for the block's diagnostic line. `unknown` is not
  /// shown — it is not a diagnostic, it is the absence of one.
  final String? errorCode;

  /// The turn ran out of lookups or time (#410). Rendered as a component
  /// below the answer, never as prose in the model's own voice.
  final NoticeEvent? notice;

  final bool streaming;

  /// The manager pressed Stop. Not an error: the partial answer stays exactly
  /// as written and one line says it was stopped.
  final bool stopped;

  /// When the question was asked. The history sheet's left column, and the
  /// only thing on this surface that needs a wall clock.
  final DateTime? askedAt;

  ChatMessage copyWith({
    String? text,
    List<ChatArtifact>? artifacts,
    List<ToolActivity>? tools,
    List<WebSource>? sources,
    String? error,
    String? errorCode,
    NoticeEvent? notice,
    bool? streaming,
    bool? stopped,
  }) =>
      ChatMessage(
        role: role,
        text: text ?? this.text,
        artifacts: artifacts ?? this.artifacts,
        tools: tools ?? this.tools,
        sources: sources ?? this.sources,
        error: error ?? this.error,
        errorCode: errorCode ?? this.errorCode,
        notice: notice ?? this.notice,
        streaming: streaming ?? this.streaming,
        stopped: stopped ?? this.stopped,
        askedAt: askedAt,
      );
}

/// What the server appends to an answer a budget cut short.
///
/// Shipped on both sides — `BUDGET_NOTICE` in `orchestrator.ts`. The client
/// lifts it out of the prose so the fact is rendered as the product
/// explaining itself rather than as the assistant apologising in a trailing
/// paragraph below its own follow-ups fence.
const String budgetNoticeProse =
    'I reached the limit on how many lookups I can make for one question, so '
    'this answer may be incomplete. Ask a narrower follow-up to go further.';

/// [text] with the server's budget sentence removed.
///
/// A no-op when the constant has drifted, which is the point: the notice
/// block is an upgrade on a fallback and never a dependency. If the strings
/// stop matching, the sentence stays in the prose and nothing breaks.
String stripBudgetNotice(String text) {
  final at = text.indexOf(budgetNoticeProse);
  if (at == -1) return text;
  final without =
      text.substring(0, at) + text.substring(at + budgetNoticeProse.length);
  return without.trimRight();
}

/// The most of a server error message that reaches a screen.
const int assistantErrorMessageCap = 160;

/// What is rendered in place of a message that cannot be trusted on a screen.
const String assistantErrorFallback = 'Something went wrong on our side.';

/// A server error message, made safe to draw.
///
/// Newlines collapse to spaces; anything over [assistantErrorMessageCap]
/// characters, carrying markup or angle brackets, or shaped like a stack
/// trace is replaced wholesale and the code row carries the diagnostic
/// instead. A guarantee written in a prose comment is not a guarantee.
String sanitiseAssistantError(String raw) {
  final flat = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return assistantErrorFallback;
  if (flat.length > assistantErrorMessageCap) return assistantErrorFallback;
  if (flat.contains('<') || flat.contains('>')) return assistantErrorFallback;
  // `at Object.foo (/srv/app.js:12:9)`, `Error: ECONNREFUSED`, `#0 main`.
  if (RegExp(r'(^|\s)(at\s+\S+\s*\(|#\d+\s|[A-Za-z]+Error:|Exception:)')
      .hasMatch(flat)) {
    return assistantErrorFallback;
  }
  if (flat.contains('\\') || RegExp(r'/[\w.-]+/[\w.-]+').hasMatch(flat)) {
    return assistantErrorFallback;
  }
  return flat;
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

  /// Completes when the live turn ends, however it ends. Held so that Stop
  /// and leaving the screen both release the `await` inside [send] — a
  /// cancelled subscription fires neither `onDone` nor `onError`, so without
  /// this the future a caller awaited would never complete.
  Completer<void>? _turn;
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
        ChatMessage(
          role: ChatRole.user,
          text: trimmed,
          askedAt: ref.read(assistantClockProvider)(),
        ),
        const ChatMessage(role: ChatRole.assistant, text: '', streaming: true),
      ],
      sending: true,
    );

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    final completer = Completer<void>();
    _turn = completer;
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
      case NoticeEvent():
        // The same fact twice on the wire — once as prose for older builds,
        // once as a code. This build takes the code and lifts the sentence
        // out of the text.
        messages[index] = current.copyWith(
          notice: event,
          text: stripBudgetNotice(current.text),
        );
      case ErrorEvent(:final code, :final message):
        messages[index] = current.copyWith(
          error: sanitiseAssistantError(message),
          errorCode: code == 'unknown' ? null : code,
          streaming: false,
        );
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
          stopped: _stopping,
          // A turn the manager stopped is not a failure and never takes the
          // error block: half an answer she asked to keep is worth more than
          // a message that erases it.
          error: !_stopping && last.text.isEmpty && last.error == null
              ? 'The assistant stopped responding. Please try again.'
              : null,
        );
      }
    }
    state = state.copyWith(messages: messages, sending: false);
    _cancelToken = null;
    _subscription = null;
    _stopping = false;
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  /// Whether the live turn is being cancelled by the manager rather than by
  /// the network or by leaving the screen.
  bool _stopping = false;

  /// STOP. Keeps everything already written and stops paying for the rest.
  ///
  /// Distinct from [cancel], which is what leaving the screen does: that turn
  /// is simply not there when she comes back, because a transcript is a
  /// session. A stopped turn stays, with its partial answer and one line
  /// saying it was stopped.
  void stop() {
    if (!state.sending) return;
    _stopping = true;
    _subscription?.cancel();
    _subscription = null;
    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel('stopped by the manager');
    }
    _cancelToken = null;
    _finish();
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel('left the conversation');
    }
    _cancelToken = null;
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
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
