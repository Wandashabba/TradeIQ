/// The assistant's answer, parsed from streamed text into blocks the chat can
/// draw.
///
/// **Why not a markdown package.** `flutter_markdown` is discontinued, and its
/// maintained fork parses a *finished* document. This text is not finished: it
/// arrives token by token, so at any moment it can end half-way through `**`,
/// a list marker or a fence. The subset the model is asked to write is small
/// (paragraphs, `###`/`####` headings, bullet and numbered lists, blockquotes,
/// bold, italic, inline code and one fenced `followups` block), and owning its
/// parser is what lets three conventions ride on top of it:
///
/// * the **first paragraph is the headline**;
/// * a **blockquote is an insight callout**, whose bold first line is its
///   kicker;
/// * a ` ```followups ` fence becomes **chips**, and is hidden while unclosed,
///   so raw backticks never flash on screen.
///
/// Pure Dart and total: every input, however truncated, parses to something,
/// and nothing here throws.
library;

enum AnswerBlockKind { paragraph, heading, bullets, numbered, quote, code }

/// One block of prose.
class AnswerBlock {
  const AnswerBlock._({
    required this.kind,
    this.text = '',
    this.items = const [],
    this.level = 0,
    this.kicker,
  });

  const AnswerBlock.paragraph(String text)
      : this._(kind: AnswerBlockKind.paragraph, text: text);
  const AnswerBlock.heading(String text, int level)
      : this._(kind: AnswerBlockKind.heading, text: text, level: level);
  const AnswerBlock.bullets(List<String> items)
      : this._(kind: AnswerBlockKind.bullets, items: items);
  const AnswerBlock.numbered(List<String> items)
      : this._(kind: AnswerBlockKind.numbered, items: items);
  const AnswerBlock.quote(String text, {String? kicker})
      : this._(kind: AnswerBlockKind.quote, text: text, kicker: kicker);
  const AnswerBlock.code(String text)
      : this._(kind: AnswerBlockKind.code, text: text);

  final AnswerBlockKind kind;

  /// Paragraph, heading, quote body or code text — still carrying its inline
  /// markers, which [parseInline] resolves.
  final String text;

  /// List items, for [AnswerBlockKind.bullets] and [AnswerBlockKind.numbered].
  final List<String> items;

  /// Heading depth, 1–6.
  final int level;

  /// A callout's bold first line, markers removed.
  final String? kicker;

  @override
  String toString() => 'AnswerBlock($kind, text: $text, items: $items, '
      'level: $level, kicker: $kicker)';
}

class ParsedAnswer {
  const ParsedAnswer({
    required this.blocks,
    required this.followUps,
    required this.hasMarkdown,
  });

  final List<AnswerBlock> blocks;

  /// At most [maxFollowUps] next questions, from a closed ` ```followups `
  /// fence (or, once the turn is over, an unclosed one).
  final List<String> followUps;

  /// Whether anything in the text used the answer conventions at all. A reply
  /// that did not is a plain reply, and renders exactly as replies always
  /// have.
  final bool hasMarkdown;

  /// The first block, when it is a paragraph short enough to be one.
  ///
  /// The length cap is what keeps an answer written **without** the headline
  /// convention looking right: a model that opens with a full explanatory
  /// paragraph (and bolds a word in it) must not have that paragraph set at
  /// headline size. A headline is one sentence a manager can take in at a
  /// glance; past [maxHeadlineLength] visible characters it is body text.
  AnswerBlock? get headline {
    if (blocks.isEmpty || blocks.first.kind != AnswerBlockKind.paragraph) {
      return null;
    }
    final visible = blocks.first.text.replaceAll(RegExp(r'[*_`]'), '');
    return visible.length <= maxHeadlineLength ? blocks.first : null;
  }
}

const maxFollowUps = 3;

/// The longest first paragraph still styled as a headline.
const maxHeadlineLength = 160;

final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _headingPartial = RegExp(r'^#{1,6}$');
final _bullet = RegExp(r'^\s*[-*+]\s+(.*)$');
final _bulletPartial = RegExp(r'^\s*[-*+]$');
final _numbered = RegExp(r'^\s*\d{1,3}[.)]\s+(.*)$');
final _numberedPartial = RegExp(r'^\s*\d{1,3}[.)]$');
final _quote = RegExp(r'^\s*>\s?(.*)$');
final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
final _fence = RegExp(r'^\s*```');
final _inlineMarker = RegExp(r'\*\*|__|`|(^|[^\w*])\*\S|(^|\W)_\S');

/// Parse [source] into blocks.
///
/// [streaming] says the text may still grow. While it is true, a construct
/// that has opened but not closed is **hidden** or **provisionally styled**
/// rather than shown raw; once false, an unclosed marker is taken at its word
/// and printed as the character it is.
ParsedAnswer parseAnswer(String source, {required bool streaming}) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <AnswerBlock>[];
  final followUps = <String>[];
  var hasMarkdown = false;

  final paragraph = <String>[];
  final quote = <String>[];
  var listKind = AnswerBlockKind.bullets;
  final list = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(AnswerBlock.paragraph(paragraph.join('\n')));
    paragraph.clear();
  }

  void flushList() {
    if (list.isEmpty) return;
    blocks.add(listKind == AnswerBlockKind.bullets
        ? AnswerBlock.bullets(List.of(list))
        : AnswerBlock.numbered(List.of(list)));
    list.clear();
  }

  void flushQuote() {
    if (quote.isEmpty) return;
    blocks.add(_quoteBlock(quote, streaming: streaming));
    quote.clear();
  }

  void flushAll() {
    flushParagraph();
    flushList();
    flushQuote();
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    // The final line of a stream still being written may be a construct's
    // first character or two. Showing `-` or `##` for a frame, then snapping
    // it into a list or heading, is the flicker this hides.
    final isTail = streaming && i == lines.length - 1;

    if (_fence.hasMatch(line)) {
      hasMarkdown = true;
      flushAll();
      final info = trimmed.substring(3).trim().toLowerCase();
      var close = -1;
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].trim() == '```') {
          close = j;
          break;
        }
      }
      final isFollowUps = info == 'followups';
      if (close == -1 && streaming) {
        // Unclosed and still arriving: everything from here is fence, and none
        // of it is ready to show.
        break;
      }
      final end = close == -1 ? lines.length : close;
      final body = lines.sublist(i + 1, end);
      if (isFollowUps) {
        for (final entry in body) {
          final question = entry.trim();
          if (question.isNotEmpty) followUps.add(question);
        }
      } else {
        blocks.add(AnswerBlock.code(body.join('\n')));
      }
      i = end;
      continue;
    }

    if (trimmed.isEmpty) {
      flushAll();
      continue;
    }

    if (isTail &&
        (trimmed == '`' ||
            trimmed == '``' ||
            trimmed == '>' ||
            _headingPartial.hasMatch(trimmed) ||
            _bulletPartial.hasMatch(line.trimRight()) ||
            _numberedPartial.hasMatch(line.trimRight()))) {
      hasMarkdown = true;
      break;
    }

    final quoteMatch = _quote.firstMatch(line);
    if (quoteMatch != null) {
      hasMarkdown = true;
      flushParagraph();
      flushList();
      quote.add(quoteMatch.group(1)!);
      continue;
    }
    flushQuote();

    if (_rule.hasMatch(line)) {
      hasMarkdown = true;
      flushAll();
      continue;
    }

    final headingMatch = _heading.firstMatch(trimmed);
    if (headingMatch != null) {
      hasMarkdown = true;
      flushAll();
      blocks.add(AnswerBlock.heading(
        headingMatch.group(2)!.trim(),
        headingMatch.group(1)!.length,
      ));
      continue;
    }

    final bulletMatch = _bullet.firstMatch(line);
    final numberedMatch = bulletMatch == null ? _numbered.firstMatch(line) : null;
    if (bulletMatch != null || numberedMatch != null) {
      hasMarkdown = true;
      flushParagraph();
      final kind = bulletMatch != null
          ? AnswerBlockKind.bullets
          : AnswerBlockKind.numbered;
      if (list.isNotEmpty && kind != listKind) flushList();
      listKind = kind;
      list.add((bulletMatch ?? numberedMatch)!.group(1)!);
      continue;
    }

    if (list.isNotEmpty && line.startsWith(RegExp(r'\s'))) {
      // An indented line under an item continues that item.
      list[list.length - 1] = '${list.last} $trimmed';
      continue;
    }
    flushList();
    paragraph.add(trimmed);
  }
  flushAll();

  if (!hasMarkdown) {
    hasMarkdown = _inlineMarker.hasMatch(source);
  }

  return ParsedAnswer(
    blocks: blocks,
    followUps: followUps.take(maxFollowUps).toList(growable: false),
    hasMarkdown: hasMarkdown,
  );
}

final _kickerLine = RegExp(r'^\s*\*\*(.+?)\*\*\s*:?\s*$');
final _kickerOpen = RegExp(r'^\s*\*\*([^*]*)$');

AnswerBlock _quoteBlock(List<String> lines, {required bool streaming}) {
  // Drop leading and trailing blank quote lines (`>` on its own).
  var start = 0;
  var end = lines.length;
  while (start < end && lines[start].trim().isEmpty) {
    start++;
  }
  while (end > start && lines[end - 1].trim().isEmpty) {
    end--;
  }
  final body = lines.sublist(start, end);
  if (body.isEmpty) return const AnswerBlock.quote('');

  final first = body.first;
  final whole = _kickerLine.firstMatch(first);
  if (whole != null) {
    return AnswerBlock.quote(
      body.skip(1).join('\n').trim(),
      kicker: whole.group(1)!.trim(),
    );
  }
  // Mid-stream, a lone first line that has opened `**` and not closed it is a
  // kicker being written — show it as one rather than as bold body text that
  // then jumps into the kicker slot.
  if (streaming && body.length == 1) {
    final open = _kickerOpen.firstMatch(first);
    if (open != null) {
      return AnswerBlock.quote('', kicker: open.group(1)!.trim());
    }
  }
  return AnswerBlock.quote(body.join('\n'));
}

/// A run of text sharing one style.
class InlineRun {
  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  bool sameStyle(InlineRun other) =>
      bold == other.bold && italic == other.italic && code == other.code;

  @override
  bool operator ==(Object other) =>
      other is InlineRun && other.text == text && sameStyle(other);

  @override
  int get hashCode => Object.hash(text, bold, italic, code);

  @override
  String toString() =>
      'InlineRun("$text"${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${code ? ', code' : ''})';
}

bool _isSpace(String c) => c.trim().isEmpty;
bool _isWord(String c) => RegExp(r'[A-Za-z0-9]').hasMatch(c);

/// Resolve `**bold**`, `__bold__`, `*italic*`, `_italic_` and `` `code` ``.
///
/// While [streaming], an opener with no closer yet styles the rest of the text
/// as though it had closed, with its marker hidden — so `**down 12` reads as
/// bold "down 12" and becomes exactly that when `.4%**` lands. When not
/// streaming, the same unclosed marker is printed literally, because the model
/// is done and that character is what it wrote.
List<InlineRun> parseInline(String text, {required bool streaming}) {
  final runs = <InlineRun>[];
  _parseInto(runs, text, streaming: streaming);
  // Merge neighbours of the same style, so the widget tree does not carry a
  // span per marker boundary.
  final merged = <InlineRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (merged.isNotEmpty && merged.last.sameStyle(run)) {
      final last = merged.removeLast();
      merged.add(InlineRun(
        last.text + run.text,
        bold: run.bold,
        italic: run.italic,
        code: run.code,
      ));
    } else {
      merged.add(run);
    }
  }
  return merged;
}

void _parseInto(
  List<InlineRun> out,
  String text, {
  required bool streaming,
  bool bold = false,
  bool italic = false,
}) {
  final buffer = StringBuffer();
  void emit() {
    if (buffer.isEmpty) return;
    out.add(InlineRun(buffer.toString(), bold: bold, italic: italic));
    buffer.clear();
  }

  var i = 0;
  while (i < text.length) {
    final c = text[i];
    final atEnd = i == text.length - 1;

    if (c == '`') {
      final close = text.indexOf('`', i + 1);
      if (close != -1) {
        emit();
        out.add(InlineRun(text.substring(i + 1, close),
            bold: bold, italic: italic, code: true));
        i = close + 1;
        continue;
      }
      if (streaming) {
        emit();
        out.add(InlineRun(text.substring(i + 1),
            bold: bold, italic: italic, code: true));
        return;
      }
      buffer.write(c);
      i++;
      continue;
    }

    if ((c == '*' || c == '_') && i + 1 < text.length && text[i + 1] == c) {
      final marker = '$c$c';
      final after = i + 2 < text.length ? text[i + 2] : '';
      if (after.isEmpty && streaming) {
        // `**` at the very end: the start of something not yet written.
        emit();
        return;
      }
      if (after.isNotEmpty && !_isSpace(after)) {
        final close = _findCloser(text, marker, i + 2);
        if (close != -1) {
          emit();
          _parseInto(out, text.substring(i + 2, close),
              streaming: streaming, bold: true, italic: italic);
          i = close + 2;
          continue;
        }
        if (streaming) {
          emit();
          _parseInto(out, text.substring(i + 2),
              streaming: streaming, bold: true, italic: italic);
          return;
        }
      }
      buffer.write(marker);
      i += 2;
      continue;
    }

    if (c == '*' || c == '_') {
      final before = i > 0 ? text[i - 1] : '';
      final after = atEnd ? '' : text[i + 1];
      if (after.isEmpty && streaming && (c == '*' || !_isWord(before))) {
        // A trailing `*` may be the first half of `**`.
        emit();
        return;
      }
      // `_` inside a word (snake_case) is never emphasis.
      final opens = after.isNotEmpty &&
          !_isSpace(after) &&
          (c == '*' || before.isEmpty || !_isWord(before));
      if (opens) {
        final close = _findCloser(text, c, i + 1);
        if (close != -1) {
          emit();
          _parseInto(out, text.substring(i + 1, close),
              streaming: streaming, bold: bold, italic: true);
          i = close + 1;
          continue;
        }
        if (streaming) {
          emit();
          _parseInto(out, text.substring(i + 1),
              streaming: streaming, bold: bold, italic: true);
          return;
        }
      }
      buffer.write(c);
      i++;
      continue;
    }

    buffer.write(c);
    i++;
  }
  emit();
}

/// The index of a closing [marker] at or after [from]: preceded by a
/// non-space, and for a single `*`/`_` not part of a doubled marker.
int _findCloser(String text, String marker, int from) {
  final single = marker.length == 1;
  var at = text.indexOf(marker, from);
  while (at != -1) {
    // Content between the markers is required: `**` then `**` is not bold.
    if (at > from) {
      final before = text[at - 1];
      final next = at + marker.length < text.length
          ? text[at + marker.length]
          : '';
      final doubled = single && (next == marker || before == marker);
      final underscoreInWord = marker.startsWith('_') && _isWord(next);
      if (!_isSpace(before) && !doubled && !underscoreInWord) return at;
    }
    at = text.indexOf(marker, at + marker.length);
  }
  return -1;
}

/// Everything in [text] a reader would see, markers removed — for tests and
/// for accessibility labels.
String plainInline(String text, {required bool streaming}) =>
    parseInline(text, streaming: streaming).map((r) => r.text).join();
