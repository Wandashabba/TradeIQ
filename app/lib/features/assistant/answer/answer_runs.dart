import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import 'answer_markdown.dart';

/// THE FIGURE RULE — every digit run in prose is set in JetBrains Mono.
///
/// The owner's decision is that Onest never renders a figure, and this is
/// where that becomes a real, testable thing rather than a sentence in a
/// document. Onest has no slashed zero, proportional digits, and an identical
/// capital I and lowercase l; at 13px through glare at 40% backlight that is
/// the difference between reading `0` and reading `O`.
///
/// A figure run is the whole number token: its sign (U+2212, never a hyphen),
/// its grouping and decimal marks — locale-driven, so Afrikaans `1 284 990,5`
/// holds together as one run — a leading `R`, and a trailing `%`, `pt` or
/// `pts`. A word that merely contains digits ("Stage 6", "U-Save 2") gives up
/// the digit run alone and keeps its letters in Onest.
///
/// ## The performance constraint that made this a separate file
///
/// The previous build called `parseInline` on **every build of every block**,
/// and a build happens on every token of a streaming answer. That is linear
/// per frame over a growing buffer, which is quadratic over a turn — and this
/// rule adds a character scan on top of it. So a settled block's runs are
/// computed once and cached; only the tail block, which is still growing, is
/// re-scanned.
@immutable
class AnswerRun {
  const AnswerRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.figure = false,
  });

  final String text;
  final bool bold;
  final bool italic;

  /// Inline code — a mono wash, and never re-scanned for figures: a number
  /// inside a code span is already mono and already someone else's literal.
  final bool code;

  /// A number token. Mono at 0.94em of the surrounding role, letterSpacing 0.
  final bool figure;

  @override
  bool operator ==(Object other) =>
      other is AnswerRun &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code &&
      other.figure == figure;

  @override
  int get hashCode => Object.hash(text, bold, italic, code, figure);

  @override
  String toString() =>
      'AnswerRun("$text"'
      '${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${code ? ', code' : ''}${figure ? ', figure' : ''})';
}

/// A number token in running prose.
///
/// Anchored on a digit, so a bare `R` or a stray `%` is language. The grouping
/// class carries the four separators this app can emit — `,` `.` and both the
/// no-break and narrow no-break spaces `TiqNumber` groups Afrikaans with — and
/// each of them must be followed by another digit, so "3 of 11" is two runs
/// and not one.
final RegExp _figureToken = RegExp(
  r'(?:R[  ]?)?'
  r'[−+-]?'
  r'\d+(?:[.,   ]\d+)*'
  r'(?:[  ]?(?:%|pts|pt))?',
);

/// Settled blocks, by their exact text. A settled block never changes, so its
/// runs never do either.
final Map<String, List<AnswerRun>> _settled = <String, List<AnswerRun>>{};

/// Enough for a long session's worth of blocks and small enough that a
/// runaway transcript cannot grow it without bound.
const int _settledCacheLimit = 512;

/// Clear the memo. For tests — nothing in the app needs this, because a
/// settled block's runs are a pure function of its text.
@visibleForTesting
void clearAnswerRunCache() => _settled.clear();

/// [text]'s runs, with the figure rule applied.
///
/// While [streaming] the result is not cached: the tail block is the only one
/// that grows, and caching it would mean a cache entry per token.
List<AnswerRun> answerRuns(String text, {required bool streaming}) {
  if (!streaming) {
    final hit = _settled[text];
    if (hit != null) return hit;
  }
  final out = <AnswerRun>[];
  for (final run in parseInline(text, streaming: streaming)) {
    if (run.code) {
      out.add(
        AnswerRun(run.text, bold: run.bold, italic: run.italic, code: true),
      );
      continue;
    }
    var at = 0;
    for (final match in _figureToken.allMatches(run.text)) {
      // A token whose only digits are inside a word ("KC-0412") still splits
      // on the digit run, which is what the rule asks for: the letters stay
      // in Onest and the digits go mono.
      if (match.start > at) {
        out.add(
          AnswerRun(
            run.text.substring(at, match.start),
            bold: run.bold,
            italic: run.italic,
          ),
        );
      }
      out.add(
        AnswerRun(
          match.group(0)!,
          bold: run.bold,
          italic: run.italic,
          figure: true,
        ),
      );
      at = match.end;
    }
    if (at < run.text.length) {
      out.add(
        AnswerRun(run.text.substring(at), bold: run.bold, italic: run.italic),
      );
    }
  }
  if (!streaming) {
    if (_settled.length >= _settledCacheLimit) _settled.clear();
    _settled[text] = out;
  }
  return out;
}

/// [runs] as spans, set against [base].
///
/// A **bold run is weight only**. The old build lifted bold runs in the
/// headline into the accent; amber is emitted light and never a word, so that
/// is gone and nothing here takes a colour from emphasis.
List<InlineSpan> answerSpans(
  List<AnswerRun> runs, {
  required TiqSkin skin,
  required TextStyle base,
}) {
  final size = base.fontSize ?? skin.text.body.size;
  return <InlineSpan>[
    for (final run in runs)
      TextSpan(
        text: run.text,
        style: run.figure || run.code
            ? base.copyWith(
                fontFamily: TiqFonts.mono,
                fontFamilyFallback: TiqFonts.monoFallback,
                // 0.94em of the surrounding role lands mono's larger x-height
                // on the same optical size as the Onest around it. Veld takes
                // 1.00em instead: glare eats counters, and out there the size
                // step matters more than the optical match.
                fontSize: size * (skin.mode == SkinMode.veld ? 1.0 : 0.94),
                letterSpacing: 0,
                fontWeight: run.bold ? FontWeight.w700 : null,
                fontStyle: run.italic ? FontStyle.italic : null,
                backgroundColor: run.code ? skin.palette.well : null,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              )
            : base.copyWith(
                fontWeight: run.bold ? FontWeight.w700 : null,
                fontStyle: run.italic ? FontStyle.italic : null,
              ),
      ),
  ];
}
