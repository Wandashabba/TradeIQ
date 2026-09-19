import 'dart:convert';

/// The SSE vocabulary `POST /assistant/chat` streams.
///
/// **Unknown event types are ignored, never treated as errors.** That is a
/// contract the server relies on: it lets the backend add an event without a
/// lockstep app release, and this file is where the app holds up its end. A
/// client that threw on an unrecognised name would turn every additive server
/// change into a forced update.
sealed class AssistantEvent {
  const AssistantEvent();

  /// Parse one `event:`/`data:` frame.
  ///
  /// Returns `null` for anything we do not recognise, or for a frame whose
  /// payload will not parse — a malformed frame mid-stream should drop that
  /// frame, not kill a turn the user is watching.
  static AssistantEvent? parse(String name, String rawData) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is! Map<String, dynamic>) return null;
      data = decoded;
    } on FormatException {
      return null;
    }

    // Every read is type-TESTED, never cast. `as String?` throws on a value
    // that is present but the wrong type, and a throw here kills a turn the
    // user is watching over a field they do not care about. Wrong type is
    // treated exactly like absent.
    String str(String key, String fallback) {
      final value = data[key];
      return value is String ? value : fallback;
    }

    int intOf(String key) {
      final value = data[key];
      return value is num ? value.toInt() : 0;
    }

    switch (name) {
      case 'conversation':
        final id = data['id'];
        return id is String ? ConversationEvent(id) : null;
      case 'token':
        final text = data['text'];
        return text is String ? TokenEvent(text) : null;
      case 'tool_start':
        return ToolStartEvent(
          name: str('name', ''),
          pillar: str('pillar', 'unknown'),
        );
      case 'tool_end':
        final ok = data['ok'];
        return ToolEndEvent(name: str('name', ''), ok: ok is bool && ok);
      case 'artifact':
        final id = data['id'];
        final type = data['type'];
        // No id means it cannot be patched in place, and no type means nothing
        // can draw it. Either way there is nothing useful to hold.
        if (id is! String || type is! String) return null;
        return ArtifactEvent(
          id: id,
          type: type,
          params: data['params'],
          data: data['data'],
        );
      case 'sources':
        return SourcesEvent(WebSource.listFrom(data['sources']));
      case 'notice':
        // #410. The same fact the prose already carries, without the English:
        // an answer that ran out of lookups, time, or had its tool calls
        // refused. A code this build has never heard of still renders — the
        // component's default sentence is the one the server also wrote into
        // the prose, so an unknown reason degrades to a true statement rather
        // than to nothing.
        return NoticeEvent(
          code: AnswerNoticeCode.parse(data['code']),
          message: str('message', ''),
        );
      case 'usage':
        final cost = data['costCents'];
        return UsageEvent(
          inputTokens: intOf('inputTokens'),
          outputTokens: intOf('outputTokens'),
          cacheReadTokens: intOf('cacheReadTokens'),
          costCents: cost is num ? cost.toDouble() : 0,
        );
      case 'error':
        return ErrorEvent(
          code: str('code', 'unknown'),
          // The server guarantees this is user-safe. It is rendered directly.
          message: str('message', 'Something went wrong.'),
        );
      case 'done':
        return const DoneEvent();
      default:
        return null;
    }
  }
}

/// Which conversation this turn belongs to.
///
/// The server mints one on a turn that arrives without an id and announces it
/// first, before anything can fail. Echoing it back on the next turn is what
/// makes artifacts findable across turns — it is what the live-artifact
/// manifest and the params-change note are both keyed by, so a client that
/// drops it silently gets a brand-new conversation every turn and neither ever
/// fires.
class ConversationEvent extends AssistantEvent {
  const ConversationEvent(this.id);
  final String id;
}

class TokenEvent extends AssistantEvent {
  const TokenEvent(this.text);
  final String text;
}

class ToolStartEvent extends AssistantEvent {
  const ToolStartEvent({required this.name, required this.pillar});
  final String name;
  final String pillar;
}

class ToolEndEvent extends AssistantEvent {
  const ToolEndEvent({required this.name, required this.ok});
  final String name;
  final bool ok;
}

/// A thing to draw.
///
/// `data` is the raw tool result and `params` is the validated spec input. Both
/// are `dynamic` because the catalog is open-ended from the client's side: the
/// registry decides what a given `type` means, and an unrecognised one falls
/// back to text rather than being parsed here into a shape it may not have.
class ArtifactEvent extends AssistantEvent {
  const ArtifactEvent({
    required this.id,
    required this.type,
    required this.params,
    required this.data,
  });
  final String id;
  final String type;
  final dynamic params;
  final dynamic data;
}

/// One live web page the answer drew on, as `webSearch` cited it.
///
/// Everything here came off the open web, so it is untrusted by construction:
/// [title] and [snippet] are plain text — never markdown, never a link — and
/// [url] is only ever http/https. The server already guarantees both; the
/// client holds the line again because a tap on this opens a browser.
class WebSource {
  const WebSource({
    required this.title,
    required this.url,
    required this.domain,
    required this.retrievedAt,
    this.pageAge,
    this.snippet,
  });

  final String title;
  final Uri url;

  /// Hostname without `www.`.
  final String domain;

  /// Free text from the search index ("3 days ago", "April 30, 2025").
  final String? pageAge;

  /// When the server fetched the result. Null when absent or unparseable.
  final DateTime? retrievedAt;

  /// ≤ 200 chars, sanitised server-side. Plain text only.
  final String? snippet;

  /// The most sources a turn carries; anything beyond is dropped.
  static const maxSources = 10;

  /// Whether [uri] is safe to hand to a browser: http or https with a host.
  static bool isWebUri(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

  /// A source from one wire entry, or null when it cannot be cited safely.
  static WebSource? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final title = raw['title'];
    final url = raw['url'];
    if (title is! String || title.trim().isEmpty || url is! String) {
      return null;
    }
    final uri = Uri.tryParse(url.trim());
    // javascript:, data:, ftp:, file: and scheme-less strings are all dropped
    // here, whatever the server said.
    if (uri == null || !isWebUri(uri)) return null;

    final domain = raw['domain'];
    final pageAge = raw['pageAge'];
    final retrievedAt = raw['retrievedAt'];
    final snippet = raw['snippet'];
    return WebSource(
      title: title.trim(),
      url: uri,
      domain: domain is String && domain.trim().isNotEmpty
          ? domain.trim()
          : _hostOf(uri),
      pageAge: pageAge is String && pageAge.trim().isNotEmpty
          ? pageAge.trim()
          : null,
      retrievedAt:
          retrievedAt is String ? DateTime.tryParse(retrievedAt) : null,
      snippet: snippet is String && snippet.trim().isNotEmpty
          ? snippet.trim()
          : null,
    );
  }

  /// Every readable entry of the `sources` array, in order, capped at
  /// [maxSources]. A malformed entry is skipped, not fatal.
  static List<WebSource> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <WebSource>[];
    for (final entry in raw) {
      final source = tryParse(entry);
      if (source != null) out.add(source);
      if (out.length == maxSources) break;
    }
    return out;
  }

  static String _hostOf(Uri uri) =>
      uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
}

/// The live web pages this turn's answer cited. At most one per turn, after
/// the answer's tokens.
class SourcesEvent extends AssistantEvent {
  const SourcesEvent(this.sources);
  final List<WebSource> sources;
}

/// Why an answer stopped short of everything it was asked (#410).
///
/// A closed vocabulary on the wire, and a closed enum here — with
/// [AnswerNoticeCode.unknown] for the code a later server sends that this
/// build has not been taught. An unknown reason is still a real notice: the
/// answer really did stop short, and saying so with the general sentence is
/// more honest than saying nothing because the reason did not parse.
enum AnswerNoticeCode {
  /// The lookup (round or cost) budget ran out.
  lookupBudget,

  /// The 120s wall-clock budget ran out.
  timeBudget,

  /// The provider ignored `toolChoice: 'none'` and its calls were not run.
  toolCallRefused,

  /// A code this build does not know.
  unknown;

  static AnswerNoticeCode parse(dynamic raw) => switch (raw) {
    'lookup_budget' => AnswerNoticeCode.lookupBudget,
    'time_budget' => AnswerNoticeCode.timeBudget,
    'tool_call_refused' => AnswerNoticeCode.toolCallRefused,
    _ => AnswerNoticeCode.unknown,
  };
}

/// The turn ran out of something. At most one per turn, after the sources.
class NoticeEvent extends AssistantEvent {
  const NoticeEvent({required this.code, required this.message});

  final AnswerNoticeCode code;

  /// The server's own English sentence. Held as a fallback only: the client
  /// renders its own localised text for every code it knows, because the
  /// wire's copy is not translated and this notice is read by managers who
  /// set their phone to Afrikaans.
  final String message;
}

class UsageEvent extends AssistantEvent {
  const UsageEvent({
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.costCents,
  });
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final double costCents;
}

class ErrorEvent extends AssistantEvent {
  const ErrorEvent({required this.code, required this.message});
  final String code;
  final String message;
}

class DoneEvent extends AssistantEvent {
  const DoneEvent();
}

/// Turns a byte stream into `AssistantEvent`s.
///
/// Kept separate from the transport so it can be tested without a socket — SSE
/// framing bugs are the kind that only show up under chunk boundaries a real
/// server happens to produce, and those are impossible to provoke on demand
/// against a live backend.
class SseParser {
  final StringBuffer _buffer = StringBuffer();

  /// Feed one decoded chunk. Chunks split anywhere — mid-frame, mid-word, even
  /// between the `event:` and `data:` lines of the same frame — so nothing may
  /// assume a chunk is a whole frame.
  List<AssistantEvent> add(String chunk) {
    _buffer.write(chunk);
    final content = _buffer.toString();

    // A frame ends at a blank line. Anything after the last one is a partial
    // frame and stays buffered for the next chunk.
    final lastBreak = content.lastIndexOf('\n\n');
    if (lastBreak == -1) return const [];

    final complete = content.substring(0, lastBreak);
    _buffer
      ..clear()
      ..write(content.substring(lastBreak + 2));

    final events = <AssistantEvent>[];
    for (final frame in complete.split('\n\n')) {
      final event = _parseFrame(frame);
      if (event != null) events.add(event);
    }
    return events;
  }

  static AssistantEvent? _parseFrame(String frame) {
    String? name;
    String? data;
    for (final line in frame.split('\n')) {
      if (line.startsWith('event: ')) {
        name = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        data = line.substring(6);
      }
    }
    if (name == null || data == null) return null;
    return AssistantEvent.parse(name, data);
  }
}
